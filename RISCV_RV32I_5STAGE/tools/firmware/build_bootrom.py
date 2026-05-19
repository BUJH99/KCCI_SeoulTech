#!/usr/bin/env python3
"""Build the fixed BootRom image used by the UART InstDma flow."""

from __future__ import annotations

from pathlib import Path
import shutil
import sys

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from common.project_config import PROJECT_ROOT, project_relative  # noqa: E402
from common.rv32i_build_common import audit_disassembly, find_toolchain, run, to_tool_path, write_mem_file  # noqa: E402


OUT_DIR = PROJECT_ROOT / "output" / "bootrom"
STARTUP_S = PROJECT_ROOT / "sw" / "bootrom" / "src" / "startup.S"
BOOTROM_C = PROJECT_ROOT / "sw" / "bootrom" / "src" / "bootrom_main.c"
LINKER_LD = PROJECT_ROOT / "sw" / "bootrom" / "linker" / "bootrom.ld"
BOOTROM_MEM_DST = PROJECT_ROOT / "src" / "timing_programs" / "uart_bootrom.mem"

ELF = OUT_DIR / "bootrom.elf"
BIN = OUT_DIR / "bootrom.bin"
MEM = OUT_DIR / "bootrom.mem"
MAP = OUT_DIR / "bootrom.map"
LST = OUT_DIR / "bootrom.lst"


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    tools = find_toolchain()
    windows_tool = tools["gcc"].suffix.lower() == ".exe"

    gcc = to_tool_path(tools["gcc"], False)
    objcopy = to_tool_path(tools["objcopy"], False)
    objdump = to_tool_path(tools["objdump"], False)
    size = to_tool_path(tools["size"], False)

    compile_cmd = [
        gcc,
        "-march=rv32i_zicsr",
        "-mabi=ilp32",
        "-ffreestanding",
        "-nostdlib",
        "-nostartfiles",
        "-nodefaultlibs",
        "-Os",
        "-g",
        "-Wall",
        "-Wextra",
        "-fno-builtin",
        "-fno-pic",
        "-fno-pie",
        "-no-pie",
        "-static",
        "-msmall-data-limit=0",
        "-Wl,--build-id=none",
        f"-Wl,-Map,{to_tool_path(MAP, windows_tool)}",
        "-T",
        to_tool_path(LINKER_LD, windows_tool),
        to_tool_path(STARTUP_S, windows_tool),
        to_tool_path(BOOTROM_C, windows_tool),
        "-o",
        to_tool_path(ELF, windows_tool),
    ]

    run(compile_cmd)
    size_output = run([size, "-A", to_tool_path(ELF, windows_tool)])
    run([objcopy, "-O", "binary", to_tool_path(ELF, windows_tool), to_tool_path(BIN, windows_tool)])
    run([objdump, "-d", to_tool_path(ELF, windows_tool)], stdout_path=LST)
    audit_disassembly(LST.read_text(encoding="utf-8", errors="ignore"))

    words, digest = write_mem_file(BIN.read_bytes(), MEM)
    shutil.copyfile(MEM, BOOTROM_MEM_DST)

    print(size_output, end="")
    print(f"BUILD_BOOTROM_PASS words={words} sha256={digest} mem={project_relative(BOOTROM_MEM_DST)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
