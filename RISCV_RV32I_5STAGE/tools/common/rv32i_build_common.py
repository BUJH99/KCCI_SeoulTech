"""Shared helpers for RV32I firmware build scripts."""

from __future__ import annotations

from pathlib import Path
import hashlib
import math
import os
import shutil
import subprocess
import sys


TOOL_PREFIXES = (
    "riscv64-unknown-elf",
    "riscv32-unknown-elf",
    "riscv32-elf",
    "riscv32-amd-linux",
)

ALLOWED_MNEMONICS = {
    "lui", "auipc", "jal", "jalr",
    "beq", "bne", "blt", "bge", "bltu", "bgeu",
    "lb", "lh", "lw", "lbu", "lhu",
    "sb", "sh", "sw",
    "addi", "slti", "sltiu", "xori", "ori", "andi",
    "slli", "srli", "srai",
    "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and",
    "fence", "ecall", "ebreak",
    "csrrw", "csrrs", "csrrc", "csrrwi", "csrrsi", "csrrci", "mret",
    "li", "mv", "j", "jr", "ret", "call", "beqz", "bnez", ".word",
    "csrw", "csrs", "csrc", "csrr", "not", "neg", "zext.b",
}


def is_wsl() -> bool:
    try:
        return "microsoft" in Path("/proc/version").read_text(encoding="utf-8").lower()
    except OSError:
        return False


def to_tool_path(path: Path | str, windows_tool: bool) -> str:
    path_str = str(path)
    if windows_tool and is_wsl():
        return subprocess.check_output(["wslpath", "-w", path_str], text=True).strip()
    return path_str


def which_tool(name: str) -> Path | None:
    found = shutil.which(name)
    if found:
        return Path(found)
    if os.name != "nt":
        found_exe = shutil.which(f"{name}.exe")
        if found_exe:
            return Path(found_exe)
    return None


def find_toolchain() -> dict[str, Path]:
    env_gcc = os.environ.get("RISCV_GCC")
    if env_gcc:
        gcc = Path(env_gcc)
        prefix = gcc.name
        for suffix in ("-gcc.exe", "-gcc"):
            if prefix.endswith(suffix):
                prefix = prefix[: -len("-gcc.exe" if suffix.endswith(".exe") else "-gcc")]
                break
        bindir = gcc.parent
        exe = ".exe" if gcc.suffix.lower() == ".exe" else ""
        tools = {
            "gcc": gcc,
            "objcopy": bindir / f"{prefix}-objcopy{exe}",
            "objdump": bindir / f"{prefix}-objdump{exe}",
            "readelf": bindir / f"{prefix}-readelf{exe}",
            "size": bindir / f"{prefix}-size{exe}",
            "nm": bindir / f"{prefix}-nm{exe}",
        }
        if all(path.exists() for path in tools.values()):
            return tools

    for prefix in TOOL_PREFIXES:
        tools = {
            "gcc": which_tool(f"{prefix}-gcc"),
            "objcopy": which_tool(f"{prefix}-objcopy"),
            "objdump": which_tool(f"{prefix}-objdump"),
            "readelf": which_tool(f"{prefix}-readelf"),
            "size": which_tool(f"{prefix}-size"),
            "nm": which_tool(f"{prefix}-nm"),
        }
        if all(tools.values()):
            return {key: Path(value) for key, value in tools.items() if value is not None}

    raise SystemExit(
        "[FAIL] No usable RISC-V GCC toolchain found. Set RISCV_GCC or add a "
        "riscv32/riscv64 bare-metal compatible GCC to PATH."
    )


def run(cmd: list[str], *, stdout_path: Path | None = None) -> str:
    if stdout_path is None:
        completed = subprocess.run(cmd, text=True, capture_output=True)
    else:
        with stdout_path.open("w", encoding="utf-8", newline="\n") as out_file:
            completed = subprocess.run(cmd, text=True, stdout=out_file, stderr=subprocess.PIPE)

    if completed.returncode != 0:
        if completed.stdout:
            print(completed.stdout, end="")
        if completed.stderr:
            print(completed.stderr, end="", file=sys.stderr)
        raise SystemExit(f"[FAIL] Command failed: {' '.join(cmd)}")

    return completed.stdout or ""


def parse_size_sections(size_output: str) -> dict[str, int]:
    sections: dict[str, int] = {}
    for line in size_output.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].startswith("."):
            try:
                sections[parts[0]] = int(parts[1], 10)
            except ValueError:
                continue
    return sections


def section_size(size_output: str, section: str) -> int:
    return parse_size_sections(size_output).get(section, 0)


def write_mem_file(binary: bytes, mem_path: Path) -> tuple[int, str]:
    words = max(1, math.ceil(len(binary) / 4))
    padded = bytearray(binary)
    while len(padded) < words * 4:
        padded.extend(b"\x13\x00\x00\x00")

    mem_path.parent.mkdir(parents=True, exist_ok=True)
    with mem_path.open("w", encoding="utf-8", newline="\n") as mem_file:
        for idx in range(words):
            word = int.from_bytes(padded[idx * 4 : idx * 4 + 4], "little")
            mem_file.write(f"{word:08x}\n")

    digest = hashlib.sha256(mem_path.read_bytes()).hexdigest()
    return words, digest


def audit_disassembly(disassembly: str) -> None:
    unsupported: list[str] = []
    for line in disassembly.splitlines():
        stripped = line.strip()
        if ":\t" not in stripped:
            continue
        parts = stripped.split("\t")
        if len(parts) < 3:
            continue
        mnemonic = parts[2].split()[0]
        if mnemonic not in ALLOWED_MNEMONICS:
            unsupported.append(stripped)

    if unsupported:
        print("[FAIL] Unsupported instruction(s) emitted by firmware build:")
        for line in unsupported[:40]:
            print(f"  {line}")
        if len(unsupported) > 40:
            print(f"  ... {len(unsupported) - 40} more")
        raise SystemExit(1)
