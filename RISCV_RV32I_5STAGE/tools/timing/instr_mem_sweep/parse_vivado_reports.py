#!/usr/bin/env python3
"""Parse Vivado and XSIM artifacts for one instruction-memory sweep case."""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from typing import Any

from generate_instr_mem import NOP, metadata_for_program, sha256_words

INSTR_TOKENS = (
    "FetchStage",
    "InstrRom",
    "BootRom",
    "ProgramRam",
    "InstrBusMux",
    "InstrBusReq",
    "InstrBusRsp",
    "IFIDData",
    "ReqAddr",
    "RspRdata",
)

SUMMARY_FIELDS = [
    "case_id",
    "variant",
    "size_bytes",
    "depth_words",
    "program",
    "benchmark_mode",
    "exec_region",
    "ifetch_build_mode",
    "vivado_level",
    "run_seed",
    "placer_seed",
    "router_seed",
    "status",
    "git_commit",
    "vivado_version",
    "part",
    "strategy",
    "top",
    "clock_period_ns",
    "lut",
    "lut_logic",
    "lut_as_memory",
    "lutram",
    "top_bucket_lut",
    "top_bucket_lutram",
    "srl",
    "ff",
    "ramb18",
    "ramb36",
    "bram_tile",
    "dsp",
    "io",
    "bufg",
    "device_lut_util_pct",
    "device_ff_util_pct",
    "device_bram_util_pct",
    "device_dsp_util_pct",
    "instr_rom_lut",
    "instr_rom_lutram",
    "instr_rom_ramb18",
    "instr_rom_ramb36",
    "program_ram_lut",
    "program_ram_lutram",
    "program_ram_ramb18",
    "program_ram_ramb36",
    "instr_fetch_memory_lut",
    "instr_fetch_memory_lutram",
    "instr_bus_mux_lut",
    "fetch_stage_lut",
    "rv32i_core_lut",
    "wns_ns",
    "overall_wns",
    "tns_ns",
    "whs_ns",
    "ths_ns",
    "fmax_est_mhz",
    "critical_path_group",
    "overall_top_path_class",
    "top_path_source",
    "top_path_destination",
    "top_path_group",
    "top_path_data_delay",
    "top_path_logic_delay",
    "top_path_route_delay",
    "logic_route_ratio",
    "top_critical_path_from",
    "top_critical_path_to",
    "top_critical_path_class",
    "top_critical_path_logic_levels",
    "top_critical_path_datapath_delay_ns",
    "top_critical_path_logic_delay_ns",
    "top_critical_path_route_delay_ns",
    "top_critical_path_logic_route_ratio",
    "clocked_only_path_found",
    "clocked_only_slack_ns",
    "clocked_only_delay_ns",
    "clocked_only_logic_delay_ns",
    "clocked_only_route_delay_ns",
    "clocked_only_logic_levels",
    "clocked_only_from",
    "clocked_only_to",
    "clocked_only_path_class",
    "instr_path_in_top10",
    "instr_path_worst_delay_ns",
    "instr_path_worst_logic_levels",
    "instr_path_route_delay_ns",
    "instr_path_score",
    "direct_fetch_path_found",
    "direct_fetch_wns",
    "direct_fetch_delay",
    "direct_fetch_actual_memory",
    "direct_fetch_source",
    "direct_fetch_destination",
    "direct_fetch_logic",
    "direct_fetch_route",
    "direct_fetch_slack_ns",
    "direct_fetch_delay_ns",
    "direct_fetch_logic_delay_ns",
    "direct_fetch_route_delay_ns",
    "direct_fetch_route_ratio",
    "direct_fetch_logic_levels",
    "direct_fetch_from",
    "direct_fetch_to",
    "direct_fetch_path_class",
    "direct_fetch_first_mem_token",
    "bootrom_fetch_wns",
    "bootrom_fetch_delay",
    "bootrom_fetch_source",
    "bootrom_fetch_destination",
    "bootrom_fetch_logic",
    "bootrom_fetch_route",
    "boot_fetch_path_found",
    "boot_fetch_slack_ns",
    "boot_fetch_delay_ns",
    "boot_fetch_logic_delay_ns",
    "boot_fetch_route_delay_ns",
    "boot_fetch_logic_levels",
    "boot_fetch_from",
    "boot_fetch_to",
    "boot_fetch_path_class",
    "programram_fetch_wns",
    "programram_fetch_delay",
    "programram_fetch_source",
    "programram_fetch_destination",
    "programram_fetch_logic",
    "programram_fetch_route",
    "program_fetch_path_found",
    "program_fetch_slack_ns",
    "program_fetch_delay_ns",
    "program_fetch_logic_delay_ns",
    "program_fetch_route_delay_ns",
    "program_fetch_logic_levels",
    "program_fetch_from",
    "program_fetch_to",
    "program_fetch_path_class",
    "ifetch_mux_to_ifid_wns",
    "ifetch_mux_to_ifid_delay",
    "ifetch_mux_to_ifid_path_found",
    "ifetch_mux_to_ifid_slack_ns",
    "ifetch_mux_to_ifid_delay_ns",
    "ifetch_mux_to_ifid_logic_delay_ns",
    "ifetch_mux_to_ifid_route_delay_ns",
    "ifetch_mux_to_ifid_logic_levels",
    "ifetch_mux_to_ifid_from",
    "ifetch_mux_to_ifid_to",
    "ifetch_mux_to_ifid_path_class",
    "pc_update_control_wns",
    "pc_update_path_found",
    "pc_update_slack_ns",
    "pc_update_delay_ns",
    "pc_update_logic_delay_ns",
    "pc_update_route_delay_ns",
    "pc_update_logic_levels",
    "pc_update_from",
    "pc_update_to",
    "async_reset_wns",
    "reset_fanout_path_found",
    "reset_fanout_slack_ns",
    "reset_fanout_delay_ns",
    "reset_fanout_logic_delay_ns",
    "reset_fanout_route_delay_ns",
    "reset_fanout_logic_levels",
    "reset_fanout_from",
    "reset_fanout_to",
    "async_reset_path_found",
    "async_reset_slack_ns",
    "async_reset_delay_ns",
    "async_reset_logic_delay_ns",
    "async_reset_route_delay_ns",
    "async_reset_logic_levels",
    "async_reset_from",
    "async_reset_to",
    "total_power_w",
    "dynamic_power_w",
    "static_power_w",
    "methodology_error_count",
    "methodology_warning_count",
    "drc_error_count",
    "drc_warning_count",
    "parse_error_count",
    "cycle_count",
    "retired_instr_count",
    "cpi",
    "fetch_wait_cycles",
    "fetch_wait_ratio",
    "fetch_request_count",
    "fetch_response_count",
    "fetch_response_efficiency",
    "fetch_boot_request_count",
    "fetch_program_request_count",
    "fetch_unmapped_request_count",
    "fetch_program_ratio",
    "redirect_flush_count",
    "prefetch_hit_count",
    "prefetch_empty_count",
    "prefetch_miss_or_empty_count",
    "prefetch_useful_ratio",
    "discarded_prefetch_count",
    "redirect_discard_avg",
    "retire_boot_instr_count",
    "retire_program_instr_count",
    "retire_unmapped_instr_count",
    "retire_program_ratio",
    "fetch_min_addr",
    "fetch_max_addr",
    "fetch_address_span_bytes",
    "retire_min_pc",
    "retire_max_pc",
    "retire_pc_span_bytes",
    "program_done",
    "watchdog_timeout",
    "content_classification",
    "wns_valid_for_pure_size_scaling",
    "wns_valid_for_workload_stress",
    "executable_kernel_words",
    "filler_start_word",
    "filler_mode",
    "filler_seed",
    "boot_image_policy",
    "program_image_policy",
    "boot_program_same_image",
    "boot_image_sha256",
    "program_image_sha256",
    "boot_prefix_preserved_from_previous_size",
    "program_prefix_preserved_from_previous_size",
    "prefix_stable",
    "prefix_preserved",
    "boot_tail_type",
    "program_tail_type",
    "tail_type",
    "boot_tail_is_all_nop",
    "program_tail_is_all_nop",
    "boot_tail_is_fixed_seed_filler",
    "program_tail_is_fixed_seed_filler",
    "boot_tail_position_dependent",
    "program_tail_position_dependent",
    "expected_boot_line_count",
    "actual_boot_line_count",
    "boot_line_count_ok",
    "expected_program_line_count",
    "actual_program_line_count",
    "program_line_count_ok",
    "line_count_ok",
    "addr_width",
    "is_power_of_two_depth",
    "depth_group",
    "has_depth_guard_comparator",
    "increment_words_from_previous_1kb",
    "grouped_wns_min",
    "grouped_wns_mean",
    "grouped_wns_max",
    "grouped_wns_stddev",
]


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def read_mem_words(path: Path | None) -> list[int]:
    if path is None or not path.exists():
        return []
    words: list[int] = []
    for line in path.read_text(encoding="ascii", errors="ignore").splitlines():
        token = line.strip()
        if not token:
            continue
        try:
            words.append(int(token, 16))
        except ValueError:
            continue
    return words


def line_count(path: Path | None) -> int:
    if path is None or not path.exists():
        return 0
    return sum(1 for line in path.read_text(encoding="ascii", errors="ignore").splitlines() if line.strip())


def bool_power_of_two(value: int) -> bool:
    return value > 0 and (value & (value - 1)) == 0


def resolve_manifest_path(case_manifest: dict[str, Any], key: str) -> Path | None:
    value = case_manifest.get(key)
    if not value:
        return None
    return Path(str(value))


def infer_legacy_policy(words: list[int], *, same_image: bool, image_role: str) -> str:
    if same_image:
        return "same_variable_benchmark_image"
    if words and words[0] != NOP and all(word == NOP for word in words[1:]):
        return "fixed_trampoline_to_program_ram"
    if words and all(word == NOP for word in words):
        return "fixed_minimal_nop_image"
    return f"legacy_{image_role}_image"


def infer_legacy_tail(words: list[int], default_type: str, default_position_dependent: bool) -> tuple[str, bool, bool]:
    if words and words[0] != NOP and all(word == NOP for word in words[1:]):
        return "fixed_trampoline_nop", True, False
    if words and all(word == NOP for word in words):
        return "fixed_minimal_nop", True, False
    return default_type, all(word == NOP for word in words) if words else False, default_position_dependent


def legacy_or_manifest_content(case_manifest: dict[str, Any]) -> dict[str, Any]:
    if isinstance(case_manifest.get("content_validation"), dict):
        return dict(case_manifest["content_validation"])

    case = case_manifest.get("case", {})
    program = str(case.get("program", case_manifest.get("program", "")))
    size_bytes = int(case.get("size_bytes", case_manifest.get("size_bytes", 0)) or 0)
    depth_words = int(case.get("depth_words", case_manifest.get("depth_words", size_bytes // 4 if size_bytes else 0)) or 0)
    addr_width = int(case_manifest.get("addr_width", math.ceil(math.log2(depth_words)) if depth_words else 0) or 0)
    boot_path = resolve_manifest_path(case_manifest, "boot_init_file")
    program_path = resolve_manifest_path(case_manifest, "program_init_file")
    boot_words = read_mem_words(boot_path)
    program_words = read_mem_words(program_path)
    boot_sha = sha256_words(boot_words) if boot_words else ""
    program_sha = sha256_words(program_words) if program_words else ""
    boot_program_same = bool(boot_sha and program_sha and boot_sha == program_sha)
    meta = metadata_for_program(program)
    inferred_build_mode = case.get("ifetch_build_mode") or case_manifest.get("ifetch_build_mode")
    if not inferred_build_mode:
        if program == "mixed_firmware" and boot_program_same:
            inferred_build_mode = "duplicated_stress"
        elif str(case.get("exec_region", case_manifest.get("exec_region", "boot"))) == "program_ram":
            inferred_build_mode = "programram_only"
        else:
            inferred_build_mode = "legacy_unspecified"

    boot_policy = infer_legacy_policy(boot_words, same_image=boot_program_same, image_role="boot")
    program_policy = infer_legacy_policy(program_words, same_image=boot_program_same, image_role="program")
    boot_tail_type, boot_tail_all_nop, boot_tail_position = infer_legacy_tail(
        boot_words,
        meta.tail_type,
        meta.tail_position_dependent,
    )
    program_tail_type, program_tail_all_nop, program_tail_position = infer_legacy_tail(
        program_words,
        meta.tail_type,
        meta.tail_position_dependent,
    )
    pure_scaling = bool(meta.wns_valid_for_pure_size_scaling and inferred_build_mode != "duplicated_stress")
    if program == "mixed_firmware":
        pure_scaling = False
    content = {
        "benchmark_mode": program,
        "content_classification": meta.content_classification,
        "wns_valid_for_pure_size_scaling": pure_scaling,
        "wns_valid_for_workload_stress": meta.wns_valid_for_workload_stress,
        "executable_kernel_words": meta.executable_kernel_words,
        "filler_start_word": meta.filler_start_word,
        "filler_mode": meta.filler_mode,
        "filler_seed": meta.filler_seed,
        "ifetch_build_mode": inferred_build_mode,
        "boot_image_policy": boot_policy,
        "program_image_policy": program_policy,
        "boot_program_same_image": boot_program_same,
        "boot_image_sha256": boot_sha,
        "program_image_sha256": program_sha,
        "boot_prefix_preserved_from_previous_size": True,
        "program_prefix_preserved_from_previous_size": True,
        "prefix_stable": True,
        "boot_tail_type": boot_tail_type,
        "program_tail_type": program_tail_type,
        "boot_tail_is_all_nop": boot_tail_all_nop,
        "program_tail_is_all_nop": program_tail_all_nop,
        "boot_tail_is_fixed_seed_filler": meta.tail_is_fixed_seed_filler,
        "program_tail_is_fixed_seed_filler": meta.tail_is_fixed_seed_filler,
        "boot_tail_position_dependent": boot_tail_position,
        "program_tail_position_dependent": program_tail_position,
        "expected_boot_line_count": depth_words,
        "actual_boot_line_count": line_count(boot_path),
        "boot_line_count_ok": line_count(boot_path) == depth_words if depth_words else False,
        "expected_program_line_count": depth_words,
        "actual_program_line_count": line_count(program_path),
        "program_line_count_ok": line_count(program_path) == depth_words if depth_words else False,
        "depth_words": depth_words,
        "addr_width": addr_width,
        "is_power_of_two_depth": bool_power_of_two(depth_words),
        "depth_group": "power_of_two" if bool_power_of_two(depth_words) else "non_power_of_two",
        "has_depth_guard_comparator": True,
        "increment_words_from_previous_1kb": 256 if size_bytes > 4096 else None,
    }
    if program == "mixed_firmware" and boot_program_same:
        content.update(
            {
                "content_classification": "mixed_content_expansion",
                "ifetch_build_mode": "duplicated_stress",
                "boot_image_policy": "same_variable_benchmark_image",
                "program_image_policy": "same_variable_benchmark_image",
                "wns_valid_for_pure_size_scaling": False,
                "wns_valid_for_workload_stress": True,
                "boot_tail_type": "active_mixed_firmware",
                "program_tail_type": "active_mixed_firmware",
                "boot_tail_position_dependent": True,
                "program_tail_position_dependent": True,
            }
        )
    return content


def parse_num(text: str | None) -> float | None:
    if text is None:
        return None
    token = str(text).strip().replace(",", "")
    token = token.replace("%", "").replace("W", "").replace("ns", "").strip()
    if not token or token.upper() in {"NA", "N/A", "-"}:
        return None
    match = re.search(r"[-+]?\d+(?:\.\d+)?", token)
    if not match:
        return None
    return float(match.group(0))


def parse_int(text: str | None) -> int | None:
    value = parse_num(text)
    if value is None:
        return None
    return int(round(value))


def pipe_cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.split("|")[1:-1]]


def normalize_label(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("*", "")).strip()


def find_pipe_row(text: str, label: str) -> list[str] | None:
    expected = normalize_label(label)
    for line in text.splitlines():
        if "|" not in line or label not in line:
            continue
        cells = pipe_cells(line)
        if cells and normalize_label(cells[0]) == expected:
            return cells
    return None


def parse_util_flat(path: Path, metrics: dict[str, Any]) -> None:
    text = read_text(path)
    if not text:
        metrics["quality"]["parse_errors"].append(f"missing {path.name}")
        return

    flat = metrics["resources"]["flat"]
    util_pct = metrics["resources"]["util_pct"]

    row_map = {
        "Slice LUTs": ("lut", "lut"),
        "LUT as Logic": ("lut_logic", None),
        "LUT as Memory": ("lut_as_memory", None),
        "LUT as Distributed RAM": ("lutram", None),
        "LUTRAM": ("lutram", None),
        "LUT as Shift Register": ("srl", None),
        "Slice Registers": ("ff", "ff"),
        "RAMB18": ("ramb18", None),
        "RAMB36/FIFO": ("ramb36", None),
        "Block RAM Tile": ("bram_tile", "bram"),
        "DSPs": ("dsp", "dsp"),
        "Bonded IOB": ("io", None),
        "BUFGCTRL": ("bufg", None),
        "BUFG": ("bufg", None),
    }
    for label, (field, pct_field) in row_map.items():
        row = find_pipe_row(text, label)
        if not row or len(row) < 2:
            continue
        value = parse_int(row[1])
        if value is not None:
            flat[field] = value
        if pct_field and len(row) >= 5:
            pct = parse_num(row[-1])
            if pct is not None:
                util_pct[pct_field] = pct


def parse_util_hier(path: Path, metrics: dict[str, Any]) -> None:
    text = read_text(path)
    if not text:
        metrics["quality"]["parse_errors"].append(f"missing {path.name}")
        return

    targets = {
        "InstrRom": "InstrRom",
        "BootRom": "InstrRom",
        "ProgramRam": "ProgramRam",
        "InstrBusMux": "InstrBusMux",
        "FetchStage": "FetchStage",
        "Rv32iCore": "Rv32iCore",
    }
    for line in text.splitlines():
        if "|" not in line:
            continue
        cells = pipe_cells(line)
        if len(cells) < 4:
            continue
        numbers = [parse_int(cell) for cell in cells[1:]]
        numbers = [value for value in numbers if value is not None]
        if not numbers:
            continue
        instance = normalize_label(cells[0])
        module = normalize_label(cells[1]) if len(cells) > 1 else ""
        if instance == "(TOP)":
            hier = metrics["resources"]["hier"].setdefault("TopBucket", {})
            hier["lut"] = numbers[0] if len(numbers) > 0 else None
            hier["logic_lut"] = numbers[1] if len(numbers) > 1 else None
            hier["lutram"] = numbers[2] if len(numbers) > 2 else None
            hier["srl"] = numbers[3] if len(numbers) > 3 else None
            hier["ff"] = numbers[4] if len(numbers) > 4 else None
            hier["ramb36"] = numbers[5] if len(numbers) > 5 else None
            hier["ramb18"] = numbers[6] if len(numbers) > 6 else None
            continue
        if instance.endswith("uInstrFetchMemory") or module == "InstrFetchMemory":
            hier = metrics["resources"]["hier"].setdefault("InstrFetchMemory", {})
            hier["lut"] = numbers[0] if len(numbers) > 0 else None
            hier["logic_lut"] = numbers[1] if len(numbers) > 1 else None
            hier["lutram"] = numbers[2] if len(numbers) > 2 else None
            hier["srl"] = numbers[3] if len(numbers) > 3 else None
            hier["ff"] = numbers[4] if len(numbers) > 4 else None
            hier["ramb36"] = numbers[5] if len(numbers) > 5 else None
            hier["ramb18"] = numbers[6] if len(numbers) > 6 else None
        hier_key = util_hier_key(instance, module, targets)
        if hier_key is None:
            continue
        hier = metrics["resources"]["hier"].setdefault(hier_key, {})
        hier["lut"] = numbers[0] if len(numbers) > 0 else None
        hier["logic_lut"] = numbers[1] if len(numbers) > 1 else None
        hier["lutram"] = numbers[2] if len(numbers) > 2 else None
        hier["srl"] = numbers[3] if len(numbers) > 3 else None
        hier["ff"] = numbers[4] if len(numbers) > 4 else None
        hier["ramb36"] = numbers[5] if len(numbers) > 5 else None
        hier["ramb18"] = numbers[6] if len(numbers) > 6 else None


def util_hier_key(instance: str, module: str, targets: dict[str, str]) -> str | None:
    if module in targets:
        return targets[module]
    tail = instance.split("/")[-1].strip()
    for token, hier_key in targets.items():
        if tail == token or tail == f"u{token}":
            return hier_key
    return None


def parse_timing_summary(path: Path, metrics: dict[str, Any]) -> None:
    text = read_text(path)
    if not text:
        metrics["quality"]["parse_errors"].append(f"missing {path.name}")
        return

    timing = metrics["timing"]
    for idx, line in enumerate(text.splitlines()):
        if "WNS(ns)" in line and "TNS(ns)" in line:
            for candidate in text.splitlines()[idx + 1 : idx + 10]:
                values = re.findall(r"[-+]?\d+(?:\.\d+)?", candidate.replace(",", ""))
                if len(values) >= 4:
                    timing["wns_ns"] = float(values[0])
                    timing["tns_ns"] = float(values[1])
                    if len(values) >= 6:
                        timing["whs_ns"] = float(values[4])
                        timing["ths_ns"] = float(values[5])
                    break
            break
    for idx, line in enumerate(text.splitlines()):
        if "WHS(ns)" in line and "THS(ns)" in line and "WNS(ns)" not in line:
            for candidate in text.splitlines()[idx + 1 : idx + 10]:
                values = re.findall(r"[-+]?\d+(?:\.\d+)?", candidate.replace(",", ""))
                if len(values) >= 2:
                    timing["whs_ns"] = float(values[0])
                    timing["ths_ns"] = float(values[1])
                    break
            break

    period = metrics["reproducibility"].get("clock_period_ns")
    wns = timing.get("wns_ns")
    if isinstance(period, (int, float)) and isinstance(wns, (int, float)):
        min_period = float(period) - float(wns)
        if min_period > 0:
            timing["fmax_est_mhz"] = 1000.0 / min_period


def parse_timing_paths(path: Path, metrics: dict[str, Any]) -> None:
    text = read_text(path)
    if not text:
        metrics["quality"]["parse_errors"].append(f"missing {path.name}")
        return

    timing = metrics["timing"]
    crit = timing["critical_path"]
    instr = timing["instruction_path"]
    paths = split_timing_paths(text)

    if paths:
        first = "\n".join(paths[0])
        path_metrics = timing_path_metrics(first)
        crit["group"] = path_metrics["group"]
        crit["from"] = path_metrics["from"]
        crit["to"] = path_metrics["to"]
        crit["class"] = classify_timing_path(first, path_metrics["from"], path_metrics["to"])
        crit["logic_levels"] = path_metrics["logic_levels"]
        crit["datapath_delay_ns"] = path_metrics["datapath_delay_ns"]
        crit["logic_delay_ns"] = path_metrics["logic_delay_ns"]
        crit["route_delay_ns"] = path_metrics["route_delay_ns"]
        crit["logic_route_ratio"] = path_metrics["logic_route_ratio"]

    best_score = 0.0
    for idx, path_lines in enumerate(paths[:30]):
        blob = "\n".join(path_lines)
        token_hit = any(token in blob for token in INSTR_TOKENS)
        if not token_hit:
            continue
        path_metrics = timing_path_metrics(blob)
        delay = path_metrics["datapath_delay_ns"]
        logic_levels = path_metrics["logic_levels"]
        route_delay = path_metrics["route_delay_ns"]
        score = 1.0 if idx < 10 else 0.5
        source = path_metrics["from"]
        dest = path_metrics["to"]
        if any(token in source or token in dest for token in INSTR_TOKENS):
            score = 2.0
        best_score = max(best_score, score)
        if instr["worst_delay_ns"] in (None, 0.0) or delay > instr["worst_delay_ns"]:
            instr["worst_delay_ns"] = delay
            instr["logic_levels"] = logic_levels
            instr["route_delay_ns"] = route_delay
        if idx < 10:
            instr["in_top10"] = True
    instr["score"] = best_score


def split_timing_paths(text: str) -> list[list[str]]:
    lines = text.splitlines()
    current_path: list[str] = []
    paths: list[list[str]] = []
    for line in lines:
        if "Slack" in line:
            if current_path:
                paths.append(current_path)
            current_path = [line]
        elif current_path:
            current_path.append(line)
    if current_path:
        paths.append(current_path)
    return paths


def timing_path_metrics(path_text: str) -> dict[str, Any]:
    delay = extract_delay(path_text, "Data Path Delay") or 0.0
    route_delay = extract_route_delay(path_text) or 0.0
    logic_delay = extract_logic_delay(path_text)
    route_ratio = route_delay / delay if delay else None
    logic_route_ratio = (logic_delay / route_delay) if logic_delay is not None and route_delay else None
    return {
        "slack_ns": extract_slack(path_text),
        "group": extract_label(path_text, "Path Group") or extract_label(path_text, "Path group") or "",
        "from": extract_label(path_text, "Source") or extract_label(path_text, "From") or "",
        "to": extract_label(path_text, "Destination") or extract_label(path_text, "To") or "",
        "logic_levels": parse_int(extract_label(path_text, "Logic Levels")) or 0,
        "datapath_delay_ns": delay,
        "logic_delay_ns": logic_delay,
        "route_delay_ns": route_delay,
        "route_ratio": route_ratio,
        "logic_route_ratio": logic_route_ratio,
    }


def classify_timing_path(path_text: str, source: str, dest: str) -> str:
    blob = f"{source}\n{dest}\n{path_text}"
    if "SysRst" in blob:
        return "reset_fanout"
    if "uInstDma" in blob and "ProgramRam" in blob and (
        "WADR" in blob or re.search(r"/A\d+\b", blob) or "MemRam_reg" in blob
    ):
        return "program_ram_write_addr"
    if ("uFetchStage/uPc" in source or "Pc_reg" in source or "oPc_reg" in source) and (
        "uIfIdReg" in dest or "IFID" in dest
    ):
        return "direct_fetch"
    if "uFetchStage/uPc" in dest or "Pc_reg" in dest or "oPc_reg" in dest:
        return "pc_update_control"
    if any(token in blob for token in INSTR_TOKENS):
        return "instruction_related"
    return "other"


def empty_timing_path_metrics() -> dict[str, Any]:
    return {
        "found": False,
        "slack_ns": None,
        "datapath_delay_ns": None,
        "logic_delay_ns": None,
        "route_delay_ns": None,
        "route_ratio": None,
        "logic_levels": 0,
        "from": "",
        "to": "",
        "path_class": "",
        "first_mem_token": "",
        "actual_memory": "unknown",
    }


def classify_fetch_path(path_text: str) -> str:
    has_boot = any(token in path_text for token in ("uInstrRom", "BootRom", "MemRom"))
    has_program = any(token in path_text for token in ("uProgramRam", "ProgramRam", "MemRam"))
    has_lutram = "RAMD" in path_text or "MemRam_reg" in path_text or "MemRom_reg" in path_text
    has_mux = "InstrBusMux" in path_text or "BootSel" in path_text or "ProgramSel" in path_text

    if has_boot and has_program:
        return "boot_and_program"
    if has_boot:
        return "boot_rom_lutram" if has_lutram else "boot_rom_logic"
    if has_program:
        return "program_ram_lutram" if has_lutram else "program_ram_logic"
    if has_mux:
        return "instr_bus_mux"
    return "unknown"


def actual_fetch_memory(path_text: str) -> str:
    has_boot = any(token in path_text for token in ("uInstrRom", "BootRom", "MemRom"))
    has_program = any(token in path_text for token in ("uProgramRam", "ProgramRam", "MemRam"))
    has_mux = "InstrBusMux" in path_text or "uInstrBusMux" in path_text
    if has_boot and not has_program:
        return "BootRom"
    if has_program and not has_boot:
        return "ProgramRam"
    if has_mux or (has_boot and has_program):
        return "mux_after_mem"
    return "unknown"


def first_mem_token(path_text: str) -> str:
    tokens = ("uInstrRom", "BootRom", "MemRom", "uProgramRam", "ProgramRam", "MemRam", "InstrBusMux")
    for line in path_text.splitlines():
        if any(token in line for token in tokens):
            return normalize_label(line)[:180]
    return ""


def update_path_metrics(target: dict[str, Any], path_text: str, *, class_mode: str = "fetch") -> None:
    path_metrics = timing_path_metrics(path_text)
    target["found"] = True
    target["slack_ns"] = path_metrics["slack_ns"]
    target["datapath_delay_ns"] = path_metrics["datapath_delay_ns"]
    target["logic_delay_ns"] = path_metrics["logic_delay_ns"]
    target["route_delay_ns"] = path_metrics["route_delay_ns"]
    target["route_ratio"] = path_metrics["route_ratio"]
    target["logic_levels"] = path_metrics["logic_levels"]
    target["from"] = path_metrics["from"]
    target["to"] = path_metrics["to"]
    if class_mode == "timing":
        target["path_class"] = classify_timing_path(path_text, path_metrics["from"], path_metrics["to"])
    else:
        target["path_class"] = classify_fetch_path(path_text)
    target["first_mem_token"] = first_mem_token(path_text)
    target["actual_memory"] = actual_fetch_memory(path_text)


def parse_direct_fetch_path(path: Path, metrics: dict[str, Any]) -> None:
    text = read_text(path)
    if not text:
        return
    if "report_error:" in text:
        metrics["quality"]["parse_errors"].append(f"{path.name}: {text.splitlines()[0]}")
        return
    paths = split_timing_paths(text)
    if not paths:
        return
    direct = metrics["timing"]["direct_fetch_path"]
    update_path_metrics(direct, "\n".join(paths[0]))


def parse_optional_timing_path(
    path: Path,
    metrics: dict[str, Any],
    timing_key: str,
    *,
    class_mode: str = "fetch",
) -> None:
    text = read_text(path)
    if not text:
        return
    if "report_error:" in text:
        metrics["quality"]["parse_errors"].append(f"{path.name}: {text.splitlines()[0]}")
        return
    paths = split_timing_paths(text)
    if not paths:
        return
    update_path_metrics(metrics["timing"][timing_key], "\n".join(paths[0]), class_mode=class_mode)


def extract_label(text: str, label: str) -> str | None:
    match = re.search(rf"{re.escape(label)}\s*:?\s+(.+)", text)
    if not match:
        return None
    return match.group(1).strip()


def extract_slack(text: str) -> float | None:
    match = re.search(r"Slack\s+\([^)]*\)\s*:\s*([-+]?\d+(?:\.\d+)?)\s*ns?", text)
    if not match:
        return None
    return float(match.group(1))


def extract_delay(text: str, label: str) -> float | None:
    match = re.search(rf"{re.escape(label)}\s*:?\s*([-+]?\d+(?:\.\d+)?)\s*ns?", text)
    if not match:
        return None
    return float(match.group(1))


def extract_logic_delay(text: str) -> float | None:
    match = re.search(r"logic\s+([-+]?\d+(?:\.\d+)?)\s*ns", text, flags=re.IGNORECASE)
    if not match:
        return None
    return float(match.group(1))


def extract_route_delay(text: str) -> float | None:
    patterns = [
        r"route\s+([-+]?\d+(?:\.\d+)?)\s*ns",
        r"Net Delay\s*:?\s*([-+]?\d+(?:\.\d+)?)\s*ns",
        r"Route Delay\s*:?\s*([-+]?\d+(?:\.\d+)?)\s*ns",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            return float(match.group(1))
    return None


def parse_power(path: Path, metrics: dict[str, Any]) -> None:
    text = read_text(path)
    if not text:
        metrics["quality"]["parse_errors"].append(f"missing {path.name}")
        return

    labels = {
        "Total On-Chip Power": "total_w",
        "Dynamic": "dynamic_w",
        "Device Static": "static_w",
        "Static": "static_w",
    }
    for line in text.splitlines():
        if "|" not in line:
            continue
        cells = pipe_cells(line)
        if len(cells) < 2:
            continue
        for label, field in labels.items():
            if label in cells[0]:
                value = parse_num(cells[1])
                if value is not None:
                    metrics["power"][field] = value


def count_report_severity(path: Path) -> tuple[int, int]:
    text = read_text(path)
    if not text:
        return 0, 0
    errors = 0
    warnings = 0
    for line in text.splitlines():
        if re.search(r"\b(?:ERROR|Error|error)\b", line):
            errors += 1
        if re.search(r"\b(?:WARNING|Warning|warning)\b", line):
            warnings += 1
    return errors, warnings


def load_runtime(path: Path, metrics: dict[str, Any]) -> None:
    if not path.exists():
        return
    try:
        runtime = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        metrics["quality"]["parse_errors"].append(f"invalid runtime JSON {path}: {exc}")
        return
    metrics["runtime"].update(runtime)
    cycles = runtime.get("cycle_count")
    retired = runtime.get("retired_instr_count")
    if isinstance(cycles, (int, float)) and isinstance(retired, (int, float)) and retired:
        metrics["runtime"]["cpi"] = float(cycles) / float(retired)
    wait_cycles = runtime.get("fetch_wait_cycles")
    if isinstance(wait_cycles, (int, float)) and isinstance(cycles, (int, float)) and cycles:
        metrics["runtime"]["fetch_wait_ratio"] = float(wait_cycles) / float(cycles)
    responses = runtime.get("fetch_response_count")
    requests = runtime.get("fetch_request_count")
    if isinstance(responses, (int, float)) and isinstance(requests, (int, float)) and requests:
        metrics["runtime"]["fetch_response_efficiency"] = float(responses) / float(requests)
    program_requests = runtime.get("fetch_program_request_count")
    if isinstance(program_requests, (int, float)) and isinstance(requests, (int, float)) and requests:
        metrics["runtime"]["fetch_program_ratio"] = float(program_requests) / float(requests)
    hits = runtime.get("prefetch_hit_count")
    if isinstance(hits, (int, float)) and isinstance(retired, (int, float)) and retired:
        metrics["runtime"]["prefetch_useful_ratio"] = float(hits) / float(retired)
    program_retires = runtime.get("retire_program_instr_count")
    if isinstance(program_retires, (int, float)) and isinstance(retired, (int, float)) and retired:
        metrics["runtime"]["retire_program_ratio"] = float(program_retires) / float(retired)
    fetch_min = runtime.get("fetch_min_addr")
    fetch_max = runtime.get("fetch_max_addr")
    if isinstance(fetch_min, (int, float)) and isinstance(fetch_max, (int, float)) and fetch_max >= fetch_min:
        metrics["runtime"]["fetch_address_span_bytes"] = int(fetch_max) - int(fetch_min) + 4
    retire_min = runtime.get("retire_min_pc")
    retire_max = runtime.get("retire_max_pc")
    if isinstance(retire_min, (int, float)) and isinstance(retire_max, (int, float)) and retire_max >= retire_min:
        metrics["runtime"]["retire_pc_span_bytes"] = int(retire_max) - int(retire_min) + 4
    discarded = runtime.get("discarded_prefetch_count")
    redirects = runtime.get("redirect_flush_count")
    if isinstance(discarded, (int, float)) and isinstance(redirects, (int, float)) and redirects:
        metrics["runtime"]["redirect_discard_avg"] = float(discarded) / float(redirects)


def empty_metrics(case_manifest: dict[str, Any]) -> dict[str, Any]:
    case = case_manifest["case"]
    project = case_manifest.get("project", {})
    content = legacy_or_manifest_content(case_manifest)
    return {
        "case": {
            "case_id": case["case_id"],
            "variant": case["variant"],
            "size_bytes": int(case["size_bytes"]),
            "depth_words": int(case.get("depth_words", case_manifest.get("depth_words", int(case["size_bytes"]) // 4))),
            "program": case["program"],
            "benchmark_mode": case.get("benchmark_mode", content.get("benchmark_mode", case["program"])),
            "exec_region": case.get("exec_region", "boot"),
            "ifetch_build_mode": case.get("ifetch_build_mode", content.get("ifetch_build_mode", "legacy_unspecified")),
            "vivado_level": case.get("vivado_level", "synth_only"),
            "run_seed": case.get("run_seed", case_manifest.get("run_seed")),
            "placer_seed": case.get("placer_seed", case_manifest.get("placer_seed")),
            "router_seed": case.get("router_seed", case_manifest.get("router_seed")),
            "status": "pass",
        },
        "reproducibility": {
            "git_commit": case_manifest.get("git_commit", ""),
            "vivado_version": "",
            "part": project.get("part", ""),
            "strategy": project.get("strategy", "Default"),
            "top": project.get("top", "TOP"),
            "clock_period_ns": float(project.get("clock_period_ns", 40.0)),
        },
        "resources": {
            "flat": {
                "lut": None,
                "lut_logic": None,
                "lut_as_memory": None,
                "lutram": None,
                "top_bucket_lut": None,
                "top_bucket_lutram": None,
                "srl": None,
                "ff": None,
                "ramb18": None,
                "ramb36": None,
                "bram_tile": None,
                "dsp": None,
                "io": None,
                "bufg": None,
            },
            "hier": {
                "InstrRom": {},
                "ProgramRam": {},
                "InstrFetchMemory": {},
                "TopBucket": {},
                "InstrBusMux": {},
                "FetchStage": {},
                "Rv32iCore": {},
            },
            "util_pct": {"lut": None, "ff": None, "bram": None, "dsp": None},
        },
        "timing": {
            "wns_ns": None,
            "tns_ns": None,
            "whs_ns": None,
            "ths_ns": None,
            "fmax_est_mhz": None,
            "critical_path": {
                "group": "",
                "from": "",
                "to": "",
                "class": "",
                "logic_levels": 0,
                "datapath_delay_ns": 0.0,
                "logic_delay_ns": None,
                "route_delay_ns": 0.0,
                "logic_route_ratio": None,
            },
            "instruction_path": {
                "in_top10": False,
                "worst_delay_ns": 0.0,
                "logic_levels": 0,
                "route_delay_ns": 0.0,
                "score": 0.0,
            },
            "direct_fetch_path": {
                **empty_timing_path_metrics(),
            },
            "clocked_only_path": empty_timing_path_metrics(),
            "boot_fetch_path": empty_timing_path_metrics(),
            "program_fetch_path": empty_timing_path_metrics(),
            "ifetch_mux_to_ifid_path": empty_timing_path_metrics(),
            "pc_update_path": empty_timing_path_metrics(),
            "reset_fanout_path": empty_timing_path_metrics(),
            "async_reset_path": empty_timing_path_metrics(),
        },
        "runtime": {},
        "power": {"total_w": None, "dynamic_w": None, "static_w": None},
        "content_validation": content,
        "quality": {
            "methodology_error_count": 0,
            "methodology_warning_count": 0,
            "drc_error_count": 0,
            "drc_warning_count": 0,
            "parse_errors": [],
        },
    }


def flatten_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    flat = {}
    case = metrics["case"]
    repro = metrics["reproducibility"]
    resources = metrics["resources"]["flat"]
    util_pct = metrics["resources"]["util_pct"]
    hier = metrics["resources"]["hier"]
    timing = metrics["timing"]
    critical = timing["critical_path"]
    instr = timing["instruction_path"]
    direct_fetch = timing.get(
        "direct_fetch_path",
        empty_timing_path_metrics(),
    )
    clocked_only = timing.get("clocked_only_path", empty_timing_path_metrics())
    boot_fetch = timing.get("boot_fetch_path", empty_timing_path_metrics())
    program_fetch = timing.get("program_fetch_path", empty_timing_path_metrics())
    ifetch_mux = timing.get("ifetch_mux_to_ifid_path", empty_timing_path_metrics())
    pc_update = timing.get("pc_update_path", empty_timing_path_metrics())
    reset_fanout = timing.get("reset_fanout_path", empty_timing_path_metrics())
    async_reset = timing.get("async_reset_path", empty_timing_path_metrics())
    runtime = metrics["runtime"]
    power = metrics["power"]
    quality = metrics["quality"]
    content = metrics.get("content_validation", {})

    flat.update(case)
    flat.setdefault("exec_region", "boot")
    flat.setdefault("ifetch_build_mode", content.get("ifetch_build_mode", "legacy_unspecified"))
    flat.setdefault("benchmark_mode", content.get("benchmark_mode", flat.get("program")))
    flat.setdefault("depth_words", int(flat["size_bytes"]) // 4 if flat.get("size_bytes") is not None else None)
    flat.update(content)
    build_mode = flat.get("ifetch_build_mode")
    if build_mode == "bootrom_only":
        flat["prefix_preserved"] = flat.get("boot_prefix_preserved_from_previous_size")
        flat["tail_type"] = flat.get("boot_tail_type")
    elif build_mode == "programram_only":
        flat["prefix_preserved"] = flat.get("program_prefix_preserved_from_previous_size")
        flat["tail_type"] = flat.get("program_tail_type")
    else:
        flat["prefix_preserved"] = flat.get("prefix_stable")
        flat["tail_type"] = flat.get("boot_tail_type") if flat.get("boot_tail_type") == flat.get("program_tail_type") else "mixed"
    flat["line_count_ok"] = bool(flat.get("boot_line_count_ok")) and bool(flat.get("program_line_count_ok"))
    flat.update(repro)
    flat.update(resources)
    flat["top_bucket_lut"] = hier.get("TopBucket", {}).get("lut")
    flat["top_bucket_lutram"] = hier.get("TopBucket", {}).get("lutram")
    flat["device_lut_util_pct"] = util_pct.get("lut")
    flat["device_ff_util_pct"] = util_pct.get("ff")
    flat["device_bram_util_pct"] = util_pct.get("bram")
    flat["device_dsp_util_pct"] = util_pct.get("dsp")
    flat["instr_rom_lut"] = hier.get("InstrRom", {}).get("lut")
    flat["instr_rom_lutram"] = hier.get("InstrRom", {}).get("lutram")
    flat["instr_rom_ramb18"] = hier.get("InstrRom", {}).get("ramb18")
    flat["instr_rom_ramb36"] = hier.get("InstrRom", {}).get("ramb36")
    flat["program_ram_lut"] = hier.get("ProgramRam", {}).get("lut")
    flat["program_ram_lutram"] = hier.get("ProgramRam", {}).get("lutram")
    flat["program_ram_ramb18"] = hier.get("ProgramRam", {}).get("ramb18")
    flat["program_ram_ramb36"] = hier.get("ProgramRam", {}).get("ramb36")
    flat["instr_fetch_memory_lut"] = hier.get("InstrFetchMemory", {}).get("lut")
    flat["instr_fetch_memory_lutram"] = hier.get("InstrFetchMemory", {}).get("lutram")
    flat["instr_bus_mux_lut"] = hier.get("InstrBusMux", {}).get("lut")
    flat["fetch_stage_lut"] = hier.get("FetchStage", {}).get("lut")
    flat["rv32i_core_lut"] = hier.get("Rv32iCore", {}).get("lut")
    flat["wns_ns"] = timing.get("wns_ns")
    flat["overall_wns"] = timing.get("wns_ns")
    flat["tns_ns"] = timing.get("tns_ns")
    flat["whs_ns"] = timing.get("whs_ns")
    flat["ths_ns"] = timing.get("ths_ns")
    flat["fmax_est_mhz"] = timing.get("fmax_est_mhz")
    flat["critical_path_group"] = critical.get("group")
    flat["overall_top_path_class"] = critical.get("class")
    flat["top_path_source"] = critical.get("from")
    flat["top_path_destination"] = critical.get("to")
    flat["top_path_group"] = critical.get("group")
    flat["top_path_data_delay"] = critical.get("datapath_delay_ns")
    flat["top_path_logic_delay"] = critical.get("logic_delay_ns")
    flat["top_path_route_delay"] = critical.get("route_delay_ns")
    flat["logic_route_ratio"] = critical.get("logic_route_ratio")
    flat["top_critical_path_from"] = critical.get("from")
    flat["top_critical_path_to"] = critical.get("to")
    flat["top_critical_path_class"] = critical.get("class")
    flat["top_critical_path_logic_levels"] = critical.get("logic_levels")
    flat["top_critical_path_datapath_delay_ns"] = critical.get("datapath_delay_ns")
    flat["top_critical_path_logic_delay_ns"] = critical.get("logic_delay_ns")
    flat["top_critical_path_route_delay_ns"] = critical.get("route_delay_ns")
    flat["top_critical_path_logic_route_ratio"] = critical.get("logic_route_ratio")
    flatten_timing_path(flat, "clocked_only", clocked_only)
    flat["instr_path_in_top10"] = instr.get("in_top10")
    flat["instr_path_worst_delay_ns"] = instr.get("worst_delay_ns")
    flat["instr_path_worst_logic_levels"] = instr.get("logic_levels")
    flat["instr_path_route_delay_ns"] = instr.get("route_delay_ns")
    flat["instr_path_score"] = instr.get("score")
    flat["direct_fetch_path_found"] = direct_fetch.get("found")
    flat["direct_fetch_wns"] = direct_fetch.get("slack_ns")
    flat["direct_fetch_delay"] = direct_fetch.get("datapath_delay_ns")
    flat["direct_fetch_actual_memory"] = direct_fetch.get("actual_memory")
    flat["direct_fetch_source"] = direct_fetch.get("from")
    flat["direct_fetch_destination"] = direct_fetch.get("to")
    flat["direct_fetch_logic"] = direct_fetch.get("logic_delay_ns")
    flat["direct_fetch_route"] = direct_fetch.get("route_delay_ns")
    flat["direct_fetch_slack_ns"] = direct_fetch.get("slack_ns")
    flat["direct_fetch_delay_ns"] = direct_fetch.get("datapath_delay_ns")
    flat["direct_fetch_logic_delay_ns"] = direct_fetch.get("logic_delay_ns")
    flat["direct_fetch_route_delay_ns"] = direct_fetch.get("route_delay_ns")
    flat["direct_fetch_route_ratio"] = direct_fetch.get("route_ratio")
    flat["direct_fetch_logic_levels"] = direct_fetch.get("logic_levels")
    flat["direct_fetch_from"] = direct_fetch.get("from")
    flat["direct_fetch_to"] = direct_fetch.get("to")
    flat["direct_fetch_path_class"] = direct_fetch.get("path_class")
    flat["direct_fetch_first_mem_token"] = direct_fetch.get("first_mem_token")
    flatten_timing_path(flat, "boot_fetch", boot_fetch)
    flat["bootrom_fetch_wns"] = boot_fetch.get("slack_ns")
    flat["bootrom_fetch_delay"] = boot_fetch.get("datapath_delay_ns")
    flat["bootrom_fetch_source"] = boot_fetch.get("from")
    flat["bootrom_fetch_destination"] = boot_fetch.get("to")
    flat["bootrom_fetch_logic"] = boot_fetch.get("logic_delay_ns")
    flat["bootrom_fetch_route"] = boot_fetch.get("route_delay_ns")
    flatten_timing_path(flat, "program_fetch", program_fetch)
    flat["programram_fetch_wns"] = program_fetch.get("slack_ns")
    flat["programram_fetch_delay"] = program_fetch.get("datapath_delay_ns")
    flat["programram_fetch_source"] = program_fetch.get("from")
    flat["programram_fetch_destination"] = program_fetch.get("to")
    flat["programram_fetch_logic"] = program_fetch.get("logic_delay_ns")
    flat["programram_fetch_route"] = program_fetch.get("route_delay_ns")
    flatten_timing_path(flat, "ifetch_mux_to_ifid", ifetch_mux)
    flat["ifetch_mux_to_ifid_wns"] = ifetch_mux.get("slack_ns")
    flat["ifetch_mux_to_ifid_delay"] = ifetch_mux.get("datapath_delay_ns")
    flat["pc_update_control_wns"] = pc_update.get("slack_ns")
    flatten_timing_path(flat, "pc_update", pc_update, include_path_class=False)
    flatten_timing_path(flat, "reset_fanout", reset_fanout, include_path_class=False)
    flat["async_reset_wns"] = async_reset.get("slack_ns")
    flatten_timing_path(flat, "async_reset", async_reset, include_path_class=False)
    flat["total_power_w"] = power.get("total_w")
    flat["dynamic_power_w"] = power.get("dynamic_w")
    flat["static_power_w"] = power.get("static_w")
    flat["methodology_error_count"] = quality.get("methodology_error_count")
    flat["methodology_warning_count"] = quality.get("methodology_warning_count")
    flat["drc_error_count"] = quality.get("drc_error_count")
    flat["drc_warning_count"] = quality.get("drc_warning_count")
    flat["parse_error_count"] = len(quality.get("parse_errors", []))
    for key in SUMMARY_FIELDS:
        if key in runtime:
            flat[key] = runtime[key]
    return {field: normalize_value(flat.get(field)) for field in SUMMARY_FIELDS}


def flatten_timing_path(
    flat: dict[str, Any],
    prefix: str,
    path_metrics: dict[str, Any],
    *,
    include_path_class: bool = True,
) -> None:
    flat[f"{prefix}_path_found"] = path_metrics.get("found")
    flat[f"{prefix}_slack_ns"] = path_metrics.get("slack_ns")
    flat[f"{prefix}_delay_ns"] = path_metrics.get("datapath_delay_ns")
    flat[f"{prefix}_logic_delay_ns"] = path_metrics.get("logic_delay_ns")
    flat[f"{prefix}_route_delay_ns"] = path_metrics.get("route_delay_ns")
    flat[f"{prefix}_logic_levels"] = path_metrics.get("logic_levels")
    flat[f"{prefix}_from"] = path_metrics.get("from")
    flat[f"{prefix}_to"] = path_metrics.get("to")
    if include_path_class:
        flat[f"{prefix}_path_class"] = path_metrics.get("path_class")


def normalize_value(value: Any) -> Any:
    if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
        return None
    return value


def parse_case(case_manifest_path: Path, reports_dir: Path, runtime_path: Path | None = None) -> dict[str, Any]:
    case_manifest = json.loads(case_manifest_path.read_text(encoding="utf-8"))
    metrics = empty_metrics(case_manifest)
    run_cfg = case_manifest.get("run", {})
    vivado_enabled = bool(run_cfg.get("vivado", True))
    status_path = reports_dir / "status.json"
    if status_path.exists():
        try:
            status = json.loads(status_path.read_text(encoding="utf-8"))
            metrics["case"]["status"] = status.get("status", metrics["case"]["status"])
            if status.get("vivado_level"):
                metrics["case"]["vivado_level"] = status["vivado_level"]
            metrics["reproducibility"]["vivado_version"] = status.get("vivado_version", "")
        except json.JSONDecodeError as exc:
            metrics["quality"]["parse_errors"].append(f"invalid status.json: {exc}")

    if vivado_enabled:
        parse_util_flat(reports_dir / "util_flat.rpt", metrics)
        parse_util_hier(reports_dir / "util_hier.rpt", metrics)
        parse_timing_summary(reports_dir / "timing_summary.rpt", metrics)
        overall_path = reports_dir / "timing_overall.rpt"
        parse_timing_paths(overall_path if overall_path.exists() else reports_dir / "timing_paths.rpt", metrics)
        parse_optional_timing_path(
            reports_dir / "timing_clocked_only.rpt",
            metrics,
            "clocked_only_path",
            class_mode="timing",
        )
        direct_path = reports_dir / "timing_direct_fetch.rpt"
        parse_direct_fetch_path(direct_path if direct_path.exists() else reports_dir / "timing_lutrom_fetch.rpt", metrics)
        bootrom_path = reports_dir / "timing_bootrom_fetch.rpt"
        parse_optional_timing_path(bootrom_path if bootrom_path.exists() else reports_dir / "timing_boot_fetch.rpt", metrics, "boot_fetch_path")
        programram_path = reports_dir / "timing_programram_fetch.rpt"
        parse_optional_timing_path(programram_path if programram_path.exists() else reports_dir / "timing_program_fetch.rpt", metrics, "program_fetch_path")
        parse_optional_timing_path(reports_dir / "timing_ifetch_mux_to_ifid.rpt", metrics, "ifetch_mux_to_ifid_path")
        pc_update_path = reports_dir / "timing_pc_update_control.rpt"
        parse_optional_timing_path(
            pc_update_path if pc_update_path.exists() else reports_dir / "timing_pc_update.rpt",
            metrics,
            "pc_update_path",
            class_mode="timing",
        )
        parse_optional_timing_path(
            reports_dir / "timing_reset_fanout.rpt",
            metrics,
            "reset_fanout_path",
            class_mode="timing",
        )
        parse_optional_timing_path(
            reports_dir / "timing_async_reset.rpt",
            metrics,
            "async_reset_path",
            class_mode="timing",
        )
        if not metrics["timing"]["async_reset_path"]["found"]:
            metrics["timing"]["async_reset_path"] = dict(metrics["timing"]["reset_fanout_path"])
        parse_power(reports_dir / "power.rpt", metrics)

        methodology_errors, methodology_warnings = count_report_severity(reports_dir / "methodology.rpt")
        drc_errors, drc_warnings = count_report_severity(reports_dir / "drc.rpt")
        metrics["quality"]["methodology_error_count"] = methodology_errors
        metrics["quality"]["methodology_warning_count"] = methodology_warnings
        metrics["quality"]["drc_error_count"] = drc_errors
        metrics["quality"]["drc_warning_count"] = drc_warnings
    else:
        metrics["case"]["status"] = "sim_only"
    if runtime_path:
        load_runtime(runtime_path, metrics)

    wns = metrics["timing"].get("wns_ns")
    if isinstance(wns, (int, float)) and wns < 0 and metrics["case"]["status"] == "pass":
        metrics["case"]["status"] = "timing_fail"
    if metrics["quality"].get("parse_errors") and metrics["case"]["status"] in {"pass", "timing_fail"}:
        metrics["case"]["status"] = "parse_fail"
    return metrics


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case-manifest", required=True, type=Path)
    parser.add_argument("--reports-dir", required=True, type=Path)
    parser.add_argument("--runtime", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    metrics = parse_case(args.case_manifest, args.reports_dir, args.runtime)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
