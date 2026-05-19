#!/usr/bin/env python3
"""Build a ProgramRam app image and matching RAXI loader packet."""

from __future__ import annotations

from pathlib import Path
import argparse
import sys

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from common.project_config import DEFAULT_APP, DEFAULT_ENTRY_ADDR, DEFAULT_LOAD_ADDR, PROJECT_ROOT, output_name_for_app_path, project_path, project_relative  # noqa: E402
from common.rv32i_build_common import audit_disassembly, find_toolchain, run, section_size, to_tool_path, write_mem_file  # noqa: E402
from uart.make_loader_packet import make_packet  # noqa: E402


STARTUP_S = PROJECT_ROOT / "sw" / "startup" / "rv32i_startup.S"
LINKER_LD = PROJECT_ROOT / "sw" / "linker" / "rv32i_uart_app.ld"
INCLUDE_DIR = PROJECT_ROOT / "sw" / "common" / "include"


def parse_int(text: str) -> int:
    return int(text, 0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, default=DEFAULT_APP)
    parser.add_argument("--name")
    parser.add_argument("--load-addr", type=parse_int, default=DEFAULT_LOAD_ADDR)
    parser.add_argument("--entry", type=parse_int, default=DEFAULT_ENTRY_ADDR)
    parser.add_argument("--allow-rodata", action="store_true")
    args = parser.parse_args()

    app_path = project_path(args.app)
    app_name = args.name or output_name_for_app_path(args.app)
    out_dir = PROJECT_ROOT / "output" / "uart_app" / app_name
    out_dir.mkdir(parents=True, exist_ok=True)

    elf = out_dir / f"{app_name}.elf"
    bin_path = out_dir / f"{app_name}.bin"
    mem = out_dir / f"{app_name}.mem"
    map_path = out_dir / f"{app_name}.map"
    lst = out_dir / f"{app_name}.lst"
    packet_bin = out_dir / f"{app_name}_loader_packet.bin"
    packet_hex = out_dir / f"{app_name}_loader_packet.hex"

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
        "-I",
        to_tool_path(INCLUDE_DIR, windows_tool),
        "-Wl,--build-id=none",
        f"-Wl,-Map,{to_tool_path(map_path, windows_tool)}",
        "-T",
        to_tool_path(LINKER_LD, windows_tool),
        to_tool_path(STARTUP_S, windows_tool),
        to_tool_path(app_path, windows_tool),
        "-o",
        to_tool_path(elf, windows_tool),
    ]

    run(compile_cmd)
    size_output = run([size, "-A", to_tool_path(elf, windows_tool)])
    if section_size(size_output, ".data") != 0:
        raise SystemExit("[FAIL] Non-zero .data is not supported by the single-segment UART loader yet.")
    if section_size(size_output, ".rodata") != 0 and not args.allow_rodata:
        raise SystemExit("[FAIL] .rodata is disabled because ProgramRam is not D-bus readable. Use --allow-rodata only for hand-audited apps.")

    run([objcopy, "-O", "binary", to_tool_path(elf, windows_tool), to_tool_path(bin_path, windows_tool)])
    run([objdump, "-d", to_tool_path(elf, windows_tool)], stdout_path=lst)
    audit_disassembly(lst.read_text(encoding="utf-8", errors="ignore"))

    words, digest = write_mem_file(bin_path.read_bytes(), mem)
    packet = make_packet(bin_path.read_bytes(), args.load_addr, args.entry)
    packet_bin.write_bytes(packet)
    packet_hex.write_text("".join(f"{byte:02x}\n" for byte in packet), encoding="ascii")

    print(size_output, end="")
    print(
        "BUILD_UART_APP_PASS "
        f"name={app_name} words={words} sha256={digest} "
        f"packet={project_relative(packet_bin)} load_addr=0x{args.load_addr:08x} entry=0x{args.entry:08x}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
