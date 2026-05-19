#!/usr/bin/env python3
"""Shared XSim runner for project-local simulation scenarios."""

from __future__ import annotations

from pathlib import Path
import argparse
import os
import shutil
import subprocess
import sys

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from common.project_config import PROJECT_ROOT  # noqa: E402


XVLOG = os.environ.get("XVLOG", "xvlog")
XELAB = os.environ.get("XELAB", "xelab")
XSIM = os.environ.get("XSIM", "xsim")


def run(cmd: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
    print("[RUN] " + " ".join(cmd))
    completed = subprocess.run(cmd, cwd=cwd, env=env)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def ensure_xsim_tools() -> None:
    missing = [tool for tool in (XVLOG, XELAB, XSIM) if shutil.which(tool) is None]
    if missing:
        raise SystemExit(f"[FAIL] Vivado XSim tool(s) not found on PATH: {', '.join(missing)}")


def clean_work_dir(work_dir: Path) -> None:
    work_dir.mkdir(parents=True, exist_ok=True)
    for dirname in ("xsim.dir", ".Xil"):
        target = work_dir / dirname
        if target.exists():
            shutil.rmtree(target)
    for pattern in ("*.log", "*.pb"):
        for target in work_dir.glob(pattern):
            if target.is_file():
                target.unlink()


def src_sv_files(exclude_names: set[str]) -> list[Path]:
    return sorted(path for path in (PROJECT_ROOT / "src").rglob("*.sv") if path.name not in exclude_names)


def src_v_files() -> list[Path]:
    return sorted((PROJECT_ROOT / "src").rglob("*.v"))


def compile_sv(path: Path, *, cwd: Path) -> None:
    run([XVLOG, "-sv", str(path)], cwd=cwd)


def compile_v(path: Path, *, cwd: Path) -> None:
    run([XVLOG, str(path)], cwd=cwd)


def compile_all_rtl(*, cwd: Path, package_names: list[str]) -> None:
    package_paths = [PROJECT_ROOT / "src" / name for name in package_names]
    print("[INFO] Compiling packages")
    run([XVLOG, "-sv", *[str(path) for path in package_paths]], cwd=cwd)

    print("[INFO] Compiling RTL")
    for path in src_sv_files(set(package_names)):
        compile_sv(path, cwd=cwd)
    for path in src_v_files():
        compile_v(path, cwd=cwd)


def glbl_path() -> Path:
    xilinx_vivado = os.environ.get("XILINX_VIVADO")
    if xilinx_vivado:
        candidate = Path(xilinx_vivado) / "data" / "verilog" / "src" / "glbl.v"
        if candidate.exists():
            return candidate
    return PROJECT_ROOT / "tb" / "glbl.v"


def check_log(log_path: Path, *, scenario: str, fail_patterns: list[str], pass_message: str | None) -> None:
    text = log_path.read_text(encoding="utf-8", errors="ignore")
    for pattern in fail_patterns:
        if pattern in text:
            raise SystemExit(f"[FAIL] {scenario} XSIM log contains `{pattern}`.")
    if pass_message is not None and pass_message not in text:
        raise SystemExit(f"[FAIL] {scenario} XSIM log is missing pass marker: {pass_message}")


def run_snapshot(
    *,
    cwd: Path,
    snapshot: str,
    top_args: list[str],
    pass_message: str | None,
    fail_patterns: list[str] | None = None,
    log_copy: str | None = None,
) -> None:
    print(f"[INFO] Elaborating {snapshot}")
    run([XELAB, "-debug", "typical", *top_args, "-s", snapshot], cwd=cwd)

    print(f"[INFO] Running {snapshot}")
    run([XSIM, snapshot, "-runall"], cwd=cwd)

    log_path = cwd / "xsim.log"
    if log_copy is not None:
        shutil.copyfile(log_path, cwd / log_copy)
        log_path = cwd / log_copy
    check_log(
        log_path,
        scenario=snapshot,
        fail_patterns=fail_patterns or ["[FAIL]", "Fatal:"],
        pass_message=pass_message,
    )


def scenario_uart_inst_dma() -> None:
    work_dir = PROJECT_ROOT / "output" / "uart_inst_dma_xsim"
    run([sys.executable, str(TOOLS_DIR / "soc" / "generate_soc_artifacts.py")])
    clean_work_dir(work_dir)
    compile_all_rtl(cwd=work_dir, package_names=["rv32i_pkg.sv", "sort_demo_pkg.sv", "soc_addr_pkg.sv"])

    print("[INFO] Compiling UART InstDma TB")
    compile_v(glbl_path(), cwd=work_dir)
    compile_sv(PROJECT_ROOT / "tb" / "tb_TOP_UartInstDma.sv", cwd=work_dir)
    run_snapshot(
        cwd=work_dir,
        snapshot="tb_TOP_UartInstDma_sim",
        top_args=["-L", "unisims_ver", "TbTop", "glbl"],
        pass_message="[PASS] TOP UART InstDma integration completed",
    )
    print("[PASS] TOP UART InstDma integration completed")


def scenario_bubble_sort_e2e() -> None:
    work_dir = PROJECT_ROOT / "output" / "bubble_sort_e2e_xsim"
    env = os.environ.copy()
    env.setdefault("BUBBLE_SORT_TICK_DELAY_LOOPS", "1000")
    run([sys.executable, str(TOOLS_DIR / "firmware" / "build_bubble_sort_firmware.py")], env=env)
    clean_work_dir(work_dir)
    compile_all_rtl(cwd=work_dir, package_names=["rv32i_pkg.sv", "sort_demo_pkg.sv"])

    print("[INFO] Compiling Bubble Sort E2E TB")
    compile_v(glbl_path(), cwd=work_dir)
    compile_sv(PROJECT_ROOT / "tb" / "tb_TOP_BubbleSortE2E.sv", cwd=work_dir)
    run_snapshot(
        cwd=work_dir,
        snapshot="tb_TOP_BubbleSortE2E_sim",
        top_args=["-L", "unisims_ver", "TbTop", "glbl"],
        fail_patterns=["[FAIL]", "Fatal:", "unsupported instruction"],
        pass_message="[PASS] Bubble Sort final E2E XSIM completed",
    )
    print("[PASS] Bubble Sort final E2E XSIM completed")


def scenario_master_slave_preflight() -> None:
    work_dir = PROJECT_ROOT / "output" / "master_slave_preflight_xsim"
    clean_work_dir(work_dir)
    compile_all_rtl(cwd=work_dir, package_names=["rv32i_pkg.sv", "sort_demo_pkg.sv"])

    print("[INFO] Compiling board-preflight TB")
    compile_sv(PROJECT_ROOT / "tb" / "tb_MasterSlave_BoardPreflight.sv", cwd=work_dir)
    run_snapshot(
        cwd=work_dir,
        snapshot="tb_MasterSlave_BoardPreflight_sim",
        top_args=["TbTop"],
        pass_message=None,
    )
    print("[PASS] MASTER/SLAVE board-preflight XSIM completed.")


def scenario_axi_apb_bus() -> None:
    work_dir = PROJECT_ROOT / "output" / "axi_apb_bus_xsim"
    clean_work_dir(work_dir)

    print("[INFO] Compiling AXI/APB bus RTL")
    rtl_files = [
        "rv32i_pkg.sv",
        "DataBusAxiLiteMaster.sv",
        "APBMux.sv",
        "AxiLiteToApbBridge.sv",
        "TimerReg.sv",
        "TimerCore.sv",
        "APB_Timer.sv",
        "CsrFile.sv",
        "TrapController.sv",
    ]
    for name in rtl_files:
        compile_sv(PROJECT_ROOT / "src" / name, cwd=work_dir)

    print("[INFO] Compiling AXI/APB bus TBs")
    tb_files = [
        "tb_DataBusAxiLiteMaster.sv",
        "tb_AxiLiteToApbBridge.sv",
        "tb_APB_Timer.sv",
        "tb_CsrFile_Timer.sv",
        "tb_TrapController_Timer.sv",
    ]
    for name in tb_files:
        compile_sv(PROJECT_ROOT / "tb" / name, cwd=work_dir)

    runs = [
        ("tb_DataBusAxiLiteMaster_sim", "tb_DataBusAxiLiteMaster", "[PASS] tb_DataBusAxiLiteMaster completed", "tb_DataBusAxiLiteMaster.xsim.log"),
        ("tb_AxiLiteToApbBridge_sim", "tb_AxiLiteToApbBridge", "[PASS] tb_AxiLiteToApbBridge completed", "tb_AxiLiteToApbBridge.xsim.log"),
        ("tb_APB_Timer_sim", "tb_APB_Timer", "[PASS] tb_APB_Timer completed", "tb_APB_Timer.xsim.log"),
        ("tb_CsrFile_Timer_sim", "tb_CsrFile_Timer", "[PASS] tb_CsrFile_Timer completed", "tb_CsrFile_Timer.xsim.log"),
        ("tb_TrapController_Timer_sim", "tb_TrapController_Timer", "[PASS] tb_TrapController_Timer completed", "tb_TrapController_Timer.xsim.log"),
    ]
    for snapshot, top, pass_message, log_copy in runs:
        run_snapshot(
            cwd=work_dir,
            snapshot=snapshot,
            top_args=[top],
            pass_message=pass_message,
            log_copy=log_copy,
        )

    print("[PASS] AXI/APB bus XSIM completed")


SCENARIOS = {
    "uart_inst_dma": scenario_uart_inst_dma,
    "bubble_sort_e2e": scenario_bubble_sort_e2e,
    "master_slave_preflight": scenario_master_slave_preflight,
    "axi_apb_bus": scenario_axi_apb_bus,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("scenario", choices=sorted(SCENARIOS))
    args = parser.parse_args()

    ensure_xsim_tools()
    SCENARIOS[args.scenario]()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

