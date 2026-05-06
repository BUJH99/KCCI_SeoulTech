#!/usr/bin/env python3
import os
import shutil
import sys

import vitis


PROJECT_ROOT = "C:/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/SW_GPIO"
WORKSPACE = "C:/tmp/swgpio_vitis"
XSA_PATH = f"{PROJECT_ROOT}/output/xsa/SW_GPIO_Basys3.xsa"
APP_SRC_DIR = f"{PROJECT_ROOT}/vitis/sw_gpio_app/src"

PLATFORM_NAME = "swgpio_pfm"
APP_NAME = "swgpio_app"
DOMAIN_NAME = "mb"
CPU_NAME = "microblaze_0"


def require_file(path):
    if not os.path.isfile(path):
        raise FileNotFoundError(path)


def main():
    require_file(XSA_PATH)
    require_file(os.path.join(APP_SRC_DIR, "main.c"))

    if os.path.isdir(WORKSPACE):
        shutil.rmtree(WORKSPACE)
    os.makedirs(WORKSPACE, exist_ok=True)

    client = vitis.create_client()
    try:
        client.set_workspace(WORKSPACE)

        print(f"Workspace : {WORKSPACE}")
        print(f"XSA       : {XSA_PATH}")

        print("Processor/OS list from XSA:")
        print(client.get_processor_os_list(xsa=XSA_PATH))

        platform = client.create_platform_component(
            name=PLATFORM_NAME,
            hw_design=XSA_PATH,
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
            from_loc=APP_SRC_DIR,
            files=["main.c"],
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
