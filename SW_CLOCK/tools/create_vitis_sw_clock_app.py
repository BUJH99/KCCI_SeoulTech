#!/usr/bin/env python3
import os
import shutil
import stat
import sys
from pathlib import Path

import vitis


PROJECT_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = Path("C:/tmp/swclock_vitis")
XSA_PATH = PROJECT_ROOT / "output" / "xsa" / "SW_CLOCK_Basys3.xsa"
APP_SRC_DIR = PROJECT_ROOT / "vitis" / "sw_clock_app" / "src"

PLATFORM_NAME = "swclock_pfm"
APP_NAME = "swclock_app"
DOMAIN_NAME = "mb"
CPU_NAME = "microblaze_0"


def configure_windows_utf8():
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


def require_file(path):
    if not Path(path).is_file():
        raise FileNotFoundError(path)


def source_files():
    files = []
    for path in sorted(APP_SRC_DIR.iterdir()):
        if path.suffix.lower() in {".c", ".h"}:
            files.append(path.name)
    if not files:
        raise FileNotFoundError(f"No C/H source files found in {APP_SRC_DIR}")
    return files


def remove_tree(path):
    def make_writable(function, failed_path, excinfo):
        try:
            os.chmod(failed_path, stat.S_IWRITE)
            function(failed_path)
        except Exception:
            raise excinfo[1]

    if path.is_dir():
        shutil.rmtree(path, onexc=make_writable)


def main():
    configure_windows_utf8()
    require_file(XSA_PATH)
    require_file(APP_SRC_DIR / "main.c")
    files = source_files()

    remove_tree(WORKSPACE)
    WORKSPACE.mkdir(parents=True, exist_ok=True)

    client = vitis.create_client()
    try:
        client.set_workspace(str(WORKSPACE))

        print(f"Workspace : {WORKSPACE}")
        print(f"XSA       : {XSA_PATH}")
        print("Processor/OS list from XSA:")
        print(client.get_processor_os_list(xsa=str(XSA_PATH)))

        platform = client.create_platform_component(
            name=PLATFORM_NAME,
            hw_design=str(XSA_PATH),
        )
        platform.add_domain(
            name=DOMAIN_NAME,
            cpu=CPU_NAME,
            os="standalone",
        )
        platform.list_domains()
        platform.build()

        platform_xpfm = client.find_platform_in_repos(PLATFORM_NAME)
        print(f"XPFM      : {platform_xpfm}")

        app = client.create_app_component(
            name=APP_NAME,
            platform=platform_xpfm,
            domain=DOMAIN_NAME,
            template="empty_application",
        )
        app.import_files(
            from_loc=str(APP_SRC_DIR),
            files=files,
            dest_dir_in_cmp="src",
        )
        app.build(target="hw")

        print("Platform and application build completed.")
    finally:
        vitis.dispose()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
