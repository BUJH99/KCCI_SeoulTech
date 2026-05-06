from __future__ import annotations

import argparse
import csv
import pathlib
import re
import sys
from collections import Counter
from collections.abc import Callable
from datetime import datetime
from typing import Any


PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[1]
REPO_ROOT = PROJECT_ROOT.parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from templates.contexts.timing_verification.adapters.python.riscv_timing_analysis.common import (  # noqa: E402
    ProgressTracker,
    load_project_contract,
    run_vivado_batch,
    write_wrapper_tcl,
    wsl_to_windows,
)
from templates.contexts.timing_verification.adapters.python.riscv_timing_analysis.execution_metrics import (  # noqa: E402
    analyze_program_trace,
    compute_runtime_speedup,
    estimate_single_cycle_execution,
    format_ratio,
    format_runtime_ns,
)
from templates.contexts.timing_verification.adapters.python.riscv_timing_analysis.focus import (  # noqa: E402
    find_module_source_path,
    parse_ansi_module_ports,
    prepare_focus_analysis_assets,
    render_defparam_wrapper,
    sanitize_token,
    strip_mem_lines,
    trace_program_words,
)
from templates.contexts.timing_verification.adapters.python.riscv_timing_analysis.integrated_report import (  # noqa: E402
    highest_status,
    merge_program_detail_section,
    render_finding_table,
    render_recommended_actions,
    shift_markdown_headings,
    status_badge,
    strip_first_markdown_heading,
    strip_noisy_report_sections,
    write_html_report,
)
from templates.contexts.timing_verification.adapters.python.riscv_timing_analysis.rv32i import (  # noqa: E402
    DEFAULT_CLASS_ORDER,
    classify_word,
    classify_mnemonic,
    parse_asm_instructions,
)


PROGRAM_LIBRARY: dict[str, dict[str, pathlib.Path | str]] = {
    "full_coverage": {
        "label": "Full Coverage",
        "mem_relpath": pathlib.Path("src") / "timing_programs" / "Full Coverage.mem",
        "asm_relpath": pathlib.Path("src") / "timing_programs" / "Full Coverage.s",
    },
    "bubble_sort": {
        "label": "Bubble Sort",
        "mem_relpath": pathlib.Path("src") / "timing_programs" / "Bubble Sort.mem",
        "asm_relpath": pathlib.Path("src") / "timing_programs" / "Bubble Sort.s",
    },
}

PROGRAM_ALIASES = {
    "full_coverage": "full_coverage",
    "fullcoverage": "full_coverage",
    "full_coverage_mem": "full_coverage",
    "full_coverage_s": "full_coverage",
    "bubble_sort": "bubble_sort",
    "bubblesort": "bubble_sort",
    "bubble_sort_mem": "bubble_sort",
    "bubble_sort_s": "bubble_sort",
}

SECTION_START_TEMPLATE = "<!-- PROGRAM_SECTION:{program_key}:START -->"
SECTION_END_TEMPLATE = "<!-- PROGRAM_SECTION:{program_key}:END -->"


def parse_summary(path: pathlib.Path, clock_period_ns: float) -> dict[str, float | None]:
    if not path.exists():
        return {
            "wns_ns": None,
            "tns_ns": None,
            "min_period_ns": None,
            "fmax_mhz": None,
        }

    text = path.read_text(encoding="utf-8", errors="ignore")
    result: dict[str, float | None] = {
        "wns_ns": None,
        "tns_ns": None,
        "min_period_ns": None,
        "fmax_mhz": None,
    }

    lines = text.splitlines()
    for idx, line in enumerate(lines):
        if "WNS(ns)" not in line or "TNS(ns)" not in line:
            continue
        for look_ahead in range(idx + 1, min(idx + 8, len(lines))):
            candidate = lines[look_ahead].strip()
            match = re.match(r"([-\d.]+)\s+([-\d.]+)\s+\d+\s+\d+\s+([-\d.]+)\s+([-\d.]+)", candidate)
            if not match:
                continue
            result["wns_ns"] = float(match.group(1))
            result["tns_ns"] = float(match.group(2))
            result["min_period_ns"] = clock_period_ns - float(match.group(1))
            break
        if result["min_period_ns"] is not None:
            break

    if result["min_period_ns"] and result["min_period_ns"] > 0:
        result["fmax_mhz"] = 1000.0 / float(result["min_period_ns"])

    return result


def analyze_project_pipeline_trace(mem_path: pathlib.Path) -> dict[str, Any]:
    resolved_mem_path = mem_path.resolve()
    summary = analyze_program_trace(resolved_mem_path)
    trace = trace_program_words(strip_mem_lines(resolved_mem_path))
    retired = list(trace.get("retired", []))

    branch_redirect_count = sum(
        1
        for item in retired[:-1]
        if bool(item.get("is_branch")) and bool(item.get("taken"))
    )
    jal_redirect_count = sum(1 for item in retired[:-1] if str(item.get("mnemonic")) == "jal")
    jalr_redirect_count = sum(1 for item in retired[:-1] if str(item.get("mnemonic")) == "jalr")

    summary.update(
        {
            "branch_redirect_count": int(branch_redirect_count),
            "jal_redirect_count": int(jal_redirect_count),
            "jalr_redirect_count": int(jalr_redirect_count),
        }
    )
    return summary


def estimate_project_pipeline_execution(
    trace_summary: dict[str, Any],
    min_period_ns: float | None,
) -> dict[str, Any]:
    instruction_count = int(trace_summary.get("instruction_count", 0))
    fill_cycles = 4 if instruction_count > 0 else 0
    stall_cycles = int(trace_summary.get("load_use_stall_count", 0))
    branch_redirect_cycles = 2 * int(trace_summary.get("branch_redirect_count", 0))
    jal_redirect_cycles = int(trace_summary.get("jal_redirect_count", 0))
    jalr_redirect_cycles = 2 * int(trace_summary.get("jalr_redirect_count", 0))
    redirect_penalty_cycles = branch_redirect_cycles + jal_redirect_cycles + jalr_redirect_cycles
    cycle_count = instruction_count + fill_cycles + stall_cycles + redirect_penalty_cycles
    cpi = (cycle_count / instruction_count) if instruction_count > 0 else None
    runtime_ns = (cycle_count * min_period_ns) if min_period_ns is not None else None

    return {
        "architecture": "5-Stage Pipeline",
        "instruction_count": instruction_count,
        "cycle_count": cycle_count,
        "cpi": cpi,
        "runtime_ns": runtime_ns,
        "fill_cycles": fill_cycles,
        "stall_cycles": stall_cycles,
        "redirect_penalty_cycles": redirect_penalty_cycles,
        "branch_redirect_cycles": branch_redirect_cycles,
        "jal_redirect_cycles": jal_redirect_cycles,
        "jalr_redirect_cycles": jalr_redirect_cycles,
        "model_note": "retired + 4 fill + load-use stalls + 2-cycle taken branches/JALR + 1-cycle decode-resolved JAL",
    }


def parse_timing_paths_tsv(path: pathlib.Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []

    rows: list[dict[str, Any]] = []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            if not row.get("index"):
                continue
            try:
                rows.append(
                    {
                        "index": int(row["index"]),
                        "slack_ns": float(row["slack_ns"]),
                        "min_period_ns": float(row["min_period_ns"]),
                        "datapath_delay_ns": float(row["datapath_delay_ns"]),
                        "logic_delay_ns": float(row["logic_delay_ns"]),
                        "net_delay_ns": float(row["net_delay_ns"]),
                        "route_share_pct": float(row["route_share_pct"]),
                        "logic_share_pct": float(row["logic_share_pct"]),
                        "logic_levels": int(float(row["logic_levels"])),
                        "max_fanout": int(float(row["max_fanout"] or 0.0)),
                        "start_pin": row["start_pin"],
                        "end_pin": row["end_pin"],
                        "path_name": row["path_name"],
                    }
                )
            except (KeyError, TypeError, ValueError):
                continue
    return rows


def count_unique_timing_paths(rows: list[dict[str, Any]]) -> int:
    unique_keys = {
        (
            str(row.get("start_pin", "")),
            str(row.get("end_pin", "")),
            f"{float(row.get('slack_ns', 0.0)):.6f}",
        )
        for row in rows
    }
    return len(unique_keys)


def extract_route_status(path: pathlib.Path) -> str:
    if not path.exists():
        return "NA"
    text = path.read_text(encoding="utf-8", errors="ignore")
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("Routing status:"):
            return stripped.split(":", 1)[1].strip()
    if "# of fully routed nets" in text and "# of nets with routing errors" in text:
        if re.search(r"# of fully routed nets\.*\s*:\s*\d+", text) and re.search(
            r"# of nets with routing errors\.*\s*:\s*0\b", text
        ):
            return "fully routed"
    if "Design is fully routed" in text:
        return "fully routed"
    return "unknown"


def extract_utilization_lut_ff(path: pathlib.Path) -> tuple[str, str]:
    if not path.exists():
        return "NA", "NA"
    lut_used = "NA"
    ff_used = "NA"
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if "Slice LUTs" in line and "|" in line:
            parts = [part.strip() for part in line.split("|") if part.strip()]
            if len(parts) >= 2 and parts[0] == "Slice LUTs":
                lut_used = parts[1]
        if "Slice Registers" in line and "|" in line:
            parts = [part.strip() for part in line.split("|") if part.strip()]
            if len(parts) >= 2 and parts[0] == "Slice Registers":
                ff_used = parts[1]
    return lut_used, ff_used


def fmt_float(value: float | None, digits: int = 3) -> str:
    if value is None:
        return "NA"
    return f"{value:.{digits}f}"


def fmt_int(value: int | None) -> str:
    if value is None:
        return "NA"
    return str(value)


def parse_int_metric(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)

    text = str(value).replace(",", "").strip()
    if not text or text.upper() == "NA":
        return None
    try:
        return int(float(text))
    except ValueError:
        return None


def fmt_delta_float(left: float | None, right: float | None, digits: int = 3) -> str:
    if left is None or right is None:
        return "NA"
    return f"{right - left:+.{digits}f}"


def fmt_delta_int(left: int | None, right: int | None) -> str:
    if left is None or right is None:
        return "NA"
    return f"{right - left:+d}"


def fmt_delta_ratio(left: float | None, right: float | None, digits: int = 3) -> str:
    if left is None or right is None:
        return "NA"
    return f"{right - left:+.{digits}f}x"


def determine_pipeline_verdict(
    *,
    pipeline_wns_ns: float | None,
    warning_count: int,
    focus_status: str,
) -> str:
    if pipeline_wns_ns is not None and pipeline_wns_ns < 0:
        return "FAIL"
    if warning_count > 0 or focus_status != "PASS":
        return "WARN"
    return "PASS"


def describe_runtime_winner(
    single_runtime_ns: float | None,
    pipeline_runtime_ns: float | None,
) -> str:
    if single_runtime_ns is None or pipeline_runtime_ns is None:
        return "NA"
    if abs(single_runtime_ns - pipeline_runtime_ns) < 1e-9:
        return "Tie"
    if pipeline_runtime_ns < single_runtime_ns:
        return f"5-stage pipeline ({format_runtime_ns(single_runtime_ns - pipeline_runtime_ns)} faster)"
    return f"Single-cycle ({format_runtime_ns(pipeline_runtime_ns - single_runtime_ns)} faster)"


def unique_strings(values: list[str]) -> list[str]:
    seen: set[str] = set()
    ordered: list[str] = []
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        ordered.append(value)
    return ordered


def safe_mean(values: list[float]) -> float | None:
    return (sum(values) / len(values)) if values else None


def format_family_search_detail(family: dict[str, Any]) -> str:
    search_groups = [
        ("instance", list(family.get("instance_patterns", []))),
        ("ref", list(family.get("ref_name_patterns", []))),
        ("endpoint", list(family.get("endpoint_patterns", []))),
        ("pin", list(family.get("pin_name_patterns", []))),
    ]
    rendered = [f"{label}={','.join(patterns)}" for label, patterns in search_groups if patterns]
    return "; ".join(rendered) if rendered else "no search patterns recorded"


def format_pin_search_detail(pin_spec: dict[str, Any]) -> str:
    search_groups = [
        ("instance", list(pin_spec.get("instance_patterns", []))),
        ("ref", list(pin_spec.get("ref_name_patterns", []))),
        ("endpoint", list(pin_spec.get("endpoint_patterns", []))),
        ("pin", list(pin_spec.get("pin_name_patterns", []))),
    ]
    rendered = [f"{label}={','.join(patterns)}" for label, patterns in search_groups if patterns]
    return "; ".join(rendered) if rendered else "no search patterns recorded"


def parse_focus_filter(raw_value: str) -> set[str] | None:
    if not raw_value.strip():
        return None
    return {item.strip().lower() for item in raw_value.split(",") if item.strip()}


def normalize_program_key(raw_value: str | None) -> str:
    token = (raw_value or "full_coverage").strip().lower()
    if token.endswith(".mem") or token.endswith(".s"):
        token = token.rsplit(".", 1)[0]
    token = re.sub(r"[^a-z0-9]+", "_", token).strip("_")
    return PROGRAM_ALIASES.get(token, token)


def resolve_selected_program(raw_value: str | None) -> dict[str, Any]:
    program_key = normalize_program_key(raw_value)
    if program_key not in PROGRAM_LIBRARY:
        supported = ", ".join(sorted(PROGRAM_LIBRARY))
        raise ValueError(f"Unsupported timing program `{raw_value}`. Supported values: {supported}.")

    program_cfg = PROGRAM_LIBRARY[program_key]
    mem_path = (PROJECT_ROOT / pathlib.Path(program_cfg["mem_relpath"])).resolve()
    asm_path = (PROJECT_ROOT / pathlib.Path(program_cfg["asm_relpath"])).resolve()
    if not mem_path.exists():
        raise FileNotFoundError(f"Timing program image was not found: {mem_path}")

    return {
        "key": program_key,
        "label": str(program_cfg["label"]),
        "mem_path": mem_path,
        "asm_path": asm_path if asm_path.exists() else None,
        "display_name": mem_path.name,
    }


def build_focus_cfg_for_program(focus_cfg: dict[str, Any], program_selection: dict[str, Any]) -> dict[str, Any]:
    updated_cfg = dict(focus_cfg)
    mem_path = pathlib.Path(program_selection["mem_path"]).resolve()
    try:
        updated_cfg["instruction_mem_relpath"] = mem_path.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        updated_cfg["instruction_mem_relpath"] = str(mem_path)
    return updated_cfg


def resolve_base_rom_param_path(contract: dict[str, Any]) -> str:
    focus_cfg = dict(contract["profile"].get("focus_analysis", {}))
    rom_param_path = str(focus_cfg.get("rom_param_path", "")).strip()
    if rom_param_path:
        return rom_param_path
    if str(contract["project_name"]) == "RISCV_32I_SINGLE":
        return "uInstrRom.P_INIT_FILE"
    raise KeyError(f"ROM init parameter path is not configured for {contract['project_name']}.")


def prepare_program_wrapper_assets(
    contract: dict[str, Any],
    output_dir: pathlib.Path,
    program_selection: dict[str, Any],
) -> dict[str, Any]:
    wrapper_dir = output_dir / "program_wrapper"
    wrapper_dir.mkdir(parents=True, exist_ok=True)

    top_name = str(contract["top_name"])
    top_source_path = find_module_source_path(list(contract["source_files"]), top_name)
    top_ports = parse_ansi_module_ports(top_source_path.read_text(encoding="utf-8", errors="ignore"), top_name)
    wrapper_module_name = (
        "TimingProgramTop_"
        + sanitize_token(f"{contract['project_name']}_{program_selection['key']}").upper()
    )
    wrapper_path = wrapper_dir / f"{wrapper_module_name}.sv"
    wrapper_path.write_text(
        render_defparam_wrapper(
            wrapper_module_name=wrapper_module_name,
            top_name=top_name,
            top_ports=top_ports,
            clock_port=str(contract["clock_port"]),
            reset_port=str(contract["reset_port"]),
            instance_name="uDesign",
            rom_param_path=resolve_base_rom_param_path(contract),
            mem_file_path=pathlib.Path(program_selection["mem_path"]),
        ),
        encoding="utf-8",
    )

    return {
        "wrapper_path": wrapper_path,
        "wrapper_module_name": wrapper_module_name,
        "source_files": list(contract["source_files"]) + [wrapper_path],
    }


def parse_selected_instruction_program_details(program_selection: dict[str, Any]) -> dict[str, Any]:
    asm_path = pathlib.Path(program_selection["asm_path"]) if program_selection.get("asm_path") else None
    mem_path = pathlib.Path(program_selection["mem_path"]).resolve()
    class_counts = Counter({class_name: 0 for class_name in DEFAULT_CLASS_ORDER})
    mnemonic_counts: Counter[str] = Counter()
    ordered_mnemonics: list[str] = []
    instructions: list[dict[str, Any]] = []
    warnings: list[str] = []

    if asm_path and asm_path.exists():
        instructions = parse_asm_instructions(asm_path)
        seen_mnemonics: set[str] = set()
        for row in instructions:
            class_name = row["class_name"]
            mnemonic = row["mnemonic"]
            class_counts[class_name] += 1
            mnemonic_counts[mnemonic] += 1
            if mnemonic not in seen_mnemonics:
                seen_mnemonics.add(mnemonic)
                ordered_mnemonics.append(mnemonic)
        return {
            "class_counts": dict(class_counts),
            "mnemonic_counts": dict(mnemonic_counts),
            "ordered_mnemonics": ordered_mnemonics,
            "instructions": instructions,
            "instruction_source": str(asm_path),
            "warnings": warnings,
        }

    for raw_line in mem_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        token = raw_line.strip().replace("_", "")
        if not token:
            continue
        try:
            class_name = classify_word(int(token, 16))
        except ValueError:
            continue
        if class_name:
            class_counts[class_name] += 1

    warnings.append(f"{mem_path.name} was used, so mnemonic-level timing rows could not be resolved.")
    return {
        "class_counts": dict(class_counts),
        "mnemonic_counts": {},
        "ordered_mnemonics": [],
        "instructions": [],
        "instruction_source": str(mem_path),
        "warnings": warnings,
    }


def build_empty_focus_summary(detail: str, selected_focuses: set[str] | None = None) -> dict[str, Any]:
    return {
        "class_rows": [],
        "mnemonic_rows": [],
        "focus_count": 0,
        "measured_focus_count": 0,
        "selected_focuses": sorted(selected_focuses) if selected_focuses else [],
        "status": "INFO",
        "detail": detail,
    }


def build_family_configs(profile: dict[str, Any]) -> list[dict[str, Any]]:
    family_configs: list[dict[str, Any]] = []
    for family in profile.get("probe_families", []):
        family_configs.append(
            {
                "key": str(family["key"]),
                "label": str(family.get("label", family["key"])),
                "description": str(family.get("description", "")),
                "artifact_key": str(family.get("artifact_key", family["key"])),
                "stage": str(family.get("stage", "NA")),
                "instance_patterns": list(family.get("instance_patterns", [])),
                "ref_name_patterns": list(family.get("ref_name_patterns", [])),
                "endpoint_patterns": list(family.get("endpoint_patterns", [])),
                "pin_name_patterns": list(family.get("pin_name_patterns", ["D"])),
            }
        )
    return family_configs


def build_stage_boundary_configs(profile: dict[str, Any]) -> list[dict[str, Any]]:
    boundary_configs: list[dict[str, Any]] = []
    for boundary in profile.get("stage_boundaries", []):
        boundary_configs.append(
            {
                "key": str(boundary["key"]),
                "label": str(boundary.get("label", boundary["key"])),
                "description": str(boundary.get("description", "")),
                "artifact_key": str(boundary.get("artifact_key", boundary["key"])),
                "stage": str(boundary.get("stage", "NA")),
                "from": dict(boundary.get("from", {})),
                "to": dict(boundary.get("to", {})),
            }
        )
    return boundary_configs


def run_vivado_for_project(
    contract: dict[str, object],
    output_dir: pathlib.Path,
    collector_tcl: pathlib.Path,
    implementation_cfg: dict[str, object],
    *,
    program_selection: dict[str, Any] | None = None,
    progress_label: str,
    progress_callback: Callable[[int, int, str], None] | None = None,
) -> pathlib.Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    wrapper_tcl = output_dir / "run_pipeline_perf_wrapper.tcl"
    log_path = output_dir / "vivado_run.log"
    source_files = list(contract["source_files"])
    top_name = str(contract["top_name"])

    if program_selection is not None:
        wrapper_assets = prepare_program_wrapper_assets(contract, output_dir, program_selection)
        source_files = list(wrapper_assets["source_files"])
        top_name = str(wrapper_assets["wrapper_module_name"])

    write_wrapper_tcl(
        wrapper_tcl,
        variables={
            "source_files": [wsl_to_windows(path) for path in source_files],
            "output_dir": wsl_to_windows(output_dir),
            "repo_root": wsl_to_windows(contract["repo_root"]),
            "part_name": contract["part_name"],
            "top_name": top_name,
            "clock_port": contract["clock_port"],
            "reset_port": contract["reset_port"],
            "clk_period_ns": float(contract["clock_period_ns"]),
            "family_configs": build_family_configs(contract["profile"]),
            "stage_boundary_configs": build_stage_boundary_configs(contract["profile"]),
            "synth_directive": implementation_cfg["synth_directive"],
            "opt_directive": implementation_cfg["opt_directive"],
            "place_directive": implementation_cfg["place_directive"],
            "phys_opt_directive": implementation_cfg["phys_opt_directive"],
            "route_directive": implementation_cfg["route_directive"],
            "post_route_phys_opt_directive": implementation_cfg["post_route_phys_opt_directive"],
            "core_pblock_clock_region": implementation_cfg["core_pblock_clock_region"],
        },
        source_path=collector_tcl,
    )
    return run_vivado_batch(
        project_root=contract["project_root"],
        wrapper_tcl=wrapper_tcl,
        log_path=log_path,
        progress_label=progress_label,
        progress_callback=progress_callback,
    )


def run_instruction_focus_vivado(
    contract: dict[str, Any],
    output_dir: pathlib.Path,
    implementation_cfg: dict[str, Any],
    *,
    prepared_metadata: dict[str, Any] | None = None,
    selected_focuses: set[str] | None = None,
    progress_label: str,
    progress_callback: Callable[[int, int, str], None] | None = None,
) -> dict[str, Any]:
    focus_cfg = dict(contract["profile"].get("focus_analysis", {}))
    if not focus_cfg.get("enabled", False):
        return {}

    metadata = prepared_metadata or prepare_focus_analysis_assets(
        contract,
        focus_cfg,
        output_dir,
        selected_focuses=selected_focuses,
    )
    focus_entries = list(metadata.get("focus_entries", []))
    if not focus_entries:
        return metadata

    wrapper_tcl = output_dir / "run_instruction_focus_wrapper.tcl"
    log_path = output_dir / "vivado_run.log"
    collector_tcl = REPO_ROOT / "templates" / "contexts" / "timing_verification" / "adapters" / "tcl" / "focus_collect_core.tcl"

    write_wrapper_tcl(
        wrapper_tcl,
        variables={
            "source_files": [wsl_to_windows(path) for path in contract["source_files"]],
            "generated_source_files": [wsl_to_windows(pathlib.Path(entry["wrapper_path"])) for entry in focus_entries],
            "output_dir": wsl_to_windows(output_dir),
            "repo_root": wsl_to_windows(contract["repo_root"]),
            "part_name": contract["part_name"],
            "clock_port": contract["clock_port"],
            "reset_port": contract["reset_port"],
            "clk_period_ns": float(contract["clock_period_ns"]),
            "family_configs": build_family_configs(contract["profile"]),
            "stage_boundary_configs": build_stage_boundary_configs(contract["profile"]),
            "focus_configs": [
                {
                    "key": str(entry["output_dir_name"]),
                    "top_name": str(entry["wrapper_module_name"]),
                }
                for entry in focus_entries
            ],
            "synth_directive": implementation_cfg["synth_directive"],
            "opt_directive": implementation_cfg["opt_directive"],
            "place_directive": implementation_cfg["place_directive"],
            "phys_opt_directive": implementation_cfg["phys_opt_directive"],
            "route_directive": implementation_cfg["route_directive"],
            "post_route_phys_opt_directive": implementation_cfg["post_route_phys_opt_directive"],
        },
        source_path=collector_tcl,
    )
    run_vivado_batch(
        project_root=contract["project_root"],
        wrapper_tcl=wrapper_tcl,
        log_path=log_path,
        progress_label=progress_label,
        progress_callback=progress_callback,
    )
    return metadata


def collect_project_metrics(output_dir: pathlib.Path, clock_period_ns: float) -> dict[str, str | float | None]:
    timing = parse_summary(output_dir / "post_route_timing_summary.rpt", clock_period_ns)
    route_status = extract_route_status(output_dir / "post_route_route_status.rpt")
    lut_used, ff_used = extract_utilization_lut_ff(output_dir / "post_route_utilization.rpt")
    return {
        "wns_ns": timing["wns_ns"],
        "tns_ns": timing["tns_ns"],
        "min_period_ns": timing["min_period_ns"],
        "fmax_mhz": timing["fmax_mhz"],
        "route_status": route_status,
        "lut_used": lut_used,
        "ff_used": ff_used,
    }


def has_family_timing_data(output_dir: pathlib.Path, profile: dict[str, Any]) -> bool:
    for family in profile.get("probe_families", []):
        candidate_keys = unique_strings(
            [str(family.get("artifact_key", family["key"]))] + list(family.get("artifact_aliases", []))
        )
        for candidate_key in candidate_keys:
            if (output_dir / f"{candidate_key}_timing_paths.tsv").exists():
                return True
    return False


def resolve_metrics_output_dir(
    preferred_dir: pathlib.Path,
    legacy_dir: pathlib.Path,
    *,
    summary_only: bool = False,
    profile: dict[str, Any] | None = None,
) -> pathlib.Path:
    if summary_only:
        if (preferred_dir / "post_route_timing_summary.rpt").exists():
            return preferred_dir
        if (legacy_dir / "post_route_timing_summary.rpt").exists():
            return legacy_dir
        return preferred_dir

    if profile is not None and has_family_timing_data(preferred_dir, profile):
        return preferred_dir
    if profile is not None and has_family_timing_data(legacy_dir, profile):
        return legacy_dir
    return preferred_dir


def collect_family_timing_rows(output_dir: pathlib.Path, profile: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for family in profile.get("probe_families", []):
        candidate_keys = unique_strings(
            [str(family.get("artifact_key", family["key"]))] + list(family.get("artifact_aliases", []))
        )
        chosen_key = None
        timing_rows: list[dict[str, Any]] = []
        first_existing_key = None
        for candidate_key in candidate_keys:
            tsv_path = output_dir / f"{candidate_key}_timing_paths.tsv"
            if not tsv_path.exists():
                continue
            if first_existing_key is None:
                first_existing_key = candidate_key
            parsed_rows = parse_timing_paths_tsv(tsv_path)
            if parsed_rows:
                chosen_key = candidate_key
                timing_rows = parsed_rows
                break
        if chosen_key is None and first_existing_key is not None:
            chosen_key = first_existing_key
            timing_rows = parse_timing_paths_tsv(output_dir / f"{chosen_key}_timing_paths.tsv")

        chosen_key = chosen_key or str(family.get("artifact_key", family["key"]))
        worst_path = timing_rows[0] if timing_rows else None
        min_period_ns = float(worst_path["min_period_ns"]) if worst_path else None
        datapath_delay_ns = float(worst_path["datapath_delay_ns"]) if worst_path else None
        fmax_mhz = 1000.0 / min_period_ns if min_period_ns and min_period_ns > 0 else None
        rows.append(
            {
                "key": str(family["key"]),
                "label": str(family.get("label", family["key"])),
                "description": str(family.get("description", "")),
                "artifact_key": chosen_key,
                "stage": str(family.get("stage", "NA")),
                "instance_patterns": list(family.get("instance_patterns", [])),
                "ref_name_patterns": list(family.get("ref_name_patterns", [])),
                "endpoint_patterns": list(family.get("endpoint_patterns", [])),
                "pin_name_patterns": list(family.get("pin_name_patterns", ["D"])),
                "tsv_path": output_dir / f"{chosen_key}_timing_paths.tsv",
                "report_path": output_dir / f"{chosen_key}_timing_top20.rpt",
                "path_count": len(timing_rows),
                "unique_path_count": count_unique_timing_paths(timing_rows),
                "worst_path": worst_path,
                "min_period_ns": min_period_ns,
                "datapath_delay_ns": datapath_delay_ns,
                "fmax_mhz": fmax_mhz,
            }
        )
    return rows


def collect_stage_boundary_timing_rows(output_dir: pathlib.Path, profile: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for boundary in profile.get("stage_boundaries", []):
        candidate_keys = unique_strings(
            [str(boundary.get("artifact_key", boundary["key"]))] + list(boundary.get("artifact_aliases", []))
        )
        chosen_key = None
        timing_rows: list[dict[str, Any]] = []
        first_existing_key = None
        for candidate_key in candidate_keys:
            tsv_path = output_dir / f"{candidate_key}_timing_paths.tsv"
            if not tsv_path.exists():
                continue
            if first_existing_key is None:
                first_existing_key = candidate_key
            parsed_rows = parse_timing_paths_tsv(tsv_path)
            if parsed_rows:
                chosen_key = candidate_key
                timing_rows = parsed_rows
                break
        if chosen_key is None and first_existing_key is not None:
            chosen_key = first_existing_key
            timing_rows = parse_timing_paths_tsv(output_dir / f"{chosen_key}_timing_paths.tsv")

        chosen_key = chosen_key or str(boundary.get("artifact_key", boundary["key"]))
        worst_path = timing_rows[0] if timing_rows else None
        min_period_ns = float(worst_path["min_period_ns"]) if worst_path else None
        datapath_delay_ns = float(worst_path["datapath_delay_ns"]) if worst_path else None
        fmax_mhz = 1000.0 / min_period_ns if min_period_ns and min_period_ns > 0 else None
        rows.append(
            {
                "key": str(boundary["key"]),
                "label": str(boundary.get("label", boundary["key"])),
                "description": str(boundary.get("description", "")),
                "artifact_key": chosen_key,
                "stage": str(boundary.get("stage", "NA")),
                "from": dict(boundary.get("from", {})),
                "to": dict(boundary.get("to", {})),
                "tsv_path": output_dir / f"{chosen_key}_timing_paths.tsv",
                "report_path": output_dir / f"{chosen_key}_timing_top20.rpt",
                "path_count": len(timing_rows),
                "unique_path_count": count_unique_timing_paths(timing_rows),
                "worst_path": worst_path,
                "min_period_ns": min_period_ns,
                "datapath_delay_ns": datapath_delay_ns,
                "fmax_mhz": fmax_mhz,
            }
        )
    return rows


def choose_worst_family(family_rows: dict[str, dict[str, Any]], candidate_keys: list[str]) -> dict[str, Any] | None:
    matches = [family_rows[key] for key in candidate_keys if key in family_rows]
    valid = [row for row in matches if row.get("min_period_ns") is not None]
    if valid:
        return max(valid, key=lambda row: float(row["min_period_ns"]))
    return matches[0] if matches else None


def build_boundary_by_stage(boundary_rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    stage_rows: dict[str, dict[str, Any]] = {}
    for row in boundary_rows:
        stage = str(row.get("stage", "NA"))
        current = stage_rows.get(stage)
        if current is None:
            stage_rows[stage] = row
            continue
        if row.get("min_period_ns") is None:
            continue
        if current.get("min_period_ns") is None or float(row["min_period_ns"]) > float(current["min_period_ns"]):
            stage_rows[stage] = row
    return stage_rows


def choose_stage_timing_cell(
    *,
    stage: str,
    candidate_keys: list[str],
    family_by_key: dict[str, dict[str, Any]],
    boundary_by_stage: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    if not candidate_keys:
        return None
    boundary_row = boundary_by_stage.get(stage)
    if boundary_row and boundary_row.get("min_period_ns") is not None:
        return boundary_row
    return choose_worst_family(family_by_key, candidate_keys)


def build_class_stage_rows(
    profile: dict[str, Any],
    instruction_details: dict[str, Any],
    family_rows: list[dict[str, Any]],
    boundary_rows: list[dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    family_by_key = {row["key"]: row for row in family_rows}
    boundary_by_stage = build_boundary_by_stage(boundary_rows or [])
    class_stage_candidate_map = dict(profile.get("class_stage_candidate_map", {}))
    stage_order = list(profile.get("stage_order", []))
    class_counts = dict(instruction_details.get("class_counts", {}))

    rows: list[dict[str, Any]] = []
    for class_name in DEFAULT_CLASS_ORDER:
        count = int(class_counts.get(class_name, 0))
        if count <= 0:
            continue
        mapping = dict(class_stage_candidate_map.get(class_name, {}))
        stage_cells: dict[str, dict[str, Any] | None] = {}
        for stage in stage_order:
            stage_cells[stage] = choose_stage_timing_cell(
                stage=stage,
                candidate_keys=list(mapping.get(stage, [])),
                family_by_key=family_by_key,
                boundary_by_stage=boundary_by_stage,
            )
        rows.append(
            {
                "class_name": class_name,
                "instruction_count": count,
                "stage_cells": stage_cells,
            }
        )
    return rows


def build_mnemonic_stage_rows(
    profile: dict[str, Any],
    instruction_details: dict[str, Any],
    family_rows: list[dict[str, Any]],
    boundary_rows: list[dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    family_by_key = {row["key"]: row for row in family_rows}
    boundary_by_stage = build_boundary_by_stage(boundary_rows or [])
    class_stage_candidate_map = dict(profile.get("class_stage_candidate_map", {}))
    mnemonic_stage_candidate_map = dict(profile.get("mnemonic_stage_candidate_map", {}))
    stage_order = list(profile.get("stage_order", []))
    ordered_mnemonics = list(instruction_details.get("ordered_mnemonics", []))
    mnemonic_counts = dict(instruction_details.get("mnemonic_counts", {}))

    rows: list[dict[str, Any]] = []
    for mnemonic in ordered_mnemonics:
        class_name = classify_mnemonic(mnemonic)
        if not class_name:
            continue
        mapping = dict(class_stage_candidate_map.get(class_name, {}))
        mnemonic_override = mnemonic_stage_candidate_map.get(mnemonic, {})
        for stage, candidate_keys in mnemonic_override.items():
            mapping[stage] = list(candidate_keys)
        stage_cells: dict[str, dict[str, Any] | None] = {}
        for stage in stage_order:
            stage_cells[stage] = choose_stage_timing_cell(
                stage=stage,
                candidate_keys=list(mapping.get(stage, [])),
                family_by_key=family_by_key,
                boundary_by_stage=boundary_by_stage,
            )
        rows.append(
            {
                "mnemonic": mnemonic,
                "class_name": class_name,
                "instruction_count": int(mnemonic_counts.get(mnemonic, 0)),
                "stage_cells": stage_cells,
            }
        )
    return rows


def build_stage_health_rows(
    profile: dict[str, Any],
    family_rows: list[dict[str, Any]],
) -> list[dict[str, str]]:
    family_by_key = {row["key"]: row for row in family_rows}
    rows: list[dict[str, str]] = []
    for family in profile.get("probe_families", []):
        key = str(family["key"])
        row = family_by_key.get(key)
        status = "PASS" if row and row.get("path_count", 0) > 0 else "WARN"
        if row and row.get("worst_path"):
            detail = row["worst_path"]["end_pin"]
        else:
            detail = f"No matched post-route timing path. searched {format_family_search_detail(row or family)}"
        rows.append(
            {
                "family": str(family.get("label", key)),
                "status": status,
                "detail": detail,
            }
        )
    return rows


def build_stage_boundary_health_rows(boundary_rows: list[dict[str, Any]]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for row in boundary_rows:
        status = "PASS" if row.get("path_count", 0) > 0 else "WARN"
        if row.get("worst_path"):
            detail = f"{row['worst_path']['start_pin']} -> {row['worst_path']['end_pin']}"
        else:
            detail = (
                "No matched register-to-register post-route timing path. "
                f"from {format_pin_search_detail(dict(row.get('from', {})))}; "
                f"to {format_pin_search_detail(dict(row.get('to', {})))}"
            )
        rows.append(
            {
                "boundary": str(row.get("label", row.get("key", "NA"))),
                "status": status,
                "detail": detail,
            }
        )
    return rows


def build_focus_stage_row(
    profile: dict[str, Any],
    entry: dict[str, Any],
    family_rows: list[dict[str, Any]],
    boundary_rows: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    family_by_key = {row["key"]: row for row in family_rows}
    boundary_by_stage = build_boundary_by_stage(boundary_rows or [])
    stage_order = list(profile.get("stage_order", []))
    class_stage_candidate_map = dict(profile.get("class_stage_candidate_map", {}))
    mnemonic_stage_candidate_map = dict(profile.get("mnemonic_stage_candidate_map", {}))

    class_name = str(entry["class_name"])
    mapping = dict(class_stage_candidate_map.get(class_name, {}))
    if entry["kind"] == "mnemonic":
        mnemonic_override = dict(mnemonic_stage_candidate_map.get(str(entry["focus_name"]), {}))
        for stage, candidate_keys in mnemonic_override.items():
            mapping[stage] = list(candidate_keys)

    stage_cells: dict[str, dict[str, Any] | None] = {}
    for stage in stage_order:
        stage_cells[stage] = choose_stage_timing_cell(
            stage=stage,
            candidate_keys=list(mapping.get(stage, [])),
            family_by_key=family_by_key,
            boundary_by_stage=boundary_by_stage,
        )

    return {
        "kind": str(entry["kind"]),
        "class_name": class_name,
        "mnemonic": str(entry["focus_name"]) if entry["kind"] == "mnemonic" else None,
        "instruction_count": int(entry.get("instruction_count", 0)),
        "kept_pc_count": int(entry.get("kept_pc_count", 0)),
        "kept_dynamic_count": int(entry.get("kept_dynamic_count", 0)),
        "output_dir_name": str(entry["output_dir_name"]),
        "stage_cells": stage_cells,
        "family_rows": family_rows,
        "boundary_rows": boundary_rows or [],
    }


def collect_focus_stage_rows(
    profile: dict[str, Any],
    metadata: dict[str, Any],
    focus_output_dir: pathlib.Path,
) -> dict[str, Any]:
    class_rows: list[dict[str, Any]] = []
    mnemonic_rows: list[dict[str, Any]] = []
    measured_rows = 0

    for entry in metadata.get("focus_entries", []):
        focus_dir = focus_output_dir / str(entry["output_dir_name"])
        family_rows = collect_family_timing_rows(focus_dir, profile)
        boundary_rows = collect_stage_boundary_timing_rows(focus_dir, profile)
        focus_row = build_focus_stage_row(profile, entry, family_rows, boundary_rows)
        if any(cell and cell.get("datapath_delay_ns") is not None for cell in focus_row["stage_cells"].values()):
            measured_rows += 1
        if entry["kind"] == "class":
            class_rows.append(focus_row)
        else:
            mnemonic_rows.append(focus_row)

    return {
        "class_rows": class_rows,
        "mnemonic_rows": mnemonic_rows,
        "focus_count": len(metadata.get("focus_entries", [])),
        "measured_focus_count": measured_rows,
        "selected_focuses": list(metadata.get("selected_focuses", [])),
    }


def render_stage_delay_cell(stage_row: dict[str, Any] | None) -> str:
    if not stage_row or stage_row.get("datapath_delay_ns") is None:
        return "NA"
    return f"{float(stage_row['datapath_delay_ns']):.3f}"


def render_delta_delay_cell(focused_stage_row: dict[str, Any] | None, base_stage_row: dict[str, Any] | None) -> str:
    if not focused_stage_row or focused_stage_row.get("datapath_delay_ns") is None:
        return "NA"
    if not base_stage_row or base_stage_row.get("datapath_delay_ns") is None:
        return "NA"
    delta = float(focused_stage_row["datapath_delay_ns"]) - float(base_stage_row["datapath_delay_ns"])
    return f"{delta:+.3f}"


def render_stage_family_table(
    lines: list[str],
    family_rows: list[dict[str, Any]],
    *,
    heading_prefix: str = "##",
) -> None:
    lines.extend(
        [
            f"{heading_prefix} Endpoint Family Timing",
            "",
            "- Endpoint-family timing uses `-to` endpoint groups only, so control feedback from another stage can appear in a family row.",
            "",
            "| Family | Stage | Data Path (ns) | Minimum Period (ns) | Fmax (MHz) | Worst Endpoint | Reported Paths | Unique Paths |",
            "| --- | --- | ---: | ---: | ---: | --- | ---: | ---: |",
        ]
    )
    for row in family_rows:
        worst_endpoint = row["worst_path"]["end_pin"] if row.get("worst_path") else "NA"
        lines.append(
            f"| {row['label']} | {row['stage']} | {fmt_float(row['datapath_delay_ns'])} | {fmt_float(row['min_period_ns'])} | {fmt_float(row['fmax_mhz'])} | `{worst_endpoint}` | {row['path_count']} | {row.get('unique_path_count', 'NA')} |"
        )
    lines.append("")


def render_stage_boundary_table(
    lines: list[str],
    boundary_rows: list[dict[str, Any]],
    *,
    heading_prefix: str = "##",
) -> None:
    lines.extend(
        [
            f"{heading_prefix} True Stage Boundary Timing",
            "",
            "- True stage timing uses explicit `-from` launch pins and `-to` capture pins.",
            "- WB is measured into the retained retire timing sink because there is no downstream pipeline register.",
            "",
        ]
    )
    if not boundary_rows:
        lines.extend(["- No true stage boundary probes are configured.", ""])
        return

    lines.extend(
        [
            "| Boundary | Stage | Data Path (ns) | Minimum Period (ns) | Fmax (MHz) | Logic Levels | Route Share (%) | Worst Start | Worst Endpoint | Reported Paths | Unique Paths |",
            "| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | ---: |",
        ]
    )
    for row in boundary_rows:
        worst_path = row.get("worst_path")
        worst_start = worst_path["start_pin"] if worst_path else "NA"
        worst_endpoint = worst_path["end_pin"] if worst_path else "NA"
        logic_levels = worst_path["logic_levels"] if worst_path else None
        route_share = worst_path["route_share_pct"] if worst_path else None
        lines.append(
            f"| {row['label']} | {row['stage']} | {fmt_float(row['datapath_delay_ns'])} | {fmt_float(row['min_period_ns'])} | {fmt_float(row['fmax_mhz'])} | {fmt_int(logic_levels)} | {fmt_float(route_share)} | `{worst_start}` | `{worst_endpoint}` | {row['path_count']} | {row.get('unique_path_count', 'NA')} |"
        )
    lines.append("")


def render_stage_matrix_table(
    lines: list[str],
    title: str,
    item_label: str,
    rows: list[dict[str, Any]],
    stage_order: list[str],
    *,
    heading_prefix: str = "##",
    include_class_column: bool = True,
    include_context_columns: bool = False,
) -> None:
    if not rows:
        lines.extend([f"{heading_prefix} {title}", "", f"- No {item_label.lower()} timing rows could be resolved.", ""])
        return

    headers = [item_label]
    if include_class_column:
        headers.append("Class")
    headers.append("Count")
    if include_context_columns:
        headers.extend(["Kept PCs", "Kept Dynamic"])
    headers.extend([f"{stage} Delay (ns)" for stage in stage_order])

    divider_cells = ["---"]
    if include_class_column:
        divider_cells.append("---")
    divider_cells.append("---:")
    if include_context_columns:
        divider_cells.extend(["---:", "---:"])
    divider_cells.extend(["---:" for _ in stage_order])

    lines.extend([f"{heading_prefix} {title}", "", "| " + " | ".join(headers) + " |", "| " + " | ".join(divider_cells) + " |"])
    for row in rows:
        label = row.get("mnemonic") or row.get("class_name", "NA")
        values = [label]
        if include_class_column:
            values.append(row["class_name"])
        values.append(str(row["instruction_count"]))
        if include_context_columns:
            values.append(str(row.get("kept_pc_count", 0)))
            values.append(str(row.get("kept_dynamic_count", 0)))
        values.extend(render_stage_delay_cell(row["stage_cells"].get(stage)) for stage in stage_order)
        lines.append("| " + " | ".join(values) + " |")
    lines.append("")


def render_stage_delta_table(
    lines: list[str],
    title: str,
    item_label: str,
    focused_rows: list[dict[str, Any]],
    base_rows: list[dict[str, Any]],
    stage_order: list[str],
    *,
    heading_prefix: str = "##",
    include_class_column: bool = True,
) -> None:
    if not focused_rows:
        lines.extend([f"{heading_prefix} {title}", "", f"- No {item_label.lower()} delta rows could be resolved.", ""])
        return

    if item_label == "Class":
        base_by_label = {str(row["class_name"]): row for row in base_rows}
    else:
        base_by_label = {str(row["mnemonic"]): row for row in base_rows}

    headers = [item_label]
    if include_class_column:
        headers.append("Class")
    headers.append("Count")
    headers.extend([f"{stage} Delta (ns)" for stage in stage_order])

    divider_cells = ["---"]
    if include_class_column:
        divider_cells.append("---")
    divider_cells.append("---:")
    divider_cells.extend(["---:" for _ in stage_order])

    lines.extend([f"{heading_prefix} {title}", "", "| " + " | ".join(headers) + " |", "| " + " | ".join(divider_cells) + " |"])
    for row in focused_rows:
        label = row.get("mnemonic") or row.get("class_name", "NA")
        base_row = base_by_label.get(str(label))
        values = [label]
        if include_class_column:
            values.append(str(row["class_name"]))
        values.append(str(row["instruction_count"]))
        values.extend(
            render_delta_delay_cell(row["stage_cells"].get(stage), base_row["stage_cells"].get(stage) if base_row else None)
            for stage in stage_order
        )
        lines.append("| " + " | ".join(values) + " |")
    lines.append("")


def render_program_report_section(
    single_contract: dict[str, object],
    single_metrics: dict[str, str | float | None],
    pipeline_contract: dict[str, object],
    pipeline_metrics: dict[str, str | float | None],
    output_root: pathlib.Path,
    implementation_cfg: dict[str, object],
    family_rows: list[dict[str, Any]],
    boundary_rows: list[dict[str, Any]],
    class_stage_rows: list[dict[str, Any]],
    mnemonic_stage_rows: list[dict[str, Any]],
    instruction_details: dict[str, Any],
    focus_summary: dict[str, Any],
    program_selection: dict[str, Any],
) -> str:
    fmax_gain = None
    if single_metrics["fmax_mhz"] is not None and pipeline_metrics["fmax_mhz"] is not None:
        fmax_gain = float(pipeline_metrics["fmax_mhz"]) - float(single_metrics["fmax_mhz"])

    trace_summary = analyze_project_pipeline_trace(pathlib.Path(program_selection["mem_path"]))
    single_execution = estimate_single_cycle_execution(trace_summary, single_metrics["min_period_ns"])
    pipeline_execution = estimate_project_pipeline_execution(trace_summary, pipeline_metrics["min_period_ns"])
    cycle_delta = int(pipeline_execution["cycle_count"]) - int(single_execution["cycle_count"])
    cpi_delta = None
    if single_execution["cpi"] is not None and pipeline_execution["cpi"] is not None:
        cpi_delta = float(pipeline_execution["cpi"]) - float(single_execution["cpi"])
    runtime_delta_ns = None
    if single_execution["runtime_ns"] is not None and pipeline_execution["runtime_ns"] is not None:
        runtime_delta_ns = float(pipeline_execution["runtime_ns"]) - float(single_execution["runtime_ns"])
    runtime_speedup = compute_runtime_speedup(single_execution["runtime_ns"], pipeline_execution["runtime_ns"])

    stage_order = list(pipeline_contract["profile"].get("stage_order", []))
    health_rows = build_stage_health_rows(pipeline_contract["profile"], family_rows)
    boundary_health_rows = build_stage_boundary_health_rows(boundary_rows)
    warning_count = sum(1 for row in health_rows if row["status"] != "PASS")
    boundary_warning_count = sum(1 for row in boundary_health_rows if row["status"] != "PASS")
    focus_count = int(focus_summary.get("focus_count", 0))
    measured_focus_count = int(focus_summary.get("measured_focus_count", 0))
    default_focus_status = "PASS" if focus_count > 0 and measured_focus_count == focus_count else "WARN"
    default_focus_detail = f"{measured_focus_count}/{focus_count} focus builds resolved with measured paths"
    focus_status = str(focus_summary.get("status", default_focus_status))
    focus_detail = str(focus_summary.get("detail", default_focus_detail))
    generated_at = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")

    single_lut_used = parse_int_metric(single_metrics["lut_used"])
    pipeline_lut_used = parse_int_metric(pipeline_metrics["lut_used"])
    single_ff_used = parse_int_metric(single_metrics["ff_used"])
    pipeline_ff_used = parse_int_metric(pipeline_metrics["ff_used"])
    valid_family_rows = [row for row in family_rows if row.get("min_period_ns") is not None]
    worst_stage_row = max(valid_family_rows, key=lambda row: float(row["min_period_ns"])) if valid_family_rows else None
    valid_boundary_rows = [row for row in boundary_rows if row.get("min_period_ns") is not None]
    worst_boundary_row = max(valid_boundary_rows, key=lambda row: float(row["min_period_ns"])) if valid_boundary_rows else None
    timing_verdict = determine_pipeline_verdict(
        pipeline_wns_ns=float(pipeline_metrics["wns_ns"]) if pipeline_metrics["wns_ns"] is not None else None,
        warning_count=warning_count + boundary_warning_count,
        focus_status=focus_status,
    )
    runtime_winner = describe_runtime_winner(single_execution["runtime_ns"], pipeline_execution["runtime_ns"])

    priorities: list[str] = []
    if pipeline_metrics["wns_ns"] is not None and float(pipeline_metrics["wns_ns"]) < 0:
        priorities.append(f"`Negative post-route slack`: pipeline WNS is {fmt_float(float(pipeline_metrics['wns_ns']))} ns.")
    if worst_stage_row is not None:
        priorities.append(
            f"`Worst stage family`: `{worst_stage_row['label']}` in `{worst_stage_row['stage']}` reaches {fmt_float(float(worst_stage_row['min_period_ns']))} ns."
        )
    if worst_boundary_row is not None:
        priorities.append(
            f"`Worst true stage boundary`: `{worst_boundary_row['label']}` in `{worst_boundary_row['stage']}` reaches {fmt_float(float(worst_boundary_row['min_period_ns']))} ns."
        )
    if focus_status != "PASS":
        priorities.append(f"`Instruction-focus coverage`: {focus_detail}")
    if fmax_gain is not None and fmax_gain <= 0:
        priorities.append(f"`Frequency headroom`: pipeline Fmax delta vs single-cycle is {fmt_float(fmax_gain)} MHz.")
    if runtime_delta_ns is not None and runtime_delta_ns > 0:
        priorities.append(f"`Execution regression`: estimated runtime delta is {format_runtime_ns(runtime_delta_ns)}.")
    if not priorities:
        priorities.append("`Steady state`: no urgent regression was detected in the current comparison set.")

    timing_rows_for_route = [
        row
        for row in list(valid_boundary_rows) + list(valid_family_rows)
        if row.get("worst_path") and row["worst_path"].get("route_share_pct") is not None
    ]
    route_shares = [float(row["worst_path"]["route_share_pct"]) for row in timing_rows_for_route]
    avg_route_share = safe_mean(route_shares)
    max_route_share = max(route_shares) if route_shares else None

    analysis_findings: list[dict[str, Any]] = []
    if pipeline_metrics["wns_ns"] is not None and float(pipeline_metrics["wns_ns"]) < 0:
        analysis_findings.append(
            {
                "severity": "FAIL",
                "category": "Timing Closure",
                "title": "Negative post-route slack",
                "evidence": f"Pipeline WNS is {fmt_float(float(pipeline_metrics['wns_ns']))} ns",
                "impact": "The 5-stage implementation does not meet the configured clock period.",
                "recommended_action": "Fix the worst true stage boundary first, then rerun the pipeline timing mode.",
                "source_artifact": output_root / "pipeline",
            }
        )
    if avg_route_share is not None and (avg_route_share >= 70.0 or (max_route_share is not None and max_route_share >= 75.0)):
        analysis_findings.append(
            {
                "severity": "WARN",
                "category": "Routing",
                "title": "Route-dominant stage paths",
                "evidence": f"Average route share {fmt_float(avg_route_share, 1)}%, max route share {fmt_float(max_route_share, 1)}%",
                "impact": "Stage timing is likely limited by physical locality or fanout, not only logic depth.",
                "recommended_action": "Check placement locality around the worst boundary and reduce high-fanout control/data nets.",
                "source_artifact": output_root / "pipeline",
            }
        )
    if worst_boundary_row is not None:
        analysis_findings.append(
            {
                "severity": "WARN" if timing_verdict != "PASS" else "INFO",
                "category": "Stage Boundary",
                "title": str(worst_boundary_row["label"]),
                "evidence": f"{worst_boundary_row['label']} reaches {fmt_float(float(worst_boundary_row['min_period_ns']))} ns",
                "impact": "This register-to-register boundary is the best first target for pipeline timing closure.",
                "recommended_action": f"Inspect `{worst_boundary_row['label']}` fan-in and split or retime the dominant logic before changing unrelated stages.",
                "source_artifact": worst_boundary_row.get("report_path"),
            }
        )
    elif worst_stage_row is not None:
        analysis_findings.append(
            {
                "severity": "WARN" if timing_verdict != "PASS" else "INFO",
                "category": "Endpoint Family",
                "title": str(worst_stage_row["label"]),
                "evidence": f"{worst_stage_row['label']} reaches {fmt_float(float(worst_stage_row['min_period_ns']))} ns",
                "impact": "No stronger true-boundary bottleneck was available, so endpoint-family timing is the fallback target.",
                "recommended_action": f"Review `{worst_stage_row['label']}` and regenerate true boundary probes if the endpoint group is too broad.",
                "source_artifact": worst_stage_row.get("report_path"),
            }
        )
    if focus_status != "PASS":
        analysis_findings.append(
            {
                "severity": "WARN",
                "category": "Instruction Focus",
                "title": "Incomplete instruction-focus coverage",
                "evidence": focus_detail,
                "impact": "Class/mnemonic-level attribution may be incomplete for this program image.",
                "recommended_action": "Rerun instruction-focus mode for the missing classes or narrow the focus filter to the failing mnemonic set.",
                "source_artifact": output_root / "instruction_focus",
            }
        )
    if runtime_delta_ns is not None and runtime_delta_ns > 0:
        analysis_findings.append(
            {
                "severity": "WARN",
                "category": "Execution Model",
                "title": "Pipeline runtime regression",
                "evidence": f"Pipeline estimate is {format_runtime_ns(runtime_delta_ns)} slower than single-cycle",
                "impact": "Frequency gain is not compensating for pipeline fill, stall, and redirect penalties on this program.",
                "recommended_action": "Inspect load-use stalls and redirect penalties before optimizing pure clock frequency.",
                "source_artifact": program_selection["mem_path"],
            }
        )
    if fmax_gain is not None and fmax_gain <= 0:
        analysis_findings.append(
            {
                "severity": "WARN",
                "category": "Frequency Headroom",
                "title": "Pipeline Fmax did not improve",
                "evidence": f"Pipeline Fmax delta vs single-cycle is {fmt_float(fmax_gain)} MHz",
                "impact": "The pipeline split is not yet buying timing margin.",
                "recommended_action": "Use the worst stage boundary as the clock-frequency optimization target.",
                "source_artifact": output_root / "pipeline",
            }
        )
    if not analysis_findings:
        analysis_findings.append(
            {
                "severity": "PASS",
                "category": "Timing",
                "title": "No urgent regression detected",
                "evidence": "Timing, focus coverage, and execution estimates did not raise a high-priority issue.",
                "impact": "This artifact set is a good baseline for the next pipeline experiment.",
                "recommended_action": "Keep this report as the baseline and compare against the next program image or RTL change.",
                "source_artifact": output_root,
            }
        )

    overall_status = highest_status([timing_verdict, focus_status] + [str(finding["severity"]) for finding in analysis_findings])
    primary_bottleneck = (
        f"{worst_boundary_row['label']} / {worst_boundary_row['stage']} at {fmt_float(float(worst_boundary_row['min_period_ns']))} ns"
        if worst_boundary_row is not None
        else (
            f"{worst_stage_row['label']} / {worst_stage_row['stage']} at {fmt_float(float(worst_stage_row['min_period_ns']))} ns"
            if worst_stage_row is not None
            else str(analysis_findings[0]["title"])
        )
    )
    root_causes = analysis_findings[:3]
    recommended_actions = render_recommended_actions(analysis_findings, limit=3)

    lines = [
        f"## {program_selection['display_name']}",
        "",
        f"- Program key: `{program_selection['key']}`",
        f"- Last updated: `{generated_at}`",
        "",
        "### 🧭 Summary",
        "",
        "| Item | Value |",
        "| --- | --- |",
        f"| Overall verdict | {status_badge(overall_status)} |",
        f"| Primary bottleneck | {primary_bottleneck} |",
        f"| Route status | {pipeline_metrics['route_status']} |",
        f"| Runtime winner | {runtime_winner} |",
        f"| Instruction-focus coverage | {status_badge(focus_status)} {focus_detail} |",
        f"| First action | {recommended_actions[0].split('. ', 1)[1] if recommended_actions else priorities[0]} |",
        "",
        "### 🧠 Analysis Result",
        "",
        "| Field | Result |",
        "| --- | --- |",
        f"| Overall Verdict | {status_badge(overall_status)} |",
        f"| Primary Bottleneck | {primary_bottleneck} |",
        f"| Root Cause Candidates | {min(3, len(root_causes))} candidate(s) promoted from parsed timing artifacts |",
        f"| Recommended Next Actions | {min(3, len(recommended_actions))} action(s) |",
        "",
        "#### Root Cause Candidates",
        "",
        *render_finding_table(root_causes, limit=3),
        "",
        "### 📊 Key Metrics",
        "",
        "- `Delta` is `5-stage pipeline - single-cycle`.",
        "- Runtime and CPI are estimated from the selected timing-program trace.",
        f"- 5-stage execution model: `{pipeline_execution['model_note']} before the terminal self-loop`.",
        "",
        "| Metric | Single-Cycle | 5-Stage Pipeline | Delta |",
        "| --- | ---: | ---: | ---: |",
        f"| WNS (ns) | {fmt_float(single_metrics['wns_ns'])} | {fmt_float(pipeline_metrics['wns_ns'])} | {fmt_delta_float(single_metrics['wns_ns'], pipeline_metrics['wns_ns'])} |",
        f"| Minimum Period (ns) | {fmt_float(single_metrics['min_period_ns'])} | {fmt_float(pipeline_metrics['min_period_ns'])} | {fmt_delta_float(single_metrics['min_period_ns'], pipeline_metrics['min_period_ns'])} |",
        f"| Fmax (MHz) | {fmt_float(single_metrics['fmax_mhz'])} | {fmt_float(pipeline_metrics['fmax_mhz'])} | {fmt_delta_float(single_metrics['fmax_mhz'], pipeline_metrics['fmax_mhz'])} |",
        f"| LUTs | {fmt_int(single_lut_used)} | {fmt_int(pipeline_lut_used)} | {fmt_delta_int(single_lut_used, pipeline_lut_used)} |",
        f"| Registers | {fmt_int(single_ff_used)} | {fmt_int(pipeline_ff_used)} | {fmt_delta_int(single_ff_used, pipeline_ff_used)} |",
        f"| Cycles | {fmt_int(single_execution['cycle_count'])} | {fmt_int(pipeline_execution['cycle_count'])} | {cycle_delta:+d} |",
        f"| CPI | {fmt_float(single_execution['cpi'])} | {fmt_float(pipeline_execution['cpi'])} | {fmt_delta_float(single_execution['cpi'], pipeline_execution['cpi'])} |",
        f"| Runtime | {format_runtime_ns(single_execution['runtime_ns'])} | {format_runtime_ns(pipeline_execution['runtime_ns'])} | {format_runtime_ns(runtime_delta_ns)} |",
        f"| Pipeline Speedup (x) | {format_ratio(1.0 if runtime_speedup is not None else None)} | {format_ratio(runtime_speedup)} | {fmt_delta_ratio(1.0 if runtime_speedup is not None else None, runtime_speedup)} |",
        "",
        "### 🎯 Recommended Actions",
        "",
        *recommended_actions,
        "",
        "### 📁 Evidence",
        "",
        "| Evidence | Location |",
        "| --- | --- |",
        f"| Artifact root | `{output_root}` |",
        f"| Single-cycle artifacts | `{output_root / 'single_cycle'}` |",
        f"| 5-stage artifacts | `{output_root / 'pipeline'}` |",
        f"| Instruction-focus artifacts | `{output_root / 'instruction_focus'}` |",
        f"| Program memory | `{program_selection['mem_path']}` |",
        f"| Instruction source | `{instruction_details['instruction_source']}` |",
        "",
        "<details>",
        "<summary>Compact timing evidence</summary>",
        "",
    ]
    render_stage_boundary_table(lines, boundary_rows, heading_prefix="####")
    render_stage_family_table(lines, family_rows, heading_prefix="####")
    lines.extend(
        [
            "#### Focus Coverage Snapshot",
            "",
            "| Check | Status | Detail |",
            "| --- | --- | --- |",
            f"| Stage family coverage | {status_badge('PASS' if warning_count == 0 else 'WARN')} | {len(family_rows) - warning_count}/{len(family_rows)} families resolved with post-route paths |",
            f"| True stage boundary coverage | {status_badge('PASS' if boundary_warning_count == 0 else 'WARN')} | {len(boundary_rows) - boundary_warning_count}/{len(boundary_rows)} boundaries resolved with register-to-register paths |",
            f"| Instruction-focus coverage | {status_badge(focus_status)} | {focus_detail} |",
        ]
    )
    if focus_summary.get("selected_focuses"):
        lines.append(f"| Focus filter | {status_badge('INFO')} | {', '.join(focus_summary['selected_focuses'])} |")
    for warning in instruction_details.get("warnings", []):
        lines.append(f"| Instruction metadata | {status_badge('WARN')} | {warning} |")
    lines.extend(["", "</details>", ""])
    return "\n".join(lines).rstrip() + "\n"


def build_integrated_pipeline_detail_text(
    section_text: str,
    *,
    report_path: pathlib.Path,
) -> str:
    compact_body = strip_noisy_report_sections(strip_first_markdown_heading(section_text))
    detail_body = shift_markdown_headings(compact_body, 1).rstrip()
    generated_at = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
    lines = [
        f"- Source report: `{report_path}`",
        f"- Detail updated: `{generated_at}`",
        "",
    ]
    if detail_body:
        lines.append(detail_body)
    else:
        lines.append("- No pipeline performance detail was rendered.")
    return "\n".join(lines).rstrip() + "\n"


def render_program_placeholder(program_selection: dict[str, Any]) -> str:
    lines = [
        f"## {program_selection['display_name']}",
        "",
        f"- Program key: `{program_selection['key']}`",
        "- No timing results recorded yet for this program image.",
    ]
    return "\n".join(lines).rstrip() + "\n"


def extract_existing_program_sections(report_text: str) -> dict[str, str]:
    normalized_text = report_text.replace("\r\n", "\n")
    pattern = re.compile(
        r"<!-- PROGRAM_SECTION:(?P<key>[a-z0-9_]+):START -->\n(?P<body>.*?)(?:\n)?<!-- PROGRAM_SECTION:(?P=key):END -->",
        flags=re.DOTALL,
    )
    sections: dict[str, str] = {}
    for match in pattern.finditer(normalized_text):
        program_key = str(match.group("key"))
        sections[program_key] = str(match.group("body")).strip() + "\n"
    return sections


def build_combined_report(program_sections: dict[str, str]) -> str:
    lines = [
        "# PIPELINE_PERF_REPORT",
        "",
        "- This report keeps one category per timing program image.",
        "- Re-running a timing program refreshes only that program section below.",
        "",
    ]

    for program_key in PROGRAM_LIBRARY:
        program_selection = resolve_selected_program(program_key)
        section_body = program_sections.get(program_key, render_program_placeholder(program_selection)).rstrip()
        lines.append(SECTION_START_TEMPLATE.format(program_key=program_key))
        lines.append(section_body)
        lines.append(SECTION_END_TEMPLATE.format(program_key=program_key))
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def merge_program_report_section(
    report_path: pathlib.Path,
    program_key: str,
    section_text: str,
) -> str:
    existing_sections: dict[str, str] = {}
    if report_path.exists():
        existing_sections = extract_existing_program_sections(report_path.read_text(encoding="utf-8", errors="ignore"))
    existing_sections[program_key] = section_text.rstrip() + "\n"
    return build_combined_report(existing_sections)


def resolve_program_output_root(
    requested_output_root: pathlib.Path,
    default_output_root: pathlib.Path,
    program_key: str,
) -> pathlib.Path:
    requested_resolved = requested_output_root.resolve()
    default_resolved = default_output_root.resolve()
    if requested_resolved == default_resolved:
        return default_resolved / "programs" / program_key
    return requested_resolved


def main(argv: list[str] | None = None) -> None:
    pipeline_contract = load_project_contract(PROJECT_ROOT)
    pipeline_profile = pipeline_contract["profile"]
    implementation_cfg = dict(pipeline_profile.get("implementation", {}))
    single_project_name = str(pipeline_profile.get("compare_single_cycle_project", "RISCV_32I_SINGLE"))
    single_project_root = REPO_ROOT / "Project" / single_project_name
    single_contract = load_project_contract(single_project_root)

    default_output_root = PROJECT_ROOT / str(pipeline_profile.get("default_output_root", ".analysis/pipeline_perf"))
    default_report_path = PROJECT_ROOT / str(pipeline_profile.get("default_report_path", "PIPELINE_PERF_REPORT.md"))
    integrated_report_path = (PROJECT_ROOT / str(pipeline_profile.get("integrated_report_path", "md/INTEGRATED_TIMING_REPORT.md"))).resolve()

    parser = argparse.ArgumentParser(
        description="Run post-route Vivado builds for the single-cycle and 5-stage cores and render a comparison report."
    )
    parser.add_argument("--output-root", type=pathlib.Path, default=default_output_root)
    parser.add_argument("--report", type=pathlib.Path, default=default_report_path)
    parser.add_argument("--skip-vivado", action="store_true", help="Reuse existing artifacts instead of launching Vivado.")
    parser.add_argument(
        "--focus-only",
        action="store_true",
        help="Reuse existing base-design artifacts and run only instruction-focus Vivado builds.",
    )
    parser.add_argument(
        "--pipeline-only",
        action="store_true",
        help="Run or refresh only the base 5-stage pipeline implementation and skip the single-cycle build.",
    )
    parser.add_argument(
        "--skip-instruction-focus",
        action="store_true",
        help="Do not run or refresh per-class and per-mnemonic focus builds.",
    )
    parser.add_argument(
        "--focus-filter",
        default="",
        help="Comma-separated focus names to run, for example `addi,lw,jalr` or `class:load,mnemonic:jalr`.",
    )
    parser.add_argument(
        "--program",
        default="full_coverage",
        help="Timing program image to use: `full_coverage` or `bubble_sort`.",
    )
    args = parser.parse_args(argv)

    selected_program = resolve_selected_program(args.program)
    output_root = resolve_program_output_root(args.output_root, default_output_root, str(selected_program["key"]))
    report_path = args.report.resolve()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    integrated_report_path.parent.mkdir(parents=True, exist_ok=True)
    single_output = output_root / "single_cycle"
    pipeline_output = output_root / "pipeline"
    focus_output = output_root / str(pipeline_profile.get("focus_analysis", {}).get("output_subdir", "instruction_focus"))
    legacy_single_output = default_output_root / "single_cycle"
    legacy_pipeline_output = default_output_root / "pipeline"
    collector_tcl = PROJECT_ROOT / "tools" / "pipeline_perf_collect.tcl"
    selected_focuses = parse_focus_filter(args.focus_filter)
    focus_cfg = build_focus_cfg_for_program(dict(pipeline_profile.get("focus_analysis", {})), selected_program)

    run_single_baseline = not args.skip_vivado and not args.focus_only and not args.pipeline_only
    run_pipeline_baseline = not args.skip_vivado and not args.focus_only
    reuse_baseline = not run_single_baseline and not run_pipeline_baseline
    prepared_focus_metadata: dict[str, Any] = {}
    if focus_cfg.get("enabled", False) and not args.skip_instruction_focus:
        prepared_focus_metadata = prepare_focus_analysis_assets(
            pipeline_contract,
            focus_cfg,
            focus_output,
            selected_focuses=selected_focuses,
        )
    focus_entry_count = len(prepared_focus_metadata.get("focus_entries", []))
    run_focus_vivado = bool(focus_cfg.get("enabled", False) and not args.skip_instruction_focus and not args.skip_vivado and focus_entry_count > 0)
    focus_vivado_units = 1 + (focus_entry_count * 4) if run_focus_vivado else 0
    total_progress_units = 3
    if focus_cfg.get("enabled", False):
        if not args.skip_instruction_focus:
            total_progress_units += 1
        total_progress_units += 1 if not run_focus_vivado else focus_vivado_units
    if run_single_baseline:
        total_progress_units += 5
    if run_pipeline_baseline:
        total_progress_units += 5
    if reuse_baseline:
        total_progress_units += 1

    tracker = ProgressTracker(total_progress_units)
    tracker.step(
        f"Loaded pipeline timing contracts: {single_contract['project_name']} vs {pipeline_contract['project_name']} | Program: {selected_program['display_name']} | Output root: {output_root} | Report: {report_path}"
    )
    if focus_cfg.get("enabled", False) and not args.skip_instruction_focus:
        tracker.step(f"Prepared instruction-focus assets ({focus_entry_count} focus builds)")

    if run_single_baseline:
        run_vivado_for_project(
            single_contract,
            single_output,
            collector_tcl,
            implementation_cfg,
            program_selection=selected_program,
            progress_label=f"Vivado baseline build for {single_contract['project_name']}",
            progress_callback=tracker.make_subrun_callback(
                tracker.completed_units,
                5,
                prefix=str(single_contract["project_name"]),
            ),
        )
    if run_pipeline_baseline:
        run_vivado_for_project(
            pipeline_contract,
            pipeline_output,
            collector_tcl,
            implementation_cfg,
            program_selection=selected_program,
            progress_label=f"Vivado baseline build for {pipeline_contract['project_name']}",
            progress_callback=tracker.make_subrun_callback(
                tracker.completed_units,
                5,
                prefix=str(pipeline_contract["project_name"]),
            ),
        )
    if reuse_baseline:
        tracker.step(f"Reused existing baseline artifacts from {output_root}")

    focus_metadata: dict[str, Any] = prepared_focus_metadata
    focus_summary = build_empty_focus_summary(
        f"No instruction-focus runs were requested for `{selected_program['display_name']}`.",
        selected_focuses,
    )
    if focus_cfg.get("enabled", False):
        if args.skip_instruction_focus:
            tracker.step(f"Skipped instruction-focus Vivado rerun for {selected_program['display_name']}")
            focus_summary = build_empty_focus_summary(
                f"Skipped instruction-focus rerun for selected program `{selected_program['display_name']}`.",
                selected_focuses,
            )
        elif args.skip_vivado:
            tracker.step(f"Reused existing instruction-focus artifacts from {focus_output}")
        elif run_focus_vivado:
            focus_metadata = run_instruction_focus_vivado(
                pipeline_contract,
                focus_output,
                implementation_cfg,
                prepared_metadata=prepared_focus_metadata,
                selected_focuses=selected_focuses,
                progress_label=f"Vivado instruction-focus builds for {pipeline_contract['project_name']}",
                progress_callback=tracker.make_subrun_callback(
                    tracker.completed_units,
                    focus_vivado_units,
                    prefix=f"{pipeline_contract['project_name']} focus",
                ),
            )
        else:
            tracker.step("No instruction-focus builds matched the current filter")
            focus_summary = build_empty_focus_summary(
                f"No instruction-focus builds matched the current filter for `{selected_program['display_name']}`.",
                selected_focuses,
            )

    instruction_details = parse_selected_instruction_program_details(selected_program)
    single_metrics_output = resolve_metrics_output_dir(
        single_output,
        legacy_single_output,
        summary_only=True,
    )
    pipeline_metrics_output = resolve_metrics_output_dir(
        pipeline_output,
        legacy_pipeline_output,
        summary_only=True,
    )
    pipeline_family_output = resolve_metrics_output_dir(
        pipeline_output,
        legacy_pipeline_output,
        profile=pipeline_profile,
    )
    single_metrics = collect_project_metrics(single_metrics_output, float(single_contract["clock_period_ns"]))
    pipeline_metrics = collect_project_metrics(pipeline_metrics_output, float(pipeline_contract["clock_period_ns"]))
    family_rows = collect_family_timing_rows(pipeline_family_output, pipeline_profile)
    boundary_rows = collect_stage_boundary_timing_rows(pipeline_family_output, pipeline_profile)
    class_stage_rows = build_class_stage_rows(pipeline_profile, instruction_details, family_rows, boundary_rows)
    mnemonic_stage_rows = build_mnemonic_stage_rows(pipeline_profile, instruction_details, family_rows, boundary_rows)
    if focus_metadata:
        focus_summary = collect_focus_stage_rows(pipeline_profile, focus_metadata, focus_output)
    tracker.step("Collected timing metrics and rendered comparison data")

    program_section_text = render_program_report_section(
        single_contract,
        single_metrics,
        pipeline_contract,
        pipeline_metrics,
        output_root,
        implementation_cfg,
        family_rows,
        boundary_rows,
        class_stage_rows,
        mnemonic_stage_rows,
        instruction_details,
        focus_summary,
        selected_program,
    )
    report_text = merge_program_report_section(report_path, str(selected_program["key"]), program_section_text)
    report_path.write_text(report_text, encoding="utf-8")
    write_html_report(report_path.with_suffix(".html"), report_text, title=report_path.stem)
    integrated_report_text = merge_program_detail_section(
        integrated_report_path,
        program_selection=selected_program,
        detail_key="pipeline_perf",
        detail_body=build_integrated_pipeline_detail_text(
            program_section_text,
            report_path=report_path,
        ),
        program_keys=list(PROGRAM_LIBRARY),
        resolve_program_selection=resolve_selected_program,
    )
    integrated_report_path.write_text(integrated_report_text, encoding="utf-8")
    write_html_report(integrated_report_path.with_suffix(".html"), integrated_report_text, title=integrated_report_path.stem)
    tracker.step(f"Report section updated for {selected_program['display_name']} at {report_path}")
    print(f"[INFO] Wrote {report_path}")

    return


if __name__ == "__main__":
    main()
