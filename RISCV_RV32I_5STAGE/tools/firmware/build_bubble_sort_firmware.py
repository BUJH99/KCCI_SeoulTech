#!/usr/bin/env python3
"""Build the RV32I Bubble Sort firmware image used by the final E2E TB."""

from __future__ import annotations

from pathlib import Path
import math
import os
import sys

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from common.project_config import PROJECT_ROOT, project_relative  # noqa: E402
from common.rv32i_build_common import (  # noqa: E402
    audit_disassembly,
    find_toolchain,
    parse_size_sections,
    run,
    to_tool_path,
    write_mem_file,
)


OUT_DIR = PROJECT_ROOT / "output" / "firmware"

APP_C = PROJECT_ROOT / "sw" / "apps" / "hello_world" / "src" / "main.c"
STARTUP_S = PROJECT_ROOT / "sw" / "startup" / "rv32i_startup.S"
LINKER_LD = PROJECT_ROOT / "sw" / "linker" / "rv32i_bubble_sort_demo.ld"
INCLUDE_DIR = PROJECT_ROOT / "sw" / "common" / "include"

ELF = OUT_DIR / "bubble_sort_demo.elf"
BIN = OUT_DIR / "bubble_sort_demo.bin"
MEM = OUT_DIR / "bubble_sort_demo.mem"
MAP = OUT_DIR / "bubble_sort_demo.map"
LST = OUT_DIR / "bubble_sort_demo.lst"


def get_sort_tick_delay_define() -> str | None:
    value = os.environ.get("BUBBLE_SORT_TICK_DELAY_LOOPS")
    if value is None or value.strip() == "":
        return None

    try:
        loops = int(value, 0)
    except ValueError as exc:
        raise SystemExit("[FAIL] BUBBLE_SORT_TICK_DELAY_LOOPS must be an integer.") from exc

    if loops < 1 or loops > 0xFFFFFFFF:
        raise SystemExit("[FAIL] BUBBLE_SORT_TICK_DELAY_LOOPS must be in the range 1..0xFFFFFFFF.")

    return f"SORT_TICK_DELAY_LOOPS={loops}u"


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    tools = find_toolchain()
    windows_tool = tools["gcc"].suffix.lower() == ".exe"
    sort_tick_delay_define = get_sort_tick_delay_define()

    gcc = to_tool_path(tools["gcc"], False)
    objcopy = to_tool_path(tools["objcopy"], False)
    objdump = to_tool_path(tools["objdump"], False)
    size = to_tool_path(tools["size"], False)
    nm = to_tool_path(tools["nm"], False)

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
        "-msmall-data-limit=0",
        "-ffunction-sections",
        "-fdata-sections",
        "-static",
        "-no-pie",
        "-Wl,--gc-sections",
        "-Wl,--no-check-sections",
        f"-Wl,-Map={to_tool_path(MAP, windows_tool)}",
        "-T",
        to_tool_path(LINKER_LD, windows_tool),
        "-I",
        to_tool_path(INCLUDE_DIR, windows_tool),
    ]
    if sort_tick_delay_define is not None:
        compile_cmd.append(f"-D{sort_tick_delay_define}")
    compile_cmd.extend(
        [
            to_tool_path(STARTUP_S, windows_tool),
            to_tool_path(APP_C, windows_tool),
            "-o",
            to_tool_path(ELF, windows_tool),
        ]
    )

    run(compile_cmd)
    run([nm, "-u", to_tool_path(ELF, windows_tool)])
    run(
        [
            objcopy,
            "-O",
            "binary",
            "-j",
            ".text",
            to_tool_path(ELF, windows_tool),
            to_tool_path(BIN, windows_tool),
        ]
    )
    disassembly = run([objdump, "-d", "-M", "no-aliases", to_tool_path(ELF, windows_tool)])
    LST.write_text(disassembly, encoding="utf-8", newline="\n")
    audit_disassembly(disassembly)

    section_sizes = parse_size_sections(run([size, "-A", to_tool_path(ELF, windows_tool)]))
    data_size = section_sizes.get(".data", 0) + section_sizes.get(".sdata", 0)
    bss_size = section_sizes.get(".bss", 0) + section_sizes.get(".sbss", 0)
    if data_size != 0:
        raise SystemExit("[FAIL] Firmware emitted nonzero .data; DataRam has no ROM copy path.")
    if bss_size > 1024:
        raise SystemExit(f"[FAIL] Firmware .bss exceeds 1 KiB DataRam: {bss_size} bytes")

    words, digest = write_mem_file(BIN.read_bytes(), MEM)
    required_addr_width = max(1, math.ceil(math.log2(words)))

    print("[PASS] firmware image built")
    print(f"[INFO] elf={project_relative(ELF)}")
    print(f"[INFO] mem={project_relative(MEM)}")
    if sort_tick_delay_define is not None:
        print(f"[INFO] firmware_define={sort_tick_delay_define}")
    print(f"[INFO] rom_words={words} required_instr_addr_width={required_addr_width}")
    print(f"[INFO] bss_bytes={bss_size} mem_sha256={digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
