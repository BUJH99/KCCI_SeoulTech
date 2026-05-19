#!/usr/bin/env python3
"""Send an InstDma RAXI packet over a serial port."""

from __future__ import annotations

from pathlib import Path
import argparse
import sys
import time

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from common.project_config import DEFAULT_BAUD, project_path  # noqa: E402


ACK_BYTE = 0x06
ERR_BYTE = 0x15


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("port")
    parser.add_argument("packet", type=Path)
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD)
    parser.add_argument("--chunk", type=int, default=32)
    parser.add_argument("--chunk-delay", type=float, default=0.002)
    parser.add_argument("--open-delay", type=float, default=0.25)
    parser.add_argument("--ack-timeout", type=float, default=2.0)
    parser.add_argument("--no-ack", action="store_true")
    args = parser.parse_args()

    try:
        import serial
    except ImportError as exc:
        raise SystemExit("pyserial is required: python -m pip install pyserial") from exc

    packet = project_path(args.packet).read_bytes()

    with serial.Serial(args.port, args.baud, timeout=0.05) as ser:
        time.sleep(args.open_delay)
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        sent = 0
        while sent < len(packet):
            chunk = packet[sent : sent + args.chunk]
            ser.write(chunk)
            ser.flush()
            sent += len(chunk)
            time.sleep(args.chunk_delay)

        if not args.no_ack:
            deadline = time.monotonic() + args.ack_timeout
            response = b""
            while time.monotonic() < deadline and not response:
                response = ser.read(1)

            if not response:
                raise SystemExit("[FAIL] No InstDma ACK/ERR byte received.")
            if response[0] == ERR_BYTE:
                raise SystemExit("[FAIL] InstDma returned ERR.")
            if response[0] != ACK_BYTE:
                raise SystemExit(f"[FAIL] Unexpected InstDma response byte: 0x{response[0]:02x}.")

    print(f"SEND_LOADER_PACKET_PASS port={args.port} baud={args.baud} bytes={len(packet)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
