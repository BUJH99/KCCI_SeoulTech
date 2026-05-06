#!/usr/bin/env python3
import os
import sys
import time

import xsdb


PROJECT_ROOT = "C:/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/SW_GPIO"
WORKSPACE = "C:/tmp/swgpio_vitis"
PLATFORM_NAME = "swgpio_pfm"
APP_NAME = "swgpio_app"

BITSTREAM_CANDIDATES = [
    f"{WORKSPACE}/{APP_NAME}/_ide/bitstream/SW_GPIO_Basys3.bit",
    f"{WORKSPACE}/{PLATFORM_NAME}/export/{PLATFORM_NAME}/hw/SW_GPIO_Basys3.bit",
]
ELF_PATH = f"{WORKSPACE}/{APP_NAME}/build/{APP_NAME}.elf"


def first_existing(paths):
    for path in paths:
        if os.path.isfile(path):
            return path
    raise FileNotFoundError("None of these files exist: " + ", ".join(paths))


def main():
    bitstream = first_existing(BITSTREAM_CANDIDATES)
    if not os.path.isfile(ELF_PATH):
        raise FileNotFoundError(ELF_PATH)

    session = xsdb.start_debug_session()
    print("Connecting to hw_server...")
    session.connect()

    print("Available targets before FPGA programming:")
    session.targets()

    print(f"Programming FPGA: {bitstream}")
    fpga_target = session.targets("-s", filter="name =~ *xc7a35t*")
    fpga_target.fpga(file=bitstream)
    time.sleep(1.0)

    print("Available targets after FPGA programming:")
    session.targets()

    print(f"Downloading ELF: {ELF_PATH}")
    mb_target = session.targets("-s", filter="name =~ MicroBlaze #0*")
    try:
        mb_target.stop()
    except Exception as exc:
        print(f"Note: stop skipped: {exc}")
    mb_target.rst(type="processor")
    mb_target.dow(file=ELF_PATH)
    mb_target.con()

    print("Application is running. Use BTNR=run, BTNL=stop, BTNC=reset.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
