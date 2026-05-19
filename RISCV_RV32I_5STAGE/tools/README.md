# RISCV_RV32I_5STAGE Tools

Project-local utilities for SoC artifact generation, RV32I firmware builds, UART loading, XSim scenarios, and timing analysis.

## Layout

| Path | Role |
|---|---|
| `common/` | Shared project defaults and RV32I build helpers. |
| `soc/` | Generate RTL/C/linker/docs artifacts from `soc.yml`. |
| `firmware/` | Build BootROM, UART app images, and Bubble Sort firmware. |
| `uart/` | Create/send RAXI loader packets and launch the UART GUI. |
| `sim/` | Shared XSim scenario runner. |
| `timing/` | Pipeline timing report generator and Vivado TCL collector. |

The `tools/` root intentionally contains no executable wrappers. Call the owner folder directly so there is only one source of truth for each tool.

## Common Flow

```bat
tools/uart/menu.bat bootrom
tools/uart/menu.bat app
tools/uart/menu.bat xsim
tools/uart/menu.bat download COM5
tools/uart/menu.bat gui
```

Equivalent direct commands:

```bat
python tools/soc/generate_soc_artifacts.py
python tools/firmware/build_bootrom.py
python tools/firmware/build_uart_app.py --app sw/apps/hello_world/src/main.c --name hello_world_uart
python tools/uart/download_uart_app.py COM5 --app sw/apps/hello_world/src/main.c --name hello_world_uart
```

## XSim Scenarios

```bash
python3 tools/sim/xsim_runner.py uart_inst_dma
python3 tools/sim/xsim_runner.py bubble_sort_e2e
python3 tools/sim/xsim_runner.py master_slave_preflight
python3 tools/sim/xsim_runner.py axi_apb_bus
```

The runner expects Vivado XSim tools on `PATH` as `xvlog`, `xelab`, and `xsim`.

## Defaults

Operational defaults live in `common/project_config.py`:

- UART baud: `115200`
- ProgramRam load/entry: `0x1000`
- Default app: `sw/apps/hello_world/src/main.c`
- Default UART app output name: `hello_world_uart`

BAT menu defaults are loaded from that Python module, so Python and Windows menu flows stay aligned.

## Host Dependencies

UART console and packet download require `pyserial` in the same Windows Python used by `tools/uart/menu.bat`:

```bat
python -m pip install pyserial
```

## Output

Generated files should stay under project-local `output/` unless they are source-controlled artifacts intentionally regenerated from `soc.yml`, such as:

- `src/soc_addr_pkg.sv`
- `sw/common/include/soc_memory.h`
- `sw/linker/generated_memory.ldh`
- `md/SOC_MEMORY_MAP.md`

## Quick Checks

```bash
find tools -name '*.py' -print0 | xargs -0 env PYTHONPYCACHEPREFIX=/tmp/fpga_tools_pycache python3 -m py_compile
python3 -m json.tool tools/timing/timing_analysis_profile.json >/tmp/timing_analysis_profile.validated.json
```
