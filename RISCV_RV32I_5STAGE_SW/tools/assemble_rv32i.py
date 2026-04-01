#!/usr/bin/env python3
"""Minimal RV32I assembler for the demo instruction ROM image.

This script intentionally supports only the instruction subset used by the
RISCV_32I_5STAGE_SW software demos. It converts a simple label-based assembly
file into a $readmemh-compatible hex ROM image.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from dataclasses import dataclass


REG_MAP = {
    "x0": 0,
    "zero": 0,
    "x1": 1,
    "ra": 1,
    "x2": 2,
    "sp": 2,
    "x3": 3,
    "gp": 3,
    "x4": 4,
    "tp": 4,
    "x5": 5,
    "t0": 5,
    "x6": 6,
    "t1": 6,
    "x7": 7,
    "t2": 7,
    "x8": 8,
    "s0": 8,
    "fp": 8,
    "x9": 9,
    "s1": 9,
    "x10": 10,
    "a0": 10,
    "x11": 11,
    "a1": 11,
    "x12": 12,
    "a2": 12,
    "x13": 13,
    "a3": 13,
    "x14": 14,
    "a4": 14,
    "x15": 15,
    "a5": 15,
    "x16": 16,
    "a6": 16,
    "x17": 17,
    "a7": 17,
    "x18": 18,
    "s2": 18,
    "x19": 19,
    "s3": 19,
    "x20": 20,
    "s4": 20,
    "x21": 21,
    "s5": 21,
    "x22": 22,
    "s6": 22,
    "x23": 23,
    "s7": 23,
    "x24": 24,
    "s8": 24,
    "x25": 25,
    "s9": 25,
    "x26": 26,
    "s10": 26,
    "x27": 27,
    "s11": 27,
    "x28": 28,
    "t3": 28,
    "x29": 29,
    "t4": 29,
    "x30": 30,
    "t5": 30,
    "x31": 31,
    "t6": 31,
}

OPCODES = {
    "load": 0b0000011,
    "opimm": 0b0010011,
    "jalr": 0b1100111,
    "store": 0b0100011,
    "rtype": 0b0110011,
    "lui": 0b0110111,
    "branch": 0b1100011,
    "jal": 0b1101111,
}


@dataclass(frozen=True)
class AsmLine:
    pc: int
    text: str
    lineno: int


def strip_comment(line: str) -> str:
    hash_idx = line.find("#")
    slash_idx = line.find("//")
    cut_idx = -1
    if hash_idx >= 0:
      cut_idx = hash_idx
    if slash_idx >= 0 and (cut_idx < 0 or slash_idx < cut_idx):
      cut_idx = slash_idx
    return line[:cut_idx] if cut_idx >= 0 else line


def parse_source(text: str) -> tuple[list[AsmLine], dict[str, int]]:
    labels: dict[str, int] = {}
    lines: list[AsmLine] = []
    pc = 0

    for lineno, raw_line in enumerate(text.splitlines(), start=1):
        line = strip_comment(raw_line).strip()
        if not line:
            continue

        while ":" in line:
            label, remainder = line.split(":", 1)
            label = label.strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", label):
                raise ValueError(f"line {lineno}: invalid label '{label}'")
            if label in labels:
                raise ValueError(f"line {lineno}: duplicate label '{label}'")
            labels[label] = pc
            line = remainder.strip()
            if not line:
                break

        if not line:
            continue

        lines.append(AsmLine(pc=pc, text=line, lineno=lineno))
        pc += 4

    return lines, labels


def parse_reg(token: str, lineno: int) -> int:
    reg_name = token.strip().lower()
    if reg_name not in REG_MAP:
        raise ValueError(f"line {lineno}: unknown register '{token}'")
    return REG_MAP[reg_name]


def parse_imm(token: str, lineno: int) -> int:
    token = token.strip()
    try:
        return int(token, 0)
    except ValueError as exc:
        raise ValueError(f"line {lineno}: invalid immediate '{token}'") from exc


def parse_offset_reg(token: str, lineno: int) -> tuple[int, int]:
    match = re.fullmatch(r"(.+)\(([^()]+)\)", token.replace(" ", ""))
    if not match:
        raise ValueError(f"line {lineno}: expected offset(base) operand, got '{token}'")
    offset_str, reg_str = match.groups()
    return parse_imm(offset_str, lineno), parse_reg(reg_str, lineno)


def encode_itype(imm: int, rs1: int, funct3: int, rd: int, opcode: int) -> int:
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_stype(imm: int, rs2: int, rs1: int, funct3: int, opcode: int) -> int:
    imm12 = imm & 0xFFF
    return (
        ((imm12 >> 5) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | ((imm12 & 0x1F) << 7)
        | opcode
    )


def encode_rtype(funct7: int, rs2: int, rs1: int, funct3: int, rd: int, opcode: int) -> int:
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_utype(imm20: int, rd: int, opcode: int) -> int:
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | opcode


def encode_btype(offset: int, rs2: int, rs1: int, funct3: int, opcode: int) -> int:
    imm13 = offset & 0x1FFF
    bit12 = (imm13 >> 12) & 0x1
    bit11 = (imm13 >> 11) & 0x1
    bits10_5 = (imm13 >> 5) & 0x3F
    bits4_1 = (imm13 >> 1) & 0xF
    return (
        (bit12 << 31)
        | (bits10_5 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (bits4_1 << 8)
        | (bit11 << 7)
        | opcode
    )


def encode_jtype(offset: int, rd: int, opcode: int) -> int:
    imm21 = offset & 0x1FFFFF
    bit20 = (imm21 >> 20) & 0x1
    bits19_12 = (imm21 >> 12) & 0xFF
    bit11 = (imm21 >> 11) & 0x1
    bits10_1 = (imm21 >> 1) & 0x3FF
    return (
        (bit20 << 31)
        | (bits19_12 << 12)
        | (bit11 << 20)
        | (bits10_1 << 21)
        | (rd << 7)
        | opcode
    )


def require_range(value: int, min_value: int, max_value: int, lineno: int, name: str) -> None:
    if value < min_value or value > max_value:
        raise ValueError(
            f"line {lineno}: {name} {value} out of range [{min_value}, {max_value}]"
        )


def parse_branch_target(token: str, labels: dict[str, int], pc: int, lineno: int) -> int:
    if token not in labels:
        raise ValueError(f"line {lineno}: unknown label '{token}'")
    offset = labels[token] - pc
    if offset & 0x1:
        raise ValueError(f"line {lineno}: branch target '{token}' is not 2-byte aligned")
    require_range(offset, -4096, 4094, lineno, "branch offset")
    return offset


def parse_jump_target(token: str, labels: dict[str, int], pc: int, lineno: int) -> int:
    if token not in labels:
        raise ValueError(f"line {lineno}: unknown label '{token}'")
    offset = labels[token] - pc
    if offset & 0x1:
        raise ValueError(f"line {lineno}: jump target '{token}' is not 2-byte aligned")
    require_range(offset, -(1 << 20), (1 << 20) - 2, lineno, "jump offset")
    return offset


def assemble_line(line: AsmLine, labels: dict[str, int]) -> int:
    parts = line.text.split(None, 1)
    mnemonic = parts[0].lower()
    operands = []
    if len(parts) > 1:
        operands = [operand.strip() for operand in parts[1].split(",")]

    if mnemonic == "addi":
        rd, rs1, imm = operands
        imm_val = parse_imm(imm, line.lineno)
        require_range(imm_val, -2048, 2047, line.lineno, "addi immediate")
        return encode_itype(imm_val, parse_reg(rs1, line.lineno), 0b000, parse_reg(rd, line.lineno), OPCODES["opimm"])

    if mnemonic == "andi":
        rd, rs1, imm = operands
        imm_val = parse_imm(imm, line.lineno)
        require_range(imm_val, -2048, 2047, line.lineno, "andi immediate")
        return encode_itype(imm_val, parse_reg(rs1, line.lineno), 0b111, parse_reg(rd, line.lineno), OPCODES["opimm"])

    if mnemonic == "slli":
        rd, rs1, shamt = operands
        shamt_val = parse_imm(shamt, line.lineno)
        require_range(shamt_val, 0, 31, line.lineno, "slli shamt")
        return encode_itype(shamt_val, parse_reg(rs1, line.lineno), 0b001, parse_reg(rd, line.lineno), OPCODES["opimm"])

    if mnemonic == "lw":
        rd, offset_base = operands
        offset, rs1 = parse_offset_reg(offset_base, line.lineno)
        require_range(offset, -2048, 2047, line.lineno, "lw offset")
        return encode_itype(offset, rs1, 0b010, parse_reg(rd, line.lineno), OPCODES["load"])

    if mnemonic == "jalr":
        rd, offset_base = operands
        offset, rs1 = parse_offset_reg(offset_base, line.lineno)
        require_range(offset, -2048, 2047, line.lineno, "jalr offset")
        return encode_itype(offset, rs1, 0b000, parse_reg(rd, line.lineno), OPCODES["jalr"])

    if mnemonic == "sw":
        rs2, offset_base = operands
        offset, rs1 = parse_offset_reg(offset_base, line.lineno)
        require_range(offset, -2048, 2047, line.lineno, "sw offset")
        return encode_stype(offset, parse_reg(rs2, line.lineno), rs1, 0b010, OPCODES["store"])

    if mnemonic == "add":
        rd, rs1, rs2 = operands
        return encode_rtype(0b0000000, parse_reg(rs2, line.lineno), parse_reg(rs1, line.lineno), 0b000, parse_reg(rd, line.lineno), OPCODES["rtype"])

    if mnemonic == "sub":
        rd, rs1, rs2 = operands
        return encode_rtype(0b0100000, parse_reg(rs2, line.lineno), parse_reg(rs1, line.lineno), 0b000, parse_reg(rd, line.lineno), OPCODES["rtype"])

    if mnemonic == "lui":
        rd, imm20 = operands
        imm20_val = parse_imm(imm20, line.lineno)
        require_range(imm20_val, 0, 0xFFFFF, line.lineno, "lui immediate")
        return encode_utype(imm20_val, parse_reg(rd, line.lineno), OPCODES["lui"])

    if mnemonic in {"beq", "bne", "blt", "bge", "bltu", "bgeu"}:
        funct3 = {
            "beq": 0b000,
            "bne": 0b001,
            "blt": 0b100,
            "bge": 0b101,
            "bltu": 0b110,
            "bgeu": 0b111,
        }[mnemonic]
        rs1, rs2, target = operands
        offset = parse_branch_target(target, labels, line.pc, line.lineno)
        return encode_btype(offset, parse_reg(rs2, line.lineno), parse_reg(rs1, line.lineno), funct3, OPCODES["branch"])

    if mnemonic == "jal":
        rd, target = operands
        offset = parse_jump_target(target, labels, line.pc, line.lineno)
        return encode_jtype(offset, parse_reg(rd, line.lineno), OPCODES["jal"])

    raise ValueError(f"line {line.lineno}: unsupported mnemonic '{mnemonic}'")


def assemble_text(text: str) -> list[tuple[AsmLine, int]]:
    lines, labels = parse_source(text)
    return [(line, assemble_line(line, labels)) for line in lines]


def build_mem_text(entries: list[tuple[AsmLine, int]]) -> str:
    output_lines = [
        "// ============================================================================",
        "// Auto-generated by tools/assemble_rv32i.py",
        "// ============================================================================",
        "",
    ]
    for line, instr in entries:
        output_lines.append(f"{instr:08x} // PC={line.pc:03d} {line.text}")
    output_lines.append("")
    return "\n".join(output_lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Assemble a minimal RV32I demo source into a .mem ROM image")
    parser.add_argument("src", nargs="?", default="src/InstructionFORTIMING.s")
    parser.add_argument("dst", nargs="?", default="src/InstructionFORTIMING.mem")
    args = parser.parse_args()

    src_path = pathlib.Path(args.src)
    dst_path = pathlib.Path(args.dst)

    source_text = src_path.read_text(encoding="utf-8")
    entries = assemble_text(source_text)
    mem_text = build_mem_text(entries)
    dst_path.write_text(mem_text, encoding="utf-8")

    print(f"Assembled {len(entries)} instructions: {src_path} -> {dst_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
