#!/usr/bin/env python3
"""Frame-level golden model for SOFTMAX_ACC TOP."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def signed16(value: int) -> int:
    value &= 0xFFFF
    return value - 0x10000 if value & 0x8000 else value


def sat16(value: int) -> int:
    if value > 32767:
        return 32767
    if value < -32768:
        return -32768
    return value


def highest_set_bit(value: int) -> int:
    if value == 0:
        return 0
    return value.bit_length() - 1


def parse_decimal_case_table(path: Path, addr_width: int) -> dict[int, int]:
    text = path.read_text(encoding="utf-8")
    table: dict[int, int] = {}
    pattern = re.compile(rf"{addr_width}'d(\d+):\s*oData\s*=\s*(-)?16'sd(\d+);")
    for match in pattern.finditer(text):
        index = int(match.group(1))
        value = int(match.group(3))
        if match.group(2):
            value = -value
        table[index] = value
    return table


def parse_unsigned_decimal_case_table(path: Path, addr_width: int) -> dict[int, int]:
    text = path.read_text(encoding="utf-8")
    table: dict[int, int] = {}
    pattern = re.compile(rf"{addr_width}'d(\d+):\s*oData\s*=\s*16'd(\d+);")
    for match in pattern.finditer(text):
        table[int(match.group(1))] = int(match.group(2))
    return table


def parse_exp_luts(path: Path) -> tuple[dict[int, int], dict[int, int], dict[int, int]]:
    text = path.read_text(encoding="utf-8")
    tables = {"lutCoeffHigh": {}, "lutCoeffMid": {}, "lutCoeffLow": {}}
    pattern = re.compile(r"4'b([01]{4}):\s*(lutCoeffHigh|lutCoeffMid|lutCoeffLow)\s*=\s*16'h([0-9A-Fa-f]+);")
    for bits, name, hex_value in pattern.findall(text):
        tables[name][int(bits, 2)] = int(hex_value, 16)
    return tables["lutCoeffHigh"], tables["lutCoeffMid"], tables["lutCoeffLow"]


class RtlModel:
    def __init__(self, src_dir: Path) -> None:
        self.exp_high, self.exp_mid, self.exp_low = parse_exp_luts(src_dir / "ExpSum.v")
        self.ln_exp = parse_decimal_case_table(src_dir / "LnExp.v", 5)
        self.ln_mant = parse_unsigned_decimal_case_table(src_dir / "LnMant.v", 10)

    @staticmethod
    def fp32_to_q78(value: int) -> int:
        is_negative = (value >> 31) & 0x1
        exponent = (value >> 23) & 0xFF
        mantissa = value & 0x7FFFFF
        mant_with_hidden = (1 << 23) | mantissa
        shift_bias = 127 + 23 - 8

        if exponent == 0xFF:
            return -32768 if is_negative else 32767
        if exponent == 0:
            return 0

        shift = exponent - shift_bias
        if shift >= 0:
            scaled_abs = 0x7FFFFFFF if shift > 31 else mant_with_hidden << shift
        else:
            right_shift = -shift
            if right_shift >= 32:
                scaled_abs = 0
            elif right_shift == 0:
                scaled_abs = mant_with_hidden
            else:
                scaled_abs = (mant_with_hidden + (1 << (right_shift - 1))) >> right_shift

        scaled_value = -scaled_abs if is_negative else scaled_abs
        return sat16(scaled_value)

    @staticmethod
    def q78_sub_sat(data_a: int, data_b: int) -> int:
        return sat16(signed16(data_a) - signed16(data_b))

    @staticmethod
    def abs_sat_q78(value: int) -> int:
        signed_value = signed16(value)
        abs_value = abs(signed_value)
        return min(abs_value, 0x7FFF)

    def exp_approx(self, value: int) -> int:
        abs_value = self.abs_sat_q78(value)
        high_coeff_en = ((abs_value >> 12) & 0x7) == 0
        coeff_high = self.exp_high.get((abs_value >> 8) & 0xF, 0xFFFF) if high_coeff_en else 0
        coeff_mid = self.exp_mid.get((abs_value >> 4) & 0xF, 0xFFFF)
        coeff_low = self.exp_low.get(abs_value & 0xF, 0xFFFF)
        prod_mid_low = coeff_mid * coeff_low
        prod_high_scale = coeff_high * ((prod_mid_low >> 16) & 0xFFFF)
        return (prod_high_scale >> 16) & 0xFFFF

    def ln_approx(self, value: int) -> int:
        if value == 0:
            exp_addr = 0
            mant_addr = 0
        else:
            msb_idx = highest_set_bit(value & 0xFFFF)
            exp_addr = msb_idx + 10
            norm_shift = (value & 0xFFFF) << (15 - msb_idx)
            mant_addr = (norm_shift >> 5) & 0x3FF

        ln_exp_term = self.ln_exp[exp_addr]
        ln_mant_term = self.ln_mant[mant_addr]
        ln_sum_q4p16 = (ln_exp_term << 5) + ln_mant_term
        ln_round_q78 = (ln_sum_q4p16 >> 8) + ((ln_sum_q4p16 >> 7) & 0x1)
        return signed16(ln_round_q78)

    @staticmethod
    def u16_to_fp32(value: int) -> int:
        value &= 0xFFFF
        if value == 0:
            return 0
        msb_idx = highest_set_bit(value)
        exponent = msb_idx + (127 - 16)
        norm_shift = (value << (15 - msb_idx)) & 0xFFFF
        fraction = ((norm_shift & 0x7FFF) << 8) & 0x7FFFFF
        return (exponent << 23) | fraction

    def process_frame(self, frame: dict[str, object]) -> dict[str, object]:
        input_values = [int(token, 16) for token in str(frame["data_hex_csv"]).split(",") if token]
        keep_values = [int(token, 16) for token in str(frame["keep_hex_csv"]).split(",") if token]

        q78_inputs = [self.fp32_to_q78(value) for value in input_values]
        q78_max = max(q78_inputs) if q78_inputs else 0
        downscale = [self.q78_sub_sat(value, q78_max) for value in q78_inputs]
        exp_sum_values = [self.exp_approx(value) for value in downscale]
        sum_acc = sum(exp_sum_values)
        sum_q78 = ((sum_acc + 1024) >> 11) & 0xFFFF
        scalar_q78 = self.ln_approx(sum_q78)
        sub_values = [self.q78_sub_sat(value, scalar_q78) for value in downscale]
        exp_out_values = [self.exp_approx(value) for value in sub_values]
        output_values = [self.u16_to_fp32(value) for value in exp_out_values]

        argmax_value = max(q78_inputs) if q78_inputs else 0
        quantized_argmax_set = [idx for idx, value in enumerate(q78_inputs) if value == argmax_value]

        return {
            "frame_id": int(frame["frame_id"]),
            "scenario": frame["scenario"],
            "input_class": frame["input_class"],
            "in_stall": frame["in_stall"],
            "out_stall": frame["out_stall"],
            "keep_kind": frame["keep_kind"],
            "result_kind": frame["result_kind"],
            "reset_phase": frame["reset_phase"],
            "term_kind": frame["term_kind"],
            "post_term_rearm": frame["post_term_rearm"],
            "special_kind": frame["special_kind"],
            "reset_epoch": int(frame["reset_epoch"]),
            "scalar_q78": signed16(scalar_q78),
            "sum_q78": signed16(sum_q78),
            "raw_argmax": quantized_argmax_set[0] if quantized_argmax_set else 0,
            "argmax_csv": ",".join(str(idx) for idx in quantized_argmax_set),
            "input_hex_csv": ",".join(f"{value:08x}" for value in input_values),
            "output_hex_csv": ",".join(f"{value:08x}" for value in output_values),
            "keep_hex_csv": ",".join("f" for _ in output_values),
            "input_keep_hex_csv": ",".join(f"{value:01x}" for value in keep_values),
        }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--in", dest="input_path", required=True)
    parser.add_argument("--out", dest="output_path", required=True)
    parser.add_argument("--policy", required=True)
    args = parser.parse_args()

    if args.policy != "rtl_saturate":
        raise SystemExit(f"Unsupported policy: {args.policy}")

    input_path = Path(args.input_path)
    output_path = Path(args.output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    project_root = Path(__file__).resolve().parents[3]
    model = RtlModel(project_root / "src")

    frames = []
    if input_path.exists():
        for line in input_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            frames.append(json.loads(line))

    with output_path.open("w", encoding="utf-8") as handle:
        for frame in frames:
            handle.write(json.dumps(model.process_frame(frame), separators=(",", ":")) + "\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
