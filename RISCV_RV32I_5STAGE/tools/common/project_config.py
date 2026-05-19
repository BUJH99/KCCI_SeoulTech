"""Central project-local tool defaults.

Keep operational defaults here so the UART build, packet, GUI, and menu flows
do not drift as the memory map evolves.
"""

from __future__ import annotations

from pathlib import Path
import argparse
import re


TOOLS_DIR = Path(__file__).resolve().parents[1]
PROJECT_ROOT = TOOLS_DIR.parent
REL_DEFAULT_APP = Path("sw") / "apps" / "hello_world" / "src" / "main.c"
REL_DEFAULT_PACKET = Path("output") / "uart_app" / "hello_world_uart" / "hello_world_uart_loader_packet.bin"

DEFAULT_BAUD = 115200
DEFAULT_LOAD_ADDR = 0x00001000
DEFAULT_ENTRY_ADDR = 0x00001000
DEFAULT_APP = PROJECT_ROOT / REL_DEFAULT_APP
DEFAULT_APP_DISPLAY = "hello_world"
DEFAULT_APP_NAME = "hello_world_uart"
DEFAULT_PACKET = PROJECT_ROOT / REL_DEFAULT_PACKET


def safe_name(path: Path) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", path.stem)


def output_name_for_app_path(app_path: Path) -> str:
    normalized = project_path(Path(app_path.as_posix().replace("\\", "/"))).resolve()
    if normalized == DEFAULT_APP.resolve():
        return DEFAULT_APP_NAME
    return safe_name(app_path)


def output_name_for_app_display(app_display: str) -> str:
    if app_display == DEFAULT_APP_DISPLAY:
        return DEFAULT_APP_NAME
    return f"{app_display}_uart"


def packet_path_for_app_name(app_name: str) -> Path:
    return PROJECT_ROOT / "output" / "uart_app" / app_name / f"{app_name}_loader_packet.bin"


def project_relative(path: Path) -> str:
    try:
        return path.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def project_path(path: Path | str) -> Path:
    candidate = Path(path)
    if candidate.is_absolute():
        return candidate
    return PROJECT_ROOT / candidate


def bat_path(path: Path | str) -> str:
    return str(path).replace("/", "\\")


def emit_bat_defaults() -> None:
    values = {
        "DEFAULT_APP": bat_path(REL_DEFAULT_APP),
        "DEFAULT_APP_NAME": DEFAULT_APP_NAME,
        "DEFAULT_PACKET": bat_path(REL_DEFAULT_PACKET),
        "DEFAULT_BAUD": str(DEFAULT_BAUD),
        "DEFAULT_LOAD_ADDR": f"0x{DEFAULT_LOAD_ADDR:X}",
        "DEFAULT_ENTRY_ADDR": f"0x{DEFAULT_ENTRY_ADDR:X}",
    }
    for key, value in values.items():
        print(f"{key}={value}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bat", action="store_true", help="Emit key=value defaults for BAT wrappers.")
    args = parser.parse_args()
    if args.bat:
        emit_bat_defaults()
        return 0
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
