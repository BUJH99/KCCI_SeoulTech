# INTC Table-Entry Vector Refactor Plan

## 1. Decision

`InterruptController`의 per-source vector 구조는 **1-bit CTRL + table-entry vector**로 단순화한다.

기존 혼합 구조는 다음 상태를 만들기 때문에 제거한다.

```text
CTRL=0x00 -> mtvec fallback
CTRL=0x01 -> base + id * stride
CTRL=0x02 -> table mode bit만 켜짐, 실제 PC는 mtvec
CTRL=0x03 -> VECTOR_ENTRY[id]
```

새 구조는 아래 두 상태만 가진다.

```text
CTRL=0x0 -> 기본/안전 모드, PC = mtvec 기반 target
CTRL=0x1 -> table-entry vector 모드, PC = VECTOR_ENTRY[claim_id]
```

목표는 `0x02` 같은 애매한 상태와 `base + id * stride` 곱셈 경로를 없애고, NPU/DMA/TIMER 같은 source가 늘어도 펌웨어가 handler 주소만 entry에 쓰면 되는 구조로 정리하는 것이다.

## 2. Final Register Map

clean-break 기준으로 `VECTOR_BASE`, `VECTOR_STRIDE` 주소를 제거하고 `VECTOR_ENTRY0`를 앞으로 당긴다.

| Offset | Name | Access | Meaning |
| ---: | --- | --- | --- |
| `0x000` | `PENDING` | RO | pending source bits |
| `0x004` | `ENABLE` | RW | source enable bits |
| `0x008` | `CLAIM` | RO | selected pending source id, read side-effect claims it |
| `0x00C` | `COMPLETE` | WO | completed source id |
| `0x010` | `CTRL` | RW | bit0 `VECTOR_ENABLE`, bits `[31:1]` reserved |
| `0x014` | `VECTOR_ENTRY[0]` | RW | reserved, id 0 means no interrupt |
| `0x018` | `VECTOR_ENTRY[1]` | RW | source id 1 handler, currently GPIO |
| `0x01C` | `VECTOR_ENTRY[2]` | RW | source id 2 handler, currently UART |

If `P_NUM_SOURCES` increases, entries continue at `0x020`, `0x024`, ...

Backward compatibility option:

- If old software already uses `0x020` as `VECTOR_ENTRY0`, keep `LP_REG_VECTOR_ENTRY0 = 12'h020`.
- For this project, the recommended cleanup is to move `VECTOR_ENTRY0` to `0x014` and treat old `0x014/0x018` base/stride behavior as removed.

## 3. CTRL Definition

| Bit | Name | Reset | Meaning |
| ---: | --- | ---: | --- |
| `0` | `VECTOR_ENABLE` | `0` | `0=mtvec fallback`, `1=use VECTOR_ENTRY[claim_id] when entry is valid` |
| `[31:1]` | reserved | `0` | write ignored or masked to zero on readback |

Recommended readback behavior:

```text
CTRL read = {31'd0, VectorEnable}
```

Recommended write behavior:

```text
VectorEnable_d = CtrlWriteWord[0]
```

Do not expose a table mode bit anymore. Table entry is the only INTC vector mode.

## 4. Target Hardware Flow

```text
GPIO/UART/NPU/DMA raw irq
  -> IntcPendingCtrl
      pending/in-service state
  -> IntcPriorityClaim
      pending & enable
      lowest source index wins
      source index 0 -> claim id 1
  -> IntcVectorTable
      TableEntryPc = VECTOR_ENTRY[claim_id]
      VectorValid = CTRL[0] && selected_source_valid && claim_id != 0 && TableEntryPc != 0
  -> TrapController
      if machine external interrupt && VectorValid:
        PC = TableEntryPc
      else:
        PC = mtvec direct/vectored target
```

Important rule:

Even in table-entry vector mode, the ISR must still read `CLAIM` near the start and write `COMPLETE` at the end. Vectoring chooses the first handler PC; it does not replace claim/complete ownership.

## 5. Files To Change

### 5.1 `src/IntcRegIf.sv`

Remove these ports:

```text
oVectorTableMode
oVectorBase
oVectorStride
```

Remove these state signals and write merge helpers:

```text
VectorTableMode_d
VectorBase_d
VectorStride_d
VectorBaseWriteWord
VectorStrideWriteWord
```

Remove these localparams:

```text
LP_REG_VECTOR_BASE
LP_REG_VECTOR_STRIDE
```

Change:

```text
LP_REG_VECTOR_ENTRY0 = 12'h014
```

Keep:

```text
oVectorEnable
oVectorEntryFlat
```

Update `CTRL` handling:

- `CtrlWord[0] = oVectorEnable`
- reserved bits read as zero
- write only updates `VectorEnable_d`

Update APB decode:

- `0x014 + n*4` accesses `VECTOR_ENTRY[n]`
- no separate case for `VECTOR_BASE`
- no separate case for `VECTOR_STRIDE`
- unknown addresses still set `oPslverr = 1`

Reset state:

```text
oVectorEnable    <= 1'b0
oVectorEntryFlat <= '0
```

### 5.2 `src/InterruptController.sv`

Remove wrapper wires:

```text
VectorTableMode
VectorBase
VectorStride
```

Remove `IntcRegIf` connections:

```text
.oVectorTableMode(...)
.oVectorBase(...)
.oVectorStride(...)
```

Remove `IntcVectorTable` inputs:

```text
.iVectorTableMode(...)
.iVectorBase(...)
.iVectorStride(...)
```

Keep the existing split:

```text
IntcRegIf
IntcPendingCtrl
IntcPriorityClaim
IntcVectorTable
```

The module split is still useful because `IntcRegIf` owns MMIO registers while `IntcVectorTable` owns PC lookup.

### 5.3 `src/IntcVectorTable.sv`

Remove stride path:

```text
iVectorTableMode
iVectorBase
iVectorStride
VectorBaseAligned
VectorStrideAligned
BaseStridePc
selected_id * stride
```

Keep table lookup:

```text
for each entry:
  if iSelectedSourceId == EntryIdx:
    TableEntryPc = iVectorEntryFlat[(EntryIdx * 32) +: 32]
```

Recommended final behavior:

```text
oVectorPc = {TableEntryPc[31:2], 2'b00}

oVectorValid = iVectorEnable
            && iSelectedSourceValid
            && (iSelectedSourceId != 32'd0)
            && (TableEntryPc[31:2] != 30'd0)
```

The nonzero entry guard makes `CTRL=1` safe before all entries are initialized. Unprogrammed entry value `0` falls back to `mtvec` instead of jumping to address zero.

### 5.4 `tb/tb_TOP.sv`

Current testbench contains old vector base/stride expectations. Update them to table-entry behavior.

Replace old intent:

```text
LP_INTC_VECTOR_BASE
LP_GPIO_VECTOR_SLOT = base + 4
LP_UART_VECTOR_SLOT = base + 8
write VECTOR_BASE
expect oVectorBase
expect oVectorStride
```

With new intent:

```text
LP_INTC_VECTOR_ENTRY0 = 0x014
LP_GPIO_VECTOR_ENTRY  = 0x018
LP_UART_VECTOR_ENTRY  = 0x01C
write VECTOR_ENTRY[1] = gpio handler PC
write VECTOR_ENTRY[2] = uart handler PC
write CTRL = 1
expect oVectorEnable == 1
expect oVectorEntryFlat entry values
```

Test entry mapping:

```text
claim id 1 -> GPIO -> VECTOR_ENTRY[1]
claim id 2 -> UART -> VECTOR_ENTRY[2]
```

### 5.5 Docs And Firmware Constants

Update any local firmware/header/docs constants:

```text
INTC_CTRL              = base + 0x010
INTC_VECTOR_ENTRY0     = base + 0x014
INTC_VECTOR_ENTRY(id)  = INTC_VECTOR_ENTRY0 + id * 4
```

Remove or mark obsolete:

```text
INTC_VECTOR_BASE
INTC_VECTOR_STRIDE
INTC_CTRL_TABLE_MODE
```

The old `md/INTC_PER_SOURCE_VECTOR_PLAN.md` is superseded by this plan for the final implementation direction.

## 6. Firmware Init Sequence

Safe boot sequence:

```text
1. Set mtvec to common trap handler.
2. Keep INTC CTRL.VECTOR_ENABLE = 0.
3. Program VECTOR_ENTRY[1] = gpio_isr.
4. Program VECTOR_ENTRY[2] = uart_isr.
5. Enable required INTC sources.
6. Enable CSR mie.MEIE.
7. Enable CSR mstatus.MIE.
8. Set INTC CTRL.VECTOR_ENABLE = 1.
```

ISR sequence in table-entry mode:

```text
gpio_isr:
  id = INTC_CLAIM
  handle GPIO cause
  clear GPIO irq status
  INTC_COMPLETE = id
  mret

uart_isr:
  id = INTC_CLAIM
  drain/read UART RX cause
  INTC_COMPLETE = id
  mret
```

Do not skip `CLAIM`. Direct vectoring does not clear pending by itself.

## 7. Verification Plan

### 7.1 Register Tests

Check after reset:

```text
CTRL == 0
VECTOR_ENTRY[0..P_NUM_SOURCES] == 0
PENDING == 0
ENABLE == 0
```

Check APB access:

```text
write/read CTRL bit0
reserved CTRL bits read zero
write/read VECTOR_ENTRY[1]
write/read VECTOR_ENTRY[2]
write to PENDING -> PSLVERR
read COMPLETE -> PSLVERR
access removed old base/stride offsets according to final map behavior
```

If `VECTOR_ENTRY0` moves to `0x014`, then `0x014` and `0x018` are valid entries, not old base/stride.

### 7.2 Redirect Tests

Test `CTRL=0`:

```text
IRQ pending and enabled
TrapController receives machine external interrupt
VectorValid is false
PC redirects to mtvec target
```

Test `CTRL=1`, programmed entry:

```text
GPIO pending -> selected id 1 -> PC = VECTOR_ENTRY[1]
UART pending -> selected id 2 -> PC = VECTOR_ENTRY[2]
```

Test `CTRL=1`, unprogrammed entry:

```text
entry value 0
VectorValid false
PC falls back to mtvec
```

Test simultaneous pending:

```text
GPIO and UART pending
GPIO id 1 selected first
CLAIM GPIO
COMPLETE GPIO
UART id 2 selected next
```

### 7.3 Claim/Complete Tests

Verify the old semantics do not change:

```text
CLAIM read clears selected pending bit
CLAIM read sets selected in-service bit
COMPLETE write clears matching in-service bit
raw irq held high does not re-pend while in-service
raw irq still high after COMPLETE re-pends
```

### 7.4 Timing And Resource Checks

Compare before/after Vivado reports:

```text
Fmax / WNS
critical path through IntcVectorTable
LUT count around INTC
FF count around INTC
DSP count must remain 0
```

Expected result:

```text
cycle latency: mostly unchanged
combinational delay: better than programmable stride path
resource: slightly fewer FFs because base/stride registers are removed
```

## 8. Acceptance Criteria

Implementation is complete when:

```text
1. src no longer contains VectorTableMode, VectorBase, VectorStride.
2. src no longer contains VECTOR_BASE or VECTOR_STRIDE register decode.
3. CTRL has only bit0 as active behavior.
4. PC vectoring only uses VECTOR_ENTRY[claim_id].
5. CTRL=0 always falls back to mtvec.
6. CTRL=1 with valid entry redirects directly to the matching source handler.
7. CLAIM/COMPLETE behavior is unchanged.
8. tb_TOP.sv no longer expects old vector base/stride registers.
9. Simulation passes the interrupt vector tests.
10. Vivado synthesis/timing completes without a new critical-path regression.
```

Recommended grep checks:

```bash
rg "VectorTableMode|VectorBase|VectorStride|VECTOR_BASE|VECTOR_STRIDE" src tb
```

Expected result after implementation:

```text
no matches in src/tb
```

Historical docs may still mention the old design, but the active implementation and active tests should not.

## 9. Implementation Order

Use this order to keep failures easy to debug:

```text
1. Update IntcVectorTable to table-only lookup.
2. Update InterruptController port wiring.
3. Update IntcRegIf register map and state.
4. Update tb_TOP.sv constants and checks.
5. Run syntax/elaboration.
6. Run interrupt testbench flow.
7. Run Vivado timing verification.
8. Update old docs or mark them superseded.
```

Do not change `IntcPendingCtrl` or `IntcPriorityClaim` unless a test proves a bug there. The table-entry refactor should only change vector target selection and MMIO register shape.
