# RISCV_RV32I_5STAGE Interrupt SW Programming Guide

이 문서는 현재 `RISCV_RV32I_5STAGE` RTL 기준으로 SW에서 interrupt를 설정하고 처리하기 위한 HW contract를 정리한다. GPIO/UART/I2C/SPI는 compact PLIC-lite INTC를 통해 machine external interrupt로 처리하고, APB timer는 별도의 machine timer interrupt(`MTIP`)로 처리한다.

## 1. 전체 구조

```text
External peripheral IRQ
  -> IntcGateway
  -> IntcPendingCtrl
  -> IntcPriorityClaim
  -> CsrFile.mip.MEIP
  -> TrapController
  -> mtvec or INTC vector PC
  -> SW handler
  -> CLAIM read
  -> peripheral service
  -> COMPLETE write
  -> mret
```

```text
APB_Timer
  -> CsrFile.mip.MTIP
  -> TrapController
  -> mtvec direct/vectored target
  -> SW timer handler
  -> TIMER_STATUS W1C clear
  -> mret
```

핵심 동작은 다음과 같다.

- 각 peripheral raw IRQ는 `IntcGateway`를 지나 pending set pulse가 된다.
- `IntcPendingCtrl`은 pending 상태와 in-service 상태를 관리한다.
- `IntcPriorityClaim`은 pending, enable, priority, threshold를 기준으로 source ID 하나를 선택한다.
- 선택 가능한 source가 있으면 `oMachineExtIrq`가 올라가고, 이것이 `CsrFile.mip.MEIP`로 들어간다.
- core는 external interrupt에 대해 `mstatus.MIE && mie.MEIE && mip.MEIP` 조건에서 trap을 받는다.
- core는 timer interrupt에 대해 `mstatus.MIE && mie.MTIE && mip.MTIP` 조건에서 trap을 받는다.
- SW는 handler에서 `CLAIM`을 읽어 source ID를 얻고, 해당 peripheral 원인을 처리한 뒤 같은 ID를 `COMPLETE`에 쓴다.
- Timer handler는 `CLAIM/COMPLETE`를 사용하지 않고 `TIMER_STATUS`를 W1C로 clear한다.

관련 구조도:

- `src/dataflow_svgs/interrupt_structure_flow.svg`

## 2. HW 기준 파일

| 파일 | SW 관점 의미 |
|---|---|
| `src/rv32i_pkg.sv` | APB base address, CSR address, INTC source ID, priority width |
| `src/TOP.sv` | peripheral IRQ와 INTC source ID 연결 |
| `src/InterruptController.sv` | INTC top wrapper |
| `src/IntcRegIf.sv` | INTC MMIO register map |
| `src/IntcGateway.sv` | raw IRQ 재발생 차단 및 COMPLETE 이후 재샘플 |
| `src/IntcPendingCtrl.sv` | pending, claim side effect, in-service, complete accept |
| `src/IntcPriorityClaim.sv` | priority/threshold 기반 source 선택 |
| `src/IntcVectorTable.sv` | source ID별 handler PC 선택 |
| `src/CsrFile.sv` | `mstatus`, `mie`, `mip`, `mtvec`, `mepc`, `mcause`, MRET 갱신 |
| `src/TrapController.sv` | interrupt accept 조건과 trap redirect PC 선택 |
| `sw/common/include/soc_mmio.h` | 현재 SW용 base/offset define |

## 3. Address Map

### 3.1 APB Window

| Peripheral | Base address |
|---|---:|
| UART | `0x4000_0000` |
| GPIO | `0x4000_1000` |
| I2C | `0x4000_2000` |
| INTC | `0x4000_3000` |
| SPI | `0x4000_4000` |
| FND | `0x4000_5000` |
| TIMER | `0x4000_6000` |

`APBMux`는 address `[31:12]`로 slave를 선택하므로 각 peripheral은 4KB window를 가진다. INTC 전체 주소는 `0x4000_3000 + offset`이다.

### 3.2 INTC Register Map

| Offset | Name | Access | Bits | Description |
|---:|---|---|---|---|
| `0x000` | `PENDING` | RO | `[5:0]` | pending source bitmap. bit `source_id - 1` |
| `0x004` | `ENABLE` | RW | `[5:0]` | interrupt enable bitmap. bit `source_id - 1` |
| `0x008` | `CLAIM` | RO | `[31:0]` | selected source ID. read has claim side effect |
| `0x00C` | `COMPLETE` | WO | `[31:0]` | completed source ID. write releases in-service source |
| `0x010` | `CTRL` | RW | `[0]` | INTC per-source vector enable |
| `0x014` | `THRESHOLD` | RW | `[2:0]` | interrupt threshold |
| `0x018` | `INFO` | RO | see below | INTC capability information |
| `0x020 + 4*id` | `PRIORITY[id]` | RW | `[2:0]` | priority for source `id`, valid `id=1..6` |
| `0x080 + 4*id` | `VECTOR[id]` | RW | `[31:2]` | handler PC for source `id`, valid `id=1..6` |

`INFO` field:

| Bits | Value | Meaning |
|---:|---:|---|
| `[7:0]` | `6` | number of interrupt sources |
| `[15:8]` | `3` | priority width |
| `[16]` | `1` | priority register exists |
| `[17]` | `1` | threshold register exists |
| `[18]` | `1` | vector table register exists |

Reserved behavior:

- Source ID `0` means no interrupt.
- `PRIORITY[0]` is reserved. Writes do not update priority state.
- `VECTOR[0]` is reserved. Writes do not update vector state.
- `PENDING`, `CLAIM`, `INFO` are read-only. Writing them raises APB slave error.
- `COMPLETE` is write-only. Reading it raises APB slave error.
- Unknown INTC offsets raise APB slave error.

## 4. Source ID Map

| Source ID | PENDING/ENABLE bit | RTL signal in `TOP.sv` | Meaning |
|---:|---:|---|---|
| `0` | - | - | no interrupt |
| `1` | `0` | `GpioIrq` | GPIO interrupt |
| `2` | `1` | `UartIrq` | UART RX interrupt |
| `3` | `2` | `I2cEventIrq` | I2C event interrupt |
| `4` | `3` | `I2cErrorIrq` | I2C error interrupt |
| `5` | `4` | `SpiEventIrq` | SPI event interrupt |
| `6` | `5` | `SpiErrorIrq` | SPI error interrupt |

## 5. Priority and Threshold Policy

`IntcPriorityClaim` selects one eligible source.

```text
eligible = pending[source] && enable[source] && (priority[source] > threshold)
```

Selection rule:

- Larger priority value wins.
- If priorities are equal, lower source ID wins because the selector scans source ID `1` to `6` and only replaces the winner on strictly greater priority.
- Priority width is 3 bits, so valid priority values are `0..7`.
- With default threshold `0`, priority `0` is not eligible. Give enabled sources priority `1` or higher.
- Setting threshold `7` blocks all current 3-bit priorities.

## 6. Claim and Complete Contract

### 6.1 CLAIM read

Reading `INTC_CLAIM` returns the currently selected source ID.

```c
uint32_t id = mmio_read32(SOC_APB_INTC_BASE + INTC_CLAIM);
```

Side effect:

- If `id != 0`, the selected source moves from pending to in-service.
- The pending bit is cleared by the claim accept path.
- A claim read with no eligible source returns `0` and has no useful service action.

### 6.2 COMPLETE write

After servicing the source, write the same source ID to `INTC_COMPLETE`.

```c
mmio_write32(SOC_APB_INTC_BASE + INTC_COMPLETE, id);
```

Side effect:

- COMPLETE is accepted only if that source is currently in-service.
- Accepted COMPLETE clears the in-service bit.
- Accepted COMPLETE releases the matching gateway.
- If the peripheral raw IRQ is still asserted at COMPLETE time, `IntcGateway` emits a new pending set pulse for the same source. Therefore SW should clear the peripheral-local IRQ cause before writing COMPLETE.

## 7. CSR Contract

### 7.1 Supported CSRs

| CSR | Address | SW use |
|---|---:|---|
| `mstatus` | `0x300` | global machine interrupt enable |
| `mie` | `0x304` | machine external interrupt enable |
| `mtvec` | `0x305` | trap entry base/mode |
| `mscratch` | `0x340` | optional SW scratch |
| `mepc` | `0x341` | return PC saved on trap |
| `mcause` | `0x342` | trap cause saved on trap |
| `mtval` | `0x343` | reads as zero in current RTL |
| `mip` | `0x344` | pending bits; `MEIP` includes INTC pending, `MTIP` includes APB timer pending |

### 7.2 Relevant bits

| CSR | Bit | Name | Meaning |
|---|---:|---|---|
| `mstatus` | `3` | `MIE` | global machine interrupt enable |
| `mstatus` | `7` | `MPIE` | previous interrupt enable saved on trap |
| `mstatus` | `[12:11]` | `MPP` | previous privilege mode |
| `mie` | `11` | `MEIE` | machine external interrupt enable |
| `mie` | `7` | `MTIE` | machine timer interrupt enable |
| `mip` | `11` | `MEIP` | machine external interrupt pending |
| `mip` | `7` | `MTIP` | machine timer interrupt pending |

In current RTL, `mip.MEIP` is:

```text
mip.MEIP = software_mip_MEIP || ExtIrqPending
mip.MTIP = software_mip_MTIP || TimerIrqPending
```

Normal INTC-driven SW should rely on `ExtIrqPending` and does not need to manually set `mip.MEIP`.

### 7.3 Interrupt accept condition

`TrapController` accepts interrupts only when the interrupt window is open:

```text
IF/ID instruction is valid
no MEM trap
no EX trap
no EX redirect
no ID trap
mstatus.MIE == 1
```

Machine external interrupt additionally requires:

```text
mie.MEIE == 1
mip.MEIP == 1
```

Machine timer interrupt additionally requires:

```text
mie.MTIE == 1
mip.MTIP == 1
```

If external and timer are both pending, external interrupt has priority. On accepted external interrupt:

- `mcause = 0x8000_000B`
- `mepc = interrupted IF/ID PC`
- `mstatus.MPIE = old mstatus.MIE`
- `mstatus.MIE = 0`
- `mstatus.MPP = machine`

On accepted timer interrupt:

- `mcause = 0x8000_0007`
- redirect uses standard `mtvec` direct/vectored target only
- INTC vector table is not used
- SW must clear `TIMER_STATUS.IRQ_PENDING` before `mret`

On `mret`:

- `mstatus.MIE = mstatus.MPIE`
- `mstatus.MPIE = 1`
- `mstatus.MPP = user`
- `ExecuteRedirectCtrl` redirects PC to `mepc`

## 8. Trap Target Selection

There are two supported SW styles.

### 8.1 Common handler through `mtvec`

This is the simplest mode.

```text
INTC_CTRL[0] = 0
mtvec = common_trap_entry
```

All machine external interrupts enter the same trap entry. The handler reads `CLAIM` to find the source.

If `mtvec` direct mode is used, trap PC is:

```text
trap_pc = mtvec_base
```

If `mtvec` vectored mode is used and INTC vector override is not valid:

```text
trap_pc = mtvec_base + 4 * mcause_code
```

For machine external interrupt, `mcause_code = 11`, so the standard vectored target is:

```text
mtvec_base + 0x2C
```

### 8.2 INTC per-source vector table

Current HW also supports an INTC-owned per-source vector table.

```text
INTC_VECTOR[id] = handler_pc
INTC_CTRL[0]    = 1
```

If the trap is machine external interrupt and `IntcVectorTable` reports a valid vector, `TrapController` redirects to `INTC_VECTOR[selected_source_id]` instead of the standard `mtvec` target.

Vector validity condition:

```text
INTC_CTRL[0] == 1
selected_source_id != 0
INTC_VECTOR[selected_source_id][31:2] != 0
```

Notes:

- Vector PC is 4-byte aligned by HW: bits `[1:0]` are forced to zero.
- The INTC vector table only selects the handler PC. It does not claim or complete the interrupt.
- Even per-source vector handlers must still read `CLAIM`, service the peripheral, write `COMPLETE`, and end with `mret`.
- Keep `mtvec` programmed to a valid fallback entry even when INTC vector mode is enabled.

## 9. Recommended SW Initialization

### 9.1 C constants

`sw/common/include/soc_mmio.h` already defines the base addresses and offsets. The effective INTC constants are:

```c
#define SOC_APB_INTC_BASE 0x40003000u

#define INTC_PENDING      0x000u
#define INTC_ENABLE       0x004u
#define INTC_CLAIM        0x008u
#define INTC_COMPLETE     0x00Cu
#define INTC_CTRL         0x010u
#define INTC_THRESHOLD    0x014u
#define INTC_INFO         0x018u
#define INTC_PRIORITY0    0x020u
#define INTC_VECTOR0      0x080u

#define INTC_SRC_GPIO      1u
#define INTC_SRC_UART_RX   2u
#define INTC_SRC_I2C_EVENT 3u
#define INTC_SRC_I2C_ERROR 4u
#define INTC_SRC_SPI_EVENT 5u
#define INTC_SRC_SPI_ERROR 6u
```

Offset helpers:

```c
static inline uint32_t intc_priority_offset(uint32_t source_id)
{
    return INTC_PRIORITY0 + (source_id * 4u);
}

static inline uint32_t intc_vector_offset(uint32_t source_id)
{
    return INTC_VECTOR0 + (source_id * 4u);
}
```

### 9.2 Common handler initialization

```c
#define CSR_MSTATUS_MIE (1u << 3)
#define CSR_MIE_MEIE    (1u << 11)

static inline void intc_write(uint32_t offset, uint32_t value)
{
    mmio_write32(SOC_APB_INTC_BASE + offset, value);
}

static void intc_set_priority(uint32_t source_id, uint32_t priority)
{
    intc_write(intc_priority_offset(source_id), priority);
}

static void intc_init(void)
{
    intc_set_priority(INTC_SRC_GPIO,      3u);
    intc_set_priority(INTC_SRC_UART_RX,   3u);
    intc_set_priority(INTC_SRC_I2C_EVENT, 2u);
    intc_set_priority(INTC_SRC_I2C_ERROR, 5u);
    intc_set_priority(INTC_SRC_SPI_EVENT, 1u);
    intc_set_priority(INTC_SRC_SPI_ERROR, 5u);

    intc_write(INTC_THRESHOLD, 0u);
    intc_write(INTC_ENABLE, 0x3Fu);
    intc_write(INTC_CTRL, 0u);
}

static void trap_enable(uintptr_t trap_entry)
{
#if defined(__riscv)
    __asm__ volatile("csrw mtvec, %0" :: "r"(trap_entry));
    __asm__ volatile("csrs mie, %0" :: "r"(CSR_MIE_MEIE));
    __asm__ volatile("csrs mstatus, %0" :: "r"(CSR_MSTATUS_MIE));
#endif
}
```

### 9.3 Optional per-source vector initialization

```c
static void intc_set_vector(uint32_t source_id, uintptr_t handler_pc)
{
    intc_write(intc_vector_offset(source_id), (uint32_t)handler_pc);
}

static void intc_enable_hw_vectors(void)
{
    intc_write(INTC_CTRL, 1u);
}
```

Use only entry points that save context and return with `mret`.

## 10. Recommended Handler Flow

Handler sequence:

```text
trap_entry:
  save caller-visible context needed by your ABI
  call trap_handler()
  restore context
  mret
```

The C handler should branch on `mcause`:

```c
void trap_handler(void)
{
    uint32_t cause = csr_read_mcause();

    if (cause == MCAUSE_MACHINE_TIMER_INT) {
        service_timer();
    } else if (cause == MCAUSE_MACHINE_EXT_INT) {
        service_claim();
    } else {
        service_exception(cause);
    }
}
```

Claim service body:

```c
static uint32_t intc_claim(void)
{
    return mmio_read32(SOC_APB_INTC_BASE + INTC_CLAIM);
}

static void intc_complete(uint32_t source_id)
{
    mmio_write32(SOC_APB_INTC_BASE + INTC_COMPLETE, source_id);
}

void service_claim(void)
{
    uint32_t source_id = intc_claim();
    if (source_id == 0u) {
        return;
    }

    switch (source_id) {
    case INTC_SRC_GPIO:
        service_gpio();
        break;
    case INTC_SRC_UART_RX:
        service_uart();
        break;
    case INTC_SRC_I2C_EVENT:
    case INTC_SRC_I2C_ERROR:
        service_i2c(source_id);
        break;
    case INTC_SRC_SPI_EVENT:
    case INTC_SRC_SPI_ERROR:
        service_spi(source_id);
        break;
    default:
        break;
    }

    intc_complete(source_id);
}
```

Peripheral service function rule:

- Clear or consume the peripheral-local IRQ cause before `intc_complete(source_id)`.
- For sticky status peripherals, read status, write back the handled status bits, then complete.
- If the raw IRQ remains high at COMPLETE, the gateway will create a new pending interrupt for the same source.

## 11. Minimal Bring-up Checklist

1. Confirm `INTC_INFO` reads `0x0007_0306` style fields: sources `6`, priority width `3`, feature bits `[18:16] = 111`.
2. Clear or initialize peripheral-local IRQ state.
3. Program each enabled source priority to a value greater than threshold.
4. Program `THRESHOLD`.
5. Program `ENABLE` bitmap.
6. Program `mtvec` to a trap entry that ends with `mret`.
7. Set `mie.MEIE`.
8. Set `mstatus.MIE`.
9. Trigger a peripheral IRQ.
10. In handler, read `CLAIM`, service source, write `COMPLETE`.

## 12. Common Bugs

| Symptom | Likely cause | Fix |
|---|---|---|
| `PENDING` bit rises but no trap | `ENABLE` bit is zero, priority is not greater than threshold, `mie.MEIE` is zero, or `mstatus.MIE` is zero | Check INTC enable/priority/threshold and CSR bits |
| `CLAIM` returns `0` | no eligible pending source | Check priority, threshold, enable, and pending |
| Same interrupt fires immediately after COMPLETE | peripheral raw IRQ cause was not cleared before COMPLETE | Clear peripheral status before writing COMPLETE |
| Trap enters wrong address | `mtvec` mode/base or INTC vector entry is wrong | Check `mtvec`, `INTC_CTRL[0]`, and `INTC_VECTOR[id]` |
| Handler returns incorrectly | trap entry used normal `ret` instead of `mret` | Use a trap entry wrapper that restores context and executes `mret` |
| Lower-priority source runs first | priorities equal and lower source ID wins ties | Assign distinct priorities for required order |

## 13. Current Demo Reference

The current `sw/apps/hello_world/src/main.c` already follows the core claim/complete pattern:

```text
intc_init()
  -> set priorities
  -> THRESHOLD = 0
  -> ENABLE = 0x3F

trap_enable()
  -> mtvec = trap_handler
  -> mie.MEIE = 1
  -> mstatus.MIE = 1

service_claim()
  -> id = CLAIM
  -> service by id
  -> COMPLETE = id
```

For production-style interrupt firmware, prefer a dedicated trap entry wrapper around the C service function so the final return instruction is `mret`.
