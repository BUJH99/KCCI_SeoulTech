from __future__ import annotations

import argparse
import csv
import json
import pathlib
import re
import sys


PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / ".analysis" / "pipeline_prep_latest"

DEFAULT_FAMILY_CONFIGS = (
    {
        "key": "IF_FETCH",
        "label": "IF / Fetch",
        "probe": "probeFetchReg",
        "description": "Instruction fetch visibility probe",
    },
    {
        "key": "ID_DECODE",
        "label": "ID / Decode-Control",
        "probe": "probeDecodeReg",
        "description": "Decode and control composition family",
    },
    {
        "key": "EX_EXEC",
        "label": "EX / ALU-Execute",
        "probe": "probeExecReg",
        "description": "ALU result and execute-stage family",
    },
    {
        "key": "MEM_LOAD_RETURN",
        "label": "MEM / Load-Return",
        "probe": "probeMemReg",
        "description": "Raw memory-return structural family",
    },
    {
        "key": "WB_LOAD_QUALIFIED",
        "label": "WB / Load-Qualified",
        "probe": "probeLoadWbReg",
        "description": "Qualified load writeback family",
    },
    {
        "key": "WB_LOAD_COMMIT",
        "label": "WB / Load-Commit",
        "probe": "loadCommitSink",
        "description": "Final load commit into Regfile D family",
    },
    {
        "key": "WB_ALU_RESULT",
        "label": "WB / ALU-Result",
        "probe": "probeAluWbReg",
        "description": "Dedicated ALU writeback family",
    },
    {
        "key": "WB_MUXED_RESULT",
        "label": "WB / Muxed-Result",
        "probe": "probeWbReg",
        "description": "Writeback mux and result-selection family",
    },
    {
        "key": "MEM_STORE_SIDE",
        "label": "MEM / Store-Side",
        "probe": "probeStoreReg",
        "description": "Store-side and address/misalignment family",
    },
    {
        "key": "NEXT_PC",
        "label": "PC / Next-PC Feedback",
        "probe": "probeNextPcReg",
        "description": "Selected next-PC and instruction-alignment family",
    },
    {
        "key": "BRANCH_TARGET",
        "label": "CF / Branch Target",
        "probe": "probeBranchTargetReg",
        "description": "Conditional-branch target and taken-decision family",
    },
    {
        "key": "JUMP_TARGET",
        "label": "CF / Jump Target",
        "probe": "probeJumpTargetReg",
        "description": "JAL target family",
    },
    {
        "key": "JALR_TARGET",
        "label": "CF / JALR Target",
        "probe": "probeJalrTargetReg",
        "description": "JALR target family",
    },
    {
        "key": "TRAP_CONTROL",
        "label": "Trap / Control",
        "probe": "probeTrapReg",
        "description": "Trap and exception-control family",
    },
)

DEFAULT_CLASS_TARGETS = {
    "RTYPE": ("probeAluWbReg", "probeExecReg", "probeWbReg"),
    "OPIMM": ("probeAluWbReg", "probeExecReg", "probeWbReg"),
    "LOAD": ("loadCommitSink",),
    "STORE": ("probeStoreReg", "probeExecReg", "probeAluWbReg"),
    "BRANCH": ("probeBranchTargetReg", "probeNextPcReg", "probeExecReg", "probeDecodeReg", "probeAluWbReg"),
    "UPPER_IMM": ("probeWbReg", "probeAluWbReg", "probeExecReg"),
    "JUMP": ("probeJalrTargetReg", "probeJumpTargetReg", "probeNextPcReg", "probeWbReg"),
    "SYSTEM": ("probeTrapReg", "probeDecodeReg", "probeWbReg"),
}

DEFAULT_STAGE_CANDIDATE_MAP = {
    "IF": ("probeFetchReg",),
    "ID": ("probeDecodeReg",),
    "EX": ("probeExecReg", "probeTrapReg"),
    "MEM": ("probeMemReg", "probeStoreReg"),
    "WB": ("loadCommitSink", "probeLoadWbReg", "probeAluWbReg", "probeWbReg"),
    "CF": ("probeNextPcReg", "probeBranchTargetReg", "probeJumpTargetReg", "probeJalrTargetReg"),
}

DEFAULT_FAMILY_ACTIVE_CLASSES = {
    "IF_FETCH": ("RTYPE", "OPIMM", "LOAD", "STORE", "BRANCH", "UPPER_IMM", "JUMP", "SYSTEM"),
    "ID_DECODE": ("RTYPE", "OPIMM", "LOAD", "STORE", "BRANCH", "UPPER_IMM", "JUMP", "SYSTEM"),
    "EX_EXEC": ("RTYPE", "OPIMM", "LOAD", "STORE", "BRANCH", "UPPER_IMM", "JUMP"),
    "MEM_LOAD_RETURN": ("LOAD",),
    "WB_LOAD_QUALIFIED": ("LOAD",),
    "WB_LOAD_COMMIT": ("LOAD",),
    "WB_ALU_RESULT": ("RTYPE", "OPIMM", "UPPER_IMM"),
    "WB_MUXED_RESULT": ("RTYPE", "OPIMM", "LOAD", "UPPER_IMM", "JUMP"),
    "MEM_STORE_SIDE": ("STORE",),
    "NEXT_PC": ("BRANCH", "JUMP", "SYSTEM"),
    "BRANCH_TARGET": ("BRANCH",),
    "JUMP_TARGET": ("JUMP",),
    "JALR_TARGET": ("JUMP",),
    "TRAP_CONTROL": ("SYSTEM",),
}

DEFAULT_CLASS_STAGE_CANDIDATE_MAP = {
    "RTYPE": {
        "IF": ("probeFetchReg",),
        "ID": ("probeDecodeReg",),
        "EX": ("probeExecReg",),
        "WB": ("probeAluWbReg", "probeWbReg"),
    },
    "OPIMM": {
        "IF": ("probeFetchReg",),
        "ID": ("probeDecodeReg",),
        "EX": ("probeExecReg",),
        "WB": ("probeAluWbReg", "probeWbReg"),
    },
    "LOAD": {
        "IF": ("probeFetchReg",),
        "ID": ("probeDecodeReg",),
        "EX": ("probeExecReg",),
        "MEM": ("probeMemReg",),
        "WB": ("loadCommitSink",),
    },
    "STORE": {
        "IF": ("probeFetchReg",),
        "ID": ("probeDecodeReg",),
        "EX": ("probeExecReg",),
        "MEM": ("probeStoreReg",),
    },
    "BRANCH": {
        "IF": ("probeFetchReg",),
        "ID": ("probeDecodeReg",),
        "EX": ("probeExecReg",),
        "CF": ("probeBranchTargetReg", "probeNextPcReg"),
    },
    "UPPER_IMM": {
        "IF": ("probeFetchReg",),
        "ID": ("probeDecodeReg",),
        "EX": ("probeExecReg",),
        "WB": ("probeAluWbReg", "probeWbReg"),
    },
    "JUMP": {
        "IF": ("probeFetchReg",),
        "ID": ("probeDecodeReg",),
        "EX": ("probeExecReg",),
        "WB": ("probeWbReg",),
        "CF": ("probeJumpTargetReg", "probeJalrTargetReg", "probeNextPcReg"),
    },
    "SYSTEM": {
        "IF": ("probeFetchReg",),
        "ID": ("probeDecodeReg",),
        "EX": ("probeTrapReg",),
        "CF": ("probeNextPcReg",),
    },
}

DEFAULT_STAGE_ORDER = ("IF", "ID", "EX", "MEM", "WB", "CF")

LOAD_POINT_METRICS = (
    ("LOAD_MEM_RETURN", "MEM_LOAD_RETURN", "probeMemReg"),
    ("LOAD_WB_INPUT", "WB_LOAD_QUALIFIED", "probeLoadWbReg"),
    ("LOAD_FINAL_COMMIT", "WB_LOAD_COMMIT", "loadCommitSink"),
)

LOAD_COMMIT_END_PIN_RE = re.compile(r"uTimingProbeTopBase/probeLoadCommitReg_reg\[\d+\]/D$")


def fmt_num(value: str | None) -> str:
    return value if value is not None else "NA"


def load_stage_rows(path: pathlib.Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            rows.append({key: value.strip() for key, value in row.items()})
    return rows


def is_numeric(value: str) -> bool:
    return value not in {"", "NA"}


def load_metadata(output_dir: pathlib.Path) -> dict[str, object]:
    metadata_path = output_dir / "analysis_metadata.json"
    if not metadata_path.exists():
        return {}
    return json.loads(metadata_path.read_text(encoding="utf-8"))


def resolve_family_configs(metadata: dict[str, object]) -> list[dict[str, str]]:
    metadata_rows = metadata.get("probe_families")
    if isinstance(metadata_rows, list) and metadata_rows:
        return [dict(row) for row in metadata_rows if isinstance(row, dict)]
    return [dict(row) for row in DEFAULT_FAMILY_CONFIGS]


def resolve_class_targets(metadata: dict[str, object]) -> dict[str, tuple[str, ...]]:
    metadata_targets = metadata.get("class_targets")
    if isinstance(metadata_targets, dict) and metadata_targets:
        return {
            str(class_name): tuple(str(probe_name) for probe_name in probe_names)
            for class_name, probe_names in metadata_targets.items()
            if isinstance(probe_names, list)
        }
    return dict(DEFAULT_CLASS_TARGETS)


def resolve_stage_candidate_map(metadata: dict[str, object]) -> dict[str, tuple[str, ...]]:
    metadata_map = metadata.get("stage_candidate_map")
    if isinstance(metadata_map, dict) and metadata_map:
        resolved: dict[str, tuple[str, ...]] = {}
        for stage_name, probe_names in metadata_map.items():
            if isinstance(probe_names, list) and probe_names:
                resolved[str(stage_name)] = tuple(str(probe_name) for probe_name in probe_names)
        if resolved:
            return resolved
    return dict(DEFAULT_STAGE_CANDIDATE_MAP)


def resolve_stage_order(stage_candidate_map: dict[str, tuple[str, ...]]) -> tuple[str, ...]:
    ordered = [stage_name for stage_name in DEFAULT_STAGE_ORDER if stage_name in stage_candidate_map]
    ordered.extend(stage_name for stage_name in stage_candidate_map if stage_name not in ordered)
    return tuple(ordered)


def resolve_family_active_classes(metadata: dict[str, object]) -> dict[str, tuple[str, ...]]:
    metadata_map = metadata.get("family_active_classes")
    if isinstance(metadata_map, dict) and metadata_map:
        resolved: dict[str, tuple[str, ...]] = {}
        for family_name, class_names in metadata_map.items():
            if isinstance(class_names, list) and class_names:
                resolved[str(family_name)] = tuple(str(class_name) for class_name in class_names)
        if resolved:
            return resolved
    return dict(DEFAULT_FAMILY_ACTIVE_CLASSES)


def resolve_class_stage_candidate_map(
    metadata: dict[str, object],
) -> dict[str, dict[str, tuple[str, ...]]]:
    metadata_map = metadata.get("class_stage_candidate_map")
    if isinstance(metadata_map, dict) and metadata_map:
        resolved: dict[str, dict[str, tuple[str, ...]]] = {}
        for class_name, stage_map in metadata_map.items():
            if not isinstance(stage_map, dict):
                continue
            stage_rows: dict[str, tuple[str, ...]] = {}
            for stage_name, probe_names in stage_map.items():
                if isinstance(probe_names, list) and probe_names:
                    stage_rows[str(stage_name)] = tuple(str(probe_name) for probe_name in probe_names)
            if stage_rows:
                resolved[str(class_name)] = stage_rows
        if resolved:
            return resolved
    return {class_name: dict(stage_map) for class_name, stage_map in DEFAULT_CLASS_STAGE_CANDIDATE_MAP.items()}


def family_lookup(family_configs: list[dict[str, str]]) -> dict[str, dict[str, str]]:
    return {config["probe"]: config for config in family_configs}


def family_priority(row: dict[str, str]) -> int:
    priorities = {
        "WB_LOAD_COMMIT": 40,
        "WB_LOAD_QUALIFIED": 30,
        "WB_ALU_RESULT": 20,
        "WB_MUXED_RESULT": 10,
    }
    return priorities.get(row["family"], 0)


def write_class_family_table(
    output_dir: pathlib.Path,
    stage_rows: list[dict[str, str]],
    family_configs: list[dict[str, str]],
) -> list[dict[str, str]]:
    probe_to_family = family_lookup(family_configs)
    output_path = output_dir / "class_architectural_family_timing_direct.tsv"
    family_rows: list[dict[str, str]] = []

    with output_path.open("w", encoding="utf-8", newline="") as handle:
        fieldnames = [
            "class",
            "family",
            "family_label",
            "description",
            "probe",
            "wns_ns",
            "min_period_ns",
            "fmax_mhz",
            "data_path_ns",
            "logic_levels",
            "start_pin",
            "end_pin",
        ]
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()

        for row in stage_rows:
            if row["probe"] == "loadCommitSink" and row["class"] != "LOAD":
                continue
            family = probe_to_family.get(row["probe"])
            if family is None:
                continue
            family_row = {
                "class": row["class"],
                "family": family["key"],
                "family_label": family["label"],
                "description": family["description"],
                "probe": row["probe"],
                "wns_ns": row["wns_ns"],
                "min_period_ns": row["min_period_ns"],
                "fmax_mhz": row["fmax_mhz"],
                "data_path_ns": row["data_path_ns"],
                "logic_levels": row["logic_levels"],
                "start_pin": row["start_pin"],
                "end_pin": row["end_pin"],
            }
            writer.writerow(family_row)
            family_rows.append(family_row)

    return family_rows


def require_load_commit_row(family_rows: list[dict[str, str]]) -> dict[str, str]:
    candidates = [
        row
        for row in family_rows
        if row["class"] == "LOAD"
        and row["family"] == "WB_LOAD_COMMIT"
        and is_numeric(row["min_period_ns"])
    ]
    if not candidates:
        raise RuntimeError("Canonical LOAD commit path is missing: LOAD/WB_LOAD_COMMIT did not produce a timed path.")

    worst_row = max(candidates, key=lambda row: float(row["min_period_ns"]))
    if not LOAD_COMMIT_END_PIN_RE.search(worst_row["end_pin"]):
        raise RuntimeError(
            "Canonical LOAD commit path is invalid: end pin is not the dedicated load-commit shadow sink "
            f"({worst_row['end_pin']})."
        )
    return worst_row


def write_load_path_points_table(
    output_dir: pathlib.Path,
    family_rows: list[dict[str, str]],
) -> None:
    output_path = output_dir / "load_path_points_direct.tsv"
    row_lookup = {(row["class"], row["family"], row["probe"]): row for row in family_rows}

    with output_path.open("w", encoding="utf-8", newline="") as handle:
        fieldnames = [
            "class",
            "metric",
            "family",
            "probe_or_sink",
            "wns_ns",
            "min_period_ns",
            "fmax_mhz",
            "data_path_ns",
            "logic_levels",
            "start_pin",
            "end_pin",
        ]
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()

        for metric_name, family_key, probe_name in LOAD_POINT_METRICS:
            source_row = row_lookup.get(("LOAD", family_key, probe_name))
            if source_row is None:
                source_row = {
                    "wns_ns": "NA",
                    "min_period_ns": "NA",
                    "fmax_mhz": "NA",
                    "data_path_ns": "NA",
                    "logic_levels": "NA",
                    "start_pin": "NA",
                    "end_pin": "NA",
                }
            writer.writerow(
                {
                    "class": "LOAD",
                    "metric": metric_name,
                    "family": family_key,
                    "probe_or_sink": probe_name,
                    "wns_ns": source_row["wns_ns"],
                    "min_period_ns": source_row["min_period_ns"],
                    "fmax_mhz": source_row["fmax_mhz"],
                    "data_path_ns": source_row["data_path_ns"],
                    "logic_levels": source_row["logic_levels"],
                    "start_pin": source_row["start_pin"],
                    "end_pin": source_row["end_pin"],
                }
            )


def write_family_summary_table(
    output_dir: pathlib.Path,
    family_rows: list[dict[str, str]],
    family_configs: list[dict[str, str]],
    family_active_classes: dict[str, tuple[str, ...]],
) -> None:
    output_path = output_dir / "architectural_family_summary_direct.tsv"
    worst_rows: list[dict[str, str]] = []

    for config in family_configs:
        active_classes = set(family_active_classes.get(config["key"], ()))
        candidates = [
            row
            for row in family_rows
            if row["family"] == config["key"]
            and is_numeric(row["min_period_ns"])
            and (not active_classes or row["class"] in active_classes)
        ]
        if not candidates:
            worst_rows.append(
                {
                    "family": config["key"],
                    "family_label": config["label"],
                    "description": config["description"],
                    "worst_class": "NA",
                    "probe": config["probe"],
                    "wns_ns": "NA",
                    "min_period_ns": "NA",
                    "fmax_mhz": "NA",
                    "data_path_ns": "NA",
                    "logic_levels": "NA",
                    "start_pin": "NA",
                    "end_pin": "NA",
                }
            )
            continue

        worst_row = max(candidates, key=lambda row: float(row["min_period_ns"]))
        worst_rows.append(
            {
                "family": config["key"],
                "family_label": config["label"],
                "description": config["description"],
                "worst_class": worst_row["class"],
                "probe": worst_row["probe"],
                "wns_ns": worst_row["wns_ns"],
                "min_period_ns": worst_row["min_period_ns"],
                "fmax_mhz": worst_row["fmax_mhz"],
                "data_path_ns": worst_row["data_path_ns"],
                "logic_levels": worst_row["logic_levels"],
                "start_pin": worst_row["start_pin"],
                "end_pin": worst_row["end_pin"],
            }
        )

    with output_path.open("w", encoding="utf-8", newline="") as handle:
        fieldnames = [
            "family",
            "family_label",
            "description",
            "worst_class",
            "probe",
            "wns_ns",
            "min_period_ns",
            "fmax_mhz",
            "data_path_ns",
            "logic_levels",
            "start_pin",
            "end_pin",
        ]
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(worst_rows)


def write_class_target_family_table(
    output_dir: pathlib.Path,
    family_rows: list[dict[str, str]],
    class_targets: dict[str, tuple[str, ...]],
) -> None:
    output_path = output_dir / "class_architectural_target_direct.tsv"
    class_probe_rows: dict[tuple[str, str], dict[str, str]] = {
        (row["class"], row["probe"]): row for row in family_rows
    }

    with output_path.open("w", encoding="utf-8", newline="") as handle:
        fieldnames = [
            "class",
            "family",
            "family_label",
            "probe",
            "wns_ns",
            "min_period_ns",
            "fmax_mhz",
            "data_path_ns",
            "logic_levels",
            "start_pin",
            "end_pin",
        ]
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()

        for class_name, target_probes in class_targets.items():
            worst_row: dict[str, str] | None = None
            worst_slack: float | None = None
            for probe_name in target_probes:
                candidate = class_probe_rows.get((class_name, probe_name))
                if candidate is None or not is_numeric(candidate["wns_ns"]):
                    continue
                slack = float(candidate["wns_ns"])
                if worst_row is None or slack < worst_slack:
                    worst_row = candidate
                    worst_slack = slack

            if worst_row is None:
                if class_name == "LOAD":
                    raise RuntimeError("Canonical LOAD target is missing: class_architectural_target_direct.tsv cannot be generated.")
                writer.writerow(
                    {
                        "class": class_name,
                        "family": "NA",
                        "family_label": "NA",
                        "probe": "NA",
                        "wns_ns": "NA",
                        "min_period_ns": "NA",
                        "fmax_mhz": "NA",
                        "data_path_ns": "NA",
                        "logic_levels": "NA",
                        "start_pin": "NA",
                        "end_pin": "NA",
                    }
                )
                continue

            writer.writerow(
                {
                    "class": class_name,
                    "family": worst_row["family"],
                    "family_label": worst_row["family_label"],
                    "probe": worst_row["probe"],
                    "wns_ns": worst_row["wns_ns"],
                    "min_period_ns": worst_row["min_period_ns"],
                    "fmax_mhz": worst_row["fmax_mhz"],
                    "data_path_ns": worst_row["data_path_ns"],
                    "logic_levels": worst_row["logic_levels"],
                    "start_pin": worst_row["start_pin"],
                    "end_pin": worst_row["end_pin"],
                }
            )


def write_class_stage_table(
    output_dir: pathlib.Path,
    family_rows: list[dict[str, str]],
    stage_candidate_map: dict[str, tuple[str, ...]],
    class_targets: dict[str, tuple[str, ...]],
    class_stage_candidate_map: dict[str, dict[str, tuple[str, ...]]],
) -> list[dict[str, str]]:
    output_path = output_dir / "class_pipeline_stage_timing_direct.tsv"
    stage_order = resolve_stage_order(stage_candidate_map)
    class_order = tuple(class_targets.keys())
    class_stage_rows: list[dict[str, str]] = []

    with output_path.open("w", encoding="utf-8", newline="") as handle:
        fieldnames = [
            "class",
            "stage",
            "family",
            "family_label",
            "probe",
            "wns_ns",
            "min_period_ns",
            "fmax_mhz",
            "data_path_ns",
            "logic_levels",
            "start_pin",
            "end_pin",
        ]
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()

        for class_name in class_order:
            stage_probe_map = class_stage_candidate_map.get(class_name, {})
            for stage_name in stage_order:
                stage_probes = set(stage_probe_map.get(stage_name, ()))
                candidates = [
                    row
                    for row in family_rows
                    if row["class"] == class_name
                    and row["probe"] in stage_probes
                    and is_numeric(row["min_period_ns"])
                ]

                if not candidates:
                    row_out = {
                        "class": class_name,
                        "stage": stage_name,
                        "family": "NA",
                        "family_label": "NA",
                        "probe": "NA",
                        "wns_ns": "NA",
                        "min_period_ns": "NA",
                        "fmax_mhz": "NA",
                        "data_path_ns": "NA",
                        "logic_levels": "NA",
                        "start_pin": "NA",
                        "end_pin": "NA",
                    }
                    writer.writerow(row_out)
                    class_stage_rows.append(row_out)
                    continue

                best_row = max(
                    candidates,
                    key=lambda row: (float(row["min_period_ns"]), family_priority(row)),
                )
                row_out = {
                    "class": class_name,
                    "stage": stage_name,
                    "family": best_row["family"],
                    "family_label": best_row["family_label"],
                    "probe": best_row["probe"],
                    "wns_ns": best_row["wns_ns"],
                    "min_period_ns": best_row["min_period_ns"],
                    "fmax_mhz": best_row["fmax_mhz"],
                    "data_path_ns": best_row["data_path_ns"],
                    "logic_levels": best_row["logic_levels"],
                    "start_pin": best_row["start_pin"],
                    "end_pin": best_row["end_pin"],
                }
                writer.writerow(row_out)
                class_stage_rows.append(row_out)

    return class_stage_rows


def write_stage_summary_table(
    output_dir: pathlib.Path,
    class_stage_rows: list[dict[str, str]],
    stage_candidate_map: dict[str, tuple[str, ...]],
) -> None:
    output_path = output_dir / "pipeline_stage_summary_direct.tsv"
    stage_order = resolve_stage_order(stage_candidate_map)
    summary_rows: list[dict[str, str]] = []

    for stage_name in stage_order:
        candidates = [
            row
            for row in class_stage_rows
            if row["stage"] == stage_name and is_numeric(row["min_period_ns"])
        ]
        if not candidates:
            summary_rows.append(
                {
                    "stage": stage_name,
                    "worst_class": "NA",
                    "family": "NA",
                    "family_label": "NA",
                    "probe": "NA",
                    "wns_ns": "NA",
                    "min_period_ns": "NA",
                    "fmax_mhz": "NA",
                    "data_path_ns": "NA",
                    "logic_levels": "NA",
                    "start_pin": "NA",
                    "end_pin": "NA",
                }
            )
            continue

        worst_row = max(
            candidates,
            key=lambda row: (float(row["min_period_ns"]), family_priority(row)),
        )
        summary_rows.append(
            {
                "stage": stage_name,
                "worst_class": worst_row["class"],
                "family": worst_row["family"],
                "family_label": worst_row["family_label"],
                "probe": worst_row["probe"],
                "wns_ns": worst_row["wns_ns"],
                "min_period_ns": worst_row["min_period_ns"],
                "fmax_mhz": worst_row["fmax_mhz"],
                "data_path_ns": worst_row["data_path_ns"],
                "logic_levels": worst_row["logic_levels"],
                "start_pin": worst_row["start_pin"],
                "end_pin": worst_row["end_pin"],
            }
        )

    with output_path.open("w", encoding="utf-8", newline="") as handle:
        fieldnames = [
            "stage",
            "worst_class",
            "family",
            "family_label",
            "probe",
            "wns_ns",
            "min_period_ns",
            "fmax_mhz",
            "data_path_ns",
            "logic_levels",
            "start_pin",
            "end_pin",
        ]
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(summary_rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate architectural family summaries for pipeline_prep raw timing.")
    parser.add_argument("--output-dir", type=pathlib.Path, default=DEFAULT_OUTPUT_DIR)
    args = parser.parse_args()

    stage_path = args.output_dir / "class_stage_delay_direct.tsv"
    if not stage_path.exists():
        raise RuntimeError(f"Required file not found: {stage_path}")

    metadata = load_metadata(args.output_dir)
    family_configs = resolve_family_configs(metadata)
    class_targets = resolve_class_targets(metadata)
    stage_candidate_map = resolve_stage_candidate_map(metadata)
    family_active_classes = resolve_family_active_classes(metadata)
    class_stage_candidate_map = resolve_class_stage_candidate_map(metadata)
    stage_rows = load_stage_rows(stage_path)
    family_rows = write_class_family_table(args.output_dir, stage_rows, family_configs)
    require_load_commit_row(family_rows)
    write_load_path_points_table(args.output_dir, family_rows)
    write_family_summary_table(args.output_dir, family_rows, family_configs, family_active_classes)
    write_class_target_family_table(args.output_dir, family_rows, class_targets)
    class_stage_rows = write_class_stage_table(
        args.output_dir,
        family_rows,
        stage_candidate_map,
        class_targets,
        class_stage_candidate_map,
    )
    write_stage_summary_table(args.output_dir, class_stage_rows, stage_candidate_map)

    print(f"Architectural family summaries written under {args.output_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
