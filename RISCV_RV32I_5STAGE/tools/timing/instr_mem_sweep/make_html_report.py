#!/usr/bin/env python3
"""Create an HTML validation report for the instruction-memory sweep."""

from __future__ import annotations

import argparse
import csv
import html
import math
from datetime import datetime
from pathlib import Path
from typing import Any

from make_summary import missing_required_rows, pure_capacity_result_rows, required_coverage_rows


NUMERIC_FIELDS = {
    "size_bytes",
    "depth_words",
    "addr_width",
    "wns_ns",
    "overall_wns",
    "top_path_data_delay",
    "top_path_logic_delay",
    "top_path_route_delay",
    "logic_route_ratio",
    "direct_fetch_wns",
    "direct_fetch_delay",
    "direct_fetch_logic",
    "direct_fetch_route",
    "bootrom_fetch_delay",
    "programram_fetch_delay",
    "ifetch_mux_to_ifid_delay",
    "async_reset_wns",
    "pc_update_control_wns",
    "actual_boot_line_count",
    "actual_program_line_count",
    "expected_boot_line_count",
    "expected_program_line_count",
    "parse_error_count",
    "grouped_wns_min",
    "grouped_wns_mean",
    "grouped_wns_max",
    "grouped_wns_stddev",
}


def parse_scalar(field: str, value: str) -> Any:
    value = value.strip()
    if value == "":
        return None
    if value in {"True", "true"}:
        return True
    if value in {"False", "false"}:
        return False
    if field not in NUMERIC_FIELDS:
        return value
    try:
        number = float(value)
    except ValueError:
        return None
    if math.isnan(number):
        return None
    if number.is_integer() and field not in {
        "wns_ns",
        "overall_wns",
        "top_path_data_delay",
        "top_path_logic_delay",
        "top_path_route_delay",
        "logic_route_ratio",
        "direct_fetch_wns",
        "direct_fetch_delay",
        "direct_fetch_logic",
        "direct_fetch_route",
        "bootrom_fetch_delay",
        "programram_fetch_delay",
        "ifetch_mux_to_ifid_delay",
        "async_reset_wns",
        "pc_update_control_wns",
        "grouped_wns_min",
        "grouped_wns_mean",
        "grouped_wns_max",
        "grouped_wns_stddev",
    }:
        return int(number)
    return number


def load_rows(path: Path) -> list[dict[str, Any]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return [{field: parse_scalar(field, value or "") for field, value in row.items()} for row in reader]


def fmt(value: Any, digits: int = 3) -> str:
    if value is None or value == "":
        return "-"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def size_label(value: Any) -> str:
    if value is None:
        return "-"
    size_bytes = int(value)
    return f"{size_bytes // 1024}KB" if size_bytes % 1024 == 0 else str(size_bytes)


def row_is_warning(row: dict[str, Any]) -> bool:
    return (
        row.get("wns_valid_for_pure_size_scaling") is False
        or row.get("boot_line_count_ok") is False
        or row.get("program_line_count_ok") is False
        or bool(row.get("parse_error_count"))
    )


def sort_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
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


def html_escape(value: Any) -> str:
    return html.escape(fmt(value))


def table(rows: list[dict[str, Any]], headers: list[tuple[str, str]], *, limit: int = 120) -> str:
    lines = ["<table>", "<thead><tr>"]
    lines.extend(f"<th>{html.escape(label)}</th>" for label, _ in headers)
    lines.extend(["</tr></thead>", "<tbody>"])
    for row in sort_rows(rows)[:limit]:
        cls = " class=\"warn\"" if row_is_warning(row) else ""
        lines.append(f"<tr{cls}>")
        for _, field in headers:
            value = size_label(row.get(field)) if field == "size_bytes" else row.get(field)
            lines.append(f"<td>{html_escape(value)}</td>")
        lines.append("</tr>")
    lines.extend(["</tbody>", "</table>"])
    if len(rows) > limit:
        lines.append(f"<p class=\"muted\">Showing first {limit} rows. Use summary.csv for all rows.</p>")
    return "\n".join(lines)


def simple_table(rows: list[dict[str, Any]], headers: list[tuple[str, str]], *, limit: int = 160) -> str:
    lines = ["<table>", "<thead><tr>"]
    lines.extend(f"<th>{html.escape(label)}</th>" for label, _ in headers)
    lines.extend(["</tr></thead>", "<tbody>"])
    for row in rows[:limit]:
        cls = " class=\"warn\"" if row.get("pass_fail") == "FAIL" else ""
        lines.append(f"<tr{cls}>")
        for _, field in headers:
            lines.append(f"<td>{html_escape(row.get(field))}</td>")
        lines.append("</tr>")
    lines.extend(["</tbody>", "</table>"])
    if len(rows) > limit:
        lines.append(f"<p class=\"muted\">Showing first {limit} rows. Use CSV/JSON outputs for all rows.</p>")
    return "\n".join(lines)


def build_html(rows: list[dict[str, Any]], output_path: Path) -> None:
    pass_count = sum(1 for row in rows if row.get("status") == "pass")
    pure_valid_count = sum(1 for row in rows if row.get("wns_valid_for_pure_size_scaling") is True)
    warn_count = sum(1 for row in rows if row_is_warning(row))
    power_two_count = sum(1 for row in rows if row.get("depth_group") == "power_of_two")
    coverage_rows = required_coverage_rows(rows)
    pure_rows = pure_capacity_result_rows(rows)
    missing_rows = missing_required_rows(coverage_rows)
    generated = datetime.now().strftime("%Y-%m-%d %H:%M")
    css = """
    :root { --text: #111827; --muted: #4b5563; --line: #d1d5db; --soft: #f3f4f6; --warn: #fff7ed; --accent: #1d4ed8; }
    * { box-sizing: border-box; }
    body { margin: 0; background: #fff; color: var(--text); font-family: "Segoe UI", Arial, sans-serif; line-height: 1.45; }
    main { max-width: 1240px; margin: 0 auto; padding: 36px 24px 56px; }
    header { border-bottom: 2px solid var(--text); padding-bottom: 16px; margin-bottom: 22px; }
    h1 { margin: 0 0 8px; font-size: 30px; letter-spacing: 0; }
    h2 { margin: 26px 0 10px; font-size: 18px; letter-spacing: 0; }
    .subhead, .muted { color: var(--muted); }
    .metrics { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin: 18px 0; }
    .metric { border: 1px solid var(--line); padding: 14px; min-height: 94px; }
    .metric b { display: block; font-size: 24px; margin-top: 8px; }
    .notice { border-left: 4px solid var(--accent); padding: 12px 16px; margin: 20px 0; }
    .table-wrap { overflow-x: auto; border: 1px solid var(--line); }
    table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
    th, td { border-bottom: 1px solid var(--line); padding: 7px 8px; text-align: left; vertical-align: top; white-space: nowrap; }
    th { background: var(--soft); font-weight: 700; }
    tr.warn td { background: var(--warn); }
    footer { margin-top: 24px; color: var(--muted); font-size: 12px; }
    @media (max-width: 900px) { .metrics { grid-template-columns: 1fr; } main { padding: 26px 16px 42px; } }
    """
    sections = [
        (
            "1. WNS / Top Path / Content Classification",
            [
                ("KB", "size_bytes"),
                ("Group", "depth_group"),
                ("Variant", "variant"),
                ("Benchmark", "benchmark_mode"),
                ("Build mode", "ifetch_build_mode"),
                ("WNS", "wns_ns"),
                ("Top path", "top_critical_path_class"),
                ("Classification", "content_classification"),
            ],
        ),
        (
            "2. Prefix Preservation",
            [
                ("KB", "size_bytes"),
                ("Case", "case_id"),
                ("Boot prefix", "boot_prefix_preserved_from_previous_size"),
                ("Program prefix", "program_prefix_preserved_from_previous_size"),
                ("Stable", "prefix_stable"),
            ],
        ),
        (
            "3. Tail Type / NOP",
            [
                ("KB", "size_bytes"),
                ("Case", "case_id"),
                ("Boot tail", "boot_tail_type"),
                ("Boot NOP", "boot_tail_is_all_nop"),
                ("Program tail", "program_tail_type"),
                ("Program NOP", "program_tail_is_all_nop"),
            ],
        ),
        (
            "4. Image Policy",
            [
                ("KB", "size_bytes"),
                ("Case", "case_id"),
                ("Build mode", "ifetch_build_mode"),
                ("Boot policy", "boot_image_policy"),
                ("Program policy", "program_image_policy"),
                ("Same image", "boot_program_same_image"),
            ],
        ),
        (
            "5. Depth / Addr Width / Line Count",
            [
                ("KB", "size_bytes"),
                ("Depth", "depth_words"),
                ("Addr width", "addr_width"),
                ("Boot lines", "actual_boot_line_count"),
                ("Boot ok", "boot_line_count_ok"),
                ("Program lines", "actual_program_line_count"),
                ("Program ok", "program_line_count_ok"),
                ("Guard", "has_depth_guard_comparator"),
            ],
        ),
        (
            "6. Pure Size Scaling KPI Validity",
            [
                ("KB", "size_bytes"),
                ("Case", "case_id"),
                ("Benchmark", "benchmark_mode"),
                ("Classification", "content_classification"),
                ("Pure valid", "wns_valid_for_pure_size_scaling"),
                ("Stress valid", "wns_valid_for_workload_stress"),
            ],
        ),
        (
            "7. Direct Fetch Actual Memory",
            [
                ("KB", "size_bytes"),
                ("Case", "case_id"),
                ("Found", "direct_fetch_path_found"),
                ("Actual memory", "direct_fetch_actual_memory"),
                ("WNS", "direct_fetch_wns"),
                ("Delay", "direct_fetch_delay"),
                ("Source", "direct_fetch_source"),
                ("Destination", "direct_fetch_destination"),
            ],
        ),
        (
            "8. Split Timing Attribution",
            [
                ("KB", "size_bytes"),
                ("Case", "case_id"),
                ("Boot delay", "bootrom_fetch_delay"),
                ("Program delay", "programram_fetch_delay"),
                ("Mux delay", "ifetch_mux_to_ifid_delay"),
                ("Async reset WNS", "async_reset_wns"),
                ("PC update WNS", "pc_update_control_wns"),
            ],
        ),
        (
            "9. Top Logic/Route and Seed Grouping",
            [
                ("KB", "size_bytes"),
                ("Case", "case_id"),
                ("Data", "top_path_data_delay"),
                ("Logic", "top_path_logic_delay"),
                ("Route", "top_path_route_delay"),
                ("Logic/route", "logic_route_ratio"),
                ("WNS min", "grouped_wns_min"),
                ("WNS mean", "grouped_wns_mean"),
                ("WNS max", "grouped_wns_max"),
                ("WNS stddev", "grouped_wns_stddev"),
            ],
        ),
    ]
    section_html = "\n".join(
        f"<section><h2>{html.escape(title)}</h2><div class=\"table-wrap\">{table(rows, headers)}</div></section>"
        for title, headers in sections
    )
    required_html = "\n".join(
        [
            "<section><h2>Required Pure Benchmark Coverage</h2><div class=\"table-wrap\">",
            simple_table(
                coverage_rows,
                [
                    ("variant", "variant"),
                    ("benchmark_mode", "benchmark_mode"),
                    ("ifetch_build_mode", "ifetch_build_mode"),
                    ("expected_cases", "expected_cases"),
                    ("actual_cases", "actual_cases"),
                    ("missing_sizes", "missing_sizes"),
                    ("all_routed", "all_routed"),
                    ("all_pure_kpi_valid", "all_pure_kpi_valid"),
                    ("pass_fail", "pass_fail"),
                ],
            ),
            "</div></section>",
            "<section><h2>Pure Capacity Sweep Results</h2><div class=\"table-wrap\">",
            simple_table(
                pure_rows,
                [
                    ("KB", "KB"),
                    ("variant", "variant"),
                    ("benchmark_mode", "benchmark_mode"),
                    ("ifetch_build_mode", "ifetch_build_mode"),
                    ("overall_wns", "overall_wns"),
                    ("top_path_class", "top_path_class"),
                    ("direct_fetch_actual_memory", "direct_fetch_actual_memory"),
                    ("content_classification", "content_classification"),
                    ("wns_valid_for_pure_size_scaling", "wns_valid_for_pure_size_scaling"),
                    ("boot_program_same_image", "boot_program_same_image"),
                    ("prefix_preserved", "prefix_preserved"),
                    ("tail_type", "tail_type"),
                    ("line_count_ok", "line_count_ok"),
                ],
            ),
            "</div></section>",
            "<section><h2>Missing Required Cases</h2><div class=\"table-wrap\">",
            simple_table(
                missing_rows,
                [
                    ("variant", "variant"),
                    ("benchmark_mode", "benchmark_mode"),
                    ("ifetch_build_mode", "ifetch_build_mode"),
                    ("missing_sizes", "missing_sizes"),
                ],
            )
            if missing_rows
            else "<p class=\"muted\">No required pure benchmark cases are missing.</p>",
            "</div></section>",
        ]
    )
    document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Instruction Memory Sweep Validation</title>
  <style>{css}</style>
</head>
<body>
  <main>
    <header>
      <h1>Instruction Memory Sweep Validation</h1>
      <p class="subhead">Routed WNS is kept as the final SoC KPI, with image policy and content validity shown next to timing.</p>
    </header>
    <section class="metrics">
      <div class="metric">Cases<b>{len(rows)}</b></div>
      <div class="metric">Pass rows<b>{pass_count}</b></div>
      <div class="metric">Pure-KPI valid<b>{pure_valid_count}</b></div>
      <div class="metric">Power-of-two depth rows<b>{power_two_count}</b></div>
    </section>
    <section class="notice">
      Warning-highlighted rows are invalid for pure size scaling, have line-count failures, or include parser/report errors. Mixed firmware rows are retained as workload stress data.
    </section>
    {required_html}
    {section_html}
    <footer>Generated: {html.escape(generated)} · Warnings: {warn_count} · Source: {html.escape(str(output_path.parent / "summary.csv"))}</footer>
  </main>
</body>
</html>
"""
    output_path.write_text(document, encoding="utf-8")


def build_report(summary_csv: Path, output_html: Path) -> None:
    rows = load_rows(summary_csv)
    output_html.parent.mkdir(parents=True, exist_ok=True)
    build_html(rows, output_html)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary-csv",
        default=Path("output/instr_mem_sweep/summary.csv"),
        type=Path,
        help="Path to summary.csv.",
    )
    parser.add_argument(
        "--output-html",
        default=Path("output/instr_mem_sweep/instr_mem_sweep_charts.html"),
        type=Path,
        help="HTML report path.",
    )
    args = parser.parse_args(argv)
    build_report(args.summary_csv, args.output_html)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
