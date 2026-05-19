#!/usr/bin/env python3
"""Generate SoC address artifacts from soc.yml."""

from __future__ import annotations

from pathlib import Path
import sys

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from common.project_config import DEFAULT_BAUD, DEFAULT_ENTRY_ADDR, DEFAULT_LOAD_ADDR, PROJECT_ROOT  # noqa: E402

SOC_YML = PROJECT_ROOT / "soc.yml"


def load_soc() -> dict:
    try:
        import yaml  # type: ignore
    except ImportError as exc:
        raise SystemExit("[FAIL] PyYAML is required to read soc.yml: python -m pip install PyYAML") from exc

    with SOC_YML.open("r", encoding="utf-8") as soc_file:
        return yaml.safe_load(soc_file)


def fmt_hex(value: int) -> str:
    return f"0x{value:08X}"


def as_int(value: object) -> int:
    if isinstance(value, str):
        return int(value, 0)
    return int(value)


def fmt_sv(value: int) -> str:
    hex_value = f"{value:08X}"
    return f"32'h{hex_value[:4]}_{hex_value[4:]}"


def validate(soc: dict) -> None:
    apb = soc["apb"]
    apb_base = as_int(apb["base"])
    apb_last = apb_base + as_int(apb["size"]) - 1
    window_size = as_int(apb["window_size"])
    used_windows: dict[int, str] = {}

    for name, periph in soc["peripherals"].items():
        base = as_int(periph["base"])
        size = as_int(periph["size"])
        if base < apb_base or (base + size - 1) > apb_last:
            raise SystemExit(f"[FAIL] {name} is outside APB range.")
        if base % window_size != 0:
            raise SystemExit(f"[FAIL] {name} is not aligned to APB window size.")
        window = base // window_size
        if window in used_windows:
            raise SystemExit(f"[FAIL] APB overlap: {name} and {used_windows[window]}.")
        used_windows[window] = name

    memory = soc["memory"]
    program_ram = memory["program_ram"]
    if as_int(program_ram["base"]) != DEFAULT_LOAD_ADDR:
        raise SystemExit("[FAIL] ProgramRam base must match InstDma/app linker default.")


def write_outputs(soc: dict) -> None:
    memory = soc["memory"]
    periph = soc["peripherals"]
    apb = soc["apb"]

    soc_pkg = PROJECT_ROOT / "src" / "soc_addr_pkg.sv"
    soc_pkg.write_text(
        "\n".join(
            [
                "/*",
                "[MODULE_INFO_START]",
                "Name: soc_addr_pkg",
                "Role: Generated SoC address constants for the RV32I 5-stage SoC",
                "Summary:",
                "  - Mirrors soc.yml memory and APB windows for RTL consumers",
                "  - Keeps InstDma, ProgramRam, and APB decode constants in one package",
                "[MODULE_INFO_END]",
                "*/",
                "",
                "`timescale 1ns / 1ps",
                "",
                "package soc_addr_pkg;",
                f"  localparam logic [31:0] LP_SOC_BOOT_ROM_BASE    = {fmt_sv(as_int(memory['boot_rom']['base']))};",
                f"  localparam logic [31:0] LP_SOC_BOOT_ROM_SIZE    = {fmt_sv(as_int(memory['boot_rom']['size']))};",
                f"  localparam logic [31:0] LP_SOC_PROGRAM_RAM_BASE = {fmt_sv(as_int(memory['program_ram']['base']))};",
                f"  localparam logic [31:0] LP_SOC_PROGRAM_RAM_SIZE = {fmt_sv(as_int(memory['program_ram']['size']))};",
                f"  localparam logic [31:0] LP_SOC_DATA_RAM_BASE    = {fmt_sv(as_int(memory['data_ram']['base']))};",
                f"  localparam logic [31:0] LP_SOC_DATA_RAM_SIZE    = {fmt_sv(as_int(memory['data_ram']['size']))};",
                "",
                f"  localparam logic [31:0] LP_SOC_APB_BASE       = {fmt_sv(as_int(apb['base']))};",
                f"  localparam logic [31:0] LP_SOC_APB_SIZE       = {fmt_sv(as_int(apb['size']))};",
                f"  localparam logic [31:0] LP_SOC_APB_UART_BASE  = {fmt_sv(as_int(periph['uart0']['base']))};",
                f"  localparam logic [31:0] LP_SOC_APB_GPIO_BASE  = {fmt_sv(as_int(periph['gpio0']['base']))};",
                f"  localparam logic [31:0] LP_SOC_APB_I2C_BASE   = {fmt_sv(as_int(periph['i2c0']['base']))};",
                f"  localparam logic [31:0] LP_SOC_APB_INTC_BASE  = {fmt_sv(as_int(periph['intc0']['base']))};",
                f"  localparam logic [31:0] LP_SOC_APB_SPI_BASE   = {fmt_sv(as_int(periph['spi0']['base']))};",
                f"  localparam logic [31:0] LP_SOC_APB_FND_BASE   = {fmt_sv(as_int(periph['fnd0']['base']))};",
                f"  localparam logic [31:0] LP_SOC_APB_TIMER_BASE = {fmt_sv(as_int(periph['timer0']['base']))};",
                f"  localparam logic [31:0] LP_SOC_APB_INST_DMA_BASE = {fmt_sv(as_int(periph['inst_dma0']['base']))};",
                "endpackage",
                "",
            ]
        ),
        encoding="ascii",
    )

    (PROJECT_ROOT / "sw" / "common" / "include" / "soc_memory.h").write_text(
        "\n".join(
            [
                "#ifndef SOC_MEMORY_H",
                "#define SOC_MEMORY_H",
                "",
                f"#define SOC_BOOT_ROM_BASE    {fmt_hex(as_int(memory['boot_rom']['base']))}u",
                f"#define SOC_BOOT_ROM_SIZE    {fmt_hex(as_int(memory['boot_rom']['size']))}u",
                f"#define SOC_PROGRAM_RAM_BASE {fmt_hex(as_int(memory['program_ram']['base']))}u",
                f"#define SOC_PROGRAM_RAM_SIZE {fmt_hex(as_int(memory['program_ram']['size']))}u",
                f"#define SOC_DATA_RAM_BASE    {fmt_hex(as_int(memory['data_ram']['base']))}u",
                f"#define SOC_DATA_RAM_SIZE    {fmt_hex(as_int(memory['data_ram']['size']))}u",
                "",
                f"#define SOC_UART_LOADER_DEFAULT_LOAD_ADDR {fmt_hex(DEFAULT_LOAD_ADDR)}u",
                f"#define SOC_UART_LOADER_DEFAULT_ENTRY     {fmt_hex(DEFAULT_ENTRY_ADDR)}u",
                f"#define SOC_UART_LOADER_DEFAULT_BAUD      {DEFAULT_BAUD}u",
                "",
                "#endif",
                "",
            ]
        ),
        encoding="ascii",
    )

    (PROJECT_ROOT / "sw" / "linker" / "generated_memory.ldh").write_text(
        "\n".join(
            [
                f"BOOT_ROM_ORIGIN = {fmt_hex(as_int(memory['boot_rom']['base']))};",
                f"BOOT_ROM_LENGTH = {fmt_hex(as_int(memory['boot_rom']['size']))};",
                f"PROGRAM_RAM_ORIGIN = {fmt_hex(as_int(memory['program_ram']['base']))};",
                f"PROGRAM_RAM_LENGTH = {fmt_hex(as_int(memory['program_ram']['size']))};",
                f"DATA_RAM_ORIGIN = {fmt_hex(as_int(memory['data_ram']['base']))};",
                f"DATA_RAM_LENGTH = {fmt_hex(as_int(memory['data_ram']['size']))};",
                "",
            ]
        ),
        encoding="ascii",
    )

    rows = [
        "# SoC Memory Map",
        "",
        "| Region | Bus | Base | Size | Notes |",
        "|---|---:|---:|---:|---|",
        "| BootRom | I-bus | `0x0000_0000` | `0x0000_1000` | Fixed boot control image |",
        "| ProgramRam | I-bus, InstDma | `0x0000_1000` | `0x0000_F000` | UART-loaded executable app image |",
        "| DataRam | D-bus | `0x0000_0000` | `0x0000_0400` | Load/store data and stack |",
        "| APB MMIO | D-bus | `0x4000_0000` | `0x0001_0000` | Routed through DataBusInterconnect and AXI/APB bridge |",
        "",
        "| Peripheral | Base | Size |",
        "|---|---:|---:|",
    ]
    for name, cfg in periph.items():
        rows.append(f"| {cfg['module'] if name == 'inst_dma0' else name.upper()} | `{fmt_hex(as_int(cfg['base']))}` | `{fmt_hex(as_int(cfg['size']))}` |")
    (PROJECT_ROOT / "md" / "SOC_MEMORY_MAP.md").write_text("\n".join(rows) + "\n", encoding="ascii")


def main() -> int:
    soc = load_soc()
    validate(soc)
    write_outputs(soc)
    print("GENERATE_SOC_ARTIFACTS_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
