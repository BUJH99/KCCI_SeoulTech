from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from types import SimpleNamespace

SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import run_instr_mem_sweep as sweep
from generate_instr_mem import NOP, generate, metadata_for_program, sha256_words
from make_summary import REQUIRED_SIZE_BYTES, required_coverage_rows


REQUIRED_SIZES = list(REQUIRED_SIZE_BYTES)


def test_mixed_firmware_prefix_stability_tail_not_nop_and_position_dependent() -> None:
    words_4kb = generate("mixed_firmware", 4096)
    words_5kb = generate("mixed_firmware", 5120)
    words_8kb = generate("mixed_firmware", 8192)
    meta = metadata_for_program("mixed_firmware")

    assert words_5kb[: len(words_4kb)] == words_4kb
    assert any(word != NOP for word in words_5kb[1024:])
    assert words_4kb[-12:] != words_8kb[-12:]
    assert meta.tail_position_dependent is True
    assert meta.content_classification == "mixed_content_expansion"
    assert meta.wns_valid_for_pure_size_scaling is False


def test_ifetch_capacity_nop_all_nop_tail_and_adjacent_prefix() -> None:
    words_4kb = generate("ifetch_capacity_nop", 4096)
    words_5kb = generate("ifetch_capacity_nop", 5120)

    assert words_5kb[: len(words_4kb)] == words_4kb
    assert all(word == NOP for word in words_5kb[1024:])
    assert len(words_5kb) - len(words_4kb) == 256
    assert metadata_for_program("ifetch_capacity_nop").wns_valid_for_pure_size_scaling is True


def test_ifetch_capacity_nop_generates_4kb_to_32kb_prefixes_and_nop_tails() -> None:
    previous_words = None
    for size_bytes in REQUIRED_SIZES:
        words = generate("ifetch_capacity_nop", size_bytes)
        assert len(words) == size_bytes // 4
        assert len(words) in range(1024, 8193, 256)
        assert all(word == NOP for word in words[1024:])
        if previous_words is not None:
            assert words[: len(previous_words)] == previous_words
            assert len(words) - len(previous_words) == 256
        previous_words = words


def test_ifetch_capacity_prbs_fixed_seed_reproducibility_and_prefix() -> None:
    words_5kb_a = generate("ifetch_capacity_prbs", 5120)
    words_5kb_b = generate("ifetch_capacity_prbs", 5120)
    words_6kb = generate("ifetch_capacity_prbs", 6144)
    meta = metadata_for_program("ifetch_capacity_prbs")

    assert words_5kb_a == words_5kb_b
    assert words_6kb[: len(words_5kb_a)] == words_5kb_a
    assert len(words_6kb) - len(words_5kb_a) == 256
    assert meta.filler_seed is not None
    assert meta.tail_is_fixed_seed_filler is True
    assert any(word != NOP for word in words_5kb_a[1024:])


def test_ifetch_capacity_prbs_generates_4kb_to_32kb_fixed_seed_prefixes() -> None:
    canonical = generate("ifetch_capacity_prbs", 32768)
    previous_words = None
    for size_bytes in REQUIRED_SIZES:
        words_a = generate("ifetch_capacity_prbs", size_bytes)
        words_b = generate("ifetch_capacity_prbs", size_bytes)
        assert words_a == words_b
        assert words_a == canonical[: size_bytes // 4]
        assert len(words_a) == size_bytes // 4
        if size_bytes > 4096:
            assert any(word != NOP for word in words_a[1024:])
        if previous_words is not None:
            assert words_a[: len(previous_words)] == previous_words
            assert len(words_a) - len(previous_words) == 256
        previous_words = words_a


def _case(tmp_path: Path, program: str, ifetch_build_mode: str, size_bytes: int = 5120) -> sweep.SweepCase:
    exec_region = sweep.default_exec_region_for_build_mode(ifetch_build_mode)
    cid = sweep.case_id("lutrom_direct", size_bytes, program, exec_region, ifetch_build_mode)
    return sweep.SweepCase(
        case_id=cid,
        variant={"id": "lutrom_direct", "instr_mem_impl": "distributed", "latency": 0, "prefetch_depth": 0},
        size_bytes=size_bytes,
        program=program,
        exec_region=exec_region,
        ifetch_build_mode=ifetch_build_mode,
        vivado_level="route",
    )


def _config() -> dict[str, object]:
    return {
        "project": {
            "top": "TOP",
            "part": "xc7a35tcpg236-1",
            "strategy": "Default",
            "clock_period_ns": 40.0,
            "xdc": [],
        },
        "run": {"target_retires": 64, "max_cycles": 1024},
    }


def _matrix_config() -> dict[str, object]:
    return {
        "variants": [
            {"id": "lutrom_direct", "instr_mem_impl": "distributed", "latency": 0, "prefetch_depth": 0},
            {"id": "bram_sync", "instr_mem_impl": "block", "latency": 1, "prefetch_depth": 0},
        ],
        "timing_characterization_sizes_bytes": list(REQUIRED_SIZES),
        "sizes_bytes": [4096, 8192],
        "programs": ["ifetch_capacity_nop", "ifetch_capacity_prbs", "mixed_firmware"],
        "execution_regions": ["auto"],
        "ifetch_build_modes": ["bootrom_only", "programram_only"],
        "pure_capacity": {
            "variants": ["lutrom_direct"],
            "sizes_bytes": list(REQUIRED_SIZES),
            "programs": ["ifetch_capacity_nop", "ifetch_capacity_prbs"],
            "execution_regions": ["auto"],
            "ifetch_build_modes": ["bootrom_only", "programram_only"],
        },
    }


def _args(**overrides):
    defaults = {
        "mode": "full",
        "vivado_level": "route",
        "only_variant": [],
        "only_size": [],
        "only_program": [],
        "only_ifetch_build_mode": [],
        "only_exec_region": [],
        "force_case": [],
        "run_seed": [],
        "placer_seed": [],
        "router_seed": [],
        "size_kb_min": None,
        "size_kb_max": None,
        "size_kb_step": None,
    }
    defaults.update(overrides)
    return SimpleNamespace(**defaults)


def test_cli_filters_select_4kb_to_32kb_1kb_step_for_one_program_and_build_mode() -> None:
    cases = sweep.select_matrix(
        _matrix_config(),
        _args(
            only_variant=["lutrom_direct"],
            only_program=["ifetch_capacity_nop"],
            only_ifetch_build_mode=["bootrom_only"],
            size_kb_min=4,
            size_kb_max=32,
            size_kb_step=1,
        ),
    )

    assert len(cases) == 29
    assert [case.size_bytes for case in cases] == REQUIRED_SIZES
    assert all(case.program == "ifetch_capacity_nop" for case in cases)
    assert all(case.ifetch_build_mode == "bootrom_only" for case in cases)
    assert cases[0].case_id == "lutrom_direct__4kb__ifetch_capacity_nop__bootrom_only"
    assert cases[-1].case_id == "lutrom_direct__32kb__ifetch_capacity_nop__bootrom_only"


def test_pure_capacity_preset_selects_required_116_cases() -> None:
    cases = sweep.select_matrix(_matrix_config(), _args(mode="pure_capacity"))

    assert len(cases) == 116
    assert {case.program for case in cases} == {"ifetch_capacity_nop", "ifetch_capacity_prbs"}
    assert {case.ifetch_build_mode for case in cases} == {"bootrom_only", "programram_only"}
    assert {case.size_bytes for case in cases} == set(REQUIRED_SIZES)


def test_write_case_inputs_mem_line_count_sha_policy_and_depth_defines(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(sweep, "OUTPUT_ROOT", tmp_path / "out")
    case = _case(tmp_path, "ifetch_capacity_nop", sweep.LP_BUILD_BOOTROM_ONLY, 5120)

    manifest_path = sweep.write_case_inputs(case, _config(), run_vivado=True, run_xsim=True)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    content = manifest["content_validation"]
    generated = manifest_path.parent
    boot_words = [int(line, 16) for line in (generated / "boot_image.mem").read_text(encoding="ascii").splitlines()]
    program_words = [int(line, 16) for line in (generated / "program_image.mem").read_text(encoding="ascii").splitlines()]
    defines = (generated / "sweep_defines.svh").read_text(encoding="ascii")

    assert len(boot_words) == 1280
    assert len(program_words) == sweep.LP_FIXED_IMAGE_DEPTH_WORDS
    assert content["actual_boot_line_count"] == 1280
    assert content["actual_program_line_count"] == sweep.LP_FIXED_IMAGE_DEPTH_WORDS
    assert content["boot_image_sha256"] == sha256_words(boot_words)
    assert content["program_image_sha256"] == sha256_words(program_words)
    assert content["boot_image_policy"] == sweep.LP_POLICY_VARIABLE
    assert content["program_image_policy"] == sweep.LP_POLICY_FIXED_NOP
    assert content["boot_prefix_preserved_from_previous_size"] is True
    assert content["program_prefix_preserved_from_previous_size"] is True
    assert content["content_classification"] == "pure_same_program_capacity"
    assert content["wns_valid_for_pure_size_scaling"] is True
    assert content["boot_program_same_image"] is False
    assert content["boot_tail_type"] == "nop"
    assert content["boot_tail_is_all_nop"] is True
    assert "`define INSTR_SWEEP_BOOT_DEPTH_WORDS 1280" in defines
    assert "`define INSTR_SWEEP_PROGRAM_DEPTH_WORDS 32" in defines
    assert "`define INSTR_SWEEP_BOOT_ADDR_WIDTH 11" in defines
    assert "`define INSTR_SWEEP_PROGRAM_ADDR_WIDTH 5" in defines
    assert "`define INSTR_SWEEP_PROGRAM_READ_ONLY_INIT 1" in defines
    assert manifest["boot_depth_words"] == manifest["depth_words"] == 1280
    assert manifest["program_depth_words"] == sweep.LP_FIXED_IMAGE_DEPTH_WORDS
    assert manifest["program_read_only_init"] == 1
    assert manifest["boot_addr_width"] == 11
    assert manifest["program_addr_width"] == 5
    assert re.search(r"P_BOOT_DEPTH_WORDS=\$boot_depth_words", (SCRIPT_DIR / "vivado_sweep.tcl").read_text(encoding="utf-8"))
    assert re.search(r"P_PROGRAM_DEPTH_WORDS=\$program_depth_words", (SCRIPT_DIR / "vivado_sweep.tcl").read_text(encoding="utf-8"))
    assert re.search(r"P_PROGRAM_READ_ONLY_INIT=\$program_read_only_init", (SCRIPT_DIR / "vivado_sweep.tcl").read_text(encoding="utf-8"))


def test_programram_only_policy_separates_boot_trampoline_from_variable_program(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(sweep, "OUTPUT_ROOT", tmp_path / "out")
    case = _case(tmp_path, "ifetch_capacity_prbs", sweep.LP_BUILD_PROGRAMRAM_ONLY, 6144)

    manifest_path = sweep.write_case_inputs(case, _config(), run_vivado=True, run_xsim=False)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    content = manifest["content_validation"]

    assert manifest["case"]["exec_region"] == sweep.LP_EXEC_REGION_PROGRAM_RAM
    assert content["ifetch_build_mode"] == sweep.LP_BUILD_PROGRAMRAM_ONLY
    assert content["boot_image_policy"] == sweep.LP_POLICY_TRAMPOLINE
    assert content["program_image_policy"] == sweep.LP_POLICY_VARIABLE
    assert content["actual_boot_line_count"] == sweep.LP_FIXED_IMAGE_DEPTH_WORDS
    assert content["actual_program_line_count"] == 1536
    assert manifest["boot_depth_words"] == sweep.LP_FIXED_IMAGE_DEPTH_WORDS
    assert manifest["program_depth_words"] == 1536
    assert manifest["program_read_only_init"] == 1
    assert manifest["boot_addr_width"] == 5
    assert manifest["program_addr_width"] == 11
    assert content["boot_program_same_image"] is False
    assert content["program_tail_is_fixed_seed_filler"] is True
    assert content["program_tail_type"] == "fixed_seed_filler"
    assert content["wns_valid_for_pure_size_scaling"] is True
    assert content["boot_tail_type"] == "fixed_trampoline_nop"


def test_duplicated_stress_is_not_pure_kpi_valid(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(sweep, "OUTPUT_ROOT", tmp_path / "out")
    case = _case(tmp_path, "mixed_firmware", sweep.LP_BUILD_DUPLICATED_STRESS, 5120)

    manifest_path = sweep.write_case_inputs(case, _config(), run_vivado=True, run_xsim=False)
    content = json.loads(manifest_path.read_text(encoding="utf-8"))["content_validation"]

    assert content["ifetch_build_mode"] == sweep.LP_BUILD_DUPLICATED_STRESS
    assert content["content_classification"] == "mixed_content_expansion"
    assert content["boot_program_same_image"] is True
    assert content["wns_valid_for_pure_size_scaling"] is False
    assert content["wns_valid_for_workload_stress"] is True


def _summary_row(program: str, build_mode: str, size_bytes: int, *, pure_valid: bool = True) -> dict[str, object]:
    return {
        "case_id": sweep.case_id("lutrom_direct", size_bytes, program, sweep.default_exec_region_for_build_mode(build_mode), build_mode),
        "variant": "lutrom_direct",
        "benchmark_mode": program,
        "program": program,
        "ifetch_build_mode": build_mode,
        "size_bytes": size_bytes,
        "vivado_level": "route",
        "status": "pass",
        "overall_wns": 1.0,
        "wns_valid_for_pure_size_scaling": pure_valid,
        "parse_error_count": 0,
    }


def test_required_coverage_checker_passes_all_four_29_case_groups() -> None:
    rows = [
        _summary_row(program, build_mode, size_bytes)
        for program in ("ifetch_capacity_nop", "ifetch_capacity_prbs")
        for build_mode in ("bootrom_only", "programram_only")
        for size_bytes in REQUIRED_SIZES
    ]

    coverage = required_coverage_rows(rows)

    assert len(coverage) == 4
    assert all(row["expected_cases"] == 29 for row in coverage)
    assert all(row["actual_cases"] == 29 for row in coverage)
    assert all(row["missing_sizes"] == "" for row in coverage)
    assert all(row["all_routed"] is True for row in coverage)
    assert all(row["all_pure_kpi_valid"] is True for row in coverage)
    assert all(row["pass_fail"] == "PASS" for row in coverage)


def test_required_coverage_checker_fails_when_5kb_or_31kb_missing() -> None:
    rows = [
        _summary_row("ifetch_capacity_nop", "bootrom_only", size_bytes)
        for size_bytes in REQUIRED_SIZES
        if size_bytes not in {5 * 1024, 31 * 1024}
    ]

    coverage = required_coverage_rows(rows)
    nop_boot = next(row for row in coverage if row["benchmark_mode"] == "ifetch_capacity_nop" and row["ifetch_build_mode"] == "bootrom_only")

    assert nop_boot["actual_cases"] == 27
    assert "5KB" in nop_boot["missing_sizes"]
    assert "31KB" in nop_boot["missing_sizes"]
    assert nop_boot["pass_fail"] == "FAIL"
