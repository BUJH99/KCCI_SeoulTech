#!/usr/bin/env python3
"""Create CSV, JSON, and Markdown summaries for instruction-memory sweep metrics."""

from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Any

from parse_vivado_reports import SUMMARY_FIELDS, flatten_metrics

REQUIRED_VARIANT = "lutrom_direct"
REQUIRED_BENCHMARKS = ("ifetch_capacity_nop", "ifetch_capacity_prbs")
REQUIRED_IFETCH_BUILD_MODES = ("bootrom_only", "programram_only")
REQUIRED_SIZE_BYTES = tuple(kb * 1024 for kb in range(4, 33))
ROUTED_STATUSES = {"pass", "timing_fail"}


def load_metrics(cases_root: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in sorted(cases_root.glob("*/metrics/case_metrics.json")):
        try:
            rows.append(json.loads(path.read_text(encoding="utf-8")))
        except json.JSONDecodeError:
            continue
    return rows


def fmt(value: Any, digits: int = 3) -> str:
    if value is None or value == "":
        return "NA"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def bool_value(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() == "true"
    return bool(value)


def int_value(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def size_label_from_bytes(value: Any) -> str:
    try:
        size_bytes = int(value)
    except (TypeError, ValueError):
        return fmt(value)
    if size_bytes % 1024 == 0:
        return f"{size_bytes // 1024}KB"
    return str(size_bytes)


def required_case_rows(rows: list[dict[str, Any]], variant: str, benchmark: str, build_mode: str) -> list[dict[str, Any]]:
    required_sizes = set(REQUIRED_SIZE_BYTES)
    return [
        row
        for row in rows
        if row.get("variant") == variant
        and (row.get("benchmark_mode") or row.get("program")) == benchmark
        and row.get("ifetch_build_mode") == build_mode
        and int_value(row.get("size_bytes")) in required_sizes
    ]


def row_is_routed(row: dict[str, Any]) -> bool:
    return (
        row.get("vivado_level") == "route"
        and row.get("status") in ROUTED_STATUSES
        and row.get("overall_wns") not in (None, "")
        and int_value(row.get("parse_error_count")) == 0
    )


def required_coverage_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    coverage: list[dict[str, Any]] = []
    for benchmark in REQUIRED_BENCHMARKS:
        for build_mode in REQUIRED_IFETCH_BUILD_MODES:
            matching = required_case_rows(rows, REQUIRED_VARIANT, benchmark, build_mode)
            present_sizes = {int_value(row.get("size_bytes")) for row in matching}
            missing = [size for size in REQUIRED_SIZE_BYTES if size not in present_sizes]
            all_routed = bool(matching) and not missing and all(row_is_routed(row) for row in matching)
            all_pure = bool(matching) and not missing and all(bool_value(row.get("wns_valid_for_pure_size_scaling")) for row in matching)
            pass_fail = "PASS" if len(matching) == len(REQUIRED_SIZE_BYTES) and not missing and all_routed and all_pure else "FAIL"
            coverage.append(
                {
                    "variant": REQUIRED_VARIANT,
                    "benchmark_mode": benchmark,
                    "ifetch_build_mode": build_mode,
                    "expected_cases": len(REQUIRED_SIZE_BYTES),
                    "actual_cases": len(matching),
                    "missing_sizes": ", ".join(size_label_from_bytes(size) for size in missing),
                    "all_routed": all_routed,
                    "all_pure_kpi_valid": all_pure,
                    "pass_fail": pass_fail,
                }
            )
    return coverage


def pure_capacity_result_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    for row in sorted_rows(rows):
        if row.get("variant") != REQUIRED_VARIANT:
            continue
        if (row.get("benchmark_mode") or row.get("program")) not in REQUIRED_BENCHMARKS:
            continue
        if row.get("ifetch_build_mode") not in REQUIRED_IFETCH_BUILD_MODES:
            continue
        if int_value(row.get("size_bytes")) not in set(REQUIRED_SIZE_BYTES):
            continue
        selected.append(
            {
                "KB": size_label_from_bytes(row.get("size_bytes")),
                "variant": row.get("variant"),
                "benchmark_mode": row.get("benchmark_mode") or row.get("program"),
                "ifetch_build_mode": row.get("ifetch_build_mode"),
                "overall_wns": row.get("overall_wns"),
                "top_path_class": row.get("overall_top_path_class") or row.get("top_critical_path_class"),
                "direct_fetch_actual_memory": row.get("direct_fetch_actual_memory"),
                "content_classification": row.get("content_classification"),
                "wns_valid_for_pure_size_scaling": row.get("wns_valid_for_pure_size_scaling"),
                "boot_program_same_image": row.get("boot_program_same_image"),
                "prefix_preserved": row.get("prefix_preserved"),
                "tail_type": row.get("tail_type"),
                "line_count_ok": row.get("line_count_ok"),
            }
        )
    return selected


def missing_required_rows(coverage_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "variant": row["variant"],
            "benchmark_mode": row["benchmark_mode"],
            "ifetch_build_mode": row["ifetch_build_mode"],
            "missing_sizes": row["missing_sizes"],
        }
        for row in coverage_rows
        if row.get("missing_sizes")
    ]


def group_key(row: dict[str, Any]) -> tuple[Any, ...]:
    return (
        row.get("variant"),
        row.get("benchmark_mode") or row.get("program"),
        row.get("ifetch_build_mode"),
        row.get("exec_region"),
        row.get("size_bytes"),
    )


def flat_rows_with_group_stats(metrics_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows = [flatten_metrics(row) for row in metrics_rows]
    grouped: dict[tuple[Any, ...], list[float]] = defaultdict(list)
    for row in rows:
        wns = row.get("wns_ns")
        if isinstance(wns, (int, float)) and not math.isnan(float(wns)):
            grouped[group_key(row)].append(float(wns))
    for row in rows:
        values = grouped.get(group_key(row), [])
        if not values:
            continue
        row["grouped_wns_min"] = min(values)
        row["grouped_wns_mean"] = statistics.fmean(values)
        row["grouped_wns_max"] = max(values)
        row["grouped_wns_stddev"] = statistics.pstdev(values) if len(values) > 1 else 0.0
    return rows


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=SUMMARY_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field) for field in SUMMARY_FIELDS})


def write_json(
    path: Path,
    rows: list[dict[str, Any]],
    coverage_rows: list[dict[str, Any]],
    pure_rows: list[dict[str, Any]],
    missing_rows: list[dict[str, Any]],
) -> None:
    document = {
        "rows": rows,
        "required_pure_benchmark_coverage": coverage_rows,
        "pure_capacity_sweep_results": pure_rows,
        "missing_required_cases": missing_rows,
    }
    path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")


def write_aux_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field) for field in fieldnames})


def render_table(headers: list[str], rows: list[list[Any]]) -> list[str]:
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(fmt(value) for value in row) + " |")
    return lines


def sorted_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        rows,
        key=lambda row: (
            str(row.get("benchmark_mode") or row.get("program")),
            str(row.get("ifetch_build_mode")),
            str(row.get("variant")),
            int(row.get("size_bytes") or 0),
            str(row.get("run_seed")),
            str(row.get("placer_seed")),
            str(row.get("router_seed")),
        ),
    )


def limited_rows(rows: list[dict[str, Any]], limit: int = 80) -> list[dict[str, Any]]:
    ordered = sorted_rows(rows)
    return ordered[:limit]


def write_markdown(path: Path, rows: list[dict[str, Any]]) -> None:
    coverage_rows = required_coverage_rows(rows)
    pure_rows = pure_capacity_result_rows(rows)
    missing_rows = missing_required_rows(coverage_rows)
    lines: list[str] = [
        "# Instruction Memory Routed WNS KPI Summary",
        "",
        f"- Cases parsed: {len(rows)}",
        "- Routed WNS remains the final SoC performance KPI, but each row now carries content and image-policy validity metadata.",
        "- Power-of-two depths and non-power-of-two depths are labelled separately; do not average them into one conclusion.",
        "- New default examples:",
        "  - `python .\\tools\\timing\\instr_mem_sweep\\run_instr_mem_sweep.py --mode full --vivado-level route --only-variant lutrom_direct --only-program ifetch_capacity_nop --only-ifetch-build-mode bootrom_only --size-kb-min 4 --size-kb-max 32 --size-kb-step 1`",
        "  - `python .\\tools\\timing\\instr_mem_sweep\\run_instr_mem_sweep.py --mode full --vivado-level route --only-variant lutrom_direct --only-program ifetch_capacity_prbs --only-ifetch-build-mode bootrom_only --size-kb-min 4 --size-kb-max 32 --size-kb-step 1`",
        "  - `python .\\tools\\timing\\instr_mem_sweep\\run_instr_mem_sweep.py --mode full --vivado-level route --only-variant lutrom_direct --only-program ifetch_capacity_nop --only-ifetch-build-mode programram_only --size-kb-min 4 --size-kb-max 32 --size-kb-step 1`",
        "  - `python .\\tools\\timing\\instr_mem_sweep\\run_instr_mem_sweep.py --mode full --vivado-level route --only-variant lutrom_direct --only-program ifetch_capacity_prbs --only-ifetch-build-mode programram_only --size-kb-min 4 --size-kb-max 32 --size-kb-step 1`",
        "",
    ]
    lines.extend(["## Required Pure Benchmark Coverage", ""])
    lines.extend(
        render_table(
            [
                "variant",
                "benchmark_mode",
                "ifetch_build_mode",
                "expected_cases",
                "actual_cases",
                "missing_sizes",
                "all_routed",
                "all_pure_kpi_valid",
                "pass_fail",
            ],
            [
                [
                    row["variant"],
                    row["benchmark_mode"],
                    row["ifetch_build_mode"],
                    row["expected_cases"],
                    row["actual_cases"],
                    row["missing_sizes"],
                    row["all_routed"],
                    row["all_pure_kpi_valid"],
                    row["pass_fail"],
                ]
                for row in coverage_rows
            ],
        )
    )
    lines.extend(["", "## Pure Capacity Sweep Results", ""])
    lines.extend(
        render_table(
            [
                "KB",
                "variant",
                "benchmark_mode",
                "ifetch_build_mode",
                "overall_wns",
                "top_path_class",
                "direct_fetch_actual_memory",
                "content_classification",
                "wns_valid_for_pure_size_scaling",
                "boot_program_same_image",
                "prefix_preserved",
                "tail_type",
                "line_count_ok",
            ],
            [
                [
                    row["KB"],
                    row["variant"],
                    row["benchmark_mode"],
                    row["ifetch_build_mode"],
                    row["overall_wns"],
                    row["top_path_class"],
                    row["direct_fetch_actual_memory"],
                    row["content_classification"],
                    row["wns_valid_for_pure_size_scaling"],
                    row["boot_program_same_image"],
                    row["prefix_preserved"],
                    row["tail_type"],
                    row["line_count_ok"],
                ]
                for row in pure_rows
            ],
        )
    )
    lines.extend(["", "## Missing Required Cases", ""])
    if missing_rows:
        lines.extend(
            render_table(
                ["variant", "benchmark_mode", "ifetch_build_mode", "missing_sizes"],
                [
                    [
                        row["variant"],
                        row["benchmark_mode"],
                        row["ifetch_build_mode"],
                        row["missing_sizes"],
                    ]
                    for row in missing_rows
                ],
            )
        )
    else:
        lines.append("No required pure benchmark cases are missing.")
    lines.append("")
    invalid_rows = [
        row
        for row in rows
        if row.get("wns_valid_for_pure_size_scaling") is False
        or row.get("boot_line_count_ok") is False
        or row.get("program_line_count_ok") is False
        or row.get("parse_error_count", 0)
    ]
    if invalid_rows:
        lines.extend(["## Warnings", ""])
        lines.extend(
            render_table(
                ["Case", "Benchmark", "Build mode", "Pure KPI valid", "Boot lines ok", "Program lines ok", "Parse errors"],
                [
                    [
                        row.get("case_id"),
                        row.get("benchmark_mode"),
                        row.get("ifetch_build_mode"),
                        row.get("wns_valid_for_pure_size_scaling"),
                        row.get("boot_line_count_ok"),
                        row.get("program_line_count_ok"),
                        row.get("parse_error_count"),
                    ]
                    for row in invalid_rows[:40]
                ],
            )
        )
        lines.append("")

    table_rows = limited_rows(rows)
    lines.extend(["## 1. WNS, Top Path, Content Classification", ""])
    lines.extend(
        render_table(
            ["KB", "Group", "Variant", "Benchmark", "Build mode", "WNS", "Top path", "Content classification"],
            [
                [
                    size_label_from_bytes(row.get("size_bytes")),
                    row.get("depth_group"),
                    row.get("variant"),
                    row.get("benchmark_mode"),
                    row.get("ifetch_build_mode"),
                    row.get("wns_ns"),
                    row.get("top_critical_path_class"),
                    row.get("content_classification"),
                ]
                for row in table_rows
            ],
        )
    )

    lines.extend(["", "## 2. Boot/Program Prefix Preservation", ""])
    lines.extend(
        render_table(
            ["KB", "Group", "Case", "Boot prefix", "Program prefix", "Prefix stable"],
            [
                [
                    size_label_from_bytes(row.get("size_bytes")),
                    row.get("depth_group"),
                    row.get("case_id"),
                    row.get("boot_prefix_preserved_from_previous_size"),
                    row.get("program_prefix_preserved_from_previous_size"),
                    row.get("prefix_stable"),
                ]
                for row in table_rows
            ],
        )
    )

    lines.extend(["", "## 3. Tail Type and NOP Status", ""])
    lines.extend(
        render_table(
            ["KB", "Case", "Boot tail", "Boot all NOP", "Program tail", "Program all NOP", "Tail position dependent"],
            [
                [
                    size_label_from_bytes(row.get("size_bytes")),
                    row.get("case_id"),
                    row.get("boot_tail_type"),
                    row.get("boot_tail_is_all_nop"),
                    row.get("program_tail_type"),
                    row.get("program_tail_is_all_nop"),
                    bool(row.get("boot_tail_position_dependent") or row.get("program_tail_position_dependent")),
                ]
                for row in table_rows
            ],
        )
    )

    lines.extend(["", "## 4. BootRom/ProgramRam Image Policy", ""])
    lines.extend(
        render_table(
            ["KB", "Case", "Build mode", "Boot policy", "Program policy", "Same image"],
            [
                [
                    size_label_from_bytes(row.get("size_bytes")),
                    row.get("case_id"),
                    row.get("ifetch_build_mode"),
                    row.get("boot_image_policy"),
                    row.get("program_image_policy"),
                    row.get("boot_program_same_image"),
                ]
                for row in table_rows
            ],
        )
    )

    lines.extend(["", "## 5. Depth, Addr Width, Line Count", ""])
    lines.extend(
        render_table(
            ["KB", "Group", "Depth words", "Addr width", "Boot lines", "Boot ok", "Program lines", "Program ok", "Depth guard"],
            [
                [
                    size_label_from_bytes(row.get("size_bytes")),
                    row.get("depth_group"),
                    row.get("depth_words"),
                    row.get("addr_width"),
                    row.get("actual_boot_line_count"),
                    row.get("boot_line_count_ok"),
                    row.get("actual_program_line_count"),
                    row.get("program_line_count_ok"),
                    row.get("has_depth_guard_comparator"),
                ]
                for row in table_rows
            ],
        )
    )

    lines.extend(["", "## 6. Pure Size Scaling KPI Validity", ""])
    lines.extend(
        render_table(
            ["KB", "Case", "Benchmark", "Classification", "Pure size KPI valid", "Workload stress valid"],
            [
                [
                    size_label_from_bytes(row.get("size_bytes")),
                    row.get("case_id"),
                    row.get("benchmark_mode"),
                    row.get("content_classification"),
                    row.get("wns_valid_for_pure_size_scaling"),
                    row.get("wns_valid_for_workload_stress"),
                ]
                for row in table_rows
            ],
        )
    )

    lines.extend(["", "## 7. Direct Fetch Actual Memory", ""])
    lines.extend(
        render_table(
            ["KB", "Case", "Found", "Actual memory", "WNS", "Delay", "Source", "Destination"],
            [
                [
                    size_label_from_bytes(row.get("size_bytes")),
                    row.get("case_id"),
                    row.get("direct_fetch_path_found"),
                    row.get("direct_fetch_actual_memory"),
                    row.get("direct_fetch_wns"),
                    row.get("direct_fetch_delay"),
                    row.get("direct_fetch_source"),
                    row.get("direct_fetch_destination"),
                ]
                for row in table_rows
            ],
        )
    )

    lines.extend(["", "## 8. Split Fetch Attribution", ""])
    lines.extend(
        render_table(
            ["KB", "Case", "Boot delay", "Program delay", "Mux-to-IFID delay", "Async reset WNS", "PC update WNS"],
            [
                [
                    size_label_from_bytes(row.get("size_bytes")),
                    row.get("case_id"),
                    row.get("bootrom_fetch_delay"),
                    row.get("programram_fetch_delay"),
                    row.get("ifetch_mux_to_ifid_delay"),
                    row.get("async_reset_wns"),
                    row.get("pc_update_control_wns"),
                ]
                for row in table_rows
            ],
        )
    )

    lines.extend(["", "## 9. Top Path Logic/Route and Seed Grouping", ""])
    lines.extend(
        render_table(
            ["KB", "Case", "Data delay", "Logic delay", "Route delay", "Logic/route", "WNS min", "WNS mean", "WNS max", "WNS stddev"],
            [
                [
                    size_label_from_bytes(row.get("size_bytes")),
                    row.get("case_id"),
                    row.get("top_path_data_delay"),
                    row.get("top_path_logic_delay"),
                    row.get("top_path_route_delay"),
                    row.get("logic_route_ratio"),
                    row.get("grouped_wns_min"),
                    row.get("grouped_wns_mean"),
                    row.get("grouped_wns_max"),
                    row.get("grouped_wns_stddev"),
                ]
                for row in table_rows
            ],
        )
    )

    if len(rows) > len(table_rows):
        lines.append("")
        lines.append(f"- Markdown tables are truncated to {len(table_rows)} rows; full flattened data is in `summary.csv` and `summary.json`.")

    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args(argv)

    rows = flat_rows_with_group_stats(load_metrics(args.cases_root))
    coverage_rows = required_coverage_rows(rows)
    pure_rows = pure_capacity_result_rows(rows)
    missing_rows = missing_required_rows(coverage_rows)
    args.output_root.mkdir(parents=True, exist_ok=True)
    write_csv(args.output_root / "summary.csv", rows)
    write_json(args.output_root / "summary.json", rows, coverage_rows, pure_rows, missing_rows)
    write_aux_csv(
        args.output_root / "required_pure_benchmark_coverage.csv",
        coverage_rows,
        [
            "variant",
            "benchmark_mode",
            "ifetch_build_mode",
            "expected_cases",
            "actual_cases",
            "missing_sizes",
            "all_routed",
            "all_pure_kpi_valid",
            "pass_fail",
        ],
    )
    write_aux_csv(
        args.output_root / "pure_capacity_sweep_results.csv",
        pure_rows,
        [
            "KB",
            "variant",
            "benchmark_mode",
            "ifetch_build_mode",
            "overall_wns",
            "top_path_class",
            "direct_fetch_actual_memory",
            "content_classification",
            "wns_valid_for_pure_size_scaling",
            "boot_program_same_image",
            "prefix_preserved",
            "tail_type",
            "line_count_ok",
        ],
    )
    write_aux_csv(
        args.output_root / "missing_required_cases.csv",
        missing_rows,
        ["variant", "benchmark_mode", "ifetch_build_mode", "missing_sizes"],
    )
    write_markdown(args.output_root / "summary.md", rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
