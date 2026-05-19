#!/usr/bin/env python3
"""Build an app and download it through the UART InstDma path."""

from __future__ import annotations

from pathlib import Path
import argparse
import subprocess
import sys

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from common.project_config import DEFAULT_APP, DEFAULT_BAUD, output_name_for_app_path, packet_path_for_app_name, project_path  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("port")
    parser.add_argument("--app", type=Path, default=DEFAULT_APP)
    parser.add_argument("--name")
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD)
    parser.add_argument("--no-ack", action="store_true")
    args = parser.parse_args()

    app_path = project_path(args.app)
    app_name = args.name or output_name_for_app_path(args.app)
    packet = packet_path_for_app_name(app_name)

    build_cmd = [sys.executable, str(TOOLS_DIR / "firmware" / "build_uart_app.py"), "--app", str(app_path), "--name", app_name]
    send_cmd = [
        sys.executable,
        str(TOOLS_DIR / "uart" / "send_loader_packet.py"),
        args.port,
        str(packet),
        "--baud",
        str(args.baud),
    ]
    if args.no_ack:
        send_cmd.append("--no-ack")

    subprocess.run(build_cmd, check=True)
    subprocess.run(send_cmd, check=True)
    print(f"DOWNLOAD_UART_APP_PASS port={args.port} name={app_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
