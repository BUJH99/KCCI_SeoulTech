#!/usr/bin/env python3
"""Run the InstrRom/ProgramRam implementation sweep end to end."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from itertools import product
from pathlib import Path
from typing import Any

import yaml

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[2]
OUTPUT_ROOT = PROJECT_ROOT / "output" / "instr_mem_sweep"

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from generate_instr_mem import (  # noqa: E402
    NOP,
    generate,
    jal,
    metadata_for_program,
    sha256_words,
    write_mem,
)
from make_html_report import main as make_html_report_main  # noqa: E402
from make_summary import main as make_summary_main  # noqa: E402
from parse_vivado_reports import parse_case  # noqa: E402

LP_PROGRAM_RAM_BASE = 0x1000
LP_EXEC_REGION_BOOT = "boot"
LP_EXEC_REGION_PROGRAM_RAM = "program_ram"

LP_BUILD_BOOTROM_ONLY = "bootrom_only"
LP_BUILD_PROGRAMRAM_ONLY = "programram_only"
LP_BUILD_COMBINED_REAL = "combined_real"
LP_BUILD_DUPLICATED_STRESS = "duplicated_stress"
LP_BUILD_MODES = {
    LP_BUILD_BOOTROM_ONLY,
    LP_BUILD_PROGRAMRAM_ONLY,
    LP_BUILD_COMBINED_REAL,
    LP_BUILD_DUPLICATED_STRESS,
}
LP_REQUIRED_SIZE_KB_MIN = 4
LP_REQUIRED_SIZE_KB_MAX = 32
LP_REQUIRED_SIZE_KB_STEP = 1
LP_FIXED_IMAGE_DEPTH_WORDS = 32

LP_POLICY_VARIABLE = "variable_benchmark_image"
LP_POLICY_FIXED_NOP = "fixed_minimal_nop_image"
LP_POLICY_TRAMPOLINE = "fixed_trampoline_to_program_ram"
LP_POLICY_DUPLICATED = "same_variable_benchmark_image"


@dataclass(frozen=True)
class SweepCase:
    case_id: str
    variant: dict[str, Any]
    size_bytes: int
    program: str
    exec_region: str
    ifetch_build_mode: str
    vivado_level: str
    run_seed: int | None = None
    placer_seed: int | None = None
    router_seed: int | None = None

    @property
    def variant_id(self) -> str:
        return str(self.variant["id"])

    @property
    def addr_width(self) -> int:
        return addr_width_for_depth(self.depth_words)

    @property
    def depth_words(self) -> int:
        return self.size_bytes // 4

    @property
    def boot_depth_words(self) -> int:
        return memory_depths_for_case(self.size_bytes, self.ifetch_build_mode)[0]

    @property
    def program_depth_words(self) -> int:
        return memory_depths_for_case(self.size_bytes, self.ifetch_build_mode)[1]

    @property
    def boot_addr_width(self) -> int:
        return addr_width_for_depth(self.boot_depth_words)

    @property
    def program_addr_width(self) -> int:
        return addr_width_for_depth(self.program_depth_words)

    @property
    def mem_impl_int(self) -> int:
        return 1 if str(self.variant.get("instr_mem_impl")) == "block" else 0

    @property
    def is_power_of_two_depth(self) -> bool:
        depth = self.depth_words
        return depth > 0 and (depth & (depth - 1)) == 0


def addr_width_for_depth(depth_words: int) -> int:
    return max(1, (max(1, depth_words) - 1).bit_length())


def memory_depths_for_case(size_bytes: int, ifetch_build_mode: str) -> tuple[int, int]:
    variable_depth_words = size_bytes // 4
    fixed_depth_words = LP_FIXED_IMAGE_DEPTH_WORDS
    if ifetch_build_mode == LP_BUILD_BOOTROM_ONLY:
        return variable_depth_words, fixed_depth_words
    if ifetch_build_mode == LP_BUILD_PROGRAMRAM_ONLY:
        return fixed_depth_words, variable_depth_words
    if ifetch_build_mode == LP_BUILD_COMBINED_REAL:
        return fixed_depth_words, variable_depth_words
    if ifetch_build_mode == LP_BUILD_DUPLICATED_STRESS:
        return variable_depth_words, variable_depth_words
    raise ValueError(f"unsupported ifetch_build_mode: {ifetch_build_mode}")


def program_read_only_init_for_case(ifetch_build_mode: str) -> int:
    return 1 if ifetch_build_mode in {LP_BUILD_BOOTROM_ONLY, LP_BUILD_PROGRAMRAM_ONLY} else 0


def run(cmd: list[str], *, cwd: Path, allow_fail: bool = False) -> int:
    print("[RUN] " + " ".join(cmd))
    completed = subprocess.run(cmd, cwd=cwd)
    if completed.returncode != 0 and not allow_fail:
        raise SystemExit(completed.returncode)
    return completed.returncode


def git_commit() -> str:
    try:
        completed = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=PROJECT_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        return completed.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def default_exec_region_for_build_mode(ifetch_build_mode: str) -> str:
    if ifetch_build_mode in {LP_BUILD_PROGRAMRAM_ONLY, LP_BUILD_COMBINED_REAL}:
        return LP_EXEC_REGION_PROGRAM_RAM
    return LP_EXEC_REGION_BOOT


def case_id(
    variant: str,
    size_bytes: int,
    program: str,
    exec_region: str,
    ifetch_build_mode: str,
    *,
    run_seed: int | None = None,
    placer_seed: int | None = None,
    router_seed: int | None = None,
) -> str:
    parts = [variant, f"{size_bytes // 1024}kb", program, ifetch_build_mode]
    default_exec = default_exec_region_for_build_mode(ifetch_build_mode)
    if exec_region != default_exec:
        parts.append(exec_region)
    if run_seed is not None:
        parts.append(f"runseed{run_seed}")
    if placer_seed is not None:
        parts.append(f"placerseed{placer_seed}")
    if router_seed is not None:
        parts.append(f"routerseed{router_seed}")
    return "__".join(parts)


def load_config(path: Path) -> dict[str, Any]:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def selected_seed_tuples(args: argparse.Namespace, config: dict[str, Any]) -> list[tuple[int | None, int | None, int | None]]:
    run_cfg = dict(config.get("run", {}))
    run_seeds = args.run_seed or list(run_cfg.get("run_seeds", [])) or [None]
    placer_seeds = args.placer_seed or list(run_cfg.get("placer_seeds", [])) or [None]
    router_seeds = args.router_seed or list(run_cfg.get("router_seeds", [])) or [None]
    return [(run_seed, placer_seed, router_seed) for run_seed, placer_seed, router_seed in product(run_seeds, placer_seeds, router_seeds)]


def select_matrix(config: dict[str, Any], args: argparse.Namespace) -> list[SweepCase]:
    variants = list(config["variants"])
    by_variant = {str(item["id"]): item for item in variants}
    if args.mode == "fast":
        mode_cfg = dict(config.get("fast", {}))
        variant_ids = list(mode_cfg.get("variants", [item["id"] for item in variants]))
        sizes = list(mode_cfg.get("sizes_bytes", config["sizes_bytes"]))
        programs = list(mode_cfg.get("programs", config["programs"]))
        ifetch_build_modes = list(mode_cfg.get("ifetch_build_modes", config.get("ifetch_build_modes", [LP_BUILD_BOOTROM_ONLY])))
        exec_regions = list(mode_cfg.get("execution_regions", config.get("execution_regions", ["auto"])))
    elif args.mode == "pure_capacity":
        mode_cfg = dict(config.get("pure_capacity", {}))
        variant_ids = list(mode_cfg.get("variants", ["lutrom_direct"]))
        sizes = list(
            mode_cfg.get(
                "sizes_bytes",
                [kb * 1024 for kb in range(LP_REQUIRED_SIZE_KB_MIN, LP_REQUIRED_SIZE_KB_MAX + 1, LP_REQUIRED_SIZE_KB_STEP)],
            )
        )
        programs = list(mode_cfg.get("programs", ["ifetch_capacity_nop", "ifetch_capacity_prbs"]))
        ifetch_build_modes = list(mode_cfg.get("ifetch_build_modes", [LP_BUILD_BOOTROM_ONLY, LP_BUILD_PROGRAMRAM_ONLY]))
        exec_regions = list(mode_cfg.get("execution_regions", ["auto"]))
    else:
        variant_ids = [str(item["id"]) for item in variants]
        sizes = list(config.get("timing_characterization_sizes_bytes", config.get("full_sizes_bytes", config["sizes_bytes"])))
        programs = list(config["programs"])
        ifetch_build_modes = list(config.get("ifetch_build_modes", [LP_BUILD_BOOTROM_ONLY]))
        exec_regions = list(config.get("execution_regions", ["auto"]))

    if args.only_variant:
        requested = set(args.only_variant)
        variant_ids = [variant for variant in variant_ids if variant in requested]
    if args.only_size:
        requested_sizes = {int(size) for size in args.only_size}
        sizes = [size for size in sizes if int(size) in requested_sizes]
    if args.size_kb_min is not None or args.size_kb_max is not None or args.size_kb_step is not None:
        if not sizes and (args.size_kb_min is None or args.size_kb_max is None):
            raise SystemExit("[FAIL] size range needs --size-kb-min and --size-kb-max when no configured sizes remain")
        min_kb = args.size_kb_min if args.size_kb_min is not None else min(int(size) // 1024 for size in sizes)
        max_kb = args.size_kb_max if args.size_kb_max is not None else max(int(size) // 1024 for size in sizes)
        step_kb = args.size_kb_step if args.size_kb_step is not None else 1
        if min_kb <= 0 or max_kb <= 0:
            raise SystemExit("[FAIL] size KB range values must be positive")
        if step_kb <= 0:
            raise SystemExit("[FAIL] --size-kb-step must be positive")
        if min_kb > max_kb:
            raise SystemExit("[FAIL] --size-kb-min must be <= --size-kb-max")
        requested_sizes = {kb * 1024 for kb in range(min_kb, max_kb + 1, step_kb)}
        sizes = [size for size in sizes if int(size) in requested_sizes]
    if args.only_program:
        requested_programs = set(args.only_program)
        programs = [program for program in programs if program in requested_programs]
    if args.only_ifetch_build_mode:
        ifetch_build_modes = list(args.only_ifetch_build_mode)
    if args.only_exec_region:
        exec_regions = list(args.only_exec_region)

    seed_tuples = selected_seed_tuples(args, config)
    cases: list[SweepCase] = []
    forced = set(args.force_case)
    for variant_id in variant_ids:
        if variant_id not in by_variant:
            raise SystemExit(f"[FAIL] Unknown variant in matrix: {variant_id}")
        for size in sizes:
            for program in programs:
                for ifetch_build_mode in ifetch_build_modes:
                    if ifetch_build_mode not in LP_BUILD_MODES:
                        raise SystemExit(f"[FAIL] Unknown ifetch_build_mode in matrix: {ifetch_build_mode}")
                    resolved_exec_regions = [
                        default_exec_region_for_build_mode(ifetch_build_mode) if region == "auto" else str(region)
                        for region in exec_regions
                    ]
                    for exec_region in resolved_exec_regions:
                        if exec_region not in {LP_EXEC_REGION_BOOT, LP_EXEC_REGION_PROGRAM_RAM}:
                            raise SystemExit(f"[FAIL] Unknown execution region in matrix: {exec_region}")
                        for run_seed, placer_seed, router_seed in seed_tuples:
                            cid = case_id(
                                variant_id,
                                int(size),
                                str(program),
                                str(exec_region),
                                str(ifetch_build_mode),
                                run_seed=run_seed,
                                placer_seed=placer_seed,
                                router_seed=router_seed,
                            )
                            if forced and cid not in forced:
                                continue
                            cases.append(
                                SweepCase(
                                    case_id=cid,
                                    variant=by_variant[variant_id],
                                    size_bytes=int(size),
                                    program=str(program),
                                    exec_region=str(exec_region),
                                    ifetch_build_mode=str(ifetch_build_mode),
                                    vivado_level=args.vivado_level,
                                    run_seed=run_seed,
                                    placer_seed=placer_seed,
                                    router_seed=router_seed,
                                )
                            )
    return cases


def render_template(template_name: str, replacements: dict[str, str]) -> str:
    text = (SCRIPT_DIR / "templates" / template_name).read_text(encoding="utf-8")
    for key, value in replacements.items():
        text = text.replace(f"@{key}@", value)
    return text


def case_dirs(case: SweepCase) -> dict[str, Path]:
    case_root = OUTPUT_ROOT / "cases" / case.case_id
    return {
        "case": case_root,
        "generated": case_root / "generated",
        "vivado": case_root / "vivado",
        "sim": case_root / "sim",
        "metrics": case_root / "metrics",
    }


def boot_trampoline_words(depth_words: int) -> list[int]:
    if depth_words <= 0:
        return []
    return [jal(0, LP_PROGRAM_RAM_BASE)] + [NOP] * (depth_words - 1)


def fixed_nop_words(depth_words: int) -> list[int]:
    return [NOP] * depth_words


def image_words_for_case(
    program: str,
    size_bytes: int,
    ifetch_build_mode: str,
) -> tuple[list[int], list[int], str, str]:
    variable_words = generate(program, size_bytes)
    boot_depth_words, program_depth_words = memory_depths_for_case(size_bytes, ifetch_build_mode)
    if ifetch_build_mode == LP_BUILD_BOOTROM_ONLY:
        return variable_words, fixed_nop_words(program_depth_words), LP_POLICY_VARIABLE, LP_POLICY_FIXED_NOP
    if ifetch_build_mode == LP_BUILD_PROGRAMRAM_ONLY:
        return boot_trampoline_words(boot_depth_words), variable_words, LP_POLICY_TRAMPOLINE, LP_POLICY_VARIABLE
    if ifetch_build_mode == LP_BUILD_COMBINED_REAL:
        return boot_trampoline_words(boot_depth_words), variable_words, LP_POLICY_TRAMPOLINE, LP_POLICY_VARIABLE
    if ifetch_build_mode == LP_BUILD_DUPLICATED_STRESS:
        return variable_words, list(variable_words), LP_POLICY_DUPLICATED, LP_POLICY_DUPLICATED
    raise ValueError(f"unsupported ifetch_build_mode: {ifetch_build_mode}")


def actual_mem_line_count(path: Path) -> int:
    if not path.exists():
        return 0
    return sum(1 for line in path.read_text(encoding="ascii").splitlines() if line.strip())


def tail_metadata_for_image(words: list[int], policy: str, program: str) -> dict[str, Any]:
    program_meta = metadata_for_program(program)
    if policy in {LP_POLICY_VARIABLE, LP_POLICY_DUPLICATED}:
        if program in {"ifetch_capacity_nop", "ifetch_capacity_prbs", "ifetch_capacity_toggle"}:
            tail = words[program_meta.filler_start_word :]
            return {
                "tail_type": program_meta.tail_type,
                "tail_is_all_nop": all(word == NOP for word in tail),
                "tail_is_fixed_seed_filler": program_meta.tail_is_fixed_seed_filler,
                "tail_position_dependent": program_meta.tail_position_dependent,
            }
        return {
            "tail_type": program_meta.tail_type,
            "tail_is_all_nop": all(word == NOP for word in words),
            "tail_is_fixed_seed_filler": program_meta.tail_is_fixed_seed_filler,
            "tail_position_dependent": program_meta.tail_position_dependent,
        }
    if policy == LP_POLICY_TRAMPOLINE:
        return {
            "tail_type": "fixed_trampoline_nop",
            "tail_is_all_nop": all(word == NOP for word in words[1:]),
            "tail_is_fixed_seed_filler": False,
            "tail_position_dependent": False,
        }
    return {
        "tail_type": "fixed_minimal_nop",
        "tail_is_all_nop": all(word == NOP for word in words),
        "tail_is_fixed_seed_filler": False,
        "tail_position_dependent": False,
    }


def variable_tail_valid(program: str, tail: dict[str, Any]) -> bool:
    if program == "ifetch_capacity_nop":
        return tail["tail_type"] == "nop" and bool(tail["tail_is_all_nop"])
    if program == "ifetch_capacity_prbs":
        return tail["tail_type"] == "fixed_seed_filler" and bool(tail["tail_is_fixed_seed_filler"])
    if program == "ifetch_capacity_toggle":
        return bool(tail["tail_type"]) and not bool(tail["tail_position_dependent"])
    return False


def image_prefix_preserved(
    case: SweepCase,
    *,
    image_name: str,
    current_words: list[int],
) -> bool:
    if case.size_bytes <= 4096:
        return True
    previous_size = case.size_bytes - 1024
    previous_boot, previous_program, _, _ = image_words_for_case(case.program, previous_size, case.ifetch_build_mode)
    previous_words = previous_boot if image_name == "boot" else previous_program
    return current_words[: len(previous_words)] == previous_words


def content_validation_metadata(
    case: SweepCase,
    boot_words: list[int],
    program_words: list[int],
    boot_policy: str,
    program_policy: str,
    boot_image_path: Path,
    program_image_path: Path,
) -> dict[str, Any]:
    program_meta = metadata_for_program(case.program, case.size_bytes)
    boot_tail = tail_metadata_for_image(boot_words, boot_policy, case.program)
    program_tail = tail_metadata_for_image(program_words, program_policy, case.program)
    build_mode_allows_pure = case.ifetch_build_mode != LP_BUILD_DUPLICATED_STRESS
    boot_sha = sha256_words(boot_words)
    program_sha = sha256_words(program_words)
    expected_boot_lines = case.boot_depth_words
    expected_program_lines = case.program_depth_words
    actual_boot_lines = actual_mem_line_count(boot_image_path)
    actual_program_lines = actual_mem_line_count(program_image_path)
    boot_prefix = image_prefix_preserved(case, image_name="boot", current_words=boot_words)
    program_prefix = image_prefix_preserved(case, image_name="program", current_words=program_words)
    line_counts_ok = actual_boot_lines == expected_boot_lines and actual_program_lines == expected_program_lines
    workload_valid = bool(program_meta.wns_valid_for_workload_stress)
    prefix_stable = bool(boot_prefix and program_prefix)
    boot_program_same = boot_sha == program_sha
    if boot_policy == LP_POLICY_VARIABLE:
        variable_tail_ok = variable_tail_valid(case.program, boot_tail)
    elif program_policy == LP_POLICY_VARIABLE:
        variable_tail_ok = variable_tail_valid(case.program, program_tail)
    else:
        variable_tail_ok = False
    pure_scaling_valid = bool(
        program_meta.wns_valid_for_pure_size_scaling
        and build_mode_allows_pure
        and line_counts_ok
        and prefix_stable
        and not boot_program_same
        and variable_tail_ok
    )
    return {
        "benchmark_mode": program_meta.benchmark_mode,
        "content_classification": program_meta.content_classification,
        "wns_valid_for_pure_size_scaling": pure_scaling_valid,
        "wns_valid_for_workload_stress": workload_valid,
        "executable_kernel_words": program_meta.executable_kernel_words,
        "filler_start_word": program_meta.filler_start_word,
        "filler_mode": program_meta.filler_mode,
        "filler_seed": program_meta.filler_seed,
        "ifetch_build_mode": case.ifetch_build_mode,
        "boot_image_policy": boot_policy,
        "program_image_policy": program_policy,
        "boot_program_same_image": boot_program_same,
        "boot_image_sha256": boot_sha,
        "program_image_sha256": program_sha,
        "boot_prefix_preserved_from_previous_size": boot_prefix,
        "program_prefix_preserved_from_previous_size": program_prefix,
        "prefix_stable": prefix_stable,
        "boot_tail_type": boot_tail["tail_type"],
        "program_tail_type": program_tail["tail_type"],
        "boot_tail_is_all_nop": boot_tail["tail_is_all_nop"],
        "program_tail_is_all_nop": program_tail["tail_is_all_nop"],
        "boot_tail_is_fixed_seed_filler": boot_tail["tail_is_fixed_seed_filler"],
        "program_tail_is_fixed_seed_filler": program_tail["tail_is_fixed_seed_filler"],
        "boot_tail_position_dependent": boot_tail["tail_position_dependent"],
        "program_tail_position_dependent": program_tail["tail_position_dependent"],
        "expected_boot_line_count": expected_boot_lines,
        "actual_boot_line_count": actual_boot_lines,
        "boot_line_count_ok": actual_boot_lines == expected_boot_lines,
        "expected_program_line_count": expected_program_lines,
        "actual_program_line_count": actual_program_lines,
        "program_line_count_ok": actual_program_lines == expected_program_lines,
        "depth_words": case.depth_words,
        "addr_width": case.addr_width,
        "boot_depth_words": case.boot_depth_words,
        "program_depth_words": case.program_depth_words,
        "boot_addr_width": case.boot_addr_width,
        "program_addr_width": case.program_addr_width,
        "program_read_only_init": program_read_only_init_for_case(case.ifetch_build_mode),
        "is_power_of_two_depth": case.is_power_of_two_depth,
        "depth_group": "power_of_two" if case.is_power_of_two_depth else "non_power_of_two",
        "has_depth_guard_comparator": True,
        "increment_words_from_previous_1kb": None if case.size_bytes <= 4096 else 256,
    }


def write_case_inputs(case: SweepCase, config: dict[str, Any], *, run_vivado: bool, run_xsim: bool) -> Path:
    dirs = case_dirs(case)
    for path in dirs.values():
        path.mkdir(parents=True, exist_ok=True)

    boot_words, program_words, boot_policy, program_policy = image_words_for_case(
        case.program,
        case.size_bytes,
        case.ifetch_build_mode,
    )
    boot_image_path = dirs["generated"] / "boot_image.mem"
    program_image_path = dirs["generated"] / "program_image.mem"
    write_mem(boot_image_path, boot_words)
    write_mem(program_image_path, program_words)
    content_meta = content_validation_metadata(
        case,
        boot_words,
        program_words,
        boot_policy,
        program_policy,
        boot_image_path,
        program_image_path,
    )

    run_cfg = dict(config.get("run", {}))
    replacements = {
        "CASE_ID": case.case_id,
        "BOOT_INIT_FILE": boot_image_path.as_posix(),
        "PROGRAM_INIT_FILE": program_image_path.as_posix(),
        "ADDR_WIDTH": str(case.addr_width),
        "BOOT_ADDR_WIDTH": str(case.boot_addr_width),
        "PROGRAM_ADDR_WIDTH": str(case.program_addr_width),
        "DEPTH_WORDS": str(case.depth_words),
        "BOOT_DEPTH_WORDS": str(case.boot_depth_words),
        "PROGRAM_DEPTH_WORDS": str(case.program_depth_words),
        "PROGRAM_READ_ONLY_INIT": str(program_read_only_init_for_case(case.ifetch_build_mode)),
        "MEM_IMPL": str(case.mem_impl_int),
        "MEM_LATENCY": str(int(case.variant.get("latency", 0))),
        "PREFETCH_DEPTH": str(int(case.variant.get("prefetch_depth", 0))),
        "TARGET_RETIRES": str(int(run_cfg.get("target_retires", 512))),
        "MAX_CYCLES": str(int(run_cfg.get("max_cycles", 20000))),
        "SIZE_BYTES": str(case.size_bytes),
        "EXEC_REGION": case.exec_region,
        "IFETCH_BUILD_MODE": case.ifetch_build_mode,
    }
    (dirs["generated"] / "sweep_defines.svh").write_text(
        render_template("sweep_defines.svh.in", replacements),
        encoding="ascii",
    )
    (dirs["generated"] / "instr_mem_variant_pkg.sv").write_text(
        render_template("instr_mem_variant_pkg.sv.in", replacements),
        encoding="ascii",
    )

    project_cfg = dict(config.get("project", {}))
    manifest = {
        "case": {
            "case_id": case.case_id,
            "variant": case.variant_id,
            "size_bytes": case.size_bytes,
            "depth_words": case.depth_words,
            "program": case.program,
            "benchmark_mode": content_meta["benchmark_mode"],
            "exec_region": case.exec_region,
            "ifetch_build_mode": case.ifetch_build_mode,
            "vivado_level": case.vivado_level,
            "run_seed": case.run_seed,
            "placer_seed": case.placer_seed,
            "router_seed": case.router_seed,
        },
        "project": {
            "root": str(PROJECT_ROOT),
            "top": project_cfg.get("top", "TOP"),
            "part": project_cfg.get("part", "xc7a35tcpg236-1"),
            "strategy": project_cfg.get("strategy", "Default"),
            "clock_period_ns": float(project_cfg.get("clock_period_ns", 40.0)),
            "xdc": project_cfg.get("xdc", []),
        },
        "variant": case.variant,
        "project_root": PROJECT_ROOT.as_posix(),
        "generated_dir": dirs["generated"].as_posix(),
        "vivado_dir": dirs["vivado"].as_posix(),
        "sim_dir": dirs["sim"].as_posix(),
        "boot_init_file": boot_image_path.as_posix(),
        "program_init_file": program_image_path.as_posix(),
        "init_file": boot_image_path.as_posix(),
        "addr_width": case.addr_width,
        "boot_addr_width": case.boot_addr_width,
        "program_addr_width": case.program_addr_width,
        "depth_words": case.depth_words,
        "boot_depth_words": case.boot_depth_words,
        "program_depth_words": case.program_depth_words,
        "program_read_only_init": program_read_only_init_for_case(case.ifetch_build_mode),
        "mem_impl": case.mem_impl_int,
        "mem_latency": int(case.variant.get("latency", 0)),
        "prefetch_depth": int(case.variant.get("prefetch_depth", 0)),
        "exec_region": case.exec_region,
        "ifetch_build_mode": case.ifetch_build_mode,
        "vivado_level": case.vivado_level,
        "run_seed": case.run_seed,
        "placer_seed": case.placer_seed,
        "router_seed": case.router_seed,
        "top": project_cfg.get("top", "TOP"),
        "part": project_cfg.get("part", "xc7a35tcpg236-1"),
        "clock_period_ns": float(project_cfg.get("clock_period_ns", 40.0)),
        "git_commit": git_commit(),
        "content_validation": content_meta,
        "run": {
            "vivado": run_vivado or (dirs["vivado"] / "status.json").exists(),
            "xsim": run_xsim,
        },
    }
    manifest_path = dirs["generated"] / "case_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest_path


def completed(case: SweepCase, *, run_vivado: bool, run_xsim: bool) -> bool:
    dirs = case_dirs(case)
    manifest_ok = (dirs["generated"] / "case_manifest.json").exists()
    vivado_ok = True
    sim_ok = True
    if run_vivado:
        status_path = dirs["vivado"] / "status.json"
        vivado_ok = False
        if status_path.exists():
            try:
                status = json.loads(status_path.read_text(encoding="utf-8"))
                status_level = status.get("vivado_level")
                if case.vivado_level == "route":
                    vivado_ok = status.get("status") == "pass" and status_level == "route"
                else:
                    vivado_ok = status.get("status") == "pass" and status_level in (None, "synth_only")
            except json.JSONDecodeError:
                vivado_ok = False
    if run_xsim:
        sim_ok = (dirs["sim"] / "counters.json").exists()
    return manifest_ok and vivado_ok and sim_ok


def ensure_tools(tool_names: list[str]) -> None:
    missing = [tool for tool in tool_names if shutil.which(tool) is None]
    if missing:
        raise SystemExit(f"[FAIL] Missing tool(s) on PATH: {', '.join(missing)}")


def tool_path(tool_name: str) -> str:
    resolved = shutil.which(tool_name)
    if resolved is None:
        raise SystemExit(f"[FAIL] Missing tool on PATH: {tool_name}")
    return resolved


def source_files_for_xsim() -> tuple[list[Path], list[Path]]:
    package_names = {"rv32i_pkg.sv", "sort_demo_pkg.sv", "soc_addr_pkg.sv"}
    package_files = [PROJECT_ROOT / "src" / name for name in ["rv32i_pkg.sv", "sort_demo_pkg.sv", "soc_addr_pkg.sv"]]
    package_files = [path for path in package_files if path.exists()]
    rtl_files = sorted(path for path in (PROJECT_ROOT / "src").rglob("*.sv") if path.name not in package_names)
    return package_files, rtl_files


def clean_sim_work(sim_dir: Path) -> None:
    sim_dir.mkdir(parents=True, exist_ok=True)
    for name in ["xsim.dir", ".Xil"]:
        target = sim_dir / name
        if target.exists():
            shutil.rmtree(target)
    for pattern in ["*.log", "*.jou", "*.pb", "counters.json"]:
        for path in sim_dir.glob(pattern):
            if path.is_file():
                path.unlink()


def clean_vivado_work(vivado_dir: Path) -> None:
    vivado_dir.mkdir(parents=True, exist_ok=True)
    xil_dir = vivado_dir / ".Xil"
    if xil_dir.exists():
        shutil.rmtree(xil_dir)
    for pattern in ["*.jou", "*.log", "*.rpt", "*.json", "*.txt", "*.dcp"]:
        for path in vivado_dir.glob(pattern):
            if path.is_file():
                path.unlink()


def run_xsim_case(case: SweepCase) -> None:
    ensure_tools(["xvlog", "xelab", "xsim"])
    xvlog = tool_path("xvlog")
    xelab = tool_path("xelab")
    xsim = tool_path("xsim")
    dirs = case_dirs(case)
    clean_sim_work(dirs["sim"])
    package_files, rtl_files = source_files_for_xsim()
    include_args = ["-i", str(dirs["generated"])]
    filelist_path = dirs["sim"] / "xsim_sources.f"
    source_files = [*package_files, *rtl_files, PROJECT_ROOT / "tb" / "tb_InstrMemSweep.sv"]
    filelist_path.write_text(
        "\n".join(path.as_posix() for path in source_files) + "\n",
        encoding="ascii",
    )
    run([xvlog, "-sv", *include_args, "-f", str(filelist_path)], cwd=dirs["sim"])
    run([xelab, "-debug", "typical", "TbTop", "-s", "instr_mem_sweep_sim"], cwd=dirs["sim"])
    run([xsim, "instr_mem_sweep_sim", "-runall"], cwd=dirs["sim"])
    if not (dirs["sim"] / "counters.json").exists():
        raise SystemExit(f"[FAIL] XSIM did not produce counters.json for {case.case_id}")


def run_vivado_case(manifest_path: Path, case: SweepCase, *, allow_fail: bool) -> None:
    ensure_tools(["vivado"])
    vivado = tool_path("vivado")
    dirs = case_dirs(case)
    clean_vivado_work(dirs["vivado"])
    cmd = [
        vivado,
        "-mode",
        "batch",
        "-source",
        str(SCRIPT_DIR / "vivado_sweep.tcl"),
        "-log",
        str(dirs["vivado"] / "vivado.log"),
        "-journal",
        str(dirs["vivado"] / "vivado.jou"),
        "-tclargs",
        str(manifest_path),
    ]
    rc = run(cmd, cwd=dirs["vivado"], allow_fail=allow_fail)
    if rc != 0:
        print(f"[WARN] Vivado failed for {case.case_id}; status will be reflected in summary.")


def parse_metrics(manifest_path: Path, case: SweepCase) -> None:
    dirs = case_dirs(case)
    runtime = dirs["sim"] / "counters.json"
    metrics = parse_case(manifest_path, dirs["vivado"], runtime if runtime.exists() else None)
    dirs["metrics"].mkdir(parents=True, exist_ok=True)
    (dirs["metrics"] / "case_metrics.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")


def write_summary() -> None:
    argv = [
        "--cases-root",
        str(OUTPUT_ROOT / "cases"),
        "--output-root",
        str(OUTPUT_ROOT),
    ]
    make_summary_main(argv)
    html_argv = [
        "--summary-csv",
        str(OUTPUT_ROOT / "summary.csv"),
        "--output-html",
        str(OUTPUT_ROOT / "instr_mem_sweep_charts.html"),
    ]
    try:
        make_html_report_main(html_argv)
    except Exception as exc:
        print(f"[WARN] HTML summary generation failed: {exc}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=SCRIPT_DIR / "instr_mem_sweep.yml")
    parser.add_argument("--mode", choices=["fast", "full", "pure_capacity"], default="fast")
    parser.add_argument("--vivado-level", choices=["synth_only", "route"], default=None)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--force-case", action="append", default=[])
    parser.add_argument("--only-variant", action="append", default=[])
    parser.add_argument("--only-size", action="append", default=[])
    parser.add_argument("--size-kb-min", type=int)
    parser.add_argument("--size-kb-max", type=int)
    parser.add_argument("--size-kb-step", type=int)
    parser.add_argument("--only-program", action="append", default=[])
    parser.add_argument("--only-exec-region", action="append", default=[])
    parser.add_argument("--only-ifetch-build-mode", action="append", default=[])
    parser.add_argument("--run-seed", action="append", type=int, default=[])
    parser.add_argument("--placer-seed", action="append", type=int, default=[])
    parser.add_argument("--router-seed", action="append", type=int, default=[])
    parser.add_argument("--skip-vivado", action="store_true")
    parser.add_argument("--skip-xsim", action="store_true")
    parser.add_argument("--parse-only", action="store_true")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    if args.vivado_level is None:
        args.vivado_level = str(config.get("run", {}).get("default_vivado_level", "synth_only"))

    run_vivado = bool(config.get("run", {}).get("vivado", True)) and not args.skip_vivado
    run_xsim = bool(config.get("run", {}).get("xsim", True)) and not args.skip_xsim
    stop_on_fail = bool(config.get("run", {}).get("stop_on_fail", False))
    cases = select_matrix(config, args)
    print(f"[INFO] Selected {len(cases)} case(s), mode={args.mode}, vivado_level={args.vivado_level}")
    if not cases:
        write_summary()
        return 0

    for idx, case in enumerate(cases, start=1):
        print(f"[INFO] Case {idx}/{len(cases)}: {case.case_id}")
        manifest_path = write_case_inputs(case, config, run_vivado=run_vivado, run_xsim=run_xsim)
        if args.resume and completed(case, run_vivado=run_vivado, run_xsim=run_xsim):
            print(f"[INFO] Skipping completed case: {case.case_id}")
            parse_metrics(manifest_path, case)
            continue
        if args.parse_only:
            parse_metrics(manifest_path, case)
            continue

        try:
            if run_xsim:
                run_xsim_case(case)
            if run_vivado:
                run_vivado_case(manifest_path, case, allow_fail=not stop_on_fail)
            parse_metrics(manifest_path, case)
        except BaseException as exc:
            if stop_on_fail:
                raise
            print(f"[WARN] Case failed but sweep continues: {case.case_id}: {exc}")
            try:
                parse_metrics(manifest_path, case)
            except BaseException as parse_exc:
                print(f"[WARN] Metrics parse also failed for {case.case_id}: {parse_exc}")

    write_summary()
    print(f"[INFO] Wrote {OUTPUT_ROOT / 'summary.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
