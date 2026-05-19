# Final Bubble Sort End-to-End Verification Plan

## 1. Decision

이 문서는 `PLIC_LITE_V1_I2C_SPI_IMPLEMENTATION_PLAN.md`의 demo scenario를 실제 최종 통합 검증으로 구현하기 위한 계획서이다.

목표는 기존 `tb_MasterSlave_BoardPreflight.sv`처럼 MASTER APB peripheral을 testbench가 직접 구동하는 검증을 넘어서, MASTER CPU가 실제 firmware를 실행하고 외부 입력만으로 전체 Bubble Sort demo를 끝까지 수행하는지 확인하는 것이다.

Final E2E 검증의 핵심 원칙:

```text
TB stimulus = external PC UART input + external GPIO button input only
MASTER action = RV32I firmware execution through TOP
SLAVE action = separate SortDisplaySlaveTop RTL connected through external SPI/I2C wires
Pass result = UART final report + MASTER FND progress + SLAVE FND/runtime counters all match
```

## 2. Relationship To Existing Plans

Primary scenario source:

- `md/PLIC_LITE_V1_I2C_SPI_IMPLEMENTATION_PLAN.md`
  - firmware states: `IDLE`, `LOADED`, `SORTING`, `PAUSED`, `DONE`
  - final scenario checklist: UART array input, MASTER FND preview, UART/GPIO start, GPIO pause/step/reset, SPI trace to SLAVE, I2C display mode, SLAVE FND realtime count
- `md/I2C_SPI_SORT_DEMO_PROTOCOL_IMPLEMENTATION_PLAN.md`
  - SPI 24-byte Bubble Sort trace frame
  - I2C SLAVE register map
  - MASTER/SLAVE boundary
- `tb/tb_MasterSlave_BoardPreflight.sv`
  - already proves APB_I2C/APB_SPI can communicate with `SortDisplaySlaveTop`
  - remains a lower-level regression, not the final firmware-in-loop proof

## 3. Current Status Snapshot

Already proven by board-preflight simulation:

- MASTER `APB_I2C` can read/write SLAVE I2C registers.
- MASTER `APB_SPI` can transmit one 24-byte Bubble Sort trace frame.
- SLAVE accepts the SPI frame, updates frame/counter registers, and exposes them over I2C.
- Open-drain I2C line behavior is modeled at the two-FPGA boundary.

Implemented but not yet proven end-to-end:

- `sw/apps/hello_world/src/main.c` contains UART command parsing, GPIO command handling, Bubble Sort state, MASTER FND writes, SPI trace frame encode/send, and I2C SLAVE helper calls.
- MASTER `TOP.sv` instantiates UART, GPIO, I2C, SPI, FND, and interrupt controller.
- SLAVE RTL exists under `src/SLAVE/`.

Main remaining verification gap:

```text
The compiled firmware image must run from InstrRom, receive UART/GPIO input through TOP pins,
and drive I2C/SPI/FND through CPU MMIO rather than direct TB APB writes.
```

## 4. Final E2E Target Topology

```text
TB PC model
  - UART TX to MASTER iUartRx
  - UART RX monitor from MASTER oUartTx
  - GPIO button model to MASTER iGpioIn

MASTER FPGA DUT
  src/TOP.sv
    RV32I CPU
    InstrRom loaded with Bubble Sort firmware image
    APB_UART
    APB_GPIO
    APB_I2C
    APB_SPI
    APB_FND
    InterruptController

External wire models
  - SPI SCLK/MOSI/CSN/MISO connection
  - I2C SCL/SDA open-drain connection

SLAVE FPGA DUT
  src/SLAVE/SortDisplaySlaveTop.sv
    SPI trace receiver
    trace frame decoder
    I2C register target
    SLAVE FND controller
```

The final TB must not instantiate SLAVE inside MASTER `TOP.sv`. The SLAVE remains a separate DUT connected only through top-level pins.

## 5. Required Firmware Image Flow

Add a reproducible ROM image build step:

```text
input:
  sw/apps/hello_world/src/main.c
  sw/common/include/soc_mmio.h
  sw/linker/rv32i_bubble_sort_demo.ld
  sw/startup/rv32i_startup.S

output:
  output/firmware/bubble_sort_demo.elf
  output/firmware/bubble_sort_demo.bin
  output/firmware/bubble_sort_demo.mem
  output/firmware/bubble_sort_demo.map
  output/firmware/bubble_sort_demo.lst
```

Preferred compiler contract:

```text
-march=rv32i
-mabi=ilp32
-ffreestanding
-nostdlib
-Os
-ffunction-sections
-fdata-sections
```

The build script should fail loudly if the available compiler emits unsupported instructions such as `mul`, compressed `c.*`, atomics, or library calls that require missing runtime support.

Required firmware runtime setup:

- Reset vector jumps to `_start`.
- `_start` initializes `sp` inside `DataRam`.
- `.bss` is cleared if used.
- `.data` is copied or avoided.
- `main()` is called.
- Trap entry reaches `trap_handler`.
- No standard C library dependency is required.

Required RTL support:

- Expose an instruction ROM init parameter through `TOP`, for example `P_INSTR_INIT_FILE`.
- If the compiled firmware is larger than the current 256-word `InstrRom`, add `P_INSTR_ADDR_WIDTH` and pass it from `TOP` to `InstrRom`.
- If firmware stack/global data exceeds the current 256-word `DataRam`, add `P_DATA_ADDR_WIDTH` and pass it from `TOP` to `DataRam`.
- Keep the default init file compatible with existing timing tests unless the test explicitly overrides it.

Fallback rule:

```text
Hand-patched TB ROM words are acceptable only for a temporary smoke test.
They do not count as final E2E verification.
```

## 6. Final Testbench Plan

Add:

```text
tb/tb_TOP_BubbleSortE2E.sv
python tools\sim\xsim_runner.py bubble_sort_e2e
python3 tools/sim/xsim_runner.py bubble_sort_e2e
```

The TB should instantiate:

- `TOP` as MASTER DUT.
- `SortDisplaySlaveTop` as SLAVE DUT.
- UART driver for PC-to-MASTER input.
- UART monitor for MASTER-to-PC report.
- GPIO button driver.
- SPI frame monitor.
- I2C transaction monitor.
- MASTER FND observer.
- SLAVE FND/register observer.

Stimulus restrictions:

- Allowed functional stimulus:
  - UART bytes into `iUartRx`
  - GPIO button toggles into `iGpioIn`
  - reset and clock
- Not allowed as primary functional stimulus:
  - direct writes into MASTER APB I2C/SPI/FND registers
  - direct writes into firmware global variables
  - direct writes into SLAVE registers

Hierarchical reads are allowed for scoreboarding when they do not change DUT behavior.

## 7. Test Cases

### Case A: UART Load And Sort

Input:

```text
UART sends: 3 1 0 4 2 s
```

Expected:

- MASTER firmware loads five values.
- MASTER FND previews loaded values.
- SPI emits `TRACE_LOAD` frames while values are entered.
- UART `s` starts sorting.
- SPI emits `TRACE_COMPARE`, optional `TRACE_SWAP`, `TRACE_PASS_DONE`, and `TRACE_DONE` frames.
- MASTER FND changes during compare/swap progress.
- SLAVE counters update from SPI trace frames.
- Final UART report contains sorted values:

```text
00 01 02 03 04
```

### Case B: GPIO Start

Input:

```text
UART sends: 5 4 3
GPIO[0] rising edge starts sort
```

Expected:

- UART only loads the array.
- GPIO start command moves firmware from `LOADED` to `SORTING`.
- Final UART report is:

```text
03 04 05
```

### Case C: GPIO Pause, Step, Resume

Input:

```text
UART sends: 4 2 1 s
GPIO[1] pauses while sorting
GPIO[2] performs one step
GPIO[1] resumes
```

Expected:

- Firmware emits a `TRACE_PAUSED` frame.
- While paused, no free-running compare/swap frames are emitted except the requested single step.
- After resume, sort completes.
- SLAVE status/phase reflects pause and later progress.

### Case D: GPIO Reset

Input:

```text
UART sends: 9 1
GPIO[3] reset
UART sends: 2 0 s
```

Expected:

- First partial array is discarded.
- MASTER FND returns to reset/idle value.
- SLAVE display mode returns to default through firmware I2C helper.
- Final UART report is:

```text
00 02
```

### Case E: I2C Display Mode During Runtime

Input:

```text
UART sends: 3 2 1 s
```

Expected:

- Firmware writes SLAVE `DISPLAY_MODE` through I2C during pass progress.
- I2C monitor observes valid transactions to slave address `7'h42`.
- SLAVE FND selected value changes according to display mode.
- I2C read/write transactions complete without NACK, bus error, or timeout.

## 8. Scoreboard Requirements

UART scoreboard:

- Capture bytes from `oUartTx`.
- Decode final sorted output line.
- Compare against expected sorted array.
- Fail on malformed output or timeout.

SPI scoreboard:

- Reconstruct frames from `oSpiSclk`, `oSpiMosi`, and `oSpiCsN`.
- Verify 24 bytes per frame.
- Verify magic, version, frame type, and XOR checksum.
- Verify frame ID monotonicity.
- Verify final frame has `TRACE_DONE`.
- Verify compare/swap/total counts match expected Bubble Sort behavior for the directed input.

I2C scoreboard:

- Monitor transactions on the modeled SCL/SDA lines.
- Verify target address is `7'h42`.
- Verify firmware writes `DISPLAY_MODE` and `BRIGHTNESS`.
- Verify firmware can read `SLAVE_ID` during init.
- Fail on NACK, timeout, or bus error status.

MASTER FND scoreboard:

- Prefer checking APB_FND register writes through hierarchy for stable functional verification.
- Optionally decode external `oSeg`, `oDp`, and `oDigitSel` over enough scan cycles.
- Verify the display is not stuck at reset once values are loaded.
- Verify compare/swap progress changes the displayed value.

SLAVE scoreboard:

- Check SLAVE accepted-frame pulse and register state.
- Verify `LAST_FRAME_ID`, `COMPARE_COUNT`, `SWAP_COUNT`, and `TOTAL_COUNT` match the final SPI frame.
- Verify `DISPLAY_MODE` changes affect the FND selected counter.
- Verify `ERROR_CODE` remains zero in happy-path cases.

Interrupt scoreboard:

- Verify UART_RX and GPIO interrupt sources are claimable and completed.
- Verify I2C/SPI event IRQs do not leave uncleared pending state at the end.
- Verify I2C/SPI error IRQs remain inactive in happy-path cases.

## 9. Pass And Fail Criteria

A test case passes only when all of the following are true:

- No `$fatal`, assertion failure, or timeout occurs.
- Firmware reaches the expected final report.
- Final UART sorted output matches expected order.
- MASTER FND shows load/progress/done activity.
- SPI frames are valid and include final `TRACE_DONE`.
- SLAVE registers match the final SPI runtime counters.
- I2C transactions to SLAVE complete without error.
- GPIO-directed cases affect firmware state as expected.
- Interrupt pending/claim/complete state is clean at test end.

A test case fails immediately on:

- unsupported instruction execution or illegal trap not expected by the scenario
- APB local error from firmware MMIO access
- I2C NACK, arbitration lost, bus error, or timeout
- SPI underrun, overflow, mode error, or frame drop
- SLAVE checksum/format/short-frame error
- UART final report mismatch
- no visible MASTER or SLAVE display activity before timeout

## 10. Implementation Phases

### Phase 0: Preserve Existing Regressions

- [ ] Keep `tools/sim/xsim_runner.py master_slave_preflight` as the protocol preflight.
- [ ] Confirm preflight still passes before and after E2E changes.
- [ ] Do not weaken the existing lower-level APB peripheral checks.

### Phase 1: Firmware ROM Build

- [ ] Add RV32I linker script.
- [ ] Add RV32I startup file.
- [ ] Add firmware build script.
- [ ] Generate `.elf`, `.bin`, `.mem`, `.map`, and `.lst`.
- [ ] Add an instruction audit step that rejects unsupported opcodes.
- [ ] Record firmware image size and required ROM depth.

### Phase 2: TOP Memory Parameterization

- [ ] Add `P_INSTR_INIT_FILE` parameter to `TOP`.
- [ ] Add/pass `P_INSTR_ADDR_WIDTH` if firmware exceeds 256 words.
- [ ] Add/pass `P_DATA_ADDR_WIDTH` if stack/data needs more than 256 words.
- [ ] Keep existing default ROM image behavior for current tests.

### Phase 3: E2E TB Harness

- [ ] Add `tb_TOP_BubbleSortE2E.sv`.
- [ ] Instantiate MASTER `TOP` with the generated firmware `.mem`.
- [ ] Instantiate SLAVE `SortDisplaySlaveTop`.
- [ ] Model I2C open-drain SCL/SDA lines.
- [ ] Connect SPI pins between MASTER and SLAVE.
- [ ] Add UART driver/monitor tasks.
- [ ] Add GPIO pulse tasks.
- [ ] Add timeout and reset sequencing.

### Phase 4: Happy-Path UART Scenario

- [ ] Implement Case A.
- [ ] Check final UART report.
- [ ] Check SPI frame stream.
- [ ] Check SLAVE counter registers.
- [ ] Check MASTER FND progress activity.

### Phase 5: GPIO Control Scenarios

- [ ] Implement Case B.
- [ ] Implement Case C.
- [ ] Implement Case D.
- [ ] Verify GPIO interrupt status is cleared by firmware.

### Phase 6: I2C Runtime Display Checks

- [ ] Implement Case E.
- [ ] Verify SLAVE `DISPLAY_MODE` writes.
- [ ] Verify `SLAVE_ID` read during firmware init.
- [ ] Verify no I2C error IRQ remains pending.

### Phase 7: Automation

- [ ] Add `python tools\sim\xsim_runner.py bubble_sort_e2e`.
- [ ] Add `python3 tools/sim/xsim_runner.py bubble_sort_e2e`.
- [ ] The scripts should build firmware first, then compile/elaborate/run XSIM.
- [ ] The scripts should scan `xsim.log` for `[FAIL]`, `Fatal:`, and unsupported instruction messages.
- [ ] Print a final one-line `[PASS]` only when every case passes.

### Phase 8: Board Readiness Gate

- [ ] MASTER bitstream uses the same firmware image or documented equivalent.
- [ ] SLAVE bitstream selects `SortDisplaySlaveTop`.
- [ ] MASTER constraints include UART, GPIO, FND, SPI, and I2C pins.
- [ ] SLAVE constraints include FND, SPI, and I2C pins.
- [ ] True board-level I2C wiring uses open-drain behavior or explicit safe adapter wiring.

## 11. Planned Run Commands

Windows:

```bat
python tools\sim\xsim_runner.py bubble_sort_e2e
```

WSL/bash:

```bash
python3 tools/sim/xsim_runner.py bubble_sort_e2e
```

Expected final log shape:

```text
[PASS] firmware image built
[PASS] Case A UART load/sort
[PASS] Case B GPIO start
[PASS] Case C GPIO pause/step/resume
[PASS] Case D GPIO reset
[PASS] Case E I2C display mode
[PASS] Bubble Sort final E2E XSIM completed
```

## 12. Risks And Mitigations

Risk: compiled C firmware is too large for current `InstrRom`.

Mitigation:

```text
Expose ROM depth parameter and increase only for the final firmware target.
Keep smaller test ROM behavior unchanged for existing tests.
```

Risk: no RV32I bare-metal compiler is available on the machine.

Mitigation:

```text
Make the build script detect toolchain availability and fail clearly.
Do not silently replace final firmware with hand-coded test ROM.
```

Risk: compiler emits unsupported instructions.

Mitigation:

```text
Use -march=rv32i -mabi=ilp32 and audit objdump output.
Reject compressed, multiply/divide, atomic, CSR instructions not implemented by the core, or external runtime calls.
```

Risk: 9600-baud UART makes simulation too slow.

Mitigation:

```text
Use a simulation TOP parameter override for P_UART_BAUD while preserving board default.
Keep one optional low-speed smoke test if needed.
```

Risk: FND external segment decoding is timing-heavy in simulation.

Mitigation:

```text
Use APB_FND register observation for primary functional scoreboarding.
Use segment/digit decode as optional display-level confirmation.
```

Risk: final bitstream uses a different image than E2E simulation.

Mitigation:

```text
Record the firmware .mem path and checksum in the simulation log and build artifacts.
Use the same path or an explicitly generated board image for Vivado.
```

Risk: current two-FPGA I2C pins are split into output/data/OE pins rather than a single bidirectional board pin.

Mitigation:

```text
Keep simulation open-drain model.
Before board upload, add or document the board-safe IOBUF/open-drain adapter wiring.
```

## 13. Definition Of Done

The final integration verification is done when:

- The firmware image is built from `sw/apps/hello_world/src/main.c`.
- `TOP` executes that firmware from `InstrRom`.
- The E2E TB sends array values and commands through UART.
- The E2E TB drives GPIO commands through `iGpioIn`.
- MASTER FND activity is observed during load, sort, and done phases.
- MASTER sends valid SPI trace frames to the external SLAVE DUT.
- MASTER configures/queries SLAVE through I2C.
- SLAVE FND/register state reflects Bubble Sort runtime counters.
- Final UART report matches the expected sorted array and statistics.
- All directed cases pass in one automated XSIM command.
- `tb_MasterSlave_BoardPreflight` still passes as a lower-level protocol regression.

