# APB Timer SW Programming Guide

`RISCV_RV32I_5STAGE` timer는 INTC source가 아니라 RISC-V machine timer interrupt 경로를 사용한다.

```text
APB_Timer.STATUS.IRQ_PENDING
  -> APB_Timer.oTimerIrqPending
  -> CsrFile.mip.MTIP
  -> TrapController
  -> mcause = 0x8000_0007
  -> mtvec direct/vectored handler
  -> SW clears TIMER_STATUS
  -> mret
```

External peripherals remain on INTC:

```text
GPIO/UART/I2C/SPI IRQ
  -> INTC
  -> CsrFile.mip.MEIP
  -> mcause = 0x8000_000B
  -> CLAIM/service/COMPLETE
```

## Address Map

| Register | Offset | Access | Description |
|---|---:|---|---|
| `CTRL` | `0x000` | RW | enable, periodic mode, local interrupt enable, write-one command pulses |
| `STATUS` | `0x004` | RW1C | sticky pending/match/overflow plus running mirror |
| `PRESCALE` | `0x008` | RW | prescaled tick every `PRESCALE + 1` clocks |
| `PERIOD` | `0x00C` | RW | periodic match interval in prescaled ticks |
| `COUNT` | `0x010` | RW | free-running 32-bit prescaled tick count |
| `COMPARE` | `0x014` | RW | one-shot compare threshold |
| `INFO` | `0x018` | RO | version/capability readback |

Base address:

```c
#define SOC_APB_TIMER_BASE 0x40006000u
```

## Bits

`CTRL`:

| Bit | Name | Meaning |
|---:|---|---|
| `0` | `ENABLE` | counter runs when set |
| `1` | `PERIODIC` | `PERIOD` generates repeated match events |
| `2` | `INT_ENABLE` | `STATUS.IRQ_PENDING` drives `mip.MTIP` |
| `3` | `CLEAR_COUNT` | write-one pulse clears `COUNT` and internal prescale/period accumulators |
| `4` | `START` | write-one pulse sets `ENABLE` |
| `5` | `STOP` | write-one pulse clears `ENABLE` |

`STATUS`:

| Bit | Name | Meaning |
|---:|---|---|
| `0` | `IRQ_PENDING` | sticky local timer pending, W1C |
| `1` | `MATCH` | period or compare event, W1C |
| `2` | `OVERFLOW` | `COUNT` wrapped, W1C |
| `8` | `RUNNING` | read-only mirror of `CTRL.ENABLE` |

`mip.MTIP` is:

```text
software_mip_MTIP || (TIMER_CTRL.INT_ENABLE && TIMER_STATUS.IRQ_PENDING)
```

## 100 Hz Setup

For the default 25 MHz system clock:

```c
static void timer_init_100hz(void)
{
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_CTRL, 0u);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_STATUS, 0xFFFFFFFFu);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_PRESCALE, 24999u);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_PERIOD, 9u);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_COUNT, 0u);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_COMPARE, 0xFFFFFFFFu);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_CTRL,
                 TIMER_CTRL_ENABLE |
                 TIMER_CTRL_PERIODIC |
                 TIMER_CTRL_INT_ENABLE);
}
```

This creates:

```text
25_000_000 / (24999 + 1) = 1000 timer ticks/sec
period 9 -> event every 10 prescaled ticks = 100 Hz
```

## Trap Handler

Enable both machine timer and machine external interrupts:

```c
__asm__ volatile("csrs mie, %0" :: "r"(MIE_MTIE | MIE_MEIE));
__asm__ volatile("csrs mstatus, %0" :: "r"(MSTATUS_MIE));
```

Split by `mcause`:

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

Timer service must clear local timer status before returning:

```c
static void service_timer(void)
{
    uint32_t status = mmio_read32(SOC_APB_TIMER_BASE + TIMER_STATUS);
    uint32_t clear_mask = status & (TIMER_STATUS_IRQ_PENDING |
                                    TIMER_STATUS_MATCH |
                                    TIMER_STATUS_OVERFLOW);

    mmio_write32(SOC_APB_TIMER_BASE + TIMER_STATUS, clear_mask);
    g_ticks++;
    g_timer_tick_pending = true;
}
```

Do not read `INTC_CLAIM` for timer interrupts. Timer has no INTC source ID and no `COMPLETE` write.
