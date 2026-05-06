# PLIC-lite v1 + I2C/SPI/FND Implementation Plan

## 1. Decision

`RISCV_RV32I_5STAGE`의 기존 `InterruptController`는 full PLIC가 아니라, 단일 machine-mode external interrupt를 만드는 compact INTC이다. I2C, SPI, FND를 추가하는 다음 단계에서는 full PLIC로 바로 가기보다 아래 범위의 **PLIC-lite v1**로 확장한다.

```text
PLIC-lite v1
- source 수 parameter화
- source ID 명시
- source별 gateway
- pending / enable / claim / complete
- source별 priority register
- 단일 threshold
- multi-context 보류
- 기존 table-entry vector는 platform extension으로 유지
```

정확한 성격은 다음과 같이 정의한다.

```text
single-context machine-mode PLIC-like interrupt controller
custom compact MMIO map
RISC-V MEIP/mtvec/mepc/mcause/mstatus flow 유지
```

## 2. Goals

1. PC가 UART로 입력한 배열값과 명령을 MASTER가 받아 Bubble Sort demo를 실행한다.
2. GPIO button으로 start, pause/resume, step, reset 같은 local command를 실행할 수 있게 한다.
3. MASTER FND는 입력 배열 preview와 Bubble Sort 진행 과정을 표시한다.
4. SPI는 MASTER에서 SLAVE로 Bubble Sort trace frame을 전송하는 data plane으로 사용한다.
5. I2C는 MASTER가 SLAVE display mode/status를 설정하고 확인하는 control/status plane으로 사용한다.
6. SLAVE FND는 Bubble Sort 진행에 필요한 pass/compare/swap/total count를 실시간 표시한다.
7. UART/GPIO 기존 interrupt 동작을 유지한다.
8. I2C/SPI 추가 시 source별 우선순위를 software에서 조절할 수 있게 한다.
9. source gateway를 추가해 level interrupt가 `complete` 전 반복 진입하지 않게 한다.
10. I2C/SPI는 event/error interrupt를 분리해 error 우선 처리가 가능하게 한다.
11. FND는 v1에서 MMIO peripheral로만 추가하고, interrupt source에서는 제외한다.
12. 기존 CSR/trap 구조는 유지한다.

## 3. Non-Goals

v1에서 하지 않을 일:

- multi-hart 지원
- S-mode context 지원
- 표준 PLIC 대형 주소 맵 완전 호환
- CLINT/MSIP/MTIP 추가
- nested interrupt 정책 구현
- FND interrupt 기본 추가

## 4. Demo Scenario Contract

Target demo:

```text
PC
  -> UART
  -> MASTER RV32I SoC
      - receives array values
      - shows input preview on MASTER FND
      - starts sort from UART command or GPIO button
      - runs Bubble Sort
      - shows compare/swap/array progress on MASTER FND
      - streams sort trace frames to SLAVE over SPI
      - configures/queries SLAVE display mode/status over I2C
      - returns final sorted array/statistics to PC over UART
  -> SLAVE display target
      - is implemented as a separate FPGA design under src/SLAVE/
      - receives SPI trace frames
      - displays pass/compare/swap/total count on SLAVE FND
      - exposes display mode/status/error registers over I2C
```

Peripheral intent:

| Peripheral | Demo role |
| --- | --- |
| UART | PC input array, PC command, final report |
| GPIO | local start/pause/step/reset buttons and optional LEDs |
| SPI | high-rate MASTER-to-SLAVE Bubble Sort trace frame stream |
| I2C | low-rate SLAVE display configuration, status, and diagnostics |
| MASTER FND | input preview, current compare pair, swap marker, array progress |
| SLAVE FND | pass/compare/swap/total counter display |

The key design rule is to keep SPI and I2C roles separate:

```text
SPI = data plane for frequent sort progress frames
I2C = control/status plane for slower display configuration and health checks
```

## 5. Current Baseline

현재 interrupt path:

```text
UART/GPIO raw irq
  -> InterruptController
  -> ExtIrqPending
  -> CsrFile.mip.MEIP
  -> TrapController
  -> mtvec 또는 INTC vector table target
  -> handler
  -> CLAIM read
  -> peripheral service
  -> COMPLETE write
  -> mret
```

현재 관련 파일:

| File | Current role |
| --- | --- |
| `src/TOP.sv` | UART/GPIO/INTC를 SoC level에서 연결 |
| `src/InterruptController.sv` | INTC wrapper |
| `src/IntcRegIf.sv` | PENDING, ENABLE, CLAIM, COMPLETE, CTRL, VECTOR_ENTRY register |
| `src/IntcPendingCtrl.sv` | raw IRQ latch, pending, in-service 관리 |
| `src/IntcPriorityClaim.sv` | 낮은 source ID 고정 우선순위 claim 선택 |
| `src/IntcVectorTable.sv` | selected source ID별 handler PC lookup |
| `src/CsrFile.sv` | `mip.MEIP`, `mie.MEIE`, `mstatus`, `mtvec`, `mepc`, `mcause` |
| `src/TrapController.sv` | interrupt accept 및 trap redirect |
| `src/APBMux.sv` | UART/GPIO/INTC APB slave select |
| `src/DataBusRouter.sv` | RAM/APB data bus window decode |

현재 source ID:

```text
0 = no interrupt
1 = GPIO
2 = UART
```

현재 한계:

- priority register가 없어 source ID 순서가 policy가 된다.
- threshold가 없어 낮은 priority interrupt를 일괄 차단할 수 없다.
- gateway 책임이 pending/in-service logic과 섞여 있다.
- APB peripheral이 늘어나면 `APBMux`/`APBMASTER` 포트가 계속 증가한다.
- 현재 `DataBusRouter`는 APB window를 좁게 잡고 있어 `0x4000_4000` 이후 peripheral을 추가하려면 수정이 필요하다.

## 6. Target Architecture

```text
PC/UART command or GPIO button
  -> Bubble Sort firmware state machine
  -> MASTER FND update
  -> SPI trace frame to SLAVE
  -> optional I2C SLAVE status/config transaction

Peripheral status/cause
  -> peripheral IRQ output
  -> per-source IntcGateway
  -> PLIC-lite pending bits
  -> priority/threshold/enable selector
  -> MEIP
  -> CSR/trap pipeline
  -> handler
  -> claim/service/complete
```

Block split:

```text
InterruptController
  IntcRegIf
  IntcGateway array
  IntcPendingCtrl
  IntcPriorityClaim
  IntcVectorTable
```

Recommended signal ownership:

| Logic | Owner |
| --- | --- |
| raw irq input sampling and retrigger block | `IntcGateway` |
| pending bit set/clear | `IntcPendingCtrl` |
| in-service set/clear | `IntcPendingCtrl` |
| complete accept vector | `IntcPendingCtrl` |
| priority/threshold winner selection | `IntcPriorityClaim` |
| MMIO register state | `IntcRegIf` |
| table-entry handler PC lookup | `IntcVectorTable` |

## 7. Source ID Map

v1 권장 source 수:

```text
P_NUM_SOURCES = 6
```

Source ID는 1-based로 정의한다. `IntcIrqVec` bit index는 `source_id - 1`이다.

| Source ID | Vector bit | Name | Meaning |
| ---: | ---: | --- | --- |
| 0 | none | NONE | claim 없음 |
| 1 | 0 | GPIO | button edge/status interrupt for start/pause/step/reset |
| 2 | 1 | UART_RX | PC array input and command RX |
| 3 | 2 | I2C_EVENT | SLAVE config/status transaction done |
| 4 | 3 | I2C_ERROR | SLAVE NACK/arbitration/bus error |
| 5 | 4 | SPI_EVENT | sort trace frame transfer done/TX ready |
| 6 | 5 | SPI_ERROR | trace stream overflow/underflow/mode error |

Optional future source:

| Source ID | Name | Meaning |
| ---: | --- | --- |
| 7 | FND_EVENT | 기본 v1에서는 사용하지 않음 |

권장 `rv32i_pkg.sv` 상수:

```systemverilog
localparam int unsigned LP_INTC_NUM_SOURCES   = 6;
localparam int unsigned LP_INTC_SRC_GPIO      = 1;
localparam int unsigned LP_INTC_SRC_UART_RX   = 2;
localparam int unsigned LP_INTC_SRC_I2C_EVENT = 3;
localparam int unsigned LP_INTC_SRC_I2C_ERROR = 4;
localparam int unsigned LP_INTC_SRC_SPI_EVENT = 5;
localparam int unsigned LP_INTC_SRC_SPI_ERROR = 6;
```

`TOP.sv`에서는 concat보다 explicit assignment를 권장한다.

```systemverilog
assign IntcIrqVec[LP_INTC_SRC_GPIO-1]      = GpioIrq;
assign IntcIrqVec[LP_INTC_SRC_UART_RX-1]   = UartRxIrq;
assign IntcIrqVec[LP_INTC_SRC_I2C_EVENT-1] = I2cEventIrq;
assign IntcIrqVec[LP_INTC_SRC_I2C_ERROR-1] = I2cErrorIrq;
assign IntcIrqVec[LP_INTC_SRC_SPI_EVENT-1] = SpiEventIrq;
assign IntcIrqVec[LP_INTC_SRC_SPI_ERROR-1] = SpiErrorIrq;
```

## 8. PLIC-lite Register Map

현재 compact 4KB INTC window는 유지한다.

Base:

```text
LP_APB_INTC_BASE = 0x4000_3000
```

v1 register map은 clean-break 기준으로 다음과 같이 정리한다.

| Offset | Name | Access | Meaning |
| ---: | --- | --- | --- |
| `0x000` | `PENDING` | RO | raw pending bitfield, bit `source_id - 1` |
| `0x004` | `ENABLE` | RW | enable bitfield, bit `source_id - 1` |
| `0x008` | `CLAIM` | RO | selected source ID, read side-effect claim |
| `0x00C` | `COMPLETE` | WO | completed source ID |
| `0x010` | `CTRL` | RW | bit0 `VECTOR_ENABLE`, others reserved |
| `0x014` | `THRESHOLD` | RW | single context priority threshold |
| `0x018` | `INFO` | RO | source count / priority width / feature bits |
| `0x020` | `PRIORITY[0]` | RW/RO | reserved ID0, read 0, write ignored |
| `0x024` | `PRIORITY[1]` | RW | GPIO priority |
| `0x028` | `PRIORITY[2]` | RW | UART_RX priority |
| `0x02C` | `PRIORITY[3]` | RW | I2C_EVENT priority |
| `0x030` | `PRIORITY[4]` | RW | I2C_ERROR priority |
| `0x034` | `PRIORITY[5]` | RW | SPI_EVENT priority |
| `0x038` | `PRIORITY[6]` | RW | SPI_ERROR priority |
| `0x080` | `VECTOR_ENTRY[0]` | RW/RO | reserved ID0, default 0 |
| `0x084` | `VECTOR_ENTRY[1]` | RW | GPIO handler PC |
| `0x088` | `VECTOR_ENTRY[2]` | RW | UART_RX handler PC |
| `0x08C` | `VECTOR_ENTRY[3]` | RW | I2C_EVENT handler PC |
| `0x090` | `VECTOR_ENTRY[4]` | RW | I2C_ERROR handler PC |
| `0x094` | `VECTOR_ENTRY[5]` | RW | SPI_EVENT handler PC |
| `0x098` | `VECTOR_ENTRY[6]` | RW | SPI_ERROR handler PC |

`INFO` suggested bit map:

| Bits | Meaning |
| --- | --- |
| `[7:0]` | `P_NUM_SOURCES` |
| `[15:8]` | `P_PRIORITY_WIDTH` |
| `[16]` | gateway supported |
| `[17]` | threshold supported |
| `[18]` | vector table supported |
| `[31:19]` | reserved 0 |

## 9. Priority and Threshold Policy

Default parameter:

```text
P_PRIORITY_WIDTH = 3
priority range = 0..7
```

Rules:

```text
priority 0 = never selected
source eligible = pending && enable && (priority > threshold)
winner = highest priority eligible source
tie break = lower source ID wins
claim read = winner source ID, or 0 if no eligible source
MEIP = winner exists
```

Reset policy:

```text
ENABLE    = 0
PRIORITY  = 0
THRESHOLD = 0
PENDING   = 0
```

Firmware must explicitly set both `PRIORITY[id]` and `ENABLE[id]`.

Recommended initial firmware priority:

| Source | Priority |
| --- | ---: |
| GPIO | 3 |
| UART_RX | 3 |
| I2C_EVENT | 2 |
| I2C_ERROR | 5 |
| SPI_EVENT | 1 |
| SPI_ERROR | 5 |

This gives:

```text
I2C/SPI error > local/PC command > I2C status event > SPI trace progress event
```

Rationale:

- `I2C_ERROR` and `SPI_ERROR` should preempt the demo.
- `GPIO` and `UART_RX` are user/PC commands, so pause/reset/new command should not wait behind trace traffic.
- `SPI_EVENT` can be frequent during sort progress streaming, so it is intentionally low priority.

## 10. Gateway Behavior

각 source 앞에 gateway를 둔다.

Gateway state:

```text
IDLE
  if raw_irq=1:
    emit pending_set pulse
    blocked=1

BLOCKED
  ignore raw_irq changes
  wait complete_accept for this source
  when complete_accept:
    blocked=0
    re-sample raw_irq on the next cycle
```

Important rule:

```text
claim read clears pending
complete write releases gateway
```

`complete` 전에는 같은 source가 다시 pending을 만들면 안 된다. `complete` 후에도 peripheral raw IRQ가 계속 1이면 다음 cycle에 새 pending을 다시 만든다.

Recommended gateway interface:

```systemverilog
module IntcGateway (
  input  logic iClk,
  input  logic iRstn,
  input  logic iRawIrq,
  input  logic iCompleteAccept,
  output logic oPendingSetPulse,
  output logic oBlocked
);
```

## 11. Pending, Claim, Complete Behavior

`IntcPendingCtrl`는 gateway set pulse, claim, complete를 관리한다.

Expected state:

```text
PendingVec
InServiceVec
CompleteAcceptVec
```

Rules:

```text
gateway pending_set pulse -> PendingVec[source] = 1
claim read with winner id -> PendingVec[source] = 0, InServiceVec[source] = 1
complete write with in-service id -> InServiceVec[source] = 0, CompleteAcceptVec[source] pulse
complete write with invalid/not-in-service id -> no side effect
```

`CLAIM` must be atomic at the APB access completion cycle:

```text
CLAIM read returns selected ID
same access claims that selected ID
```

## 12. I2C Peripheral Plan

Add APB I2C master block to the MASTER SoC:

```text
APB_I2C
  I2cRegs
  I2cCore
```

Demo role:

```text
MASTER I2C controller
  -> configures SLAVE FND display mode
  -> reads SLAVE status, last frame id, and error code
  -> raises I2C_EVENT when a control/status transaction completes
  -> raises I2C_ERROR on NACK/arbitration/bus error
```

Recommended base:

```text
LP_APB_I2C_BASE = 0x4000_2000
```

Required interrupt outputs:

```systemverilog
output logic oEventIrq;
output logic oErrorIrq;
```

Recommended I2C register map:

| Offset | Name | Access | Meaning |
| ---: | --- | --- | --- |
| `0x000` | `CTRL` | RW | enable, start, stop, ack control |
| `0x004` | `STATUS` | RO | busy, done, rx_valid, tx_ready, error summary |
| `0x008` | `TXDATA` | WO | TX byte |
| `0x00C` | `RXDATA` | RO | RX byte |
| `0x010` | `CLKDIV` | RW | SCL divider |
| `0x014` | `ADDR` | RW | slave address / rw |
| `0x018` | `IRQ_STATUS` | RW1C | sticky event/error causes |
| `0x01C` | `IRQ_ENABLE` | RW | cause mask |

Suggested MASTER I2C cause bits:

| Bit | Cause | Group |
| ---: | --- | --- |
| 0 | `DONE` | event |
| 1 | `RX_VALID` | event |
| 2 | `TX_READY` | event |
| 3 | `SLAVE_STATUS_READY` | event |
| 8 | `NACK` | error |
| 9 | `ARB_LOST` | error |
| 10 | `BUS_ERROR` | error |

IRQ outputs:

```text
oEventIrq = |(IRQ_STATUS[event_bits] & IRQ_ENABLE[event_bits])
oErrorIrq = |(IRQ_STATUS[error_bits] & IRQ_ENABLE[error_bits])
```

Handler order:

```text
id = INTC.CLAIM
status = I2C.IRQ_STATUS
service cause
I2C.IRQ_STATUS = clear_mask
INTC.COMPLETE = id
mret
```

Recommended SLAVE I2C register contract:

| Offset | Name | Access from MASTER | Meaning |
| ---: | --- | --- | --- |
| `0x00` | `SLAVE_ID` | RO | fixed display target ID |
| `0x04` | `DISPLAY_MODE` | RW | `0=PASS`, `1=COMPARE`, `2=SWAP`, `3=TOTAL` |
| `0x08` | `STATUS` | RO | ready, busy, error |
| `0x0C` | `LAST_FRAME_ID` | RO | last accepted SPI trace frame |
| `0x10` | `ERROR_CODE` | RO/W1C | SPI/I2C/display error code |
| `0x14` | `BRIGHTNESS` | RW | optional SLAVE FND brightness |

## 13. SPI Peripheral Plan

Add APB SPI master block to the MASTER SoC:

```text
APB_SPI
  SpiRegs
  SpiCore
```

Demo role:

```text
MASTER SPI controller
  -> streams Bubble Sort trace frames to SLAVE
  -> raises SPI_EVENT when a frame transfer completes or TX can accept the next frame
  -> raises SPI_ERROR if the trace stream overflows or transfer framing fails
```

Recommended base:

```text
LP_APB_SPI_BASE = 0x4000_4000
```

Required interrupt outputs:

```systemverilog
output logic oEventIrq;
output logic oErrorIrq;
```

Recommended SPI register map:

| Offset | Name | Access | Meaning |
| ---: | --- | --- | --- |
| `0x000` | `CTRL` | RW | enable, start, CPOL, CPHA, LSB/MSB, CS control |
| `0x004` | `STATUS` | RO | busy, done, tx_ready, rx_valid, fifo flags |
| `0x008` | `TXDATA` | WO | TX data |
| `0x00C` | `RXDATA` | RO | RX data |
| `0x010` | `CLKDIV` | RW | SCLK divider |
| `0x014` | `CS` | RW | chip select mask |
| `0x018` | `IRQ_STATUS` | RW1C | sticky event/error causes |
| `0x01C` | `IRQ_ENABLE` | RW | cause mask |

Suggested MASTER SPI cause bits:

| Bit | Cause | Group |
| ---: | --- | --- |
| 0 | `FRAME_DONE` | event |
| 1 | `TX_READY` | event |
| 2 | `RX_VALID` | event |
| 8 | `RX_OVERFLOW` | error |
| 9 | `TX_UNDERFLOW` | error |
| 10 | `MODE_ERROR` | error |
| 11 | `FRAME_DROPPED` | error |

IRQ outputs:

```text
oEventIrq = |(IRQ_STATUS[event_bits] & IRQ_ENABLE[event_bits])
oErrorIrq = |(IRQ_STATUS[error_bits] & IRQ_ENABLE[error_bits])
```

Recommended SPI trace frame:

```text
frame_id
phase            // LOAD, COMPARE, SWAP, PASS_DONE, DONE
pass_idx
compare_idx
left_value
right_value
swap_flag
changed_index
compare_count
swap_count
total_count
checksum/parity  // optional
```

The SLAVE FND does not need to display every field at once. It selects one counter or mode through the I2C `DISPLAY_MODE` register and updates its FND from the latest SPI frame.

## 14. FND Peripheral Plan

FND는 v1에서 interrupt source로 넣지 않는다. 대신 MASTER local display와 SLAVE remote display target을 역할로 분리한다.

Reason:

- display scan/blink는 local tick으로 처리하는 편이 CPU interrupt보다 자연스럽다.
- FND update complete interrupt는 실사용 가치가 낮다.
- source ID와 priority 정책을 I2C/SPI/UART/GPIO에 집중하는 편이 좋다.

MASTER FND role:

```text
LOAD phase    -> UART로 받은 배열값 preview
COMPARE phase -> 현재 비교 중인 left/right value 표시
SWAP phase    -> swap marker와 바뀐 값 표시
PASS phase    -> pass index 또는 partial array state 표시
DONE phase    -> sorted/done marker 또는 final values 순환 표시
```

SLAVE FND role:

```text
I2C DISPLAY_MODE = PASS     -> pass count 표시
I2C DISPLAY_MODE = COMPARE  -> compare count 표시
I2C DISPLAY_MODE = SWAP     -> swap count 표시
I2C DISPLAY_MODE = TOTAL    -> total operation count 표시
```

Existing candidate:

```text
trashLegacy/APB_FND.sv
trashLegacy/FndRegs.sv
trashLegacy/FndTickGen.sv
trashLegacy/FndController.sv
...
```

Recommended base:

```text
LP_APB_FND_BASE = 0x4000_5000
```

Integration work:

- 필요한 FND files를 `trashLegacy/`에서 `src/`로 승격한다.
- `TOP.sv`에 MASTER FND output port를 추가한다.
- board target에서 FND pin을 쓸 경우 `constrs/*.xdc`를 업데이트한다.
- IRQ output은 만들지 않는다.
- SLAVE FND는 second-FPGA target RTL로 `src/SLAVE/` 아래에 구현한다.
- `tb/`에는 SLAVE protocol model을 둘 수 있지만, 실제 demo는 MASTER `TOP.sv` 내부 SLAVE block이 아니라 외부 SLAVE FPGA와 SPI/I2C pins로 연결한다.

Optional future:

```text
ID7 = FND_EVENT
```

단, v1에서는 구현하지 않는다.

## 15. APB Address Plan

Recommended SoC MMIO map:

| Base | Peripheral |
| ---: | --- |
| `0x4000_0000` | UART |
| `0x4000_1000` | GPIO |
| `0x4000_2000` | I2C |
| `0x4000_3000` | INTC / PLIC-lite |
| `0x4000_4000` | SPI |
| `0x4000_5000` | FND |

Add constants in `rv32i_pkg.sv`:

```systemverilog
localparam logic [31:0] LP_APB_BASE      = 32'h4000_0000;
localparam logic [31:0] LP_APB_LAST      = 32'h4000_FFFF;
localparam logic [31:0] LP_APB_UART_BASE = 32'h4000_0000;
localparam logic [31:0] LP_APB_GPIO_BASE = 32'h4000_1000;
localparam logic [31:0] LP_APB_I2C_BASE  = 32'h4000_2000;
localparam logic [31:0] LP_APB_INTC_BASE = 32'h4000_3000;
localparam logic [31:0] LP_APB_SPI_BASE  = 32'h4000_4000;
localparam logic [31:0] LP_APB_FND_BASE  = 32'h4000_5000;
```

`DataBusRouter.sv` must be updated. Current APB decode is too narrow for SPI/FND.

Recommended:

```systemverilog
assign oApbSel = iReq.ReqValid
              && (iReq.ReqAddr >= LP_APB_BASE)
              && (iReq.ReqAddr <= LP_APB_LAST);
```

or:

```systemverilog
assign oApbSel = iReq.ReqValid && (iReq.ReqAddr[31:16] == LP_APB_BASE[31:16]);
```

Each APB slave still receives 12-bit local offset:

```text
APBCtrl.oPaddr = ReqAddr[11:0]
```

That is enough because each peripheral keeps a 4KB window.

## 16. RTL File Change Plan

### 16.1 `src/rv32i_pkg.sv`

Add:

- APB base/last constants
- I2C/SPI/FND base constants
- INTC source ID constants
- `LP_INTC_NUM_SOURCES`
- optional priority width default constant

Keep existing CSR constants and `LP_MCAUSE_MACHINE_EXT_INT`.

### 16.2 `src/InterruptController.sv`

Change:

- `P_NUM_SOURCES` default from 2 to `rv32i_pkg::LP_INTC_NUM_SOURCES` if package use is acceptable.
- Add parameter `P_PRIORITY_WIDTH = 3`.
- Instantiate `IntcGateway` per source.
- Wire gateway set pulses into `IntcPendingCtrl`.
- Wire complete accept pulses back to gateways.
- Wire priority vector and threshold from `IntcRegIf` into `IntcPriorityClaim`.

Keep:

- `oMachineExtIrq`
- `oVectorValid`
- `oVectorPc`
- `oSelectedSourceId`

### 16.3 `src/IntcGateway.sv`

New file.

Responsibilities:

- block repeated notification until complete accept
- generate one-cycle pending set pulse
- reissue after complete if raw level is still high

### 16.4 `src/IntcPendingCtrl.sv`

Refactor input from raw IRQ to gateway set pulse.

New inputs:

```text
iPendingSetVec
iClaimReadEn
iClaimSelVec
iCompleteWriteEn
iCompleteSelVec
```

New output:

```text
oCompleteAcceptVec
```

Keep:

```text
oPendingVec
oInServiceVec
```

Rules:

- pending set from gateway pulses
- claim clears pending and sets in-service
- complete only accepted when selected source is in-service

### 16.5 `src/IntcRegIf.sv`

Add register state:

```text
PriorityEntryFlat
Threshold
InfoWord
```

Add outputs:

```text
oPriorityEntryFlat
oThreshold
```

Update register map:

- `0x014` becomes `THRESHOLD`
- `0x018` becomes `INFO`
- `0x020 + id*4` becomes `PRIORITY[id]`
- `0x080 + id*4` becomes `VECTOR_ENTRY[id]`

Reset:

```text
EnableVec        = 0
VectorEnable     = 0
VectorEntryFlat  = 0
PriorityEntry    = 0
Threshold        = 0
```

### 16.6 `src/IntcPriorityClaim.sv`

Change from fixed low-ID priority to programmable priority.

Inputs:

```text
iPendingVec
iEnableVec
iPriorityEntryFlat
iThreshold
iCompleteId
```

Output behavior:

```text
selected source = highest priority eligible source
eligible = pending && enable && priority > threshold
tie = lower source ID
oMachineExtIrq = selected valid
oClaimId = selected source ID or 0
```

### 16.7 `src/IntcVectorTable.sv`

Keep table-entry vector as existing platform extension.

Update base offset assumption in tests and docs:

```text
VECTOR_ENTRY[0] starts at INTC offset 0x080
```

No automatic claim is added. Handler still owns `CLAIM` and `COMPLETE`.

### 16.8 `src/TOP.sv`

Add:

- `APB_I2C`
- `APB_SPI`
- `APB_FND`
- I2C/SPI/FND top ports
- I2C/SPI IRQ wires
- Bubble Sort demo firmware가 사용할 MASTER FND MMIO path
- external SLAVE connection pins for I2C and SPI
- wider `IntcIrqVec`
- `InterruptController.P_NUM_SOURCES( LP_INTC_NUM_SOURCES )`

Recommended source vector assignment:

```systemverilog
logic [LP_INTC_NUM_SOURCES-1:0] IntcIrqVec;

assign IntcIrqVec[LP_INTC_SRC_GPIO-1]      = GpioIrq;
assign IntcIrqVec[LP_INTC_SRC_UART_RX-1]   = UartRxIrq;
assign IntcIrqVec[LP_INTC_SRC_I2C_EVENT-1] = I2cEventIrq;
assign IntcIrqVec[LP_INTC_SRC_I2C_ERROR-1] = I2cErrorIrq;
assign IntcIrqVec[LP_INTC_SRC_SPI_EVENT-1] = SpiEventIrq;
assign IntcIrqVec[LP_INTC_SRC_SPI_ERROR-1] = SpiErrorIrq;
```

### 16.9 `src/APBMux.sv` and `src/APBMASTER.sv`

Minimum v1 path:

- add I2C, SPI, FND ports to direct mux
- add select signals `oI2cPsel`, `oSpiPsel`, `oFndPsel`
- add response mux entries

Better follow-up:

- refactor APB slave mux into array/struct style to avoid port explosion

For v1, direct mux is acceptable if tests are updated.

### 16.10 `src/DataBusRouter.sv`

Expand APB window to include all new MMIO bases.

Recommended:

```text
0x4000_0000..0x4000_FFFF -> APB
```

### 16.11 New peripheral files

I2C:

```text
src/APB_I2C.sv
src/I2cRegs.sv
src/I2cCore.sv
```

SPI:

```text
src/APB_SPI.sv
src/SpiRegs.sv
src/SpiCore.sv
```

Planned SLAVE-side second-FPGA files:

```text
src/SLAVE/SortDisplaySlaveTop.sv
src/SLAVE/SpiTraceSlave.sv
src/SLAVE/SortTraceFrameDecoder.sv
src/SLAVE/I2cSlaveRegTarget.sv
src/SLAVE/SortSlaveRegs.sv
src/SLAVE/SlaveFndController.sv
```

Simulation-only models can live in `tb/`, but synthesizable SLAVE RTL should live under `src/SLAVE/` because the SLAVE is a separate FPGA target.

Build boundary:

```text
MASTER FPGA top = current project top `Top`
SLAVE FPGA top  = planned `src/SLAVE/SortDisplaySlaveTop.sv`
```

The SLAVE top should be selected by a later SLAVE-specific build target or manifest. It should not be instantiated inside MASTER `TOP.sv` for the hardware demo.

FND:

```text
src/APB_FND.sv
src/FndRegs.sv
src/FndTickGen.sv
src/FndController.sv
src/FndBcdDecoder.sv
src/FndBlinkEffect.sv
src/FndDigitSelector.sv
src/FndScanCounter.sv
```

FND files can be promoted from `trashLegacy/` after reviewing style and top-level reset polarity.

## 17. Firmware Contract

Initialization order:

```text
1. Set mtvec
2. Configure UART RX interrupt for PC array/command input
3. Configure GPIO button edge interrupts
4. Configure I2C controller and set SLAVE display mode/status defaults
5. Configure SPI controller and trace frame TX path
6. Configure peripheral IRQ status/enable
7. Set INTC PRIORITY[id]
8. Set INTC THRESHOLD
9. Set INTC ENABLE bits
10. Set mie.MEIE
11. Set mstatus.MIE
```

Handler order:

```text
1. id = INTC.CLAIM
2. if id == 0: mret
3. dispatch by id
4. read peripheral IRQ_STATUS
5. service peripheral
6. clear peripheral IRQ_STATUS or consume FIFO/data
7. INTC.COMPLETE = id
8. mret
```

Important:

```text
clear peripheral cause before COMPLETE
```

If software writes COMPLETE while peripheral raw IRQ is still high, gateway will correctly reissue after complete.

Bubble Sort demo firmware state:

```text
IDLE
  wait UART array input

LOADED
  show array preview on MASTER FND
  wait UART SORT_START or GPIO start button

SORTING
  run compare/swap steps
  update MASTER FND
  emit SPI trace frame per step or per visible event
  service GPIO pause/step/reset command when pending

PAUSED
  hold sort state
  allow GPIO step or UART resume command

DONE
  show final values on MASTER FND
  report sorted array and statistics over UART
```

## 18. Implementation Phases

### Phase 0: Freeze map and constants

- [ ] Add INTC source ID constants to `rv32i_pkg.sv`
- [ ] Add I2C/SPI/FND APB base constants
- [ ] Decide `P_PRIORITY_WIDTH = 3`
- [ ] Update docs/tests to new INTC register offsets
- [ ] Freeze Bubble Sort trace frame format
- [ ] Freeze SLAVE I2C display/status register contract

### Phase 1: PLIC-lite core

- [ ] Add `IntcGateway.sv`
- [ ] Refactor `IntcPendingCtrl.sv`
- [ ] Add priority/threshold state to `IntcRegIf.sv`
- [ ] Update `IntcPriorityClaim.sv`
- [ ] Update `InterruptController.sv`
- [ ] Keep vector table extension working at new `0x080` offset

### Phase 2: Existing UART/GPIO migration

- [ ] Update `TOP.sv` source vector mapping to explicit source ID assignments
- [ ] Set `P_NUM_SOURCES = 6`, but leave I2C/SPI IRQ wires tied low until modules exist
- [ ] Update existing UART/GPIO interrupt tests to write priority registers
- [ ] Verify gateway retrigger behavior with UART RX and GPIO status

### Phase 3: APB map expansion

- [ ] Expand `DataBusRouter.sv` APB range
- [ ] Add I2C/SPI/FND selects to `APBMux.sv`
- [ ] Add I2C/SPI/FND response ports to `APBMASTER.sv`
- [ ] Add local error tests for unmapped APB holes

### Phase 4: I2C peripheral

- [ ] Add `APB_I2C.sv`
- [ ] Add `I2cRegs.sv`
- [ ] Add minimal `I2cCore.sv`
- [ ] Implement event/error IRQ outputs
- [ ] Implement SLAVE display mode/status transaction support in firmware
- [ ] Add I2C event/error interrupt tests

### Phase 5: SPI peripheral

- [ ] Add `APB_SPI.sv`
- [ ] Add `SpiRegs.sv`
- [ ] Add minimal `SpiCore.sv`
- [ ] Implement event/error IRQ outputs
- [ ] Implement Bubble Sort trace frame TX path
- [ ] Add SPI event/error interrupt tests

### Phase 6: FND peripheral

- [ ] Promote FND modules from `trashLegacy/`
- [ ] Add `APB_FND` to `TOP.sv`
- [ ] Add MASTER FND output ports
- [ ] Update XDC if targeting board pins
- [ ] Verify MASTER FND MMIO read/write and display output behavior
- [ ] Add SLAVE second-FPGA RTL under `src/SLAVE/`
- [ ] Add SLAVE simulation model in `tb/` only when useful for protocol tests

### Phase 7: Firmware and integration

- [ ] Add software header constants for MMIO bases and INTC offsets
- [ ] Add simple interrupt init routine
- [ ] Add claim/complete helper
- [ ] Add I2C/SPI handler examples
- [ ] Add all-source priority/threshold demo program
- [ ] Add UART array parser and command parser
- [ ] Add GPIO button command handler
- [ ] Add Bubble Sort state machine
- [ ] Add MASTER FND display formatter
- [ ] Add SPI trace frame encoder
- [ ] Add I2C SLAVE display mode/status helper

### Phase 8: End-to-end Bubble Sort demo

- [ ] PC sends array over UART
- [ ] MASTER FND previews loaded array
- [ ] UART command starts sort
- [ ] GPIO button starts sort
- [ ] GPIO pause/resume/step/reset work during sort
- [ ] MASTER FND shows compare/swap/pass/done progress
- [ ] SPI trace frames reach SLAVE display target
- [ ] I2C changes SLAVE FND display mode
- [ ] SLAVE FND shows pass/compare/swap/total count in real time
- [ ] UART reports final sorted array and statistics

## 19. Verification Plan

### Unit-level tests

`IntcGateway`:

- [ ] raw high produces one pending pulse
- [ ] raw high does not repeat before complete
- [ ] complete with raw low returns idle
- [ ] complete with raw high reissues on next cycle

`IntcPendingCtrl`:

- [ ] pending set pulse sets pending
- [ ] claim clears pending and sets in-service
- [ ] complete clears in-service only when matching source is in-service
- [ ] invalid complete has no side effect

`IntcPriorityClaim`:

- [ ] priority 0 never selected
- [ ] disabled source not selected
- [ ] threshold masks `priority <= threshold`
- [ ] highest priority wins
- [ ] same priority lower source ID wins
- [ ] claim ID 0 when no candidate exists

`IntcRegIf`:

- [ ] priority read/write
- [ ] threshold read/write
- [ ] byte strobe merge
- [ ] reserved ID0 priority read 0/write ignored
- [ ] vector entry offset starts at `0x080`
- [ ] invalid addresses raise `PSLVERR`

### TOP-level tests

- [ ] existing UART IRQ still works with priority configured
- [ ] existing GPIO IRQ still works with priority configured
- [ ] UART/GPIO simultaneous IRQ follows priority, not source ID only
- [ ] GPIO button interrupt can preempt frequent SPI trace progress events
- [ ] UART command interrupt can preempt frequent SPI trace progress events
- [ ] threshold blocks lower priority interrupt
- [ ] I2C_ERROR beats I2C_EVENT
- [ ] SPI_ERROR beats SPI_EVENT
- [ ] I2C_ERROR beats UART when priority is higher
- [ ] vector table dispatch works for ID 1..6
- [ ] gateway prevents repeated entry before complete
- [ ] gateway reissues after complete if peripheral cause remains set
- [ ] APB access to I2C/SPI/FND windows reaches correct slave
- [ ] APB access outside mapped windows returns access fault

### Firmware-level tests

- [ ] common mtvec handler reads claim and dispatches by ID
- [ ] table-entry vector mode reaches per-source handlers
- [ ] UART array input parser loads demo array
- [ ] UART `SORT_START` command starts Bubble Sort
- [ ] GPIO start/pause/step/reset command affects Bubble Sort state
- [ ] I2C event handler clears event before complete
- [ ] I2C error handler clears error before complete
- [ ] I2C can set SLAVE `DISPLAY_MODE` and read `LAST_FRAME_ID`
- [ ] SPI event handler clears event before complete
- [ ] SPI error handler clears error before complete
- [ ] SPI trace frame contains pass/compare/swap/total counters
- [ ] MASTER FND formatter shows load/compare/swap/pass/done phases
- [ ] priority/threshold demo masks GPIO while allowing I2C/SPI error

### Scenario-level tests

- [ ] PC UART input array is shown on MASTER FND before sort
- [ ] Bubble Sort progress is visible on MASTER FND
- [ ] SLAVE FND count increments in real time from SPI trace frames
- [ ] I2C display mode changes what the SLAVE FND counts
- [ ] Final UART report matches final sorted array and count statistics

## 20. Compatibility Notes

This is not a full standard PLIC map. It keeps a compact register window because the current SoC uses small APB windows and one machine-mode context.

PLIC-like behavior that v1 keeps:

- source ID 0 means no interrupt
- source-specific pending
- source-specific enable
- source-specific priority
- threshold
- claim read side effect
- complete write gateway release
- priority tie lower ID

PLIC behavior intentionally omitted:

- multi-context enable arrays
- context-specific threshold/claim blocks
- standard large memory map
- multi-hart routing

If full PLIC compatibility is needed later, add a v2 register map or mirror map rather than bending this compact v1 map too far.

## 21. Risks and Guardrails

Risk: old tests assume enable alone is enough to generate MEIP.

Guardrail:

```text
tests and firmware must write PRIORITY[id] > THRESHOLD
```

Risk: SPI/FND base addresses are outside current APB decode window.

Guardrail:

```text
update DataBusRouter APB range before adding those slaves
```

Risk: peripheral raw IRQ remains high after handler.

Guardrail:

```text
handler clears peripheral cause before INTC.COMPLETE
gateway reissue after complete is expected behavior
```

Risk: direct APBMux port list grows too much.

Guardrail:

```text
direct mux is acceptable for v1
array/struct APB mux refactor should be a separate cleanup
```

Risk: FND reset polarity/style from `trashLegacy` may not match current source style.

Guardrail:

```text
review and normalize FND modules before moving to src
```

Risk: SPI and I2C roles become redundant.

Guardrail:

```text
SPI only streams high-rate sort trace frames
I2C only carries low-rate SLAVE display mode/status/diagnostics
```

Risk: SLAVE FND is confused with MASTER APB_FND.

Guardrail:

```text
MASTER FND is local APB MMIO
SLAVE FND is a separate FPGA target under src/SLAVE/
SLAVE FND is driven by SPI trace frames and configured through I2C registers
MASTER TOP only connects to SLAVE through external SPI/I2C pins
```

## 22. Definition of Done

PLIC-lite v1 is done when:

- `P_NUM_SOURCES=6` works in RTL
- gateway blocks repeated source notification before complete
- priority and threshold control source selection
- UART/GPIO existing interrupt tests pass after priority init
- I2C event/error IRQs can be claimed/completed independently
- SPI event/error IRQs can be claimed/completed independently
- MASTER FND is accessible as APB MMIO and has no IRQ dependency
- SLAVE FND display behavior is proven with SPI trace frames and I2C display mode/status registers
- trap path still uses `mip.MEIP`, `mie.MEIE`, `mstatus.MIE`, `mepc`, `mcause`, and `mret` correctly
- table-entry vector mode still works as a platform extension
- end-to-end Bubble Sort demo works from UART input or GPIO start through MASTER/SLAVE FND output
