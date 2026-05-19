#!/usr/bin/env python3
"""Generate deterministic RV32I instruction images for the instruction-memory sweep."""

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Any

NOP = 0x00000013
CANONICAL_SIZE_BYTES = 32 * 1024
CANONICAL_WORDS = CANONICAL_SIZE_BYTES // 4
KERNEL_REGION_BYTES = 4 * 1024
KERNEL_REGION_WORDS = KERNEL_REGION_BYTES // 4
PRBS_FILLER_SEED = 0x1BAD_C0DE


@dataclass(frozen=True)
class ProgramMetadata:
    benchmark_mode: str
    content_classification: str
    executable_kernel_words: int
    filler_start_word: int
    filler_mode: str
    filler_seed: int | None
    pure_same_program_capacity: bool
    high_entropy_capacity: bool
    wns_valid_for_pure_size_scaling: bool
    wns_valid_for_workload_stress: bool
    tail_type: str
    tail_is_all_nop: bool
    tail_is_fixed_seed_filler: bool
    tail_position_dependent: bool


def _bits(value: int, width: int) -> int:
    return value & ((1 << width) - 1)


def addi(rd: int, rs1: int, imm: int) -> int:
    return (_bits(imm, 12) << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0x13


def xori(rd: int, rs1: int, imm: int) -> int:
    return (_bits(imm, 12) << 20) | (rs1 << 15) | (0b100 << 12) | (rd << 7) | 0x13


def ori(rd: int, rs1: int, imm: int) -> int:
    return (_bits(imm, 12) << 20) | (rs1 << 15) | (0b110 << 12) | (rd << 7) | 0x13


def andi(rd: int, rs1: int, imm: int) -> int:
    return (_bits(imm, 12) << 20) | (rs1 << 15) | (0b111 << 12) | (rd << 7) | 0x13


def slli(rd: int, rs1: int, shamt: int) -> int:
    return ((shamt & 0x1F) << 20) | (rs1 << 15) | (0b001 << 12) | (rd << 7) | 0x13


def srli(rd: int, rs1: int, shamt: int) -> int:
    return ((shamt & 0x1F) << 20) | (rs1 << 15) | (0b101 << 12) | (rd << 7) | 0x13


def rtype(rd: int, rs1: int, rs2: int, *, funct3: int, funct7: int = 0) -> int:
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x33


def lw(rd: int, rs1: int, imm: int) -> int:
    return (_bits(imm, 12) << 20) | (rs1 << 15) | (0b010 << 12) | (rd << 7) | 0x03


def sw(rs2: int, rs1: int, imm: int) -> int:
    imm12 = _bits(imm, 12)
    return ((imm12 >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) | ((imm12 & 0x1F) << 7) | 0x23


def branch(rs1: int, rs2: int, offset: int, *, funct3: int) -> int:
    imm = _bits(offset, 13)
    bit12 = (imm >> 12) & 0x1
    bit11 = (imm >> 11) & 0x1
    bits10_5 = (imm >> 5) & 0x3F
    bits4_1 = (imm >> 1) & 0xF
    return (
        (bit12 << 31)
        | (bits10_5 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (bits4_1 << 8)
        | (bit11 << 7)
        | 0x63
    )


def beq(rs1: int, rs2: int, offset: int) -> int:
    return branch(rs1, rs2, offset, funct3=0b000)


def bne(rs1: int, rs2: int, offset: int) -> int:
    return branch(rs1, rs2, offset, funct3=0b001)


def jal(rd: int, offset: int) -> int:
    imm = _bits(offset, 21)
    bit20 = (imm >> 20) & 0x1
    bits10_1 = (imm >> 1) & 0x3FF
    bit11 = (imm >> 11) & 0x1
    bits19_12 = (imm >> 12) & 0xFF
    return (bit20 << 31) | (bits10_1 << 21) | (bit11 << 20) | (bits19_12 << 12) | (rd << 7) | 0x6F


def linear_sweep(count: int) -> list[int]:
    pattern = [
        addi(1, 1, 1),
        addi(2, 1, 7),
        sw(2, 0, 0),
        lw(3, 0, 0),
        addi(4, 3, -3),
        beq(0, 1, 8),
        addi(5, 5, 1),
        addi(6, 6, -1),
    ]
    return [pattern[idx % len(pattern)] for idx in range(count)]


def branch_loop(count: int) -> list[int]:
    words: list[int] = []
    while len(words) < count:
        loop_start = len(words)
        words.extend(
            [
                addi(1, 0, 0),
                addi(2, 0, 8),
                addi(1, 1, 1),
                sw(1, 0, 4),
                lw(3, 0, 4),
                bne(1, 2, -12),
                addi(4, 4, 1),
                beq(0, 0, 8),
                addi(5, 5, 1),
                addi(6, 6, 1),
            ]
        )
        if len(words) == loop_start:
            break
    return words[:count]


def mixed_firmware(count: int) -> list[int]:
    words: list[int] = []
    while len(words) < count:
        base = len(words)
        words.extend(
            [
                addi(10, 0, (base // 4) & 0x7F),
                addi(11, 10, 3),
                sw(11, 0, 8),
                lw(12, 0, 8),
                beq(12, 11, 8),
                addi(13, 13, 1),
                jal(0, 8),
                addi(14, 14, -1),
                addi(15, 15, 1),
                bne(15, 10, 8),
                addi(16, 16, 2),
                sw(16, 0, 12),
            ]
        )
    return words[:count]


def fixed_executable_kernel() -> list[int]:
    """Small fixed RV32I kernel; addresses and branch targets do not depend on image size."""

    return [
        addi(1, 0, 0),      # loop counter
        addi(2, 0, 16),     # deterministic trip count
        addi(3, 0, 0),      # arithmetic accumulator
        addi(3, 3, 1),
        sw(3, 0, 0),
        lw(4, 0, 0),
        addi(1, 1, 1),
        bne(1, 2, -16),     # back to accumulator update at word 3
        addi(5, 5, 1),
        jal(0, -36),        # restart at reset vector word 0
    ]


def _xorshift32(value: int) -> int:
    value &= 0xFFFF_FFFF
    value ^= (value << 13) & 0xFFFF_FFFF
    value ^= value >> 17
    value ^= (value << 5) & 0xFFFF_FFFF
    return value & 0xFFFF_FFFF


def _legal_prbs_word(index: int, state: int) -> int:
    rd = (state >> 0) & 0x1F
    rs1 = (state >> 5) & 0x1F
    rs2 = (state >> 10) & 0x1F
    imm = (state >> 15) & 0xFFF
    shamt = (state >> 20) & 0x1F
    op = (state >> 27) % 8
    if op == 0:
        return addi(rd, rs1, imm)
    if op == 1:
        return xori(rd, rs1, imm)
    if op == 2:
        return ori(rd, rs1, imm)
    if op == 3:
        return andi(rd, rs1, imm)
    if op == 4:
        return slli(rd, rs1, shamt)
    if op == 5:
        return srli(rd, rs1, shamt)
    if op == 6:
        return rtype(rd, rs1, rs2, funct3=(index & 0x7), funct7=0)
    return rtype(rd, rs1, rs2, funct3=0, funct7=0x20)


def _toggle_word(index: int) -> int:
    rd = (index % 31) + 1
    rs1 = ((index * 3) % 31) + 1
    rs2 = ((index * 7) % 31) + 1
    imm = ((index * 0x155) ^ 0x5A5) & 0xFFF
    op = index % 8
    if op == 0:
        return addi(rd, rs1, imm)
    if op == 1:
        return xori(rd, rs1, imm ^ 0xFFF)
    if op == 2:
        return ori(rd, rs1, imm)
    if op == 3:
        return andi(rd, rs1, imm ^ 0xAAA)
    if op == 4:
        return slli(rd, rs1, index & 0x1F)
    if op == 5:
        return srli(rd, rs1, (31 - index) & 0x1F)
    if op == 6:
        return rtype(rd, rs1, rs2, funct3=0b100, funct7=0)
    return rtype(rd, rs1, rs2, funct3=0b111, funct7=0)


def _capacity_prefix(filler: list[int]) -> list[int]:
    kernel = fixed_executable_kernel()
    if len(kernel) > KERNEL_REGION_WORDS:
        raise ValueError("fixed executable kernel must fit inside 4KB")
    prefix = kernel + [NOP] * (KERNEL_REGION_WORDS - len(kernel))
    return prefix + filler


def ifetch_capacity_nop(count: int) -> list[int]:
    filler = [NOP] * (CANONICAL_WORDS - KERNEL_REGION_WORDS)
    return _capacity_prefix(filler)[:count]


def ifetch_capacity_prbs(count: int) -> list[int]:
    state = PRBS_FILLER_SEED
    filler: list[int] = []
    for index in range(CANONICAL_WORDS - KERNEL_REGION_WORDS):
        state = _xorshift32(state)
        filler.append(_legal_prbs_word(index, state))
    return _capacity_prefix(filler)[:count]


def ifetch_capacity_toggle(count: int) -> list[int]:
    filler = [_toggle_word(index) for index in range(CANONICAL_WORDS - KERNEL_REGION_WORDS)]
    return _capacity_prefix(filler)[:count]


PROGRAM_BUILDERS: dict[str, Callable[[int], list[int]]] = {
    "linear_sweep": linear_sweep,
    "branch_loop": branch_loop,
    "mixed_firmware": mixed_firmware,
    "ifetch_capacity_nop": ifetch_capacity_nop,
    "ifetch_capacity_prbs": ifetch_capacity_prbs,
    "ifetch_capacity_toggle": ifetch_capacity_toggle,
}


def capacity_programs() -> set[str]:
    return {"ifetch_capacity_nop", "ifetch_capacity_prbs", "ifetch_capacity_toggle"}


def generate(program: str, size_bytes: int) -> list[int]:
    if size_bytes % 4 != 0:
        raise ValueError("size_bytes must be a multiple of 4")
    if size_bytes <= 0:
        raise ValueError("size_bytes must be positive")
    if size_bytes > CANONICAL_SIZE_BYTES:
        raise ValueError(f"size_bytes must be <= canonical max {CANONICAL_SIZE_BYTES}")
    if program not in PROGRAM_BUILDERS:
        raise ValueError(f"unsupported program: {program}")
    if program in capacity_programs():
        words = PROGRAM_BUILDERS[program](CANONICAL_WORDS)[: size_bytes // 4]
    else:
        words = PROGRAM_BUILDERS[program](size_bytes // 4)
    if len(words) != size_bytes // 4:
        raise ValueError(f"{program} generated {len(words)} words, expected {size_bytes // 4}")
    return words


def metadata_for_program(program: str, size_bytes: int | None = None) -> ProgramMetadata:
    if program == "ifetch_capacity_nop":
        return ProgramMetadata(
            benchmark_mode=program,
            content_classification="pure_same_program_capacity",
            executable_kernel_words=len(fixed_executable_kernel()),
            filler_start_word=KERNEL_REGION_WORDS,
            filler_mode="nop",
            filler_seed=None,
            pure_same_program_capacity=True,
            high_entropy_capacity=False,
            wns_valid_for_pure_size_scaling=True,
            wns_valid_for_workload_stress=False,
            tail_type="nop",
            tail_is_all_nop=True,
            tail_is_fixed_seed_filler=False,
            tail_position_dependent=False,
        )
    if program == "ifetch_capacity_prbs":
        return ProgramMetadata(
            benchmark_mode=program,
            content_classification="high_entropy_capacity",
            executable_kernel_words=len(fixed_executable_kernel()),
            filler_start_word=KERNEL_REGION_WORDS,
            filler_mode="fixed_seed_prbs_legal_rv32i",
            filler_seed=PRBS_FILLER_SEED,
            pure_same_program_capacity=False,
            high_entropy_capacity=True,
            wns_valid_for_pure_size_scaling=True,
            wns_valid_for_workload_stress=False,
            tail_type="fixed_seed_filler",
            tail_is_all_nop=False,
            tail_is_fixed_seed_filler=True,
            tail_position_dependent=False,
        )
    if program == "ifetch_capacity_toggle":
        return ProgramMetadata(
            benchmark_mode=program,
            content_classification="address_toggle_capacity",
            executable_kernel_words=len(fixed_executable_kernel()),
            filler_start_word=KERNEL_REGION_WORDS,
            filler_mode="address_index_toggle_legal_rv32i",
            filler_seed=None,
            pure_same_program_capacity=False,
            high_entropy_capacity=False,
            wns_valid_for_pure_size_scaling=True,
            wns_valid_for_workload_stress=False,
            tail_type="address_toggle_legal_rv32i_filler",
            tail_is_all_nop=False,
            tail_is_fixed_seed_filler=False,
            tail_position_dependent=False,
        )
    if program == "mixed_firmware":
        return ProgramMetadata(
            benchmark_mode=program,
            content_classification="mixed_content_expansion",
            executable_kernel_words=0,
            filler_start_word=0,
            filler_mode="active_mixed_firmware",
            filler_seed=None,
            pure_same_program_capacity=False,
            high_entropy_capacity=False,
            wns_valid_for_pure_size_scaling=False,
            wns_valid_for_workload_stress=True,
            tail_type="active_mixed_firmware",
            tail_is_all_nop=False,
            tail_is_fixed_seed_filler=False,
            tail_position_dependent=True,
        )
    return ProgramMetadata(
        benchmark_mode=program,
        content_classification="legacy_active_program",
        executable_kernel_words=0,
        filler_start_word=0,
        filler_mode="active_program",
        filler_seed=None,
        pure_same_program_capacity=False,
        high_entropy_capacity=False,
        wns_valid_for_pure_size_scaling=False,
        wns_valid_for_workload_stress=True,
        tail_type="active_program",
        tail_is_all_nop=False,
        tail_is_fixed_seed_filler=False,
        tail_position_dependent=False,
    )


def sha256_words(words: list[int]) -> str:
    text = "\n".join(f"{word:08x}" for word in words) + "\n"
    return hashlib.sha256(text.encode("ascii")).hexdigest()


def write_mem(path: Path, words: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(f"{word:08x}" for word in words) + "\n", encoding="ascii")


def metadata_dict(program: str, size_bytes: int, words: list[int], output: Path) -> dict[str, Any]:
    meta = metadata_for_program(program, size_bytes)
    result = {
        "program": program,
        "benchmark_mode": meta.benchmark_mode,
        "content_classification": meta.content_classification,
        "size_bytes": size_bytes,
        "instruction_count": len(words),
        "canonical_size_bytes": CANONICAL_SIZE_BYTES,
        "canonical_words": CANONICAL_WORDS,
        "executable_kernel_words": meta.executable_kernel_words,
        "filler_start_word": meta.filler_start_word,
        "filler_mode": meta.filler_mode,
        "filler_seed": meta.filler_seed,
        "tail_type": meta.tail_type,
        "tail_is_all_nop": meta.tail_is_all_nop,
        "tail_is_fixed_seed_filler": meta.tail_is_fixed_seed_filler,
        "tail_position_dependent": meta.tail_position_dependent,
        "wns_valid_for_pure_size_scaling": meta.wns_valid_for_pure_size_scaling,
        "wns_valid_for_workload_stress": meta.wns_valid_for_workload_stress,
        "sha256": sha256_words(words),
        "output": str(output),
    }
    if program in capacity_programs() and size_bytes > KERNEL_REGION_BYTES:
        previous = generate(program, size_bytes - 1024)
        result["adjacent_prefix_preserved"] = words[: len(previous)] == previous
        result["increment_words_from_previous_1kb"] = len(words) - len(previous)
    else:
        result["adjacent_prefix_preserved"] = True
        result["increment_words_from_previous_1kb"] = None
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--program", required=True, choices=sorted(PROGRAM_BUILDERS))
    parser.add_argument("--size-bytes", required=True, type=int)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--metadata", type=Path)
    args = parser.parse_args()

    words = generate(args.program, args.size_bytes)
    write_mem(args.output, words)
    if args.metadata:
        args.metadata.parent.mkdir(parents=True, exist_ok=True)
        args.metadata.write_text(
            json.dumps(metadata_dict(args.program, args.size_bytes, words, args.output), indent=2) + "\n",
            encoding="utf-8",
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
