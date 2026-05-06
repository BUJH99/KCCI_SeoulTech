#!/usr/bin/env python3
import sys
import time
from pathlib import Path

import xsdb


WORKSPACE = Path("C:/tmp/swclock_vitis")
PLATFORM_NAME = "swclock_pfm"
APP_NAME = "swclock_app"

BITSTREAM_CANDIDATES = [
    WORKSPACE / APP_NAME / "_ide" / "bitstream" / "SW_CLOCK_Basys3.bit",
    WORKSPACE / PLATFORM_NAME / "export" / PLATFORM_NAME / "hw" / "SW_CLOCK_Basys3.bit",
]
ELF_PATH = WORKSPACE / APP_NAME / "build" / f"{APP_NAME}.elf"


def configure_windows_utf8():
    import os

    os.environ.setdefault("PYTHONUTF8", "1")
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    if os.name != "nt":
        return

    try:
        import ctypes

        ctypes.windll.kernel32.SetConsoleCP(65001)
        ctypes.windll.kernel32.SetConsoleOutputCP(65001)
    except Exception:
        pass


def first_existing(paths):
    for path in paths:
        if path.is_file():
            return path
    raise FileNotFoundError("None of these files exist: " + ", ".join(str(path) for path in paths))


def select_target(session, filter_expr, description):
    try:
        return session.targets("-s", filter=filter_expr)
    except Exception as exc:
        raise RuntimeError(
            f"{description} target was not found. Check Basys3 USB power/JTAG connection and rerun."
        ) from exc


def main():
    configure_windows_utf8()
    bitstream = first_existing(BITSTREAM_CANDIDATES)
    if not ELF_PATH.is_file():
        raise FileNotFoundError(ELF_PATH)

    session = xsdb.start_debug_session()
    print("Connecting to hw_server...")
    session.connect()

    print("Available targets before FPGA programming:")
    session.targets()

    print(f"Programming FPGA: {bitstream}")
    fpga_target = select_target(session, "name =~ *xc7a35t*", "Basys3 FPGA")
    fpga_target.fpga(file=str(bitstream))
    time.sleep(1.0)

    print("Available targets after FPGA programming:")
    session.targets()

    print(f"Downloading ELF: {ELF_PATH}")
    mb_target = select_target(session, "name =~ MicroBlaze #0*", "MicroBlaze")
    try:
        mb_target.stop()
    except Exception as exc:
        print(f"Note: stop skipped: {exc}")
    mb_target.rst(type="processor")
    mb_target.dow(file=str(ELF_PATH))
    mb_target.con()

    print("Application is running. BTNU=mode, BTNR=run, BTNL=stop, BTND=reset, BTNC=system reset.")


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
