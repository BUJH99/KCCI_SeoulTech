#!/usr/bin/env python3
"""Create an RAXI UART loader packet for InstDma."""

from __future__ import annotations

from pathlib import Path
import argparse
import struct
import sys

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from common.project_config import DEFAULT_ENTRY_ADDR, DEFAULT_LOAD_ADDR, project_path  # noqa: E402


def parse_int(text: str) -> int:
    return int(text, 0)


def make_packet(payload: bytes, load_addr: int, entry_addr: int) -> bytes:
    padded = bytearray(payload)
    while len(padded) % 4:
        padded.append(0)

    checksum = sum(padded) & 0xFFFFFFFF
    header = b"RAXI" + struct.pack(
        "<IIII",
        load_addr & 0xFFFFFFFF,
        len(padded) & 0xFFFFFFFF,
        entry_addr & 0xFFFFFFFF,
        checksum,
    )
    return header + bytes(padded)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("payload", type=Path)
    parser.add_argument("packet_bin", type=Path)
    parser.add_argument("--packet-hex", type=Path)
    parser.add_argument("--load-addr", type=parse_int, default=DEFAULT_LOAD_ADDR)
    parser.add_argument("--entry", type=parse_int, default=DEFAULT_ENTRY_ADDR)
    args = parser.parse_args()

    payload_path = project_path(args.payload)
    packet_bin = project_path(args.packet_bin)
    packet_hex = project_path(args.packet_hex) if args.packet_hex is not None else None

    payload = payload_path.read_bytes()
    packet = make_packet(payload, args.load_addr, args.entry)
    checksum = sum(packet[20:]) & 0xFFFFFFFF

    packet_bin.parent.mkdir(parents=True, exist_ok=True)
    packet_bin.write_bytes(packet)

    if packet_hex is not None:
        packet_hex.parent.mkdir(parents=True, exist_ok=True)
        packet_hex.write_text("".join(f"{byte:02x}\n" for byte in packet), encoding="ascii")

    print(
        "MAKE_LOADER_PACKET_PASS "
        f"payload_bytes={len(packet) - 20} packet_bytes={len(packet)} "
        f"load_addr=0x{args.load_addr:08x} entry=0x{args.entry:08x} "
        f"checksum=0x{checksum:08x}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
