#!/usr/bin/env python3
"""matplotlib 기반의 Toss 스타일 한글 TB 보고서를 생성한다."""

from __future__ import annotations

import argparse
import base64
import html
import io
import json
import math
import re
import struct
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib.font_manager import FontProperties
from matplotlib.lines import Line2D


TOSS_BLUE = "#3182F6"
TOSS_BLUE_DARK = "#1B64DA"
TOSS_GREEN = "#00C773"
TOSS_RED = "#F04452"
TOSS_YELLOW = "#FFD54A"
TOSS_ORANGE = "#FF8A00"
TOSS_GRAY_900 = "#191F28"
TOSS_GRAY_700 = "#4E5968"
TOSS_GRAY_500 = "#8B95A1"
TOSS_GRAY_300 = "#DDE2E8"
TOSS_GRAY_100 = "#F2F4F6"
TOSS_WHITE = "#FFFFFF"
TITLE_FONT = FontProperties(
    family=[
        "Pretendard",
        "Segoe UI Variable",
        "Segoe UI",
        "Malgun Gothic",
        "Arial",
        "DejaVu Sans",
    ],
    weight="bold",
)

COVERAGE_POINT_GROUPS = [
    {"key": "reset_phase", "label": "Reset", "prefix": "cp_reset_phase:", "total": 4},
    {"key": "frame_len", "label": "Len", "prefix": "cp_frame_len:", "total": 11},
    {"key": "term_kind", "label": "Term", "prefix": "cp_term_kind:", "total": 3},
    {"key": "post_term_rearm", "label": "Rearm", "prefix": "cp_post_term_rearm:", "total": 2},
    {"key": "input_class", "label": "Class", "prefix": "cp_input_class:", "total": 5},
    {"key": "max_pos", "label": "MaxPos", "prefix": "cp_max_pos:", "total": 5},
    {"key": "in_stall", "label": "InStall", "prefix": "cp_in_stall:", "total": 7},
    {"key": "out_stall", "label": "OutStall", "prefix": "cp_out_stall:", "total": 7},
    {"key": "keep_kind", "label": "Keep", "prefix": "cp_keep_kind:", "total": 4},
    {"key": "special_fp32", "label": "Special", "prefix": "cp_special_fp32:", "total": 7},
    {"key": "result_kind", "label": "Result", "prefix": "cp_result_kind:", "total": 6},
    {"key": "output_last", "label": "Last", "prefix": "cp_output_last:", "total": 3},
    {"key": "reset_result", "label": "Reset*Res", "prefix": "cp_reset_phase_result_combo:", "total": 4},
    {"key": "len_term", "label": "Len*Term", "prefix": "cp_len_term_combo:", "total": 11},
    {"key": "term_rearm", "label": "Term*Re", "prefix": "cp_term_rearm_combo:", "total": 6},
    {"key": "class_maxpos", "label": "Class*Pos", "prefix": "cp_class_maxpos_combo:", "total": 13},
    {"key": "stall_pair", "label": "Stall*Pair", "prefix": "cp_stall_pair_combo:", "total": 49},
    {"key": "len_result", "label": "Len*Res", "prefix": "cp_len_result_combo:", "total": 22},
]

STALL_MODE_INDEX = {
    "none": 0,
    "light": 1,
    "heavy": 2,
    "alternate": 3,
    "burst": 4,
    "random": 5,
    "scripted": 6,
}

RESET_EVENT_FALLBACKS = {
    "reset_idle_event": {"reset_phase": "idle", "in_stall": "none", "out_stall": "none"},
    "reset_capture_event": {"reset_phase": "capture", "in_stall": "none", "out_stall": "light"},
    "reset_replay_event": {"reset_phase": "replay", "in_stall": "light", "out_stall": "light"},
    "reset_output_valid_event": {"reset_phase": "output_valid", "in_stall": "light", "out_stall": "heavy"},
}


plt.rcParams.update(
    {
        "figure.facecolor": TOSS_WHITE,
        "axes.facecolor": TOSS_WHITE,
        "axes.edgecolor": TOSS_GRAY_300,
        "axes.labelcolor": TOSS_GRAY_700,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "axes.titleweight": 800,
        "axes.titlesize": 13.5,
        "axes.labelsize": 10.5,
        "axes.labelweight": 600,
        "xtick.color": TOSS_GRAY_500,
        "ytick.color": TOSS_GRAY_500,
        "xtick.labelsize": 10,
        "ytick.labelsize": 10,
        "grid.color": "#EEF2F7",
        "grid.linewidth": 0.8,
        "text.color": TOSS_GRAY_900,
        "font.size": 10,
        "font.family": "sans-serif",
        "font.sans-serif": [
            "Pretendard",
            "Segoe UI Variable",
            "Segoe UI",
            "Malgun Gothic",
            "Arial",
            "DejaVu Sans",
        ],
        "legend.fontsize": 9.5,
        "legend.title_fontsize": 9.5,
    }
)


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def set_chart_title(ax: Any, title: str) -> None:
    ax.set_title(
        title,
        loc="left",
        pad=12,
        fontproperties=TITLE_FONT,
        fontsize=15,
        color=TOSS_GRAY_900,
    )


def downsample_indices(length: int, max_points: int) -> list[int]:
    if length <= max_points:
        return list(range(length))
    if max_points <= 2:
        return [0, length - 1]
    indices = {
        min(length - 1, max(0, round(idx * (length - 1) / (max_points - 1))))
        for idx in range(max_points)
    }
    return sorted(indices)


def draw_round_bar_series(
    ax: Any,
    x_values: list[float],
    y_values: list[float],
    color: str,
    label: str,
    linewidth: float,
    zorder: int = 2,
) -> Line2D:
    stems = ax.vlines(
        x_values,
        [0.0] * len(x_values),
        y_values,
        colors=color,
        linewidth=linewidth,
        alpha=0.96,
        zorder=zorder,
    )
    stems.set_capstyle("round")
    ax.scatter(
        x_values,
        y_values,
        s=max(40.0, linewidth * linewidth * 0.95),
        color=color,
        edgecolors=TOSS_WHITE,
        linewidths=1.1,
        zorder=zorder + 1,
    )
    return Line2D(
        [0],
        [0],
        color=color,
        linewidth=linewidth,
        marker="o",
        markersize=max(5.5, linewidth * 0.58),
        markerfacecolor=color,
        markeredgecolor=TOSS_WHITE,
        markeredgewidth=1.0,
        solid_capstyle="round",
        label=label,
    )


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            rows.append(json.loads(line))
    return rows


def sanitize_name(name: str) -> str:
    if not name:
        return "unnamed"
    return "".join(char if (char.isalnum() or char in {"_", "-"}) else "_" for char in name)


def csv_tokens(value: str) -> list[str]:
    if not value:
        return []
    return [token for token in value.split(",") if token]


def bits_to_float(value: int) -> float:
    return struct.unpack(">f", struct.pack(">I", value & 0xFFFFFFFF))[0]


def csv_hex_to_float_list(value: str) -> list[float]:
    return [bits_to_float(int(token, 16)) for token in csv_tokens(value)]


def csv_preview(value: str, limit: int = 24) -> str:
    tokens = csv_tokens(value)
    preview = tokens[:limit]
    if len(tokens) > limit:
        preview.append(f"... (추가 {len(tokens) - limit}개)")
    return ", ".join(preview)


def csv_float_preview(values: list[float], limit: int = 24) -> str:
    preview = [f"{value:.8f}" for value in values[:limit]]
    if len(values) > limit:
        preview.append(f"... (추가 {len(values) - limit}개)")
    return ", ".join(preview)


def pct_text(value: Any) -> str:
    return f"{float(value):.1f}%"


def sci_text(value: Any) -> str:
    return f"{float(value):.6e}"


def compact_chart_value(value: float) -> str:
    magnitude = abs(float(value))
    if magnitude >= 1.0e-3:
        return f"{value:.4f}"
    if magnitude >= 1.0e-5:
        return f"{value:.2e}"
    return f"{value:.1e}"


def percent_fill(value: float, ceiling: float = 100.0, minimum: float = 6.0) -> float:
    if ceiling <= 0.0:
        return minimum
    ratio = max(0.0, min(1.0, float(value) / ceiling))
    if ratio == 0.0:
        return minimum
    return max(minimum, ratio * 100.0)


def status_text(status: str) -> str:
    return {
        "PASS": "Pass",
        "FAIL": "Fail",
        "UNKNOWN": "Pending",
    }.get(status, status)


def yes_no_text(value: bool) -> str:
    return "Yes" if value else "No"


def excluded_reason_text(reason: str) -> str:
    if reason == "":
        return ""
    return {
        "missing_input_frame": "input frame missing",
        "non_finite_input_or_invalid_softmax": "non-finite input 또는 ideal softmax 계산 불가",
        "no_overlap_between_actual_and_ideal": "actual-ideal overlap 없음",
    }.get(reason, reason.replace("length_mismatch", "length mismatch"))


def status_badge(status: str) -> str:
    badge_class = "pass" if status == "PASS" else "fail"
    return f'<span class="badge {badge_class}">{html.escape(status_text(status))}</span>'


def short_label(value: str, limit: int = 18) -> str:
    if len(value) <= limit:
        return value
    return value[: limit - 1] + "…"


def compact_testname(value: str) -> str:
    tokens = [token for token in str(value).split("_") if token]
    if len(tokens) >= 3 and tokens[0] == "test":
        return "_".join(tokens[:2] + [tokens[-1]])
    return short_label(str(value), 14)


def axis_test_label(value: str) -> str:
    tokens = [token for token in str(value).split("_") if token]
    if len(tokens) >= 2 and tokens[0] == "test" and tokens[1].isdigit():
        return f"test{int(tokens[1]):02d}"
    return short_label(str(value), 8)


def case_purpose_text(testname: str) -> str:
    return {
        "test_01_reset_matrix": "리셋 시 동작 중단(Abort), 이전 출력(Stale output) 차단, 프레임 간 격리(Isolation)가 정상적으로 이루어지는지 검증합니다.",
        "test_02_singleton_frame": "길이가 1인 단일 프레임 입력 시 Softmax 출력이 1.0인지 확인하고, 마지막 데이터 처리 및 최단 경로(Minimum path) 동작을 점검합니다.",
        "test_03_uniform_frame": "모든 원소 값이 동일한 벡터 입력 시 동일한 확률값이 출력되는지 확인하고, 내부 정규화(Normalization) 연산 품질을 검증합니다.",
        "test_04_mixed_vector_directed": "양수/음수 혼합 입력 시 Argmax 갱신을 확인하고, 값 차이가 미미한 상황(Near-tie)에서의 하드웨어 근사(Approximation) 처리를 검증합니다.",
        "test_05_backpressure_protocol": "입출력 Stall 및 백프레셔(Backpressure) 발생 시 데이터 유실이나 중복 없이 통신 프로토콜이 안정적으로 유지되는지 확인합니다.",
        "test_06_frame_boundary_cmax": "iLast를 통한 프레임 종료와 C_MAX 도달에 따른 자동 종료 조건에서 프레임 경계(Boundary) 처리가 충돌 없이 수행되는지 검증합니다.",
        "test_07_boundary_collision_rearm": "iLast와 C_MAX가 동시에 발생하는 예외 종료 후, 즉각적인 시스템 재가동(Immediate re-arm)과 연속적인 데이터 수용(Back-to-back accept)이 가능한지 확인합니다.",
        "test_08_keep_ignore": "입력 측 Keep 신호 무시 동작과 출력 측의 고정 Keep 정책(Fixed output keep policy)이 설계대로 적용되는지 검증합니다.",
        "test_09_special_fp32_policy": "0, 무한대(Inf), 비정상 수치(NaN) 등 특수 FP32 입력에 대한 포화(Saturation) 정책과 예외 처리 동작을 검증합니다.",
        "test_10_random_cov": "가중치가 부여된 랜덤 패턴(Weighted-random)을 주입해 검증 커버리지를 확보하고, 근사 연산의 오차 분포를 전반적으로 확인하는 회귀(Regression) 테스트입니다.",
    }.get(testname, "이 case의 frame handling, numeric stability, coverage contribution을 요약한 verification page입니다.")


def fig_to_data_uri(fig: plt.Figure) -> str:
    buffer = io.BytesIO()
    fig.savefig(buffer, format="png", dpi=170, bbox_inches="tight", facecolor=TOSS_WHITE)
    plt.close(fig)
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def empty_chart_svg(message: str) -> str:
    escaped = html.escape(message)
    return (
        "data:image/svg+xml;base64,"
        + base64.b64encode(
            (
                "<svg xmlns='http://www.w3.org/2000/svg' width='960' height='420'>"
                "<rect width='100%' height='100%' rx='20' fill='#F9FAFB'/>"
                "<text x='50%' y='50%' dominant-baseline='middle' text-anchor='middle' "
                "font-family='Pretendard, Segoe UI Variable, Segoe UI, Malgun Gothic, Arial, sans-serif' font-size='20' fill='#8B95A1'>"
                + escaped
                + "</text></svg>"
            ).encode("utf-8")
        ).decode("ascii")
    )


@dataclass
class NumericStats:
    checked_beats: int = 0
    eligible_beats: int = 0
    eligible_frames: int = 0
    excluded_frames: int = 0
    abs_err_sum: float = 0.0
    abs_err_max: float = 0.0
    rel_err_sum_pct: float = 0.0
    rel_err_max_pct: float = 0.0

    def note_frame(self, abs_errors: list[float], rel_errors: list[float], eligible: bool) -> None:
        if not eligible:
            self.excluded_frames += 1
            return
        self.eligible_frames += 1
        self.checked_beats += len(abs_errors)
        self.eligible_beats += len(abs_errors)
        for abs_err, rel_err in zip(abs_errors, rel_errors):
            self.abs_err_sum += abs_err
            self.rel_err_sum_pct += rel_err
            self.abs_err_max = max(self.abs_err_max, abs_err)
            self.rel_err_max_pct = max(self.rel_err_max_pct, rel_err)

    @property
    def avg_abs_err(self) -> float:
        if self.eligible_beats == 0:
            return 0.0
        return self.abs_err_sum / self.eligible_beats

    @property
    def avg_rel_err_pct(self) -> float:
        if self.eligible_beats == 0:
            return 0.0
        return self.rel_err_sum_pct / self.eligible_beats


@dataclass
class ChartSpec:
    title: str
    description: str
    uri: str
    meaning: str
    evidence: str
    why_used: str
    class_name: str = ""


def render_inline_markup(value: str) -> str:
    rendered: list[str] = []
    code_parts = str(value).split("`")
    for index, code_part in enumerate(code_parts):
        if index % 2 == 1:
            rendered.append(f"<code>{html.escape(code_part)}</code>")
            continue
        cursor = 0
        for match in re.finditer(r"\$(.+?)\$", code_part):
            rendered.append(html.escape(code_part[cursor:match.start()]))
            rendered.append(f"<span class='math'>\\({html.escape(match.group(1))}\\)</span>")
            cursor = match.end()
        rendered.append(html.escape(code_part[cursor:]))
    return "".join(rendered)


def ideal_softmax(values: list[float]) -> list[float] | None:
    if not values or any(not math.isfinite(value) for value in values):
        return None
    max_value = max(values)
    exp_values = [math.exp(value - max_value) for value in values]
    exp_sum = sum(exp_values)
    if exp_sum == 0.0 or not math.isfinite(exp_sum):
        return None
    return [value / exp_sum for value in exp_values]


def compute_ideal_metrics(
    inputs: list[dict[str, Any]],
    actual: list[dict[str, Any]],
) -> tuple[NumericStats, dict[str, NumericStats], dict[int, dict[str, Any]]]:
    input_map = {int(row["frame_id"]): row for row in inputs}
    scenario_stats: dict[str, NumericStats] = {}
    frame_metrics: dict[int, dict[str, Any]] = {}
    total = NumericStats()

    for act_row in actual:
        frame_id = int(act_row["frame_id"])
        in_row = input_map.get(frame_id)
        scenario = str(act_row.get("scenario", in_row.get("scenario") if in_row else "Unclassified"))
        scenario_stats.setdefault(scenario, NumericStats())

        actual_values = csv_hex_to_float_list(str(act_row.get("data_hex_csv", "")))
        eligible = False
        abs_errors: list[float] = []
        rel_errors: list[float] = []
        ideal_values: list[float] = []
        input_values: list[float] = []
        excluded_reason = ""

        if in_row is None:
            excluded_reason = "missing_input_frame"
        else:
            input_values = csv_hex_to_float_list(str(in_row.get("data_hex_csv", "")))
            ideal_values = ideal_softmax(input_values) or []
            if not ideal_values:
                excluded_reason = "non_finite_input_or_invalid_softmax"
            else:
                compare_len = min(len(actual_values), len(ideal_values))
                eligible = compare_len > 0
                for idx in range(compare_len):
                    abs_err = abs(actual_values[idx] - ideal_values[idx])
                    denom = abs(ideal_values[idx])
                    if denom <= 1.0e-12:
                        rel_err = 0.0 if abs_err <= 1.0e-12 else 100.0
                    else:
                        rel_err = (abs_err * 100.0) / denom
                    abs_errors.append(abs_err)
                    rel_errors.append(rel_err)
                if not eligible:
                    excluded_reason = "no_overlap_between_actual_and_ideal"
                elif len(actual_values) != len(ideal_values):
                    excluded_reason = f"length_mismatch actual={len(actual_values)} ideal={len(ideal_values)}"

        total.note_frame(abs_errors, rel_errors, eligible)
        scenario_stats[scenario].note_frame(abs_errors, rel_errors, eligible)
        frame_metrics[frame_id] = {
            "eligible": eligible,
            "excluded_reason": excluded_reason,
            "input_values": input_values,
            "ideal_values": ideal_values,
            "actual_values": actual_values,
            "beat_abs_errors": abs_errors,
            "beat_rel_errors_pct": rel_errors,
            "compare_len": min(len(actual_values), len(ideal_values)),
            "actual_sum": sum(actual_values) if actual_values else 0.0,
            "ideal_sum": sum(ideal_values) if ideal_values else 0.0,
            "sum_residual": (sum(actual_values) - 1.0) if actual_values else 0.0,
            "avg_abs_err": (sum(abs_errors) / len(abs_errors)) if abs_errors else 0.0,
            "max_abs_err": max(abs_errors) if abs_errors else 0.0,
            "avg_rel_err_pct": (sum(rel_errors) / len(rel_errors)) if rel_errors else 0.0,
            "max_rel_err_pct": max(rel_errors) if rel_errors else 0.0,
        }

    return total, scenario_stats, frame_metrics


def max_pos_kind_from_argmax(input_len: int, argmax_csv: str) -> str:
    argmax_tokens = [token for token in str(argmax_csv).split(",") if token]
    if not argmax_tokens:
        return "none"
    if len(argmax_tokens) > 1:
        return "tie"
    max_index = int(argmax_tokens[0])
    if max_index == 0:
        return "first"
    if max_index == max(input_len - 1, 0):
        return "last"
    return "middle"


def len_term_combo_value(frame_len: int, term_kind: str) -> int | None:
    if term_kind == "iLast_only":
        mapping = {1: 0, 2: 1, 3: 2, 5: 3, 7: 4, 16: 5, 63: 6, 64: 7, 1023: 8}
        return mapping.get(frame_len)
    if frame_len == 1024 and term_kind == "cmax_only":
        return 9
    if frame_len == 1024 and term_kind == "iLast_and_cmax":
        return 10
    return None


def term_rearm_combo_value(term_kind: str, post_term_rearm: str) -> int | None:
    mapping = {
        ("iLast_only", "delayed"): 0,
        ("iLast_only", "back_to_back"): 1,
        ("cmax_only", "delayed"): 2,
        ("cmax_only", "back_to_back"): 3,
        ("iLast_and_cmax", "delayed"): 4,
        ("iLast_and_cmax", "back_to_back"): 5,
    }
    return mapping.get((term_kind, post_term_rearm))


def class_maxpos_combo_value(input_class: str, max_pos_kind: str) -> int | None:
    if input_class == "uniform" and max_pos_kind == "tie":
        return 0
    if input_class == "mixed_sign":
        mapping = {"first": 1, "middle": 2, "last": 3, "tie": 4}
        return mapping.get(max_pos_kind)
    if input_class == "dominant_peak":
        mapping = {"first": 5, "middle": 6, "last": 7}
        return mapping.get(max_pos_kind)
    if input_class == "near_equal":
        mapping = {"middle": 8, "tie": 9}
        return mapping.get(max_pos_kind)
    if input_class == "special_exp":
        mapping = {"first": 10, "last": 11, "tie": 12}
        return mapping.get(max_pos_kind)
    return None


def stall_pair_combo_value(in_stall: str, out_stall: str) -> int | None:
    if in_stall not in STALL_MODE_INDEX or out_stall not in STALL_MODE_INDEX:
        return None
    return STALL_MODE_INDEX[in_stall] * 7 + STALL_MODE_INDEX[out_stall]


def len_result_combo_value(frame_len: int, result_kind: str) -> int | None:
    len_mapping = {1: 0, 2: 1, 3: 2, 5: 3, 7: 4, 16: 5, 63: 6, 64: 7, 1023: 8, 1024: 9}
    len_idx = len_mapping.get(frame_len)
    if result_kind == "normal" and len_idx is not None:
        return len_idx
    if result_kind == "reset_aborted" and frame_len == 1:
        return 10
    if result_kind == "special" and frame_len == 2:
        return 11
    if result_kind == "random_cov" and len_idx is not None:
        return 12 + len_idx
    return None


def frame_point_keys(
    frame_len: int,
    input_class: str,
    in_stall: str,
    out_stall: str,
    keep_kind: str,
    result_kind: str,
    reset_phase: str,
    term_kind: str,
    post_term_rearm: str,
    special_kind: str,
    argmax_csv: str,
    last_count: int,
) -> set[str]:
    point_keys: set[str] = set()
    max_pos_kind = max_pos_kind_from_argmax(frame_len, argmax_csv)
    output_last = "single" if int(last_count) == 1 else "missing" if int(last_count) == 0 else "dup"

    if reset_phase and reset_phase != "none":
        point_keys.add(f"cp_reset_phase:{reset_phase}")
    if frame_len in {1, 2, 3, 5, 7, 16, 63, 64, 1023, 1024}:
        point_keys.add(f"cp_frame_len:{frame_len}")
    if term_kind:
        point_keys.add(f"cp_term_kind:{term_kind}")
    if post_term_rearm:
        point_keys.add(f"cp_post_term_rearm:{post_term_rearm}")
    if input_class and input_class != "unknown":
        point_keys.add(f"cp_input_class:{input_class}")
    point_keys.add(f"cp_max_pos:{max_pos_kind}")
    if in_stall:
        point_keys.add(f"cp_in_stall:{in_stall}")
    if out_stall:
        point_keys.add(f"cp_out_stall:{out_stall}")
    if keep_kind:
        point_keys.add(f"cp_keep_kind:{keep_kind}")
    if special_kind:
        point_keys.add(f"cp_special_fp32:{special_kind}")
    if result_kind:
        point_keys.add(f"cp_result_kind:{result_kind}")
    point_keys.add(f"cp_output_last:{output_last}")

    if result_kind == "reset_aborted" and reset_phase in {"idle", "capture", "replay", "output_valid"}:
        reset_result_map = {"idle": 0, "capture": 1, "replay": 2, "output_valid": 3}
        point_keys.add(f"cp_reset_phase_result_combo:{reset_result_map[reset_phase]}")

    len_term_value = len_term_combo_value(frame_len, term_kind)
    if len_term_value is not None:
        point_keys.add(f"cp_len_term_combo:{len_term_value}")

    term_rearm_value = term_rearm_combo_value(term_kind, post_term_rearm)
    if term_rearm_value is not None:
        point_keys.add(f"cp_term_rearm_combo:{term_rearm_value}")

    class_maxpos_value = class_maxpos_combo_value(input_class, max_pos_kind)
    if class_maxpos_value is not None:
        point_keys.add(f"cp_class_maxpos_combo:{class_maxpos_value}")

    stall_pair_value = stall_pair_combo_value(in_stall, out_stall)
    if stall_pair_value is not None:
        point_keys.add(f"cp_stall_pair_combo:{stall_pair_value}")

    len_result_value = len_result_combo_value(frame_len, result_kind)
    if len_result_value is not None:
        point_keys.add(f"cp_len_result_combo:{len_result_value}")

    return point_keys


def reconstruct_scenario_cov_points(case: dict[str, Any]) -> list[dict[str, Any]]:
    if case.get("scenario_cov_points"):
        return case["scenario_cov_points"]

    input_map = {int(row["frame_id"]): row for row in case.get("inputs", [])}
    expected_map = {int(row["frame_id"]): row for row in case.get("expected", [])}
    actual_map = {int(row["frame_id"]): row for row in case.get("actual", [])}
    scenario_point_keys_map: dict[str, set[str]] = {}

    for frame_id, expected_row in expected_map.items():
        input_row = input_map.get(frame_id, {})
        actual_row = actual_map.get(frame_id, {})
        scenario_name = str(expected_row.get("scenario", input_row.get("scenario", "")))
        if not scenario_name:
            continue
        scenario_point_keys_map.setdefault(scenario_name, set()).update(
            frame_point_keys(
                frame_len=len(csv_tokens(str(input_row.get("data_hex_csv", "")))),
                input_class=str(expected_row.get("input_class", input_row.get("input_class", "unknown"))),
                in_stall=str(expected_row.get("in_stall", input_row.get("in_stall", "none"))),
                out_stall=str(expected_row.get("out_stall", input_row.get("out_stall", "none"))),
                keep_kind=str(expected_row.get("keep_kind", input_row.get("keep_kind", "all_f"))),
                result_kind=str(expected_row.get("result_kind", input_row.get("result_kind", "normal"))),
                reset_phase=str(expected_row.get("reset_phase", input_row.get("reset_phase", "none"))),
                term_kind=str(expected_row.get("term_kind", input_row.get("term_kind", "iLast_only"))),
                post_term_rearm=str(expected_row.get("post_term_rearm", input_row.get("post_term_rearm", "delayed"))),
                special_kind=str(expected_row.get("special_kind", input_row.get("special_kind", "none"))),
                argmax_csv=str(expected_row.get("argmax_csv", "")),
                last_count=int(actual_row.get("last_count", 0)),
            )
        )

    for scenario_row in case.get("scenario_cov", []):
        scenario_name = str(scenario_row.get("name", ""))
        if scenario_name in scenario_point_keys_map or scenario_name not in RESET_EVENT_FALLBACKS:
            continue
        reset_meta = RESET_EVENT_FALLBACKS[scenario_name]
        scenario_point_keys_map[scenario_name] = frame_point_keys(
            frame_len=1,
            input_class="unknown",
            in_stall=str(reset_meta["in_stall"]),
            out_stall=str(reset_meta["out_stall"]),
            keep_kind="all_f",
            result_kind="reset_aborted",
            reset_phase=str(reset_meta["reset_phase"]),
            term_kind="iLast_only",
            post_term_rearm="delayed",
            special_kind="none",
            argmax_csv="",
            last_count=0,
        )

    rows = []
    for scenario_name, point_keys in scenario_point_keys_map.items():
        rows.append(
            {
                "name": scenario_name,
                "point_count": len(point_keys),
                "union_count": len(point_keys),
                "point_keys_pipe": "|".join(sorted(point_keys)),
            }
        )
    rows.sort(key=lambda row: str(row.get("name", "")))
    return rows


def load_case_data(case_dir: Path) -> dict[str, Any]:
    summary = load_json(case_dir / "report_summary.json")
    scenario_cov = load_jsonl(case_dir / "scenario_coverage.jsonl")
    scenario_cov_points = load_jsonl(case_dir / "scenario_cov_points.jsonl")
    scenario_quality = load_jsonl(case_dir / "scenario_quality.jsonl")
    inputs = load_jsonl(case_dir / "input_frames.jsonl")
    expected = load_jsonl(case_dir / "expected_frames.jsonl")
    actual = load_jsonl(case_dir / "actual_frames.jsonl")
    mismatches = load_jsonl(case_dir / "mismatch_events.jsonl")
    ideal_total, ideal_by_scenario, ideal_by_frame = compute_ideal_metrics(inputs, actual)
    case_data = {
        "dir": case_dir,
        "summary": summary,
        "scenario_cov": scenario_cov,
        "scenario_cov_points_from_artifact": bool(scenario_cov_points),
        "scenario_cov_points": scenario_cov_points,
        "scenario_quality": scenario_quality,
        "inputs": inputs,
        "expected": expected,
        "actual": actual,
        "mismatches": mismatches,
        "ideal_total": ideal_total,
        "ideal_by_scenario": ideal_by_scenario,
        "ideal_by_frame": ideal_by_frame,
    }
    case_data["scenario_cov_points"] = reconstruct_scenario_cov_points(case_data)
    return case_data


def discover_case_dirs(runtime_root: Path, testname: str, suite_summary: dict[str, Any]) -> list[Path]:
    csv_value = str(suite_summary.get("case_names_csv", ""))
    if csv_value:
        candidates = [runtime_root / sanitize_name(name) for name in csv_value.split(",") if name]
    elif testname == "all":
        candidates = [path.parent for path in runtime_root.glob("*/report_summary.json")]
    else:
        candidates = [runtime_root / sanitize_name(testname)]
    candidates = [path for path in candidates if (path / "report_summary.json").exists()]
    return sorted(candidates, key=lambda path: load_json(path / "report_summary.json").get("case_index", 9999))


def aggregate_suite_summary(case_data: list[dict[str, Any]], suite_summary: dict[str, Any], testname: str) -> dict[str, Any]:
    total_errors = sum(int(case["summary"].get("total_errors", 0)) for case in case_data)
    total_warnings = sum(int(case["summary"].get("warnings", 0)) for case in case_data)
    statuses = [str(case["summary"].get("status", "UNKNOWN")) for case in case_data]
    suite_status = "PASS" if statuses and all(status == "PASS" for status in statuses) else "FAIL"

    ideal_total = NumericStats()
    for case in case_data:
        local = case["ideal_total"]
        ideal_total.checked_beats += local.checked_beats
        ideal_total.eligible_beats += local.eligible_beats
        ideal_total.eligible_frames += local.eligible_frames
        ideal_total.excluded_frames += local.excluded_frames
        ideal_total.abs_err_sum += local.abs_err_sum
        ideal_total.rel_err_sum_pct += local.rel_err_sum_pct
        ideal_total.abs_err_max = max(ideal_total.abs_err_max, local.abs_err_max)
        ideal_total.rel_err_max_pct = max(ideal_total.rel_err_max_pct, local.rel_err_max_pct)

    residual_values = [
        abs(float(metric.get("sum_residual", 0.0)))
        for case in case_data
        for metric in case["ideal_by_frame"].values()
        if metric.get("eligible", False)
    ]

    return {
        "requested_test": suite_summary.get("requested_test", testname),
        "case_names_csv": suite_summary.get("case_names_csv", ""),
        "suite_status": suite_status,
        "suite_coverage_pct": float(suite_summary.get("suite_coverage_pct", 0.0)),
        "suite_vivado_builtin_coverage_pct": float(suite_summary.get("vivado_builtin_coverage_pct", 0.0)),
        "total_cases": len(case_data),
        "failed_case_count": int(suite_summary.get("failed_case_count", 0)),
        "failed_error_total": int(suite_summary.get("failed_error_total", 0)),
        "failed_case_names_csv": str(suite_summary.get("failed_case_names_csv", "")),
        "total_errors": total_errors,
        "total_warnings": total_warnings,
        "rtl_checked_beats": int(suite_summary.get("rtl_checked_beats", 0)),
        "rtl_mismatch_beats": int(suite_summary.get("rtl_mismatch_beats", 0)),
        "rtl_mismatch_rate_pct": float(suite_summary.get("rtl_mismatch_rate_pct", 0.0)),
        "rtl_numeric_beats": int(suite_summary.get("rtl_numeric_beats", 0)),
        "rtl_avg_abs_err": float(suite_summary.get("rtl_avg_abs_err", 0.0)),
        "rtl_max_abs_err": float(suite_summary.get("rtl_max_abs_err", 0.0)),
        "rtl_avg_rel_err_pct": float(suite_summary.get("rtl_avg_rel_err_pct", 0.0)),
        "rtl_max_rel_err_pct": float(suite_summary.get("rtl_max_rel_err_pct", 0.0)),
        "rtl_failed_frames": int(suite_summary.get("rtl_failed_frames", 0)),
        "ideal_checked_beats": ideal_total.checked_beats,
        "ideal_eligible_frames": ideal_total.eligible_frames,
        "ideal_excluded_frames": ideal_total.excluded_frames,
        "ideal_avg_abs_err": ideal_total.avg_abs_err,
        "ideal_max_abs_err": ideal_total.abs_err_max,
        "ideal_avg_rel_err_pct": ideal_total.avg_rel_err_pct,
        "ideal_max_rel_err_pct": ideal_total.rel_err_max_pct,
        "ideal_avg_sum_residual": (sum(residual_values) / len(residual_values)) if residual_values else 0.0,
        "ideal_max_sum_residual": max(residual_values) if residual_values else 0.0,
    }


def suite_ideal_error_chart(case_data: list[dict[str, Any]], summary: dict[str, Any]) -> str:
    if not case_data:
        return empty_chart_svg("No ideal error data")
    names = [axis_test_label(str(case["summary"].get("testname", "케이스"))) for case in case_data]
    avg_values = [case["ideal_total"].avg_rel_err_pct for case in case_data]
    max_values = [case["ideal_total"].rel_err_max_pct for case in case_data]
    suite_avg = float(summary.get("ideal_avg_rel_err_pct", 0.0))
    suite_max = float(summary.get("ideal_max_rel_err_pct", 0.0))
    x = list(range(len(names)))
    fig, ax = plt.subplots(figsize=(7.2, 3.8))
    avg_x = [idx - 0.16 for idx in x]
    max_x = [idx + 0.16 for idx in x]
    avg_handle = draw_round_bar_series(ax, avg_x, avg_values, TOSS_BLUE, "Case avg", linewidth=10.0, zorder=3)
    max_handle = draw_round_bar_series(ax, max_x, max_values, TOSS_ORANGE, "Case max", linewidth=10.0, zorder=4)
    set_chart_title(ax, "Ideal Softmax Relative Error by Case")
    ax.set_ylabel("Relative error (%)")
    ax.set_xticks(x, names, rotation=0, ha="center")
    y_limit = max(1.0, max(max_values + [suite_avg, suite_max]) * 1.35 if max_values else 1.0)
    ax.set_ylim(0, y_limit)
    ax.grid(axis="y")
    suite_avg_line = ax.axhline(
        suite_avg,
        color=TOSS_GREEN,
        linewidth=1.8,
        linestyle=(0, (4, 3)),
        label="Overall avg",
    )
    suite_max_line = ax.axhline(
        suite_max,
        color=TOSS_RED,
        linewidth=1.8,
        linestyle=(0, (6, 3)),
        label="Overall max",
    )
    ax.annotate(
        f"avg {suite_avg:.1f}%",
        xy=(0.995, suite_avg),
        xycoords=ax.get_yaxis_transform(),
        xytext=(-2, 5),
        textcoords="offset points",
        ha="right",
        va="bottom",
        fontsize=8.0,
        color=TOSS_GREEN,
        bbox={"boxstyle": "round,pad=0.16", "fc": TOSS_WHITE, "ec": "none", "alpha": 0.92},
    )
    ax.annotate(
        f"max {suite_max:.1f}%",
        xy=(0.995, suite_max),
        xycoords=ax.get_yaxis_transform(),
        xytext=(-2, -6),
        textcoords="offset points",
        ha="right",
        va="top",
        fontsize=8.0,
        color=TOSS_RED,
        bbox={"boxstyle": "round,pad=0.16", "fc": TOSS_WHITE, "ec": "none", "alpha": 0.92},
    )
    ax.legend(
        [avg_handle, max_handle, suite_avg_line, suite_max_line],
        ["Case avg", "Case max", "Overall avg", "Overall max"],
        frameon=False,
        loc="upper center",
        bbox_to_anchor=(0.5, -0.25),
        ncol=4,
        fontsize=7.4,
        columnspacing=0.9,
        handlelength=1.7,
    )
    fig.subplots_adjust(bottom=0.32, top=0.90)
    fig.tight_layout(rect=(0, 0.09, 1, 1))
    return fig_to_data_uri(fig)


def suite_accuracy_contrast_chart(summary: dict[str, Any]) -> str:
    values = [
        float(summary.get("rtl_mismatch_rate_pct", 0.0)),
        float(summary.get("ideal_avg_rel_err_pct", 0.0)),
        float(summary.get("ideal_max_rel_err_pct", 0.0)),
    ]
    labels = ["RTL error", "Ideal avg rel error", "Ideal max rel error"]
    colors = [TOSS_GREEN, TOSS_BLUE, TOSS_ORANGE]
    fig, ax = plt.subplots(figsize=(6.8, 3.8))
    bars = ax.barh(labels, values, color=colors, height=0.52)
    set_chart_title(ax, "RTL Match vs Ideal Error")
    ax.set_xlabel("Rate (%)")
    ax.set_xlim(0, max(1.0, max(values) * 1.35 if values else 1.0))
    ax.grid(axis="x")
    for bar, value in zip(bars, values):
        ax.text(value + max(ax.get_xlim()[1] * 0.015, 0.02), bar.get_y() + bar.get_height() / 2, f"{value:.1f}%", va="center", fontsize=9)
    fig.tight_layout()
    return fig_to_data_uri(fig)


def suite_eligibility_chart(summary: dict[str, Any]) -> str:
    eligible = int(summary.get("ideal_eligible_frames", 0))
    excluded = int(summary.get("ideal_excluded_frames", 0))
    total = eligible + excluded
    if total == 0:
        return empty_chart_svg("No ideal analysis eligibility data")
    fig, ax = plt.subplots(figsize=(7.0, 3.8))
    wedges, _ = ax.pie(
        [eligible, excluded],
        labels=None,
        colors=[TOSS_BLUE, TOSS_GRAY_300],
        startangle=90,
        radius=0.68,
        center=(-0.36, 0.0),
        wedgeprops={"width": 0.23, "edgecolor": TOSS_WHITE},
    )
    set_chart_title(ax, "Ideal Analysis Eligibility")
    ax.text(-0.36, 0.03, f"{eligible}", ha="center", va="center", fontsize=18, fontweight="bold")
    ax.text(-0.36, -0.16, "Eligible\nFrames", ha="center", va="center", fontsize=8.3, color=TOSS_GRAY_500)
    ax.legend(wedges, ["Eligible", "Excluded"], frameon=False, loc="center left", bbox_to_anchor=(0.72, 0.5), fontsize=8.8, handlelength=1.2)
    ax.set(aspect="equal")
    ax.set_xlim(-1.18, 1.28)
    ax.set_ylim(-0.84, 0.84)
    fig.tight_layout(rect=(0.01, 0.02, 0.98, 0.98))
    return fig_to_data_uri(fig)


def case_avg_sum_residual(case: dict[str, Any]) -> float:
    values = [
        abs(float(metric.get("sum_residual", 0.0)))
        for metric in case["ideal_by_frame"].values()
        if metric.get("eligible", False)
    ]
    if not values:
        return 0.0
    return sum(values) / len(values)


def case_max_sum_residual(case: dict[str, Any]) -> float:
    values = [
        abs(float(metric.get("sum_residual", 0.0)))
        for metric in case["ideal_by_frame"].values()
        if metric.get("eligible", False)
    ]
    if not values:
        return 0.0
    return max(values)


def suite_sum_residual_chart(case_data: list[dict[str, Any]]) -> str:
    if not case_data:
        return empty_chart_svg("No probability sum residual data")
    names = [axis_test_label(str(case["summary"].get("testname", "케이스"))) for case in case_data]
    avg_values = [case_avg_sum_residual(case) for case in case_data]
    max_values = [case_max_sum_residual(case) for case in case_data]
    x = list(range(len(names)))
    fig, ax = plt.subplots(figsize=(6.8, 3.8))
    avg_x = [idx - 0.14 for idx in x]
    max_x = [idx + 0.14 for idx in x]
    ax.vlines(avg_x, [0.0] * len(avg_x), avg_values, color=TOSS_BLUE_DARK, linewidth=2.0, alpha=0.95)
    ax.scatter(avg_x, avg_values, color=TOSS_BLUE_DARK, s=42, label="Avg |sum(actual)-1|", zorder=3)
    ax.vlines(max_x, [0.0] * len(max_x), max_values, color=TOSS_ORANGE, linewidth=2.0, alpha=0.95)
    ax.scatter(max_x, max_values, color=TOSS_ORANGE, s=42, label="Max |sum(actual)-1|", zorder=3)
    ax.axhline(0.0, color=TOSS_GRAY_500, linewidth=1.0)
    set_chart_title(ax, "Sum Residual by Case")
    ax.set_ylabel("Absolute residual")
    ax.set_xticks(x, names, rotation=0, ha="center")
    ax.set_ylim(0, max(0.02, max(max_values) * 1.35 if max_values else 0.02))
    ax.grid(axis="y")
    ax.legend(
        frameon=False,
        loc="upper center",
        bbox_to_anchor=(0.5, -0.18),
        ncol=2,
        fontsize=8.0,
        columnspacing=1.2,
        handlelength=1.8,
    )
    fig.subplots_adjust(bottom=0.26, top=0.90)
    fig.tight_layout(rect=(0, 0.06, 1, 1))
    return fig_to_data_uri(fig)


def suite_scenario_rows(case_data: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for case in case_data:
        case_name = str(case["summary"].get("testname", "Unclassified"))
        for row in case["scenario_cov"]:
            scenario_name = str(row.get("name", ""))
            if not scenario_name:
                continue
            rows.append(
                {
                    "case_name": case_name,
                    "scenario_name": scenario_name,
                    "coverage_pct": float(row.get("coverage_pct", 0.0)),
                    "checked_beats": int(row.get("checked_beats", 0)),
                    "frame_samples": int(row.get("frame_samples", 0)),
                    "reset_samples": int(row.get("reset_samples", 0)),
                }
            )
    return rows


def suite_scenario_coverage_chart(case_data: list[dict[str, Any]]) -> str:
    rows = suite_scenario_rows(case_data)
    if not rows:
        return empty_chart_svg("No suite scenario coverage data")
    sample = sorted(rows, key=lambda row: (row["coverage_pct"], row["checked_beats"], row["scenario_name"]))[:12]
    labels = [
        short_label(f"{row['case_name']}:{row['scenario_name']}", 28)
        for row in sample
    ]
    values = [row["coverage_pct"] for row in sample]
    fig, ax = plt.subplots(figsize=(7.1, 4.6))
    bars = ax.barh(range(len(sample)), values, color=TOSS_BLUE, height=0.38)
    set_chart_title(ax, "Lowest Scenario Coverage in Regression")
    ax.set_xlabel("Coverage (%)")
    ax.set_yticks(range(len(sample)), labels)
    ax.invert_yaxis()
    ax.set_xlim(0, max(10.0, max(values) * 1.20 if values else 10.0))
    ax.grid(axis="x")
    for bar, value in zip(bars, values):
        ax.text(
            value + max(ax.get_xlim()[1] * 0.015, 0.08),
            bar.get_y() + bar.get_height() / 2,
            f"{value:.1f}%",
            va="center",
            fontsize=8.5,
        )
    fig.subplots_adjust(left=0.34, right=0.97, top=0.88, bottom=0.12)
    return fig_to_data_uri(fig)


def scenario_point_keys(row: dict[str, Any]) -> list[str]:
    return [token for token in str(row.get("point_keys_pipe", "")).split("|") if token]


def case_scenario_cov_point_rows(case: dict[str, Any]) -> list[dict[str, Any]]:
    point_rows = {str(row.get("name", "")): row for row in case.get("scenario_cov_points", [])}
    scenario_names = [str(row.get("name", "")) for row in case.get("scenario_cov", []) if str(row.get("name", ""))]
    if not scenario_names:
        scenario_names = sorted(point_rows.keys())

    rows: list[dict[str, Any]] = []
    for scenario_name in scenario_names:
        point_row = point_rows.get(scenario_name, {})
        point_key_set = set(scenario_point_keys(point_row))
        groups = []
        for group in COVERAGE_POINT_GROUPS:
            group_keys = sorted(point_key for point_key in point_key_set if point_key.startswith(group["prefix"]))
            hit_count = len(group_keys)
            total_count = int(group["total"])
            groups.append(
                {
                    "label": str(group["label"]),
                    "prefix": str(group["prefix"]),
                    "keys": group_keys,
                    "hits": hit_count,
                    "total": total_count,
                    "ratio": (float(hit_count) / float(total_count)) if total_count else 0.0,
                }
            )
        rows.append(
            {
                "name": scenario_name,
                "point_count": int(point_row.get("point_count", len(point_key_set))),
                "groups": groups,
            }
        )
    return rows


def case_scenario_cov_point_heatmap(case: dict[str, Any]) -> str:
    rows = case_scenario_cov_point_rows(case)
    if not rows:
        return empty_chart_svg("No scenario coverage point data")

    matrix = [[float(group["ratio"]) for group in row["groups"]] for row in rows]
    labels = [short_label(str(row["name"]), 22) for row in rows]
    annotation = [
        [f"{int(group['hits'])}/{int(group['total'])}" for group in row["groups"]]
        for row in rows
    ]
    x_labels = [str(group["label"]) for group in COVERAGE_POINT_GROUPS]
    fig_w = max(10.8, len(x_labels) * 0.70)
    fig_h = max(4.0, len(rows) * 0.40 + 2.1)
    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    coverage_cmap = mcolors.LinearSegmentedColormap.from_list(
        "coverage_traffic",
        [TOSS_RED, TOSS_YELLOW, TOSS_GREEN],
    )
    heatmap = ax.imshow(matrix, cmap=coverage_cmap, aspect="auto", vmin=0.0, vmax=1.0)
    set_chart_title(ax, "Coverage Point Heatmap by Scenario")
    ax.set_xlabel("Coverage point group")
    ax.set_ylabel("Scenario")
    ax.set_xticks(range(len(x_labels)), x_labels, rotation=28, ha="right")
    ax.set_yticks(range(len(labels)), labels)
    ax.set_xticks([idx - 0.5 for idx in range(1, len(x_labels))], minor=True)
    ax.set_yticks([idx - 0.5 for idx in range(1, len(labels))], minor=True)
    ax.grid(which="minor", color=TOSS_WHITE, linewidth=1.0)
    ax.tick_params(which="minor", bottom=False, left=False)

    font_size = 8.0 if len(rows) <= 10 else 7.0
    for row_idx, row_values in enumerate(matrix):
        for col_idx, value in enumerate(row_values):
            ax.text(
                col_idx,
                row_idx,
                annotation[row_idx][col_idx],
                ha="center",
                va="center",
                fontsize=font_size,
                color=TOSS_WHITE if value <= 0.16 or value >= 0.74 else TOSS_GRAY_900,
                fontweight=700 if value >= 0.34 else 600,
            )

    color_bar = fig.colorbar(heatmap, ax=ax, fraction=0.028, pad=0.02)
    color_bar.set_label("Hit ratio")
    color_bar.set_ticks([0.0, 0.5, 1.0])
    color_bar.set_ticklabels(["0%", "50%", "100%"])
    fig.tight_layout()
    return fig_to_data_uri(fig)


def build_cov_point_chip_list(point_keys: list[str]) -> str:
    if not point_keys:
        return "<span class='coverage-chip muted'>-</span>"
    return "".join(
        f"<code class='coverage-chip'>{html.escape(point_key)}</code>"
        for point_key in point_keys
    )


def split_cov_point_key(point_key: str) -> tuple[str, str]:
    if ":" not in point_key:
        return point_key, "-"
    point_name, bin_name = point_key.split(":", 1)
    return point_name, bin_name


def build_cov_point_item_rows(point_keys: list[str]) -> str:
    if not point_keys:
        return (
            "<div class='coverage-key-row muted'>"
            "<code class='coverage-key-point'>-</code>"
            "<code class='coverage-key-bin'>bin=-</code>"
            "</div>"
        )
    rows = []
    for point_key in point_keys:
        point_name, bin_name = split_cov_point_key(point_key)
        rows.append(
            "<div class='coverage-key-row'>"
            f"<code class='coverage-key-point'>{html.escape(point_name)}</code>"
            f"<code class='coverage-key-bin'>bin={html.escape(bin_name)}</code>"
            "</div>"
        )
    return "".join(rows)


def build_case_cov_point_drilldown(case: dict[str, Any]) -> str:
    rows = case_scenario_cov_point_rows(case)
    if not rows:
        return ""

    cards = []
    for row in rows:
        family_rows = []
        active_groups = [group for group in row["groups"] if int(group["hits"]) > 0]
        for group in active_groups:
            family_rows.append(
                "<div class='coverage-family-row'>"
                "<div class='coverage-family-head'>"
                f"<span class='coverage-family-name'>{html.escape(str(group['label']))}</span>"
                f"<span class='coverage-family-count'>{int(group['hits'])}/{int(group['total'])}</span>"
                "</div>"
                f"<div class='coverage-key-list'>{build_cov_point_item_rows(list(group['keys']))}</div>"
                "</div>"
            )

        cards.append(
            "<details class='coverage-point-card'>"
            "<summary class='coverage-point-summary'>"
            f"<span class='coverage-point-name'>{html.escape(str(row['name']))}</span>"
            "<span class='coverage-point-meta'>"
            f"<span class='coverage-point-badge'>{int(row['point_count'])} hit</span>"
            f"<span class='coverage-point-badge'>{len(active_groups)} groups</span>"
            "</span>"
            "</summary>"
            "<div class='coverage-point-body'>"
            + "".join(family_rows)
            + "</div>"
            "</details>"
        )

    return (
        "<div class='section-block coverage-detail-section'>"
        "<h3>Coverage Point Detail</h3>"
        "<div class='coverage-point-grid'>"
        + "".join(cards)
        + "</div></div>"
    )


def case_scenario_chart(case: dict[str, Any]) -> str:
    names = [str(row.get("name", "")) for row in case["scenario_cov"]]
    if not names:
        return empty_chart_svg("No scenario coverage samples")
    cov_values = [float(row.get("coverage_pct", 0.0)) for row in case["scenario_cov"]]

    x = list(range(len(names)))
    fig, ax1 = plt.subplots(figsize=(8.4, 4.0))
    draw_round_bar_series(
        ax1,
        x,
        cov_values,
        TOSS_BLUE,
        "Coverage",
        linewidth=9.0 if len(names) == 1 else 8.2,
        zorder=3,
    )
    set_chart_title(ax1, "Scenario Coverage by Scenario")
    ax1.set_ylabel("Coverage (%)")
    ax1.set_xticks(x, [short_label(name, 16) for name in names], rotation=18, ha="right")
    ax1.set_ylim(0, max(25.0, max(cov_values) * 1.35))
    if len(names) == 1:
        ax1.set_xlim(-0.55, 0.55)
    else:
        ax1.margins(x=0.08)
    ax1.grid(axis="y")
    fig.tight_layout()
    return fig_to_data_uri(fig)


def case_error_combo_chart(case: dict[str, Any]) -> str:
    eligible_frames = [
        (frame_id, metric)
        for frame_id, metric in sorted(case["ideal_by_frame"].items())
        if metric.get("eligible", False)
    ]
    if not eligible_frames:
        return empty_chart_svg("No frame error data")
    frame_ids = [frame_id for frame_id, _ in eligible_frames]
    avg_rel = [float(metric.get("avg_rel_err_pct", 0.0)) for _, metric in eligible_frames]
    max_rel = [float(metric.get("max_rel_err_pct", 0.0)) for _, metric in eligible_frames]
    x = list(range(len(frame_ids)))
    fig, ax1 = plt.subplots(figsize=(8.4, 4.0))
    avg_x = [value - 0.14 for value in x]
    max_x = [value + 0.14 for value in x]
    avg_handle = draw_round_bar_series(
        ax1, avg_x, avg_rel, TOSS_BLUE_DARK, "Avg rel error", linewidth=8.6, zorder=3
    )
    max_handle = draw_round_bar_series(
        ax1, max_x, max_rel, TOSS_ORANGE, "Max rel error", linewidth=8.6, zorder=4
    )
    set_chart_title(ax1, "Ideal Relative Error by Frame")
    ax1.set_ylabel("Relative error (%)")
    ax1.set_xlabel("Frame ID")
    ax1.grid(axis="y")
    ax1.set_ylim(0, max(1.0, max(max_rel) * 1.35 if max_rel else 1.0))
    if len(frame_ids) <= 24:
        ax1.set_xticks(x, [str(frame_id) for frame_id in frame_ids])
    else:
        step = max(1, len(frame_ids) // 12)
        tick_idx = list(range(0, len(frame_ids), step))
        if tick_idx[-1] != len(frame_ids) - 1:
            tick_idx.append(len(frame_ids) - 1)
        ax1.set_xticks(tick_idx, [str(frame_ids[idx]) for idx in tick_idx])
    ax1.legend([avg_handle, max_handle], ["Avg rel error", "Max rel error"], frameon=False, loc="upper left")
    fig.tight_layout()
    return fig_to_data_uri(fig)


def case_sum_residual_chart(case: dict[str, Any]) -> str:
    eligible_frames = [
        (frame_id, metric)
        for frame_id, metric in sorted(case["ideal_by_frame"].items())
        if metric.get("eligible", False)
    ]
    if not eligible_frames:
        return empty_chart_svg("No probability sum residual data")
    frame_ids = [frame_id for frame_id, _ in eligible_frames]
    residual_values = [float(metric.get("sum_residual", 0.0)) for _, metric in eligible_frames]
    colors = [TOSS_BLUE if value >= 0.0 else TOSS_RED for value in residual_values]
    x = list(range(len(frame_ids)))
    fig, ax = plt.subplots(figsize=(8.4, 3.6))
    ax.vlines(x, [0.0] * len(x), residual_values, colors=colors, linewidth=2.3, alpha=0.95)
    ax.scatter(x, residual_values, color=colors, s=46, zorder=3)
    peak = max(abs(value) for value in residual_values) if residual_values else 1.0e-6
    margin = max(peak * 0.35, 1.0e-6)
    ax.axhline(0.0, color=TOSS_GRAY_500, linewidth=1.0)
    set_chart_title(ax, "Sum Residual by Frame")
    ax.set_xlabel("Frame ID")
    ax.set_ylabel("sum(actual) - 1")
    ax.set_ylim(
        min(min(residual_values) - margin, -margin),
        max(max(residual_values) + margin, margin),
    )
    ax.margins(x=0.06)
    ax.grid(axis="y")
    if len(frame_ids) <= 24:
        ax.set_xticks(x, [str(frame_id) for frame_id in frame_ids])
    else:
        step = max(1, len(frame_ids) // 12)
        tick_idx = list(range(0, len(frame_ids), step))
        if tick_idx[-1] != len(frame_ids) - 1:
            tick_idx.append(len(frame_ids) - 1)
        ax.set_xticks(tick_idx, [str(frame_ids[idx]) for idx in tick_idx])
    if len(frame_ids) <= 32:
        for idx, value in enumerate(residual_values):
            offset_y = 4 if value >= 0.0 else -6
            va = "bottom" if value >= 0.0 else "top"
            ax.annotate(
                compact_chart_value(value),
                (x[idx], value),
                xytext=(0, offset_y),
                textcoords="offset points",
                ha="center",
                va=va,
                fontsize=8,
            )
    else:
        top_indices = sorted(range(len(residual_values)), key=lambda idx: abs(residual_values[idx]), reverse=True)[:4]
        for idx in top_indices:
            value = residual_values[idx]
            offset_y = 4 if value >= 0.0 else -6
            va = "bottom" if value >= 0.0 else "top"
            ax.annotate(
                f"#{frame_ids[idx]} {compact_chart_value(value)}",
                (x[idx], value),
                xytext=(0, offset_y),
                textcoords="offset points",
                ha="center",
                va=va,
                fontsize=8,
            )
    fig.subplots_adjust(left=0.10, right=0.98, top=0.88, bottom=0.22)
    return fig_to_data_uri(fig)


def case_rel_error_distribution_chart(case: dict[str, Any]) -> str:
    rel_values = [
        float(metric.get("max_rel_err_pct", 0.0))
        for metric in case["ideal_by_frame"].values()
        if metric.get("eligible", False)
    ]
    if not rel_values:
        return empty_chart_svg("No ideal relative error distribution")
    fig, ax = plt.subplots(figsize=(8.4, 4.0))
    bins = min(8, max(3, len(rel_values)))
    ax.hist(rel_values, bins=bins, color=TOSS_BLUE, alpha=0.86, edgecolor=TOSS_WHITE)
    ax.axvline(sum(rel_values) / len(rel_values), color=TOSS_ORANGE, linewidth=2.0, linestyle="--", label="Mean frame max rel error")
    set_chart_title(ax, "Frame Max Relative Error Distribution")
    ax.set_xlabel("Maximum relative error (%)")
    ax.set_ylabel("Frame count")
    ax.grid(axis="y")
    ax.legend(frameon=False, loc="upper right")
    fig.tight_layout()
    return fig_to_data_uri(fig)


def case_worst_frame_chart(case: dict[str, Any]) -> str:
    if not case["ideal_by_frame"]:
        return empty_chart_svg("No frame overlay data")
    worst_frame_id = None
    worst_metric = -1.0
    for frame_id, metric in case["ideal_by_frame"].items():
        if metric.get("eligible", False) and metric.get("max_rel_err_pct", 0.0) > worst_metric:
            worst_metric = metric.get("max_rel_err_pct", 0.0)
            worst_frame_id = frame_id
    if worst_frame_id is None:
        return empty_chart_svg("No eligible frame for ideal comparison")

    actual_map = {int(row["frame_id"]): row for row in case["actual"]}
    expected_map = {int(row["frame_id"]): row for row in case["expected"]}
    actual_row = actual_map.get(worst_frame_id, {})
    expected_row = expected_map.get(worst_frame_id, {})
    metric = case["ideal_by_frame"][worst_frame_id]

    actual_values = metric.get("actual_values", [])
    ideal_values = metric.get("ideal_values", [])
    rtl_values = csv_hex_to_float_list(str(expected_row.get("output_hex_csv", "")))
    compare_len = min(len(actual_values), len(ideal_values))
    if compare_len == 0:
        return empty_chart_svg("No overlap for the worst-case frame")

    sample_indices = downsample_indices(compare_len, 240)
    x = [idx for idx in sample_indices]
    actual_plot = [actual_values[idx] for idx in sample_indices]
    ideal_plot = [ideal_values[idx] for idx in sample_indices]
    rtl_plot = [rtl_values[idx] for idx in sample_indices] if rtl_values else []
    fig, ax = plt.subplots(figsize=(8.4, 4.0))
    plot_len = len(sample_indices)
    if plot_len <= 48:
        marker_every = 1
        marker_size = 4.8
    elif plot_len <= 192:
        marker_every = max(1, plot_len // 18)
        marker_size = 3.8
    else:
        marker_every = max(1, plot_len // 28)
        marker_size = 2.8

    common_line = {
        "markevery": marker_every,
        "markersize": marker_size,
        "solid_capstyle": "round",
        "solid_joinstyle": "round",
    }
    ax.plot(
        x,
        actual_plot,
        color=TOSS_BLUE,
        linewidth=2.2,
        marker="o",
        label="Actual DUT output",
        **common_line,
    )
    if rtl_plot:
        ax.plot(
            x,
            rtl_plot,
            color=TOSS_GREEN,
            linewidth=1.8,
            linestyle="--",
            marker="s",
            label="RTL golden",
            **common_line,
        )
    ax.plot(
        x,
        ideal_plot,
        color=TOSS_ORANGE,
        linewidth=2.0,
        marker="D",
        label="Ideal softmax",
        **common_line,
    )
    set_chart_title(ax, f"Worst-Case Frame Overlay (Frame {worst_frame_id})")
    ax.set_xlabel("Sample index")
    ax.set_ylabel("Probability")
    ax.grid(axis="y")
    ax.margins(x=0.02)
    ax.legend(frameon=False, loc="best")
    fig.tight_layout()
    return fig_to_data_uri(fig)


def chart_card(spec: ChartSpec) -> str:
    class_suffix = f" {spec.class_name}" if spec.class_name else ""
    description_html = (
        f"<p>{render_inline_markup(spec.description)}</p>" if str(spec.description).strip() else ""
    )
    method_html = (
        f"<pre class='brief-code'>{html.escape(str(spec.evidence).strip())}</pre>"
        if str(spec.evidence).strip()
        else "<pre class='brief-code'>-</pre>"
    )
    return (
        f"<div class='chart-card{class_suffix}'>"
        f"<div class='chart-head'><h3>{html.escape(spec.title)}</h3>{description_html}</div>"
        f"<img alt='{html.escape(spec.title)}' src='{spec.uri}' />"
        "<div class='chart-brief'>"
        "<div class='brief-item'>"
        "<div class='brief-label'>Meaning</div>"
        f"<p>{render_inline_markup(spec.meaning)}</p>"
        "</div>"
        "<div class='brief-item'>"
        "<div class='brief-label'>Method</div>"
        f"{method_html}"
        "</div>"
        "<div class='brief-item'>"
        "<div class='brief-label'>Why</div>"
        f"<p>{render_inline_markup(spec.why_used)}</p>"
        "</div>"
        "</div>"
        "</div>"
    )


def build_case_jump_chips(case_data: list[dict[str, Any]]) -> str:
    if not case_data:
        return "<span class='jump-chip muted'>No Cases</span>"
    chips = []
    for case in case_data:
        testname = str(case["summary"].get("testname", "Unclassified"))
        chips.append(
            f"<a class='jump-chip' href='#{sanitize_name(testname)}'>{html.escape(testname)}</a>"
        )
    return "".join(chips)


def build_suite_cards(summary: dict[str, Any], case_data: list[dict[str, Any]]) -> str:
    highest_ideal = max(case_data, key=lambda case: case["ideal_total"].avg_rel_err_pct, default=None)
    highest_residual = max(case_data, key=case_avg_sum_residual, default=None)
    coverage = float(summary.get("suite_coverage_pct", 0.0))
    rtl_mismatch = float(summary.get("rtl_mismatch_rate_pct", 0.0))
    rtl_match = max(0.0, 100.0 - rtl_mismatch)
    avg_rel = float(summary.get("ideal_avg_rel_err_pct", 0.0))
    max_rel = float(summary.get("ideal_max_rel_err_pct", 0.0))
    avg_residual = float(summary.get("ideal_avg_sum_residual", 0.0))
    max_residual = float(summary.get("ideal_max_sum_residual", 0.0))
    eligible = int(summary.get("ideal_eligible_frames", 0))
    excluded = int(summary.get("ideal_excluded_frames", 0))
    total_scope = max(eligible + excluded, 1)
    fail_ratio = percent_fill(int(summary.get("failed_case_count", 0)), max(int(summary.get("total_cases", 0)), 1))
    rel_ceiling = max(max_rel, 3.0, 1.0)
    residual_ceiling = max(max_residual, 0.02, 1.0e-6)

    cards = [
        (
            "Run Overview",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Status</span><strong class='metric-pair-value'>{status_badge(str(summary['suite_status']))}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Coverage</span><strong class='metric-pair-value'>{pct_text(coverage)}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Beats</span><strong class='metric-pair-value'>{summary['rtl_checked_beats']}</strong></div>"
            "</div>",
            [("filled blue", percent_fill(coverage), f"Coverage {pct_text(coverage)}")],
            [],
        ),
        (
            "Case Status",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Total</span><strong class='metric-pair-value'>{summary['total_cases']}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Failed</span><strong class='metric-pair-value'>{summary['failed_case_count']}</strong></div>"
            "</div>",
            [("filled red", fail_ratio, f"Fail Ratio {pct_text((float(summary.get('failed_case_count', 0)) / max(int(summary.get('total_cases', 0)), 1)) * 100.0)}")],
            [],
        ),
        (
            "Errors / RTL Error",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Errors</span><strong class='metric-pair-value'>{summary['total_errors']}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>RTL Error</span><strong class='metric-pair-value'>{pct_text(rtl_mismatch)}</strong></div>"
            "</div>",
            [("filled green", percent_fill(rtl_match), f"Match {pct_text(rtl_match)}")],
            [],
        ),
        (
            "Ideal Avg Error",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Abs</span><strong class='metric-pair-value'>{sci_text(summary['ideal_avg_abs_err'])}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Rel</span><strong class='metric-pair-value'>{pct_text(avg_rel)}</strong></div>"
            "</div>",
            [("filled blue", percent_fill(avg_rel, rel_ceiling), f"Avg {pct_text(avg_rel)}")],
            [f"Peak {compact_testname(str(highest_ideal['summary'].get('testname', '-')))}" if highest_ideal else "Peak -"],
        ),
        (
            "Ideal Max Error",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Abs</span><strong class='metric-pair-value'>{sci_text(summary['ideal_max_abs_err'])}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Rel</span><strong class='metric-pair-value'>{pct_text(max_rel)}</strong></div>"
            "</div>",
            [("filled orange", percent_fill(max_rel, rel_ceiling), f"Max {pct_text(max_rel)}")],
            [],
        ),
        (
            "Sum Residual",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Avg</span><strong class='metric-pair-value'>{sci_text(avg_residual)}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Max</span><strong class='metric-pair-value'>{sci_text(max_residual)}</strong></div>"
            "</div>",
            [
                ("filled blue", percent_fill(avg_residual, residual_ceiling), f"Avg {compact_chart_value(avg_residual)}"),
                ("filled red", percent_fill(max_residual, residual_ceiling), f"Max {compact_chart_value(max_residual)}"),
            ],
            [f"Peak {compact_testname(str(highest_residual['summary'].get('testname', '-')))}" if highest_residual else "Peak -"],
        ),
        (
            "Ideal Frame Scope",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Eligible</span><strong class='metric-pair-value'>{eligible}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Excluded</span><strong class='metric-pair-value'>{excluded}</strong></div>"
            "</div>",
            [
                ("filled blue", percent_fill(eligible, total_scope), f"Eligible {eligible} / Excluded {excluded}"),
            ],
            [f"Total {total_scope} frames"],
        ),
    ]

    html_cards = []
    for label, value, _meters, footers in cards:
        footer_html = "".join(f"<span>{html.escape(text)}</span>" for text in footers)
        footer_block = f"<div class='reading-footer metric-footer'>{footer_html}</div>" if footers else ""
        html_cards.append(
            "<div class='metric-card'>"
            f"<div class='metric-label'>{label}</div>"
            f"<div class='metric-value-shell'><div class='metric-value'>{value}</div></div>"
            f"{footer_block}"
            "</div>"
        )
    return "".join(html_cards)


def build_suite_reading_cards(summary: dict[str, Any], case_data: list[dict[str, Any]]) -> str:
    highest_ideal = max(case_data, key=lambda case: case["ideal_total"].avg_rel_err_pct, default=None)
    highest_residual = max(case_data, key=case_avg_sum_residual, default=None)
    eligible = int(summary.get("ideal_eligible_frames", 0))
    excluded = int(summary.get("ideal_excluded_frames", 0))
    total_scope = max(eligible + excluded, 1)
    coverage = float(summary.get("suite_coverage_pct", 0.0))
    rtl_mismatch = float(summary.get("rtl_mismatch_rate_pct", 0.0))
    rtl_match = max(0.0, 100.0 - rtl_mismatch)
    avg_rel = float(summary.get("ideal_avg_rel_err_pct", 0.0))
    max_rel = float(summary.get("ideal_max_rel_err_pct", 0.0))
    avg_residual = float(summary.get("ideal_avg_sum_residual", 0.0))
    max_residual = float(summary.get("ideal_max_sum_residual", 0.0))
    residual_ceiling = max(max_residual, 0.02, 1.0e-6)
    rel_ceiling = max(max_rel, 3.0, 1.0)

    cards = [
        (
            "통합 커버리지",
            pct_text(coverage),
            "회귀 전체 커버리지입니다.",
            [
                ("filled blue", percent_fill(coverage), f"커버리지 {pct_text(coverage)}"),
            ],
            [f"케이스 {summary.get('total_cases', 0)}개", f"실패 {summary.get('failed_case_count', 0)}개"],
        ),
        (
            "RTL 정합",
            pct_text(rtl_match),
            "RTL 기준 exact compare 결과입니다.",
            [
                ("filled green", percent_fill(rtl_match), f"일치 {pct_text(rtl_match)}"),
            ],
            [f"불일치 {pct_text(rtl_mismatch)}", f"비교 {summary.get('rtl_checked_beats', 0)} beat"],
        ),
        (
            "ideal 근사 오차",
            pct_text(avg_rel),
            "평균·최대 근사 오차 기준입니다.",
            [
                ("filled blue", percent_fill(avg_rel, rel_ceiling), f"평균 {pct_text(avg_rel)}"),
                ("filled orange", percent_fill(max_rel, rel_ceiling), f"최대 {pct_text(max_rel)}"),
            ],
            [f"최대 케이스 {highest_ideal['summary'].get('testname', '-')}" if highest_ideal else "최대 케이스 -", f"최댓값 {pct_text(max_rel)}"],
        ),
        (
            "확률합 안정성",
            sci_text(avg_residual),
            "출력 합이 1.0에 얼마나 가까운지 봅니다.",
            [
                ("filled blue", percent_fill(avg_residual, residual_ceiling), f"평균 {compact_chart_value(avg_residual)}"),
                ("filled red", percent_fill(max_residual, residual_ceiling), f"최대 {compact_chart_value(max_residual)}"),
            ],
            [f"최대 케이스 {highest_residual['summary'].get('testname', '-')}" if highest_residual else "최대 케이스 -", f"최댓값 {compact_chart_value(max_residual)}"],
        ),
        (
            "ideal 분석 모집단",
            f"{eligible}/{total_scope}",
            "ideal 계산에 포함된 프레임 비율입니다.",
            [
                ("filled blue", percent_fill(eligible, total_scope), f"대상 {eligible}"),
                ("filled gray", percent_fill(excluded, total_scope), f"제외 {excluded}"),
            ],
            [f"대상 {eligible} frame", f"제외 {excluded} frame"],
        ),
    ]

    html_cards = []
    for title, value, copy, meters, footers in cards:
        meter_html = "".join(
            "<div class='reading-meter-row'>"
            f"<div class='reading-meter-track'><span class='{tone}' style='width:{width:.1f}%'></span></div>"
            f"<div class='reading-meter-label'>{html.escape(label)}</div>"
            "</div>"
            for tone, width, label in meters
        )
        footer_html = "".join(f"<span>{html.escape(text)}</span>" for text in footers)
        html_cards.append(
            "<div class='reading-card'>"
            f"<div class='reading-title'>{html.escape(title)}</div>"
            f"<div class='reading-kpi'>{html.escape(value)}</div>"
            "<div class='reading-section-block'>"
            "<div class='reading-subhead'>요약</div>"
            f"<p class='reading-copy'>{html.escape(copy)}</p>"
            "</div>"
            "<div class='reading-section-block'>"
            "<div class='reading-subhead'>지표</div>"
            f"<div class='reading-meter-group'>{meter_html}</div>"
            "</div>"
            "<div class='reading-section-block'>"
            "<div class='reading-subhead'>참고</div>"
            f"<div class='reading-footer'>{footer_html}</div>"
            "</div>"
            "</div>"
        )
    return "".join(html_cards)


def build_suite_notes(summary: dict[str, Any], case_data: list[dict[str, Any]]) -> str:
    highest_ideal = max(case_data, key=lambda case: case["ideal_total"].avg_rel_err_pct, default=None)
    lines = [
        f"여기서 보이는 통합 커버리지는 merge_instances=1 이 설정된 covergroup에 대해 get_coverage() 를 사용해 계산한 회귀 전체 결과이며 현재 값은 {pct_text(summary['suite_coverage_pct'])} 입니다.",
        "즉 메인 통합 커버리지는 가장 높은 케이스 커버리지가 아니라, 한 시뮬레이션 안에서 실행된 여러 케이스와 시나리오 인스턴스가 채운 coverage bin을 합친 결과입니다.",
        "RTL 불일치 지표는 DUT와 RTL 충실 Python 모델 사이의 일치도를 의미하며, 근사 파이프라인 구현 충실도를 보여줍니다.",
        "ideal 근사 지표는 실제 DUT 출력과 수학적으로 이상적인 배정밀도 softmax를 비교한 값이며, 진짜 근사 오차를 정량화합니다.",
        f"현재 통합 ideal 요약은 avg_abs_err={sci_text(summary['ideal_avg_abs_err'])}, max_abs_err={sci_text(summary['ideal_max_abs_err'])}, avg_rel_err={pct_text(summary['ideal_avg_rel_err_pct'])}, max_rel_err={pct_text(summary['ideal_max_rel_err_pct'])} 입니다.",
        f"확률합 안정성은 avg|sum(actual)-1|={sci_text(summary['ideal_avg_sum_residual'])}, max|sum(actual)-1|={sci_text(summary['ideal_max_sum_residual'])} 로 별도 표시했습니다.",
    ]
    if highest_ideal is not None:
        lines.append(
            f"ideal 평균 상대오차가 가장 큰 케이스는 {highest_ideal['summary'].get('testname', '미분류')}={pct_text(highest_ideal['ideal_total'].avg_rel_err_pct)} 입니다."
        )
    if int(summary.get("failed_case_count", 0)) != 0:
        lines.append(
            f"이번 실행의 실패 케이스는 {summary.get('failed_case_names_csv', '-')} 이고, 총 에러 수는 {summary.get('failed_error_total', 0)} 입니다."
        )
    return "".join(f"<li>{html.escape(line)}</li>" for line in lines)


def build_suite_scenario_summary_rows(case_data: list[dict[str, Any]], limit: int = 12) -> str:
    rows = suite_scenario_rows(case_data)
    if not rows:
        return "<tr><td colspan='6'>요약할 시나리오 coverage 데이터가 없습니다.</td></tr>"
    sample = sorted(rows, key=lambda row: (row["coverage_pct"], row["checked_beats"], row["scenario_name"]))[:limit]
    return "".join(
        "<tr>"
        f"<td>{html.escape(row['case_name'])}</td>"
        f"<td>{html.escape(row['scenario_name'])}</td>"
        f"<td>{pct_text(row['coverage_pct'])}</td>"
        f"<td>{row['checked_beats']}</td>"
        f"<td>{row['frame_samples']}</td>"
        f"<td>{row['reset_samples']}</td>"
        "</tr>"
        for row in sample
    )


def build_case_overview_rows(case_data: list[dict[str, Any]]) -> str:
    rows = []
    for case in case_data:
        summary = case["summary"]
        ideal = case["ideal_total"]
        rows.append(
            "<tr>"
            f"<td>{summary.get('case_index', '-')}</td>"
            f"<td>{html.escape(str(summary.get('testname', 'Unclassified')))}</td>"
            f"<td>{status_badge(str(summary.get('status', 'UNKNOWN')))}</td>"
            f"<td>{pct_text(summary.get('case_coverage_pct', 0.0))}</td>"
            f"<td>{summary.get('checked_beats', 0)}</td>"
            f"<td>{summary.get('total_errors', 0)}</td>"
            f"<td>{pct_text(summary.get('golden_mismatch_rate_pct', 0.0))}</td>"
            f"<td>{sci_text(ideal.avg_abs_err)}</td>"
            f"<td>{sci_text(ideal.abs_err_max)}</td>"
            f"<td>{pct_text(ideal.avg_rel_err_pct)}</td>"
            f"<td>{pct_text(ideal.rel_err_max_pct)}</td>"
            "</tr>"
        )
    return "".join(rows)


def build_case_cards(case: dict[str, Any]) -> str:
    summary = case["summary"]
    ideal = case["ideal_total"]
    avg_residual = abs(case_avg_sum_residual(case))
    max_residual = abs(case_max_sum_residual(case))
    cards = [
        (
            "Run Overview",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Status</span><strong class='metric-pair-value'>{status_badge(str(summary.get('status', 'UNKNOWN')))}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Coverage</span><strong class='metric-pair-value'>{pct_text(summary.get('case_coverage_pct', 0.0))}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Beats</span><strong class='metric-pair-value'>{summary.get('checked_beats', 0)}</strong></div>"
            "</div>",
        ),
        ("Errors / Warnings", f"{summary.get('total_errors', 0)} / {summary.get('warnings', 0)}"),
        (
            "Ideal Avg Error",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Abs</span><strong class='metric-pair-value'>{sci_text(ideal.avg_abs_err)}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Rel</span><strong class='metric-pair-value'>{pct_text(ideal.avg_rel_err_pct)}</strong></div>"
            "</div>",
        ),
        (
            "Ideal Max Error",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Abs</span><strong class='metric-pair-value'>{sci_text(ideal.abs_err_max)}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Rel</span><strong class='metric-pair-value'>{pct_text(ideal.rel_err_max_pct)}</strong></div>"
            "</div>",
        ),
        (
            "Sum Residual",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Avg</span><strong class='metric-pair-value'>{sci_text(avg_residual)}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Max</span><strong class='metric-pair-value'>{sci_text(max_residual)}</strong></div>"
            "</div>",
        ),
        (
            "Ideal Frame Scope",
            "<div class='metric-pair'>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Eligible</span><strong class='metric-pair-value'>{ideal.eligible_frames}</strong></div>"
            f"<div class='metric-pair-line'><span class='metric-pair-key'>Excluded</span><strong class='metric-pair-value'>{ideal.excluded_frames}</strong></div>"
            "</div>",
        ),
    ]
    return "".join(
        f'<div class="metric-card"><div class="metric-label">{label}</div><div class="metric-value">{value}</div></div>'
        for label, value in cards
    )


def build_case_insight_cards(case: dict[str, Any]) -> str:
    summary = case["summary"]
    ideal = case["ideal_total"]
    scenario_rows = case["scenario_cov"]
    worst_scenario = None
    if case["ideal_by_scenario"]:
        worst_scenario = max(case["ideal_by_scenario"].items(), key=lambda item: item[1].avg_rel_err_pct)
    worst_frame = None
    eligible_frames = [
        (frame_id, metric)
        for frame_id, metric in case["ideal_by_frame"].items()
        if metric.get("eligible", False)
    ]
    if eligible_frames:
        worst_frame = max(eligible_frames, key=lambda item: float(item[1].get("max_rel_err_pct", 0.0)))
    rtl_mismatch = float(summary.get("golden_mismatch_rate_pct", 0.0))
    rtl_match = max(0.0, 100.0 - rtl_mismatch)
    avg_rel = float(ideal.avg_rel_err_pct)
    max_rel = float(ideal.rel_err_max_pct)
    avg_residual = abs(case_avg_sum_residual(case))
    max_residual = abs(case_max_sum_residual(case))
    residual_ceiling = max(max_residual, 0.02, 1.0e-6)
    rel_ceiling = max(max_rel, 3.0, 1.0)
    eligible = int(ideal.eligible_frames)
    excluded = int(ideal.excluded_frames)
    total_scope = max(eligible + excluded, 1)

    cards = [
        (
            "Coverage Scope",
            pct_text(float(summary.get("case_coverage_pct", 0.0))),
            "이 case가 coverage model에서 얼마나 넓게 hit됐는지 보여줍니다.",
            [("filled blue", percent_fill(float(summary.get("case_coverage_pct", 0.0))), f"coverage {pct_text(summary.get('case_coverage_pct', 0.0))}")],
            [f"scenarios {len(scenario_rows)}", f"checked {summary.get('checked_beats', 0)} beats"],
        ),
        (
            "RTL Match",
            pct_text(rtl_match),
            "Python RTL-faithful model과 DUT의 exact match 수준을 보여줍니다.",
            [("filled green", percent_fill(rtl_match), f"match {pct_text(rtl_match)}")],
            [f"mismatch {pct_text(rtl_mismatch)}", f"errors {summary.get('total_errors', 0)} warnings {summary.get('warnings', 0)}"],
        ),
        (
            "Ideal Approx Error",
            pct_text(avg_rel),
            "ideal softmax 대비 avg/max relative error를 한 카드에 묶었습니다.",
            [
                ("filled blue", percent_fill(avg_rel, rel_ceiling), f"avg {pct_text(avg_rel)}"),
                ("filled orange", percent_fill(max_rel, rel_ceiling), f"max {pct_text(max_rel)}"),
            ],
            [f"avg_abs {sci_text(ideal.avg_abs_err)}", f"max_abs {sci_text(ideal.abs_err_max)}"],
        ),
        (
            "Probability Mass Stability",
            sci_text(avg_residual),
            "output probability sum이 1.0을 얼마나 안정적으로 유지하는지 보여줍니다.",
            [
                ("filled blue", percent_fill(avg_residual, residual_ceiling), f"avg {compact_chart_value(avg_residual)}"),
                ("filled red", percent_fill(max_residual, residual_ceiling), f"max {compact_chart_value(max_residual)}"),
            ],
            [f"avg|sum-1| {sci_text(avg_residual)}", f"max|sum-1| {sci_text(max_residual)}"],
        ),
        (
            "Hot Spot",
            worst_scenario[0] if worst_scenario is not None else "No hot scenario",
            "relative error 기준 worst scenario와 frame을 바로 찾습니다.",
            [
                ("filled orange", percent_fill(float(worst_scenario[1].avg_rel_err_pct), rel_ceiling), f"scenario {pct_text(worst_scenario[1].avg_rel_err_pct)}") if worst_scenario is not None else ("filled gray", 6.0, "scenario -"),
                ("filled red", percent_fill(float(worst_frame[1].get('max_rel_err_pct', 0.0)), rel_ceiling), f"frame {pct_text(worst_frame[1].get('max_rel_err_pct', 0.0))}") if worst_frame is not None else ("filled gray", 6.0, "frame -"),
            ],
            [f"worst scenario {worst_scenario[0]}" if worst_scenario is not None else "worst scenario -", f"worst frame {worst_frame[0]}" if worst_frame is not None else "worst frame -"],
        ),
        (
            "Ideal Frame Scope",
            f"{eligible}/{total_scope}",
            "ideal softmax 비교에 포함된 frame과 제외된 frame을 함께 보여줍니다.",
            [
                ("filled blue", percent_fill(eligible, total_scope), f"eligible {eligible}"),
                ("filled gray", percent_fill(excluded, total_scope), f"excluded {excluded}"),
            ],
            [f"eligible {eligible} frames", f"excluded {excluded} frames"],
        ),
    ]

    html_cards = []
    for title, value, copy, meters, footers in cards:
        meter_html = "".join(
            "<div class='reading-meter-row'>"
            f"<div class='reading-meter-track'><span class='{tone}' style='width:{width:.1f}%'></span></div>"
            f"<div class='reading-meter-label'>{html.escape(label)}</div>"
            "</div>"
            for tone, width, label in meters
        )
        footer_html = "".join(f"<span>{html.escape(text)}</span>" for text in footers)
        html_cards.append(
            "<div class='case-insight-card'>"
            f"<div class='case-insight-title'>{html.escape(title)}</div>"
            f"<div class='case-insight-kpi'>{html.escape(str(value))}</div>"
            f"<p class='case-insight-copy'>{html.escape(copy)}</p>"
            f"<div class='reading-meter-group'>{meter_html}</div>"
            f"<div class='reading-footer'>{footer_html}</div>"
            "</div>"
        )
    return "".join(html_cards)


def build_case_scenario_rows(case: dict[str, Any]) -> str:
    cov_map = {str(row.get("name", "")): row for row in case["scenario_cov"]}
    rtl_map = {str(row.get("name", "")): row for row in case["scenario_quality"]}
    ideal_map = case["ideal_by_scenario"]
    names: list[str] = []
    for row in case["scenario_cov"]:
        name = str(row.get("name", ""))
        if name and name not in names:
            names.append(name)
    for row in case["scenario_quality"]:
        name = str(row.get("name", ""))
        if name and name not in names:
            names.append(name)
    for name in ideal_map:
        if name not in names:
            names.append(name)

    rows = []
    for name in names:
        cov = cov_map.get(name, {})
        rtl = rtl_map.get(name, {})
        ideal = ideal_map.get(name, NumericStats())
        rows.append(
            "<tr>"
            f"<td>{html.escape(name)}</td>"
            f"<td>{cov.get('checked_beats', rtl.get('checked_beats', 0))}</td>"
            f"<td>{cov.get('frame_samples', 0)}</td>"
            f"<td>{cov.get('reset_samples', 0)}</td>"
            f"<td>{pct_text(cov.get('coverage_pct', 0.0))}</td>"
            f"<td>{rtl.get('mismatch_beats', 0)}</td>"
            f"<td>{pct_text(rtl.get('mismatch_rate_pct', 0.0)) if rtl else '-'}</td>"
            f"<td>{sci_text(ideal.avg_abs_err)}</td>"
            f"<td>{sci_text(ideal.abs_err_max)}</td>"
            f"<td>{pct_text(ideal.avg_rel_err_pct)}</td>"
            f"<td>{pct_text(ideal.rel_err_max_pct)}</td>"
            f"<td>{ideal.eligible_frames}</td>"
            f"<td>{ideal.excluded_frames}</td>"
            "</tr>"
        )
    return "".join(rows)


def build_case_frame_rows(case: dict[str, Any]) -> str:
    inputs = {int(row["frame_id"]): row for row in case["inputs"]}
    expected = {int(row["frame_id"]): row for row in case["expected"]}
    actual = {int(row["frame_id"]): row for row in case["actual"]}
    frame_ids = sorted(set(inputs) | set(expected) | set(actual))
    rows = []
    for frame_id in frame_ids:
        in_row = inputs.get(frame_id, {})
        exp_row = expected.get(frame_id, {})
        act_row = actual.get(frame_id, {})
        ideal = case["ideal_by_frame"].get(frame_id, {})
        scenario = str(act_row.get("scenario") or exp_row.get("scenario") or in_row.get("scenario") or "Unclassified")
        status = "FAIL" if bool(int(act_row.get("frame_failed", 0))) else "PASS"
        rows.append(
            "<tr>"
            f"<td>{frame_id}</td>"
            f"<td>{html.escape(scenario)}</td>"
            f"<td>{html.escape(status_text(status))}</td>"
            f"<td>{len(csv_tokens(str(in_row.get('data_hex_csv', ''))))}</td>"
            f"<td>{len(csv_tokens(str(exp_row.get('output_hex_csv', ''))))}</td>"
            f"<td>{len(csv_tokens(str(act_row.get('data_hex_csv', ''))))}</td>"
            f"<td>{ideal.get('compare_len', 0)}</td>"
            f"<td>{act_row.get('checked_beats', 0)}</td>"
            f"<td>{act_row.get('mismatch_beats', 0)}</td>"
            f"<td>{sci_text(ideal.get('avg_abs_err', 0.0))}</td>"
            f"<td>{sci_text(ideal.get('max_abs_err', 0.0))}</td>"
            f"<td>{pct_text(ideal.get('avg_rel_err_pct', 0.0))}</td>"
            f"<td>{pct_text(ideal.get('max_rel_err_pct', 0.0))}</td>"
            f"<td>{sci_text(abs(float(ideal.get('sum_residual', 0.0))))}</td>"
            f"<td>{yes_no_text(bool(ideal.get('eligible', False)))}</td>"
            "</tr>"
        )
    return "".join(rows)


def build_case_frame_details(case: dict[str, Any]) -> str:
    inputs = {int(row["frame_id"]): row for row in case["inputs"]}
    expected = {int(row["frame_id"]): row for row in case["expected"]}
    actual = {int(row["frame_id"]): row for row in case["actual"]}
    frame_ids = sorted(set(inputs) | set(expected) | set(actual))
    details = []
    for frame_id in frame_ids:
        in_row = inputs.get(frame_id, {})
        exp_row = expected.get(frame_id, {})
        act_row = actual.get(frame_id, {})
        ideal = case["ideal_by_frame"].get(frame_id, {})
        scenario = str(act_row.get("scenario") or exp_row.get("scenario") or in_row.get("scenario") or "Unclassified")
        input_hex = str(in_row.get("data_hex_csv", ""))
        rtl_hex = str(exp_row.get("output_hex_csv", ""))
        actual_hex = str(act_row.get("data_hex_csv", ""))
        input_floats = csv_hex_to_float_list(input_hex)
        rtl_floats = csv_hex_to_float_list(rtl_hex)
        actual_floats = csv_hex_to_float_list(actual_hex)
        ideal_values = list(ideal.get("ideal_values", []))
        compare_len = int(ideal.get("compare_len", 0))
        input_len = len(csv_tokens(input_hex))
        rtl_len = len(csv_tokens(rtl_hex))
        actual_len = len(csv_tokens(actual_hex))
        excluded_reason = excluded_reason_text(str(ideal.get("excluded_reason", "-")))
        ideal_error_text = "\n".join(
            [
                f"avg_abs_err={sci_text(ideal.get('avg_abs_err', 0.0))}",
                f"max_abs_err={sci_text(ideal.get('max_abs_err', 0.0))}",
                f"avg_rel_err={pct_text(ideal.get('avg_rel_err_pct', 0.0))}",
                f"max_rel_err={pct_text(ideal.get('max_rel_err_pct', 0.0))}",
                f"compare_len={compare_len}",
                f"actual_sum={ideal.get('actual_sum', 0.0):.8f}",
                f"ideal_sum={ideal.get('ideal_sum', 0.0):.8f}",
                f"sum_residual={ideal.get('sum_residual', 0.0):.8f}",
                f"excluded_reason={excluded_reason}",
            ]
        )
        details.append(
            "<details class='frame-detail'>"
            "<summary>"
            f"<span class='detail-summary-title'>Frame {frame_id}</span>"
            f"<span class='detail-summary-meta'>{html.escape(scenario)}</span>"
            f"<span class='detail-summary-meta'>eligible {yes_no_text(bool(ideal.get('eligible', False)))}</span>"
            f"<span class='detail-summary-meta'>compare {compare_len}</span>"
            f"<span class='detail-summary-meta'>avg {pct_text(ideal.get('avg_rel_err_pct', 0.0))}</span>"
            f"<span class='detail-summary-meta'>max {pct_text(ideal.get('max_rel_err_pct', 0.0))}</span>"
            "</summary>"
            "<div class='frame-meta-grid'>"
            f"<div class='frame-meta-card'><span class='frame-meta-label'>Input / RTL / Actual</span><strong>{input_len} / {rtl_len} / {actual_len}</strong></div>"
            f"<div class='frame-meta-card'><span class='frame-meta-label'>Compare Len</span><strong>{compare_len}</strong></div>"
            f"<div class='frame-meta-card'><span class='frame-meta-label'>Avg Rel</span><strong>{pct_text(ideal.get('avg_rel_err_pct', 0.0))}</strong></div>"
            f"<div class='frame-meta-card'><span class='frame-meta-label'>Max Rel</span><strong>{pct_text(ideal.get('max_rel_err_pct', 0.0))}</strong></div>"
            f"<div class='frame-meta-card'><span class='frame-meta-label'>|sum-1|</span><strong>{sci_text(abs(float(ideal.get('sum_residual', 0.0))))}</strong></div>"
            f"<div class='frame-meta-card'><span class='frame-meta-label'>Excluded Reason</span><strong>{html.escape(excluded_reason)}</strong></div>"
            "</div>"
            "<div class='detail-grid detail-grid-2'>"
            f"<div class='detail-card'><h4>Input</h4><div class='detail-stack'><div><span class='detail-chip'>Hex</span><pre>{html.escape(csv_preview(input_hex))}</pre></div><div><span class='detail-chip'>Float</span><pre>{html.escape(csv_float_preview(input_floats))}</pre></div></div></div>"
            f"<div class='detail-card'><h4>RTL Golden</h4><div class='detail-stack'><div><span class='detail-chip'>Hex</span><pre>{html.escape(csv_preview(rtl_hex))}</pre></div><div><span class='detail-chip'>Float</span><pre>{html.escape(csv_float_preview(rtl_floats))}</pre></div></div></div>"
            f"<div class='detail-card'><h4>Actual DUT</h4><div class='detail-stack'><div><span class='detail-chip'>Hex</span><pre>{html.escape(csv_preview(actual_hex))}</pre></div><div><span class='detail-chip'>Float</span><pre>{html.escape(csv_float_preview(actual_floats))}</pre></div></div></div>"
            f"<div class='detail-card'><h4>Ideal Softmax</h4><div class='detail-stack'><div><span class='detail-chip'>Float</span><pre>{html.escape(csv_float_preview(ideal_values))}</pre></div><div><span class='detail-chip'>Error Summary</span><pre>{html.escape(ideal_error_text)}</pre></div></div></div>"
            "</div>"
            "<div class='detail-grid detail-grid-2 detail-grid-tail'>"
            f"<div class='detail-card'><h4>Beat Abs Error</h4><pre>{html.escape(csv_float_preview(list(ideal.get('beat_abs_errors', []))))}</pre></div>"
            f"<div class='detail-card'><h4>Beat Rel Error (%)</h4><pre>{html.escape(csv_float_preview(list(ideal.get('beat_rel_errors_pct', []))))}</pre></div>"
            "</div>"
            "<div class='token-row'>"
            f"<span>Input Class={html.escape(str(in_row.get('input_class', '-')))}</span>"
            f"<span>Term Kind={html.escape(str(in_row.get('term_kind', '-')))}</span>"
            f"<span>Reset Phase={html.escape(str(in_row.get('reset_phase', '-')))}</span>"
            f"<span>Input Stall={html.escape(str(in_row.get('in_stall', '-')))}</span>"
            f"<span>Output Stall={html.escape(str(in_row.get('out_stall', '-')))}</span>"
            f"<span>Result Kind={html.escape(str(in_row.get('result_kind', '-')))}</span>"
            "</div>"
            "</details>"
        )
    return "".join(details)


def build_case_mismatch_rows(case: dict[str, Any]) -> str:
    mismatches = case["mismatches"]
    if not mismatches:
        return "<tr><td colspan='7'>No RTL error events were recorded.</td></tr>"
    rows = []
    for row in mismatches:
        rows.append(
            "<tr>"
            f"<td>{row.get('frame_id', '-')}</td>"
            f"<td>{html.escape(str(row.get('scenario', '-')))}</td>"
            f"<td>{html.escape(str(row.get('reason', '-')))}</td>"
            f"<td>{row.get('beat', '-')}</td>"
            f"<td><code>{html.escape(csv_preview(str(row.get('input_hex_csv', '')), 10))}</code></td>"
            f"<td><code>{html.escape(csv_preview(str(row.get('expected_hex_csv', '')), 10))}</code></td>"
            f"<td><code>{html.escape(csv_preview(str(row.get('actual_hex_csv', '')), 10))}</code></td>"
            "</tr>"
        )
    return "".join(rows)


def build_case_section(case: dict[str, Any]) -> str:
    summary = case["summary"]
    testname = str(summary.get("testname", "Unclassified"))
    purpose = case_purpose_text(testname)
    chart_specs: list[ChartSpec] = []
    chart_specs.append(
        ChartSpec(
            title="Scenario Coverage by Scenario",
            description="",
            uri=case_scenario_chart(case),
            meaning="$C_s = \\mathrm{coverage\\_pct}(s)$",
            evidence="source: scenario_coverage.jsonl\nfield: coverage_pct\ngroup: by scenario",
            why_used="coverage gap 위치를 먼저 식별하기 위해 사용합니다.",
        )
    )
    chart_specs.append(
        ChartSpec(
            title="Ideal Relative Error by Frame",
            description="",
            uri=case_error_combo_chart(case),
            meaning="$E_{rel,avg}(f),\\ E_{rel,max}(f)$",
            evidence="source: ideal_by_frame\nfields: avg_rel_err_pct, max_rel_err_pct\ngroup: by frame",
            why_used="평균 오차와 peak 오차를 함께 보기 위해 사용합니다.",
        )
    )
    chart_specs.append(
        ChartSpec(
            title="Sum Residual by Frame",
            description="",
            uri=case_sum_residual_chart(case),
            meaning="$R_f = \\left|\\sum_i p_i - 1\\right|$",
            evidence="source: ideal_by_frame\nfield: sum_residual\ngroup: by frame",
            why_used="normalization drift를 별도로 보기 위해 사용합니다.",
        )
    )
    charts = "".join(chart_card(spec) for spec in chart_specs)
    heatmap_section = ""
    coverage_point_detail = ""
    if case.get("scenario_cov_points"):
        heatmap_method = (
            "source: scenario_cov_points.jsonl\nkey: point_keys_pipe\ngroup: by prefix family"
            if case.get("scenario_cov_points_from_artifact")
            else "fallback: input_frames.jsonl + expected_frames.jsonl + actual_frames.jsonl\nrule: coverage.svh point-key reconstruction\ngroup: by prefix family"
        )
        heatmap_section = (
            "<div class='chart-grid chart-grid-single'>"
            + chart_card(
                ChartSpec(
                    title="Coverage Point Heatmap by Scenario",
                    description="",
                    uri=case_scenario_cov_point_heatmap(case),
                    meaning="$H_{s,g} / N_g$",
                    evidence=heatmap_method,
                    why_used="scenario별 coverage hole을 group 단위로 찾기 위해 사용합니다.",
                    class_name="chart-card-wide",
                )
            )
            + "</div>"
        )
        coverage_point_detail = build_case_cov_point_drilldown(case)
    return f"""
    <section class="report-page case-page" id="{sanitize_name(str(summary.get('testname', 'Unclassified')))}">
      <div class="page-head">
        <div class="page-title-stack">
          <div class="eyebrow">Case {summary.get('case_index', '-')} / {summary.get('case_count', '-')}</div>
          <div class="page-title-row">
            <h2>{html.escape(testname)}</h2>
            <div class="case-purpose-pill">{html.escape(purpose)}</div>
          </div>
        </div>
        <div>{status_badge(str(summary.get('status', 'UNKNOWN')))}</div>
      </div>
      <div class="metric-grid">{build_case_cards(case)}</div>
      <div class="chart-grid">{charts}</div>
      {heatmap_section}
      {coverage_point_detail}
      <div class="section-block">
        <h3>Scenario Matrix</h3>
        <table class="dense-head-table">
          <thead>
            <tr>
              <th>Scenario</th>
              <th>Checked Beats</th>
              <th>Frame Samples</th>
              <th>Reset Samples</th>
              <th>Coverage</th>
              <th>RTL Error Beats</th>
              <th>RTL Error</th>
              <th>Ideal Avg Abs</th>
              <th>Ideal Max Abs</th>
              <th>Ideal Avg Rel</th>
              <th>Ideal Max Rel</th>
              <th>Ideal Eligible</th>
              <th>Ideal Excluded</th>
            </tr>
          </thead>
          <tbody>{build_case_scenario_rows(case)}</tbody>
        </table>
      </div>
      <div class="section-block">
        <h3>Frame Ledger</h3>
        <table class="ledger-head-table">
          <thead>
            <tr>
              <th>Frame</th>
              <th>Scenario</th>
              <th>Status</th>
              <th>Input Len</th>
              <th>RTL Len</th>
              <th>Actual Len</th>
              <th>Compare Len</th>
              <th>Checked Beats</th>
              <th>RTL Error</th>
              <th>Ideal Avg Abs</th>
              <th>Ideal Max Abs</th>
              <th>Ideal Avg Rel</th>
              <th>Ideal Max Rel</th>
              <th>|sum-1|</th>
              <th>Ideal Eligible</th>
            </tr>
          </thead>
          <tbody>{build_case_frame_rows(case)}</tbody>
        </table>
      </div>
      <div class="section-block">
        <h3>Frame Drill-down</h3>
        {build_case_frame_details(case)}
      </div>
      <div class="section-block">
        <h3>RTL Error Log</h3>
        <table>
          <thead>
            <tr>
              <th>Frame</th>
              <th>Scenario</th>
              <th>Reason</th>
              <th>Beat</th>
              <th>Input Hex</th>
              <th>Expected Hex</th>
              <th>Actual Hex</th>
            </tr>
          </thead>
          <tbody>{build_case_mismatch_rows(case)}</tbody>
        </table>
      </div>
    </section>
    """


def build_case_sidebar(case_data: list[dict[str, Any]]) -> str:
    items = [
        (
            "<a class='side-nav-home' href='#suite_top'>"
            "<span class='side-nav-index'>Σ</span>"
            "<span class='side-nav-copy'><strong>Main Page</strong><small>front page summary로 이동</small></span>"
            "</a>"
        )
    ]
    for case in case_data:
        summary = case["summary"]
        testname = str(summary.get("testname", "Unclassified"))
        items.append(
            "<a class='side-nav-item' href='#{anchor}'>"
            "<span class='side-nav-index'>{index}</span>"
            "<span class='side-nav-copy'>"
            "<strong>{name}</strong>"
            "<small>{status} · cov {coverage} · beats {beats}</small>"
            "</span>"
            "</a>".format(
                anchor=sanitize_name(testname),
                index=int(summary.get("case_index", 0)),
                name=html.escape(testname),
                status=html.escape(status_text(str(summary.get("status", "UNKNOWN")))),
                coverage=html.escape(pct_text(summary.get("case_coverage_pct", 0.0))),
                beats=int(summary.get("checked_beats", 0)),
            )
        )

    return (
        "<aside class='side-nav' aria-label='Case navigation'>"
        "<div class='side-nav-head'>"
        "<div class='side-nav-mini'>TB</div>"
        "<div class='side-nav-title'>Case Dashboard</div>"
        "<div class='side-nav-subtitle'>hover/focus 시 expand됩니다</div>"
        "</div>"
        "<nav class='side-nav-links'>"
        + "".join(items)
        + "</nav></aside>"
    )


def generate_html(runtime_root: Path, testname: str) -> str:
    suite_summary = load_json(runtime_root / f"suite_summary_{sanitize_name(testname)}.json")
    case_dirs = discover_case_dirs(runtime_root, testname, suite_summary)
    case_data = [load_case_data(case_dir) for case_dir in case_dirs]
    suite = aggregate_suite_summary(case_data, suite_summary, testname)
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    title = "UVM Report - Softmax Acceleator"
    if testname == "all":
        browser_title = title
    else:
        browser_title = f"{title} | {testname}"

    front_charts = "".join(
        [
            chart_card(
                ChartSpec(
                    title="Sum Residual by Case",
                    description="",
                    uri=suite_sum_residual_chart(case_data),
                    meaning="$R_c^{avg},\\ R_c^{max}$",
                    evidence="source: ideal_by_frame\nfields: avg(|sum-1|), max(|sum-1|)\ngroup: by case",
                    why_used="residual이 큰 case를 빠르게 찾기 위해 사용합니다.",
                    class_name="brief-compact",
                )
            ),
            chart_card(
                ChartSpec(
                    title="Ideal Relative Error by Case",
                    description="",
                    uri=suite_ideal_error_chart(case_data, suite),
                    meaning="$E_{rel,avg}(c),\\ E_{rel,max}(c),\\ \\bar{E}_{rel},\\ E_{rel}^{max}$",
                    evidence="bars: ideal_total.avg_rel_err_pct, ideal_total.rel_err_max_pct\nlines: suite ideal_avg_rel_err_pct, ideal_max_rel_err_pct",
                    why_used="overall 대비 취약한 case를 찾기 위해 사용합니다.",
                    class_name="brief-compact",
                )
            ),
            chart_card(
                ChartSpec(
                    title="Ideal Frame Scope",
                    description="",
                    uri=suite_eligibility_chart(suite),
                    meaning="$N_{eligible},\\ N_{excluded}$",
                    evidence="source: compute_ideal_metrics\nfields: eligible_frames, excluded_frames",
                    why_used="sample count 기준을 함께 보기 위해 사용합니다.",
                    class_name="compact-donut",
                )
            ),
        ]
    )

    case_sections = "".join(build_case_section(case) for case in case_data)

    return f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{html.escape(browser_title)}</title>
  <script>
    window.MathJax = {{
      tex: {{ inlineMath: [['\\\\(', '\\\\)'], ['$', '$']] }},
      svg: {{ fontCache: 'global' }}
    }};
  </script>
  <script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js"></script>
  <style>
    :root {{
      --bg: #f2f4f6;
      --surface: #ffffff;
      --surface-2: #f9fafb;
      --ink: #191f28;
      --muted: #8b95a1;
      --line: #e5e8eb;
      --blue: #3182f6;
      --blue-dark: #1b64da;
      --green: #00c773;
      --red: #f04452;
      --shadow: 0 18px 42px rgba(25, 31, 40, 0.06);
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background:
        radial-gradient(circle at top center, rgba(49,130,246,0.08), transparent 20%),
        linear-gradient(180deg, #f8fafc 0%, #eef2f6 100%);
      color: var(--ink);
      font-family: "Pretendard Variable", "Pretendard", "Segoe UI", "Malgun Gothic", sans-serif;
      -webkit-font-smoothing: antialiased;
      text-rendering: optimizeLegibility;
    }}
    .page-shell {{
      position: relative;
      min-height: 100vh;
      padding: 0 18px 0 220px;
    }}
    .page-wrap {{
      width: min(1520px, 100%);
      margin: 18px auto 56px;
    }}
    .side-nav {{
      position: fixed;
      top: 18px;
      bottom: 18px;
      left: 18px;
      z-index: 40;
      width: 76px;
      display: flex;
      flex-direction: column;
      gap: 16px;
      padding: 16px 12px;
      border-radius: 28px;
      border: 1px solid rgba(255,255,255,0.66);
      background: rgba(255,255,255,0.78);
      backdrop-filter: blur(24px);
      box-shadow: 0 18px 40px rgba(25, 31, 40, 0.10);
      overflow: hidden;
      transition: width 220ms ease, box-shadow 220ms ease, transform 220ms ease;
    }}
    .side-nav:hover,
    .side-nav:focus-within {{
      width: 294px;
      box-shadow: 0 24px 48px rgba(25, 31, 40, 0.14);
      transform: translateY(-1px);
    }}
    .side-nav-head {{
      display: grid;
      gap: 4px;
      padding: 2px 4px 2px 2px;
    }}
    .side-nav-mini {{
      width: 44px;
      height: 44px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border-radius: 16px;
      background: linear-gradient(135deg, #3182f6, #1b64da);
      color: white;
      font-size: 14px;
      font-weight: 800;
      letter-spacing: 0.08em;
    }}
    .side-nav-title,
    .side-nav-subtitle {{
      opacity: 0;
      transform: translateX(-10px);
      transition: opacity 180ms ease, transform 180ms ease;
      white-space: nowrap;
    }}
    .side-nav:hover .side-nav-title,
    .side-nav:hover .side-nav-subtitle,
    .side-nav:focus-within .side-nav-title,
    .side-nav:focus-within .side-nav-subtitle {{
      opacity: 1;
      transform: translateX(0);
    }}
    .side-nav-title {{
      font-size: 13px;
      font-weight: 800;
      color: var(--blue-dark);
      letter-spacing: 0.02em;
    }}
    .side-nav-subtitle {{
      font-size: 12px;
      color: var(--muted);
    }}
    .side-nav-links {{
      display: flex;
      flex-direction: column;
      gap: 8px;
      overflow: auto;
      padding-right: 2px;
    }}
    .side-nav-home,
    .side-nav-item {{
      display: flex;
      align-items: center;
      gap: 12px;
      min-height: 52px;
      padding: 8px 8px;
      border-radius: 18px;
      text-decoration: none;
      background: rgba(244, 247, 251, 0.76);
      border: 1px solid transparent;
      transition: background 180ms ease, border-color 180ms ease, transform 180ms ease;
      cursor: pointer;
    }}
    .side-nav-home:hover,
    .side-nav-home:focus-visible,
    .side-nav-item:hover,
    .side-nav-item:focus-visible {{
      background: #eef4ff;
      border-color: #dbe7ff;
      transform: translateX(2px);
      outline: none;
    }}
    .side-nav-index {{
      flex: 0 0 40px;
      width: 40px;
      height: 40px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border-radius: 14px;
      background: white;
      color: var(--blue-dark);
      font-size: 13px;
      font-weight: 800;
      box-shadow: inset 0 0 0 1px rgba(49,130,246,0.09);
    }}
    .side-nav-copy {{
      display: grid;
      gap: 3px;
      min-width: 0;
      opacity: 0;
      transform: translateX(-10px);
      transition: opacity 180ms ease, transform 180ms ease;
      white-space: nowrap;
      pointer-events: none;
    }}
    .side-nav:hover .side-nav-copy,
    .side-nav:focus-within .side-nav-copy {{
      opacity: 1;
      transform: translateX(0);
      pointer-events: auto;
    }}
    .side-nav-copy strong {{
      font-size: 13px;
      color: var(--ink);
      overflow: hidden;
      text-overflow: ellipsis;
    }}
    .side-nav-copy small {{
      font-size: 11px;
      color: var(--muted);
      overflow: hidden;
      text-overflow: ellipsis;
    }}
    .jump-bar {{
      position: sticky;
      top: 12px;
      z-index: 20;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      padding: 14px 18px;
      margin-bottom: 16px;
      border: 1px solid rgba(255,255,255,0.55);
      border-radius: 20px;
      background: rgba(255,255,255,0.72);
      backdrop-filter: blur(20px);
      box-shadow: 0 12px 28px rgba(25, 31, 40, 0.08);
    }}
    .jump-label {{
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--blue-dark);
      white-space: nowrap;
    }}
    .jump-links {{
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      justify-content: flex-end;
    }}
    .jump-chip {{
      display: inline-flex;
      align-items: center;
      min-height: 34px;
      padding: 8px 12px;
      border-radius: 999px;
      background: #eef4ff;
      color: var(--blue-dark);
      text-decoration: none;
      font-size: 12px;
      font-weight: 700;
      transition: transform 180ms ease, background 180ms ease;
    }}
    .jump-chip:hover {{
      background: #e1ecff;
      transform: translateY(-1px);
    }}
    .jump-chip.muted {{
      background: #f2f4f6;
      color: var(--muted);
    }}
    .report-page {{
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 28px;
      padding: 28px;
      box-shadow: var(--shadow);
      page-break-after: always;
      break-after: page;
      scroll-margin-top: 88px;
    }}
    .report-page + .report-page {{
      margin-top: 24px;
    }}
    .hero {{
      background:
        radial-gradient(circle at top right, rgba(49,130,246,0.14), transparent 26%),
        radial-gradient(circle at top left, rgba(0,199,115,0.07), transparent 20%),
        linear-gradient(180deg, rgba(255,255,255,0.98), rgba(249,250,251,0.96));
    }}
    .eyebrow {{
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--blue-dark);
      margin-bottom: 10px;
    }}
    h1 {{
      margin: 0 0 10px;
      font-size: clamp(34px, 5vw, 58px);
      line-height: 1.02;
      letter-spacing: -0.045em;
    }}
    h2 {{
      margin: 0;
      font-size: 30px;
      line-height: 1.08;
      letter-spacing: -0.04em;
    }}
    h3 {{
      margin: 0 0 8px;
      font-size: 20px;
      line-height: 1.15;
      letter-spacing: -0.03em;
    }}
    h4 {{
      margin: 0 0 8px;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.09em;
      color: var(--muted);
    }}
    p, li {{
      color: #4e5968;
      line-height: 1.62;
    }}
    .lede {{
      max-width: 980px;
      margin: 0;
      font-size: 17px;
    }}
    .token-row {{
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin-top: 18px;
    }}
    .token-row span {{
      display: inline-flex;
      align-items: center;
      padding: 8px 12px;
      border-radius: 999px;
      background: #f2f7ff;
      color: var(--blue-dark);
      font-size: 12px;
      font-weight: 600;
    }}
    .page-head {{
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
      margin-bottom: 20px;
    }}
    .page-title-stack {{
      display: grid;
      gap: 8px;
      min-width: 0;
    }}
    .page-title-row {{
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 12px;
    }}
    .case-purpose-pill {{
      display: inline-flex;
      align-items: center;
      min-height: 36px;
      max-width: min(880px, 100%);
      padding: 8px 14px;
      border-radius: 999px;
      background: linear-gradient(180deg, #f6faff 0%, #edf4ff 100%);
      border: 1px solid #dbe7ff;
      color: var(--blue-dark);
      font-size: 13px;
      font-weight: 700;
      line-height: 1.5;
    }}
    .metric-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(176px, 1fr));
      gap: 14px;
      margin-top: 22px;
      align-items: start;
    }}
    .insight-grid {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 16px;
      margin-top: 18px;
    }}
    .insight-card {{
      position: relative;
      overflow: hidden;
      background: linear-gradient(135deg, #f9fbff 0%, #f3f7ff 100%);
      border: 1px solid #dbe7ff;
      border-radius: 24px;
      padding: 18px 18px 20px;
    }}
    .insight-card::after {{
      content: "";
      position: absolute;
      inset: auto -10px -36px auto;
      width: 110px;
      height: 110px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(49,130,246,0.14), rgba(49,130,246,0.0));
    }}
    .insight-label {{
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--blue-dark);
      font-weight: 800;
      margin-bottom: 12px;
    }}
    .insight-title {{
      font-size: 26px;
      line-height: 1.06;
      letter-spacing: -0.04em;
      font-weight: 800;
      margin-bottom: 8px;
    }}
    .insight-copy {{
      font-size: 14px;
      color: var(--muted);
      line-height: 1.55;
      max-width: 34ch;
    }}
    .metric-card {{
      align-self: start;
      background: var(--surface-2);
      border: 1px solid var(--line);
      border-radius: 22px;
      padding: 15px 16px 14px;
      min-height: 118px;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.7);
    }}
    .metric-value-shell {{
      display: grid;
      gap: 8px;
      margin-top: 8px;
    }}
    .metric-label {{
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--muted);
      margin-bottom: 10px;
      font-weight: 700;
    }}
    .metric-value {{
      font-size: 25px;
      line-height: 1.06;
      letter-spacing: -0.04em;
      font-weight: 800;
      color: var(--ink);
    }}
    .metric-pair {{
      display: grid;
      gap: 8px;
      font-size: 14px;
      line-height: 1.4;
      letter-spacing: 0;
    }}
    .metric-pair-line {{
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 10px;
      white-space: nowrap;
    }}
    .metric-pair-key {{
      font-size: 12px;
      font-weight: 800;
      color: var(--muted);
      letter-spacing: 0.04em;
      text-transform: uppercase;
    }}
    .metric-pair-value {{
      font-size: 18px;
      line-height: 1.1;
      letter-spacing: -0.02em;
      color: var(--ink);
    }}
    .reading-section {{
      margin-top: 22px;
    }}
    .reading-head {{
      display: flex;
      align-items: flex-end;
      justify-content: space-between;
      gap: 16px;
      margin-bottom: 14px;
    }}
    .reading-head p {{
      margin: 0;
      font-size: 14px;
      color: var(--muted);
      max-width: 72ch;
    }}
    .reading-grid {{
      display: grid;
      grid-template-columns: repeat(5, minmax(0, 1fr));
      gap: 14px;
    }}
    .reading-card {{
      display: grid;
      gap: 12px;
      padding: 18px;
      border-radius: 24px;
      background: linear-gradient(180deg, rgba(255,255,255,0.98), rgba(246,249,253,0.98));
      border: 1px solid var(--line);
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.8);
    }}
    .reading-title {{
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      font-weight: 800;
      color: var(--blue-dark);
    }}
    .reading-kpi {{
      font-size: 28px;
      line-height: 1.05;
      letter-spacing: -0.04em;
      font-weight: 800;
      color: var(--ink);
    }}
    .reading-copy {{
      margin: 0;
      min-height: 0;
      font-size: 13px;
      color: var(--muted);
      line-height: 1.5;
    }}
    .reading-section-block {{
      display: grid;
      gap: 8px;
    }}
    .reading-subhead {{
      display: inline-flex;
      align-items: center;
      width: fit-content;
      min-height: 24px;
      padding: 4px 10px;
      border-radius: 999px;
      background: #f3f7ff;
      color: var(--blue-dark);
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.06em;
      text-transform: uppercase;
    }}
    .reading-meter-group {{
      display: grid;
      gap: 8px;
    }}
    .metric-meter-group {{
      margin-top: 12px;
    }}
    .reading-meter-row {{
      display: grid;
      gap: 6px;
    }}
    .reading-meter-track {{
      width: 100%;
      height: 8px;
      border-radius: 999px;
      background: #edf2f7;
      overflow: hidden;
    }}
    .reading-meter-track span {{
      display: block;
      height: 100%;
      border-radius: inherit;
    }}
    .filled.blue {{ background: linear-gradient(90deg, #3182f6, #63a4ff); }}
    .filled.green {{ background: linear-gradient(90deg, #00c773, #54dba0); }}
    .filled.orange {{ background: linear-gradient(90deg, #ff8a00, #ffb155); }}
    .filled.red {{ background: linear-gradient(90deg, #f04452, #ff7e88); }}
    .filled.gray {{ background: linear-gradient(90deg, #c7d0db, #dde2e8); }}
    .reading-meter-label {{
      font-size: 12px;
      color: var(--muted);
      font-weight: 700;
    }}
    .reading-footer {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 2px;
    }}
    .metric-footer {{
      margin-top: 12px;
    }}
    .reading-footer span {{
      display: inline-flex;
      align-items: center;
      min-height: 28px;
      padding: 6px 10px;
      border-radius: 999px;
      background: #f2f7ff;
      color: var(--blue-dark);
      font-size: 10px;
      font-weight: 700;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 100%;
    }}
    .badge {{
      display: inline-flex;
      align-items: center;
      border-radius: 999px;
      padding: 7px 12px;
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.08em;
    }}
    .pass {{ background: rgba(0,199,115,0.12); color: var(--green); }}
    .fail {{ background: rgba(240,68,82,0.12); color: var(--red); }}
    .note-card {{
      background: var(--surface-2);
      border: 1px solid var(--line);
      border-radius: 24px;
      padding: 18px 20px;
    }}
    .note-card.emphasis {{
      background: linear-gradient(180deg, #f9fbff 0%, #f5f8ff 100%);
      border-color: #dbe7ff;
    }}
    .case-intro {{
      margin-top: 22px;
    }}
    .case-intro-copy {{
      margin: 0 0 14px;
      font-size: 14px;
      color: var(--muted);
      line-height: 1.62;
    }}
    .case-insight-grid {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 14px;
    }}
    .case-insight-card {{
      display: grid;
      gap: 10px;
      padding: 16px;
      border-radius: 20px;
      background: rgba(255,255,255,0.88);
      border: 1px solid #e6edf7;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.85);
    }}
    .case-insight-title {{
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      font-weight: 800;
      color: var(--blue-dark);
    }}
    .case-insight-kpi {{
      font-size: 24px;
      line-height: 1.05;
      letter-spacing: -0.035em;
      font-weight: 800;
      color: var(--ink);
      word-break: break-word;
    }}
    .case-insight-copy {{
      margin: 0;
      min-height: 58px;
      font-size: 13px;
      line-height: 1.58;
      color: var(--muted);
    }}
    .chart-grid {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 18px;
      margin-top: 24px;
      align-items: start;
    }}
    .chart-grid-front {{
      grid-template-columns: repeat(3, minmax(0, 1fr));
      align-items: stretch;
    }}
    .chart-grid-single {{
      grid-template-columns: 1fr;
      margin-top: 18px;
    }}
    .chart-grid-front .chart-card {{
      height: 100%;
      padding: 18px;
    }}
    .chart-grid-front .chart-card img {{
      height: 286px;
      object-fit: contain;
    }}
    .chart-card {{
      display: flex;
      flex-direction: column;
      align-self: start;
      background: var(--surface-2);
      border: 1px solid var(--line);
      border-radius: 24px;
      padding: 18px;
      overflow: hidden;
    }}
    .chart-head p {{
      margin: 0 0 14px;
      font-size: 14px;
      line-height: 1.58;
      white-space: normal;
      overflow: visible;
      text-overflow: clip;
      overflow-wrap: anywhere;
      word-break: break-word;
    }}
    .chart-grid-front .chart-head p {{
      margin: 0 0 12px;
      font-size: 13px;
      line-height: 1.45;
      white-space: normal;
      overflow: visible;
      text-overflow: clip;
      overflow-wrap: anywhere;
      word-break: break-word;
    }}
    .chart-card img {{
      width: 100%;
      display: block;
      border-radius: 18px;
      background: white;
      border: 1px solid #eef2f6;
    }}
    .chart-card.chart-card-wide img {{
      max-height: none;
      object-fit: contain;
    }}
    .chart-card.compact-donut img {{
      max-height: 286px;
      object-fit: contain;
    }}
    .chart-brief {{
      display: grid;
      grid-template-columns: 1fr;
      gap: 8px;
      margin-top: 10px;
    }}
    .brief-item {{
      display: grid;
      grid-template-columns: 58px 1fr;
      gap: 10px;
      align-items: start;
      padding: 10px 12px;
      border-radius: 14px;
      background: white;
      border: 1px solid #e8edf3;
    }}
    .chart-card.compact-donut {{
      padding: 18px;
    }}
    .chart-card.compact-donut .brief-item {{
      align-items: start;
    }}
    .chart-card.compact-donut .brief-item p {{
      font-size: 12.5px;
      line-height: 1.52;
    }}
    .chart-card.brief-compact .brief-item p {{
      font-size: 12.5px;
      line-height: 1.52;
    }}
    .brief-label {{
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--blue-dark);
      margin-bottom: 0;
    }}
    .brief-item p {{
      margin: 0;
      font-size: 12.5px;
      line-height: 1.45;
      color: var(--muted);
      white-space: normal;
      overflow: visible;
      text-overflow: clip;
      overflow-wrap: anywhere;
      word-break: break-word;
    }}
    .brief-code {{
      margin: 0;
      padding: 10px 12px;
      min-height: 0;
      border-radius: 14px;
      background: #202632;
      color: #f5f7fa;
      white-space: pre-wrap;
      word-break: break-word;
      overflow-wrap: anywhere;
      font-size: 11.5px;
      line-height: 1.5;
      font-family: Consolas, "Courier New", monospace;
    }}
    .chart-brief code,
    .chart-head code {{
      padding: 2px 6px;
      border-radius: 999px;
      background: rgba(49,130,246,0.10);
      color: var(--blue-dark);
      font-size: 0.95em;
      font-family: "SFMono-Regular", "Consolas", "Menlo", monospace;
      white-space: normal;
      overflow-wrap: anywhere;
      word-break: break-word;
    }}
    .chart-brief .math,
    .chart-head .math {{
      color: var(--ink);
      font-weight: 600;
    }}
    .coverage-detail-section {{
      padding: 12px 12px 10px;
    }}
    .coverage-detail-section > h3 {{
      margin-bottom: 6px;
    }}
    .coverage-point-grid {{
      display: flex;
      flex-wrap: wrap;
      align-items: flex-start;
      justify-content: center;
      gap: 8px;
      margin-top: 8px;
    }}
    .coverage-point-grid > .coverage-point-card {{
      flex: 0 0 calc((100% - 16px) / 3);
      max-width: calc((100% - 16px) / 3);
    }}
    .coverage-point-card {{
      display: block;
      margin: 0;
      width: auto;
      min-width: 0;
      border: 1px solid #e7edf5;
      border-radius: 13px;
      background: #fff;
      overflow: hidden;
    }}
    .coverage-point-grid > .coverage-point-card[open] {{
      flex-basis: 100%;
      max-width: 100%;
    }}
    .coverage-point-card[open] {{
      box-shadow: 0 10px 24px rgba(15, 23, 42, 0.06);
    }}
    .coverage-point-summary {{
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto auto;
      align-items: center;
      gap: 7px;
      list-style: none;
      cursor: pointer;
      height: 48px;
      min-height: 48px;
      padding: 4px 10px;
      font-size: 12px;
      font-weight: 700;
      line-height: 1;
      color: var(--ink);
    }}
    .coverage-point-summary::-webkit-details-marker {{
      display: none;
    }}
    .coverage-point-summary::after {{
      content: "+";
      margin-left: 0;
      justify-self: end;
      align-self: center;
      color: var(--blue-dark);
      font-size: 14px;
      font-weight: 800;
      line-height: 1;
    }}
    .coverage-point-card[open] .coverage-point-summary::after {{
      content: "−";
    }}
    .coverage-point-name {{
      min-width: 0;
      font-size: 16px;
      font-weight: 800;
      letter-spacing: -0.02em;
      line-height: 1;
      color: var(--ink);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }}
    .coverage-point-meta {{
      display: grid;
      grid-auto-flow: row;
      gap: 3px;
      justify-items: start;
      align-self: center;
      line-height: 1;
      white-space: normal;
    }}
    .coverage-point-badge {{
      display: inline-flex;
      align-items: center;
      padding: 2px 5px;
      width: fit-content;
      border-radius: 999px;
      background: #f2f7ff;
      color: var(--blue-dark);
      font-size: 9.5px;
      font-weight: 700;
      line-height: 1;
      white-space: nowrap;
    }}
    .coverage-point-body {{
      display: grid;
      gap: 6px;
      padding: 0 6px 10px;
    }}
    .coverage-family-row {{
      display: grid;
      gap: 5px;
      padding: 8px 5px;
      border-radius: 8px;
      background: #f9fbff;
      border: 1px solid #edf3fb;
    }}
    .coverage-family-head {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 6px;
    }}
    .coverage-family-name {{
      font-size: 10.5px;
      font-weight: 800;
      letter-spacing: 0.08em;
      line-height: 1.05;
      text-transform: uppercase;
      color: var(--blue-dark);
    }}
    .coverage-family-count {{
      font-size: 10.5px;
      font-weight: 700;
      line-height: 1.05;
      color: var(--muted);
      white-space: nowrap;
    }}
    .coverage-key-list {{
      display: grid;
      gap: 5px;
    }}
    .coverage-key-row {{
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      align-items: center;
      gap: 6px;
      padding: 5px 4px;
      border-radius: 7px;
      background: #ffffff;
      border: 1px solid #e7edf5;
    }}
    .coverage-key-point,
    .coverage-key-bin {{
      display: inline-flex;
      align-items: center;
      width: fit-content;
      max-width: 100%;
      padding: 3px 4px;
      border-radius: 999px;
      font-size: 10px;
      line-height: 1.2;
      font-family: "SFMono-Regular", "Consolas", "Menlo", monospace;
      white-space: normal;
      overflow-wrap: anywhere;
      word-break: break-word;
    }}
    .coverage-key-point {{
      background: rgba(49,130,246,0.10);
      color: var(--blue-dark);
    }}
    .coverage-key-bin {{
      justify-self: end;
      background: #f4f7fb;
      color: var(--muted);
      white-space: nowrap;
    }}
    .coverage-key-row.muted .coverage-key-point,
    .coverage-key-row.muted .coverage-key-bin {{
      background: #f2f4f6;
      color: var(--muted);
    }}
    .section-block {{
      margin-top: 26px;
      background: var(--surface-2);
      border: 1px solid var(--line);
      border-radius: 24px;
      padding: 18px;
    }}
    .overview-block {{
      margin-top: 18px;
    }}
    .overview-block table {{
      font-size: 12px;
    }}
    .overview-block th {{
      padding: 10px 8px;
      font-size: 10px;
      letter-spacing: 0.04em;
      white-space: nowrap;
    }}
    .overview-block td {{
      padding: 11px 8px;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
      background: transparent;
    }}
    th, td {{
      padding: 12px 12px;
      border-bottom: 1px solid var(--line);
      text-align: left;
      vertical-align: top;
    }}
    th {{
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }}
    .dense-head-table th {{
      padding: 9px 6px;
      font-size: 9px;
      line-height: 1.0;
      letter-spacing: 0.03em;
      white-space: nowrap;
    }}
    .dense-head-table td {{
      padding: 11px 8px;
    }}
    .ledger-head-table th {{
      padding: 8px 5px;
      font-size: 8px;
      line-height: 1.0;
      letter-spacing: 0.02em;
      white-space: nowrap;
    }}
    .ledger-head-table td {{
      padding: 11px 8px;
    }}
    tbody tr:hover {{
      background: rgba(49,130,246,0.04);
    }}
    details {{
      background: white;
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 16px;
    }}
    details + details {{
      margin-top: 12px;
    }}
    summary {{
      cursor: pointer;
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      align-items: center;
      font-weight: 800;
      font-size: 15px;
      color: var(--ink);
    }}
    .detail-summary-title {{
      font-size: 15px;
      font-weight: 800;
      color: var(--ink);
    }}
    .detail-summary-meta {{
      padding: 4px 10px;
      border-radius: 999px;
      background: rgba(49,130,246,0.08);
      color: var(--muted);
      font-size: 11px;
      font-weight: 700;
      white-space: nowrap;
    }}
    .frame-meta-grid {{
      display: grid;
      grid-template-columns: repeat(6, minmax(0, 1fr));
      gap: 10px;
      margin-top: 14px;
    }}
    .frame-meta-card {{
      padding: 12px 12px 11px;
      border-radius: 16px;
      background: rgba(255,255,255,0.86);
      border: 1px solid var(--line);
      min-width: 0;
    }}
    .frame-meta-label {{
      display: block;
      margin-bottom: 6px;
      color: var(--muted);
      font-size: 10px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      white-space: nowrap;
    }}
    .frame-meta-card strong {{
      display: block;
      font-size: 13px;
      line-height: 1.35;
      word-break: break-word;
    }}
    .detail-grid {{
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 14px;
      margin-top: 14px;
    }}
    .detail-grid-2 {{
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }}
    .detail-grid-tail {{
      margin-top: 12px;
    }}
    .detail-card {{
      min-width: 0;
    }}
    .detail-card h4 {{
      margin: 0 0 10px;
      font-size: 12px;
      font-weight: 800;
      color: var(--ink);
    }}
    .detail-stack {{
      display: grid;
      gap: 10px;
    }}
    .detail-chip {{
      display: inline-flex;
      margin-bottom: 6px;
      padding: 3px 8px;
      border-radius: 999px;
      background: rgba(49,130,246,0.08);
      color: var(--blue-dark);
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 0.03em;
      text-transform: uppercase;
    }}
    pre {{
      margin: 0;
      padding: 12px;
      min-height: 68px;
      border-radius: 16px;
      background: #202632;
      color: #f5f7fa;
      white-space: pre-wrap;
      word-break: break-word;
      font-size: 12px;
      line-height: 1.48;
    }}
    code {{
      font-family: Consolas, "Courier New", monospace;
      font-size: 12px;
    }}
    @page {{
      size: A4 landscape;
      margin: 8mm;
    }}
    @media print {{
      html, body {{
        background: #ffffff !important;
      }}
      body {{
        print-color-adjust: exact;
        -webkit-print-color-adjust: exact;
      }}
      .page-shell {{
        padding: 0;
        min-height: auto;
      }}
      .page-wrap {{
        width: 100%;
        max-width: none;
        margin: 0;
      }}
      .side-nav {{
        display: none !important;
      }}
      .report-page {{
        width: 100%;
        min-height: 193mm;
        margin: 0 0 6mm 0;
        padding: 12mm;
        border-radius: 20px;
        border: 1px solid #dfe5ec;
        box-shadow: none;
        page-break-after: always;
        break-after: page;
        page-break-inside: avoid;
        break-inside: avoid-page;
      }}
      .report-page:last-of-type {{
        page-break-after: auto;
        break-after: auto;
      }}
      .report-page + .report-page {{
        margin-top: 0;
      }}
      .metric-grid,
      .chart-grid,
      .chart-grid-front,
      .frame-meta-grid,
      .detail-grid,
      .detail-grid-2 {{
        break-inside: avoid;
        page-break-inside: avoid;
      }}
      .section-block,
      .chart-card,
      .frame-detail,
      table,
      details {{
        break-inside: avoid;
        page-break-inside: avoid;
      }}
      thead {{
        display: table-header-group;
      }}
      tr,
      img,
      pre {{
        break-inside: avoid;
        page-break-inside: avoid;
      }}
      .section-block {{
        box-shadow: none;
      }}
      a[href] {{
        text-decoration: none;
        color: inherit;
      }}
    }}
    @media (max-width: 1180px) {{
      .page-shell {{
        padding: 0;
      }}
      .page-wrap {{
        width: min(1520px, calc(100% - 32px));
        margin: 18px auto 56px;
      }}
      .side-nav,
      .side-nav:hover,
      .side-nav:focus-within {{
        position: sticky;
        top: 12px;
        bottom: auto;
        left: auto;
        width: min(100% - 32px, 980px);
        margin: 18px auto 16px;
      }}
      .side-nav-title,
      .side-nav-subtitle,
      .side-nav-copy {{
        opacity: 1;
        transform: none;
        pointer-events: auto;
      }}
      .side-nav-links {{
        flex-direction: row;
        flex-wrap: wrap;
      }}
      .side-nav-home,
      .side-nav-item {{
        flex: 1 1 220px;
      }}
      .insight-grid,
      .reading-grid,
      .case-insight-grid,
      .chart-grid,
      .chart-brief,
      .detail-grid,
      .detail-grid-2,
      .frame-meta-grid {{
        grid-template-columns: 1fr;
      }}
      .coverage-point-grid {{
        display: grid;
        grid-template-columns: 1fr;
      }}
      .coverage-point-grid > .coverage-point-card,
      .coverage-point-grid > .coverage-point-card:last-child:nth-child(odd) {{
        flex: none;
        max-width: none;
        width: 100%;
      }}
      .page-title-row {{
        align-items: flex-start;
      }}
      .case-purpose-pill {{
        border-radius: 18px;
      }}
      .reading-head {{
        align-items: flex-start;
        flex-direction: column;
      }}
    }}
  </style>
</head>
  <body>
  <div class="page-shell">
    {build_case_sidebar(case_data)}
    <div class="page-wrap">
    <section class="report-page hero" id="suite_top">
      <h1>{html.escape(title)}</h1>
      <div class="token-row">
        <span>Generated={html.escape(generated_at)}</span>
        <span>Requested Test={html.escape(testname)}</span>
        <span>Case Count={suite['total_cases']}</span>
        <span>Merged Coverage={pct_text(suite['suite_coverage_pct'])}</span>
      </div>
      <div class="metric-grid">{build_suite_cards(suite, case_data)}</div>
      <div class="section-block overview-block">
        <h3>Case Overview</h3>
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Case</th>
              <th>Status</th>
              <th>Case Coverage</th>
              <th>Checked Beats</th>
              <th>Errors</th>
              <th>RTL Error</th>
              <th>Ideal Avg Abs</th>
              <th>Ideal Max Abs</th>
              <th>Ideal Avg Rel</th>
              <th>Ideal Max Rel</th>
            </tr>
          </thead>
          <tbody>{build_case_overview_rows(case_data)}</tbody>
        </table>
      </div>
      <div class="chart-grid chart-grid-front">{front_charts}</div>
    </section>
    {case_sections}
    </div>
  </div>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime-root", required=True)
    parser.add_argument("--testname", required=True)
    args = parser.parse_args()

    runtime_root = Path(args.runtime_root)
    runtime_root.mkdir(parents=True, exist_ok=True)
    output_path = runtime_root / f"report_{sanitize_name(args.testname)}.html"
    output_path.write_text(generate_html(runtime_root, args.testname), encoding="utf-8")
    return 0


if __name__ == "__main__":
    main()
