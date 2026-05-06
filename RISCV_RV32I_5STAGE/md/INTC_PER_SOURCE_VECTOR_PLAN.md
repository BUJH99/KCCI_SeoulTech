# INTC Per-Source Vector Implementation Plan

> Superseded: final implementation direction is now `INTC_TABLE_ENTRY_VECTOR_REFACTOR_PLAN.md`, which removes `VECTOR_BASE`/`VECTOR_STRIDE` and uses `CTRL[0] + VECTOR_ENTRY[claim_id]` only.

## 1. Goal

이 문서는 `RISCV_RV32I_5STAGE`에 **INTC per-source vector** 기능을 추가하기 위한 최종 구현 계획이다.

목표는 단순 학습용 interrupt가 아니라, 다음 두 요구를 동시에 만족하는 구조를 만드는 것이다.

1. RISC-V privileged architecture의 기본 trap/interrupt 흐름을 유지한다.
2. 프로젝트 확장 기능으로 external interrupt source별 handler 주소로 직접 redirect할 수 있게 한다.

중요한 설계 원칙은 다음과 같다.

- 표준 `mtvec` direct/vectored 동작은 반드시 유지한다.
- INTC per-source vector는 기본 동작이 아니라 명시적으로 enable되는 platform extension으로 둔다.
- per-source vector가 꺼져 있을 때는 모든 machine external interrupt가 표준적으로 `mcause=0x8000_000B`와 `mtvec` 경로를 사용해야 한다.
- per-source vector가 켜져 있을 때도 `mepc`, `mcause`, `mstatus.MIE/MPIE`, `mret`, `claim/complete` 의미는 깨지면 안 된다.

## 2. Current Baseline

현재 흐름은 다음과 같다.

```text
UART/GPIO IRQ
  -> InterruptController
  -> ExtIrqPending
  -> CsrFile.mip.MEIP
  -> TrapController
  -> PC = mtvec
  -> common trap handler
  -> software reads INTC CLAIM
  -> software dispatches by ClaimId
```

현재 핵심 모듈 역할은 다음과 같다.

| Module | Current role |
| --- | --- |
| `IntcPendingCtrl.sv` | raw IRQ를 pending으로 latch하고 claim/complete 상태를 관리 |
| `IntcPriorityClaim.sv` | pending & enable 중 우선순위 source를 골라 `ClaimId` 생성 |
| `IntcRegIf.sv` | PENDING, ENABLE, CLAIM, COMPLETE MMIO register 제공 |
| `InterruptController.sv` | INTC wrapper, `oMachineExtIrq` 생성 |
| `CsrFile.sv` | `mstatus`, `mie`, `mip`, `mtvec`, `mepc`, `mcause` 관리 |
| `TrapController.sv` | trap/interrupt accept, EPC/cause 선택, redirect PC 생성 |
| `PipeFlowCtrl.sv` | PC enable, flush, hold 제어 |

현재는 interrupt source별 handler 주소를 하드웨어가 고르지 않는다. `TrapController`는 trap redirect PC를 항상 `mtvec`로 보낸다.

## 3. Target Architecture

최종 구조는 다음과 같다.

```text
Peripheral IRQs
  UART/GPIO/SPI/I2C/...
    -> INTC pending/enable/priority
    -> selected source id
    -> ExtIrqPending
    -> CSR mip.MEIP
    -> TrapController
        standard mode:
          PC = mtvec direct/vectored target
        INTC per-source vector mode:
          PC = INTC vector target for selected source id
    -> handler
    -> INTC CLAIM
    -> service peripheral
    -> INTC COMPLETE
    -> mret
```

권장 block split은 다음과 같다.

```text
InterruptController
  IntcRegIf
  IntcPendingCtrl
  IntcPriorityClaim
  IntcVectorTable      <- new
  IntcVectorCtrl       <- optional small helper, if table logic grows

TrapController
  TrapVectorTarget     <- new helper or integrated logic
```

## 4. Standard Compatibility Policy

RISC-V 표준 관점에서 machine external interrupt의 cause는 `11`이다. 따라서 표준 `mtvec.MODE=Vectored`만 사용하면 external interrupt는 source가 UART든 GPIO든 기본적으로:

```text
PC = mtvec.BASE + 4 * 11
```

로 간다.

따라서 이 프로젝트의 per-source vector는 다음처럼 정의한다.

```text
INTC per-source vector = platform-specific fast external interrupt dispatch extension
```

호환성 규칙은 다음과 같다.

| Mode | Redirect target |
| --- | --- |
| `INTC_VECTOR_EN=0`, `mtvec.MODE=Direct` | `mtvec.BASE` |
| `INTC_VECTOR_EN=0`, `mtvec.MODE=Vectored`, interrupt | `mtvec.BASE + 4 * mcause_code` |
| `INTC_VECTOR_EN=0`, exception | `mtvec.BASE` |
| `INTC_VECTOR_EN=1`, machine external interrupt | `intc_vector_target[SelectedSourceId]` |
| `INTC_VECTOR_EN=1`, non-external interrupt or exception | standard `mtvec` target |

이렇게 하면 표준 동작을 기본값으로 보존하면서, 프로젝트에서 원하는 source별 direct handler 진입을 선택 기능으로 제공할 수 있다.

## 5. Register Map Plan

현재 INTC register는 다음과 같다.

```text
0x000 PENDING   RO
0x004 ENABLE    RW
0x008 CLAIM     RO
0x00C COMPLETE  WO
```

per-source vector를 위해 다음 register를 추가한다.

```text
0x010 CTRL
0x014 VECTOR_BASE
0x018 VECTOR_STRIDE
0x020 VECTOR_ENTRY0
0x024 VECTOR_ENTRY1
0x028 VECTOR_ENTRY2
...
```

권장 register 의미:

| Register | Bits | Meaning |
| --- | --- | --- |
| `CTRL` | `[0]` | `VECTOR_EN`, per-source vector enable |
| `CTRL` | `[1]` | `TABLE_MODE`, `0=base+stride`, `1=entry table` |
| `CTRL` | `[2]` | `AUTO_CLAIM_ON_VECTOR`, 초기 구현에서는 `0`만 지원 |
| `VECTOR_BASE` | `[31:2]` | vector base address, word aligned |
| `VECTOR_STRIDE` | `[7:2]` | bytes per source slot, 기본 `4` 또는 `16` |
| `VECTOR_ENTRYn` | `[31:2]` | source n handler address, word aligned |

초기 구현은 단순하게 시작한다.

```text
Phase 1:
  VECTOR_EN
  VECTOR_BASE
  VECTOR_STRIDE = fixed 4
  target = VECTOR_BASE + SelectedSourceId * 4

Phase 2:
  VECTOR_ENTRYn table 추가
  target = VECTOR_ENTRY[SelectedSourceId]
```

source ID 정책은 기존과 동일하게 둔다.

```text
ClaimId 0 = no interrupt
ClaimId 1 = source index 0
ClaimId 2 = source index 1
...
```

따라서 base+stride mode에서는 ID 0 slot을 비워두고 다음처럼 배치한다.

```text
VECTOR_BASE + 0  : no interrupt / reserved
VECTOR_BASE + 4  : source ID 1 handler
VECTOR_BASE + 8  : source ID 2 handler
VECTOR_BASE + 12 : source ID 3 handler
```

## 6. RTL Change Plan

### 6.1 `rv32i_pkg.sv`

추가할 상수:

```systemverilog
localparam logic [31:0] LP_MCAUSE_MACHINE_SOFT_INT  = 32'h8000_0003;
localparam logic [31:0] LP_MCAUSE_MACHINE_TIMER_INT = 32'h8000_0007;
localparam logic [31:0] LP_MCAUSE_MACHINE_EXT_INT   = 32'h8000_000B;

localparam int unsigned LP_MTVEC_MODE_LSB = 0;
localparam int unsigned LP_MTVEC_MODE_MSB = 1;
localparam logic [1:0]  LP_MTVEC_MODE_DIRECT   = 2'b00;
localparam logic [1:0]  LP_MTVEC_MODE_VECTORED = 2'b01;
```

필요하면 helper function을 추가한다.

```systemverilog
function automatic logic McauseIsInterrupt(input logic [31:0] iMcause);
function automatic logic [30:0] McauseCode(input logic [31:0] iMcause);
```

### 6.2 `CsrFile.sv`

현재 `mtvec` write는 하위 2비트를 버린다.

```systemverilog
MtvecNext = {iCsrWriteData[31:2], 2'b00};
```

변경 후에는 mode를 보존한다.

```systemverilog
unique case (iCsrWriteData[1:0])
  LP_MTVEC_MODE_DIRECT,
  LP_MTVEC_MODE_VECTORED: MtvecNext = iCsrWriteData;
  default:                MtvecNext = {iCsrWriteData[31:2], LP_MTVEC_MODE_DIRECT};
endcase
```

권장 CSR 확장:

- `mstatus.MPP`
- `mie.MSIE`, `mie.MTIE`, `mie.MEIE`
- `mip.MSIP`, `mip.MTIP`, `mip.MEIP`
- `mtval`

처음에는 `mtval=0`으로 구현하고, instruction/load/store fault에서 나중에 실제 fault value를 연결한다.

### 6.3 `IntcPriorityClaim.sv`

현재 `oClaimId`만 외부로 제공한다. per-source vector용으로 selected source 정보를 wrapper까지 명시적으로 올린다.

추가 output:

```systemverilog
output logic [31:0] oSelectedSourceId,
output logic        oSelectedSourceValid
```

`oSelectedSourceId`는 `oClaimId`와 동일하게 1-based ID를 사용한다.

주의:

- vector target 계산을 위해 selected source ID를 쓰더라도 pending clear는 하지 않는다.
- pending clear는 기존처럼 software가 CLAIM register를 읽을 때만 수행한다.
- 이렇게 해야 기존 claim/complete 의미가 보존된다.

### 6.4 `IntcRegIf.sv`

register decode 확장:

```text
0x010 CTRL
0x014 VECTOR_BASE
0x018 VECTOR_STRIDE
0x020 VECTOR_ENTRY0...
```

추가 output:

```systemverilog
output logic        oVectorEnable,
output logic        oVectorTableMode,
output logic [31:0] oVectorBase,
output logic [31:0] oVectorStride,
output logic [31:0] oVectorEntry [P_NUM_SOURCES:0]
```

SystemVerilog packed/unpacked array port 제약이나 tool 호환성이 불편하면, Phase 1에서는 entry table 없이 base+stride만 구현한다.

### 6.5 New `IntcVectorTable.sv`

Phase 1 module interface:

```systemverilog
module IntcVectorTable #(
  parameter int unsigned P_NUM_SOURCES = 2
) (
  input  logic        iVectorEnable,
  input  logic [31:0] iVectorBase,
  input  logic [31:0] iVectorStride,
  input  logic        iSelectedSourceValid,
  input  logic [31:0] iSelectedSourceId,

  output logic        oVectorValid,
  output logic [31:0] oVectorPc
);
```

Phase 1 target:

```systemverilog
oVectorValid = iVectorEnable && iSelectedSourceValid && (iSelectedSourceId != 32'd0);
oVectorPc    = {iVectorBase[31:2], 2'b00}
             + (iSelectedSourceId * {iVectorStride[31:2], 2'b00});
```

기본 stride는 `4`를 권장하지만, handler slot에 `jal real_handler` 같은 branch stub을 넣을 경우 `4`면 충분하다. 더 큰 prologue slot을 원하면 `16`을 기본값으로 잡는다.

### 6.6 `InterruptController.sv`

추가 output:

```systemverilog
output logic        oVectorValid,
output logic [31:0] oVectorPc,
output logic [31:0] oSelectedSourceId
```

내부 연결:

```text
IntcPriorityClaim.oSelectedSourceId
  -> IntcVectorTable
  -> InterruptController.oVectorPc
```

`oMachineExtIrq`는 그대로 `|ClaimPendingVec`에서 만든다.

### 6.7 `TOP.sv`

`InterruptController`와 `TrapController` 사이에 vector target 신호를 추가한다.

```systemverilog
logic        IntcVectorValid;
logic [31:0] IntcVectorPc;
logic [31:0] IntcSelectedSourceId;
```

`TrapController` 입력에 연결:

```systemverilog
.iIntcVectorValid(IntcVectorValid),
.iIntcVectorPc   (IntcVectorPc)
```

### 6.8 `TrapController.sv`

추가 input:

```systemverilog
input logic        iIntcVectorValid,
input logic [31:0] iIntcVectorPc
```

추가 내부 구분:

```systemverilog
logic TrapIsInterrupt;
logic [31:0] MtvecBase;
logic [1:0] MtvecMode;
logic [31:0] StandardTrapPc;
```

redirect priority:

```text
1. synchronous trap target uses standard mtvec rule
2. non-external interrupt uses standard mtvec rule
3. machine external interrupt:
   if INTC vector valid, use iIntcVectorPc
   else use standard mtvec rule
```

주의:

- `oTrapEnterCause`는 계속 `LP_MCAUSE_MACHINE_EXT_INT`로 기록한다.
- source별 ID는 `mcause`에 넣지 않는다.
- source별 ID가 필요하면 handler가 CLAIM을 읽는다.
- custom CSR에 selected source ID snapshot을 넣는 것은 Phase 2에서만 고려한다.

### 6.9 `PipeFlowCtrl.sv`

현재 interrupt accept는 `TrapFromEx`/`TrapFromMem`을 세우지 않는다. per-source vector와 별개로 precise interrupt를 위해 점검해야 한다.

권장 변경:

```text
TrapCaptureValid가 interrupt일 때도 IF/ID younger instruction이 잘못 진행하지 않도록
IDEXFlush 조건 또는 별도 TrapFromInterrupt를 추가한다.
```

새 input 후보:

```systemverilog
input logic iTrapFromInterrupt
```

그리고:

```systemverilog
oIdexFlushReq = iTrapFromMem
              || iTrapFromEx
              || iTrapFromInterrupt
              || iExRedirectValid
              || iLoadUseStall;
```

이 항목은 per-source vector 구현 전에 먼저 검증해도 좋다.

## 7. Software Contract

per-source vector를 켠 뒤에도 handler는 다음 규칙을 따른다.

```text
1. handler entry
2. save volatile context
3. read INTC CLAIM
4. verify claim id matches expected source or dispatch fallback
5. service peripheral
6. clear peripheral interrupt condition
7. write INTC COMPLETE with claim id
8. restore context
9. mret
```

권장 vector table layout:

```asm
.align 6
intc_vector_base:
  j irq_reserved        # ID 0
  j gpio_irq_handler    # ID 1
  j uart_irq_handler    # ID 2
  j spi_irq_handler     # ID 3
  j i2c_irq_handler     # ID 4
```

초기 boot code sequence:

```text
write mtvec = common_trap_base | direct/vectored mode
write INTC_VECTOR_BASE = intc_vector_base
write INTC_VECTOR_STRIDE = 4
write INTC_CTRL.VECTOR_EN = 1
write INTC_ENABLE for enabled sources
write mie.MEIE = 1
write mstatus.MIE = 1
```

## 8. Verification Plan

### 8.1 Unit-level checks

`IntcVectorTable`:

- `VECTOR_EN=0`이면 `oVectorValid=0`
- selected ID 0이면 vector invalid
- selected ID 1이면 `base + stride`
- selected ID 2이면 `base + 2*stride`
- unaligned base/stride write는 word aligned로 정리

`IntcRegIf`:

- 기존 PENDING/ENABLE/CLAIM/COMPLETE 동작 유지
- CTRL write/readback
- VECTOR_BASE write/readback
- VECTOR_STRIDE reset/default/write/readback
- invalid address `PSLVERR`

`TrapController`:

- synchronous trap이 interrupt보다 우선
- `INTC_VECTOR_EN=0`이면 기존 mtvec target
- `INTC_VECTOR_EN=1`이고 external interrupt이면 `IntcVectorPc`
- `mcause`는 source별 값이 아니라 `0x8000_000B`
- `mepc`는 interrupted PC

### 8.2 Integration simulation

시나리오:

1. GPIO IRQ only
   - source ID 1 selected
   - PC redirects to `VECTOR_BASE + 4`
   - CLAIM returns 1
   - COMPLETE clears in-service

2. UART IRQ only
   - source ID 2 selected
   - PC redirects to `VECTOR_BASE + 8`
   - CLAIM returns 2

3. GPIO and UART simultaneous
   - priority rule selects lower source ID first
   - second source remains pending until first complete

4. vector disabled
   - external interrupt redirects to standard `mtvec` path

5. synchronous trap and external IRQ same cycle
   - MEM/EX/ID trap priority wins
   - IRQ remains pending

6. APB stall active
   - trap/vector redirect delayed consistently with existing `MemApbStall` gating

7. mret
   - PC returns to `mepc`
   - `mstatus.MIE <= MPIE`

### 8.3 Regression checks

- Existing normal instruction programs still retire correctly.
- Existing trap entry behavior works when `INTC_VECTOR_EN=0`.
- CSR instructions still read/write `mtvec`, `mie`, `mip`, `mepc`, `mcause`.
- Interrupt source pending does not disappear before software CLAIM.

## 9. Implementation Phases

### Phase 0: Standard trap cleanup

1. Preserve `mtvec.MODE`.
2. Implement standard direct/vectored target calculation.
3. Add tests for direct/vectored `mtvec`.
4. Fix precise interrupt flush if needed.

Exit criteria:

- Existing trap tests pass.
- `mtvec.MODE=Direct` behaves like current design.
- `mtvec.MODE=Vectored` sends machine external interrupt to `BASE + 4*11`.

### Phase 1: INTC base+stride per-source vector

1. Add `CTRL.VECTOR_EN`.
2. Add `VECTOR_BASE`.
3. Add fixed or writable `VECTOR_STRIDE`.
4. Add `IntcVectorTable.sv`.
5. Expose `oVectorValid/oVectorPc` from `InterruptController`.
6. Route vector target into `TrapController`.
7. Add integration tests for GPIO/UART vector target.

Exit criteria:

- `VECTOR_EN=0` preserves standard path.
- `VECTOR_EN=1` redirects source ID 1/2 to expected PC.
- CLAIM/COMPLETE behavior remains software-controlled.

### Phase 2: Table-entry mode

1. Add `VECTOR_ENTRYn` register array.
2. Add `TABLE_MODE`.
3. Select between base+stride target and entry target.
4. Add tests for individually programmed handler addresses.

Exit criteria:

- each source can redirect to an arbitrary word-aligned handler address.
- table mode and base+stride mode are both test-covered.

### Phase 3: PLIC-like feature growth

1. Add priority register per source.
2. Add threshold register.
3. Keep source ID 0 reserved.
4. Expand source count for SPI/I2C.
5. Decide whether to align register map closer to PLIC-compatible layout.

Exit criteria:

- simultaneous interrupts respect priority, not only lowest source index.
- SPI/I2C sources integrate without changing trap/CSR contract.

## 10. Risk Register

| Risk | Impact | Mitigation |
| --- | --- | --- |
| per-source vector breaks RISC-V `mtvec` semantics | software incompatibility | keep feature disabled by default; standard path remains golden |
| source ID used before CLAIM creates stale vector | wrong handler entry | vector target uses selected pending source but does not clear pending; handler still CLAIMs |
| simultaneous IRQ priority and vector mismatch | wrong source handler | `SelectedSourceId`, `ClaimId`, and vector target must come from the same priority selector |
| APB stall overlaps interrupt accept | duplicated or lost trap | keep existing `MemApbStall` gating and add directed tests |
| handler forgets COMPLETE | source stuck in-service | document software contract and add test |
| I2C/SPI source count expansion breaks register width | integration churn | parameterize `P_NUM_SOURCES` and test with 2, 4, 8 sources |

## 11. Final Recommendation

최종적으로는 다음 순서가 가장 안전하다.

```text
1. Standard mtvec direct/vectored 구현
2. INTC per-source vector를 optional extension으로 추가
3. base+stride mode부터 검증
4. table-entry mode 추가
5. SPI/I2C source 확장
6. priority/threshold를 붙여 PLIC-like 방향으로 성장
```

이 방식이면 RISC-V 표준 trap 흐름을 잃지 않으면서, 프로젝트 목표인 source별 빠른 interrupt handler 진입도 구현할 수 있다.
