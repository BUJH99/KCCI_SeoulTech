#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "soc_mmio.h"

#define DEMO_ARRAY_LEN 4u
#define SPI_DEMO_CLKDIV 1u
#define TIMER_PRESCALE_100HZ 24999u
#define TIMER_PERIOD_100HZ 9u
#define SORT_STEP_TICKS 1u
#define GPIO_DEBOUNCE_TICKS 1u
#define SLAVE_HEALTH_TICKS 100u
#define SPI_TIMEOUT_TICKS 20u
#define I2C_TIMEOUT_TICKS 20u
#define GPIO_BTN_SORT (1u << 0)
#define GPIO_BTN_PAUSE (1u << 1)
#define GPIO_BTN_STEP (1u << 2)
#define GPIO_BTN_RESET (1u << 3)
#define GPIO_BUTTON_MASK (GPIO_BTN_SORT | GPIO_BTN_PAUSE | GPIO_BTN_STEP | GPIO_BTN_RESET)
#define SLAVE_DISPLAY_MODE_PASS 0u
#define SLAVE_DISPLAY_MODE_COMPARE 1u
#define SLAVE_DISPLAY_MODE_SWAP 2u
#define SLAVE_DISPLAY_MODE_TOTAL 3u
#define SLAVE_DISPLAY_MODE_COUNT 4u

typedef enum {
    DEMO_IDLE = 0,
    DEMO_LOADED,
    DEMO_SORTING,
    DEMO_PAUSED,
    DEMO_DONE
} demo_state_t;

typedef enum {
    TRACE_LOAD = 0x01u,
    TRACE_COMPARE = 0x02u,
    TRACE_SWAP = 0x03u,
    TRACE_PASS_DONE = 0x04u,
    TRACE_DONE = 0x05u,
    TRACE_PAUSED = 0x06u
} trace_phase_t;

static volatile demo_state_t g_state = DEMO_IDLE;
static volatile uint8_t g_array[DEMO_ARRAY_LEN];
static volatile uint32_t g_pass_idx = 0;
static volatile uint32_t g_compare_idx = 0;
static volatile uint32_t g_compare_count = 0;
static volatile uint32_t g_swap_count = 0;
static volatile uint32_t g_total_count = 0;
static volatile uint32_t g_frame_id = 0;
static volatile bool g_slave_online = false;
static volatile uint32_t g_gpio_prev_sample = 0;
static volatile uint32_t g_gpio_debounced_sample = 0;
static volatile uint32_t g_gpio_irq_pending = 0;
static volatile uint8_t g_slave_display_mode = SLAVE_DISPLAY_MODE_PASS;
static volatile uint8_t g_slave_display_mode_applied = 0u;
static volatile bool g_slave_display_mode_applied_valid = false;
static volatile uint32_t g_ticks = 0;
static volatile bool g_timer_tick_pending = false;
static volatile uint32_t g_sort_last_tick = 0;
static volatile uint32_t g_gpio_stable_ticks = 0;
static volatile uint32_t g_slave_health_last_tick = 0;

void trap_handler(void);
extern void trap_entry(void);

static void demo_sort_step(void);

static void fnd_show_hex16(uint16_t value)
{
    mmio_write32(SOC_APB_FND_BASE + FND_DIGITS_BCD, value);
    mmio_write32(SOC_APB_FND_BASE + FND_BLINK_MASK, 0u);
    mmio_write32(SOC_APB_FND_BASE + FND_DP_MASK, 0u);
    mmio_write32(SOC_APB_FND_BASE + FND_CTRL, 1u);
}

static uint16_t demo_pack_array_hex4(void)
{
    return (uint16_t)(((uint16_t)(g_array[0] & 0x0Fu) << 12)
                    | ((uint16_t)(g_array[1] & 0x0Fu) << 8)
                    | ((uint16_t)(g_array[2] & 0x0Fu) << 4)
                    |  (uint16_t)(g_array[3] & 0x0Fu));
}

static void demo_show_array(void)
{
    fnd_show_hex16(demo_pack_array_hex4());
}

static uint32_t timer_ticks(void)
{
    return g_ticks;
}

static bool ticks_elapsed(uint32_t start, uint32_t delay)
{
    return ((uint32_t)(timer_ticks() - start) >= delay);
}

static void timer_init_100hz(void)
{
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_CTRL, 0u);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_STATUS, 0xFFFFFFFFu);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_PRESCALE, TIMER_PRESCALE_100HZ);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_PERIOD, TIMER_PERIOD_100HZ);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_COUNT, 0u);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_COMPARE, 0xFFFFFFFFu);
    mmio_write32(SOC_APB_TIMER_BASE + TIMER_CTRL,
                 TIMER_CTRL_ENABLE | TIMER_CTRL_PERIODIC | TIMER_CTRL_INT_ENABLE);
}

static uint8_t trace_checksum(const uint8_t *frame)
{
    uint8_t checksum = 0u;
    for (uint32_t idx = 0; idx < (SORT_TRACE_FRAME_BYTES - 1u); idx++) {
        checksum ^= frame[idx];
    }
    return checksum;
}

static bool spi_wait_status_clear(uint32_t busy_mask)
{
    uint32_t start = timer_ticks();

    while (!ticks_elapsed(start, SPI_TIMEOUT_TICKS)) {
        uint32_t status = mmio_read32(SOC_APB_SPI_BASE + SPI_STATUS);
        if ((status & SPI_STATUS_ERROR) != 0u) {
            return false;
        }
        if ((status & busy_mask) == 0u) {
            return true;
        }
    }
    return false;
}

static bool spi_wait_tx_ready(void)
{
    uint32_t start = timer_ticks();

    while (!ticks_elapsed(start, SPI_TIMEOUT_TICKS)) {
        uint32_t status = mmio_read32(SOC_APB_SPI_BASE + SPI_STATUS);
        if ((status & SPI_STATUS_ERROR) != 0u) {
            return false;
        }
        if ((status & SPI_STATUS_TX_READY) != 0u) {
            return true;
        }
    }
    return false;
}

static bool spi_send_frame(const uint8_t *frame)
{
    if (!spi_wait_status_clear(SPI_STATUS_BUSY)) {
        return false;
    }

    mmio_write32(SOC_APB_SPI_BASE + SPI_IRQ_STATUS, 0xFFFFFFFFu);
    mmio_write32(SOC_APB_SPI_BASE + SPI_CTRL, SPI_CTRL_ENABLE | SPI_CTRL_TX_FIFO_CLR | SPI_CTRL_RX_FIFO_CLR);
    mmio_write32(SOC_APB_SPI_BASE + SPI_CTRL, SPI_CTRL_ENABLE);

    for (uint32_t idx = 0; idx < SORT_TRACE_FRAME_BYTES; idx++) {
        if (!spi_wait_tx_ready()) {
            return false;
        }
        mmio_write32(SOC_APB_SPI_BASE + SPI_TXDATA, frame[idx]);
    }

    mmio_write32(SOC_APB_SPI_BASE + SPI_FRAME_LEN, SORT_TRACE_FRAME_BYTES);
    mmio_write32(SOC_APB_SPI_BASE + SPI_CTRL, SPI_CTRL_ENABLE | SPI_CTRL_START);

    uint32_t start = timer_ticks();

    while (!ticks_elapsed(start, SPI_TIMEOUT_TICKS)) {
        uint32_t status = mmio_read32(SOC_APB_SPI_BASE + SPI_STATUS);
        if ((status & SPI_STATUS_ERROR) != 0u) {
            return false;
        }
        if ((status & SPI_STATUS_FRAME_DONE) != 0u) {
            return true;
        }
    }

    return false;
}

static void spi_send_trace(
    trace_phase_t phase,
    uint8_t left_idx,
    uint8_t right_idx,
    uint8_t left,
    uint8_t right,
    uint8_t changed_idx,
    uint8_t status_code,
    bool swapped
)
{
    uint8_t frame[SORT_TRACE_FRAME_BYTES];
    uint32_t frame_id = g_frame_id++;
    uint8_t flags = 0u;

    if (swapped) {
        flags |= (1u << 0);
    }
    if (phase == TRACE_DONE) {
        flags |= (1u << 1);
    }
    if (phase == TRACE_PAUSED) {
        flags |= (1u << 2);
    }
    if ((left_idx != 0xFFu) && (right_idx != 0xFFu)) {
        flags |= (1u << 3);
    }

    frame[0] = SORT_FRAME_MAGIC0;
    frame[1] = SORT_FRAME_MAGIC1;
    frame[2] = SORT_FRAME_VERSION;
    frame[3] = SORT_FRAME_TYPE_TRACE;
    frame[4] = (uint8_t)(frame_id & 0xFFu);
    frame[5] = (uint8_t)((frame_id >> 8) & 0xFFu);
    frame[6] = (uint8_t)phase;
    frame[7] = flags;
    frame[8] = (uint8_t)DEMO_ARRAY_LEN;
    frame[9] = (uint8_t)g_pass_idx;
    frame[10] = (uint8_t)g_compare_idx;
    frame[11] = left_idx;
    frame[12] = right_idx;
    frame[13] = left;
    frame[14] = right;
    frame[15] = changed_idx;
    frame[16] = (uint8_t)(g_compare_count & 0xFFu);
    frame[17] = (uint8_t)((g_compare_count >> 8) & 0xFFu);
    frame[18] = (uint8_t)(g_swap_count & 0xFFu);
    frame[19] = (uint8_t)((g_swap_count >> 8) & 0xFFu);
    frame[20] = (uint8_t)(g_total_count & 0xFFu);
    frame[21] = (uint8_t)((g_total_count >> 8) & 0xFFu);
    frame[22] = status_code;
    frame[23] = trace_checksum(frame);

    (void)spi_send_frame(frame);
}

static bool i2c_wait_done(uint32_t done_mask)
{
    uint32_t start = timer_ticks();

    while (!ticks_elapsed(start, I2C_TIMEOUT_TICKS)) {
        uint32_t status = mmio_read32(SOC_APB_I2C_BASE + I2C_STATUS);
        if ((status & I2C_STATUS_ERROR) != 0u) {
            return false;
        }
        if ((status & done_mask) != 0u) {
            return true;
        }
    }
    return false;
}

static bool i2c_write_reg(uint8_t reg, uint32_t value, uint32_t len)
{
    mmio_write32(SOC_APB_I2C_BASE + I2C_IRQ_STATUS, 0xFFFFFFFFu);
    mmio_write32(SOC_APB_I2C_BASE + I2C_SLAVE_ADDR, SORT_SLAVE_I2C_ADDR);
    mmio_write32(SOC_APB_I2C_BASE + I2C_REG_ADDR, reg);
    mmio_write32(SOC_APB_I2C_BASE + I2C_WDATA, value);
    mmio_write32(SOC_APB_I2C_BASE + I2C_LEN, len);
    mmio_write32(SOC_APB_I2C_BASE + I2C_CTRL, I2C_CTRL_ENABLE | I2C_CTRL_START);
    return i2c_wait_done(I2C_STATUS_DONE);
}

static bool i2c_read_reg(uint8_t reg, uint32_t len, uint32_t *value)
{
    mmio_write32(SOC_APB_I2C_BASE + I2C_IRQ_STATUS, 0xFFFFFFFFu);
    mmio_write32(SOC_APB_I2C_BASE + I2C_SLAVE_ADDR, SORT_SLAVE_I2C_ADDR);
    mmio_write32(SOC_APB_I2C_BASE + I2C_REG_ADDR, reg);
    mmio_write32(SOC_APB_I2C_BASE + I2C_LEN, len);
    mmio_write32(SOC_APB_I2C_BASE + I2C_CTRL, I2C_CTRL_ENABLE | I2C_CTRL_RW | I2C_CTRL_START);

    if (!i2c_wait_done(I2C_STATUS_DONE | I2C_STATUS_RX_VALID)) {
        return false;
    }

    *value = mmio_read32(SOC_APB_I2C_BASE + I2C_RDATA);
    return true;
}

static void slave_disable_link(void)
{
    g_slave_online = false;
    g_slave_display_mode_applied_valid = false;
    mmio_write32(SOC_APB_I2C_BASE + I2C_IRQ_ENABLE, 0u);
    mmio_write32(SOC_APB_I2C_BASE + I2C_IRQ_STATUS, 0xFFFFFFFFu);
    mmio_write32(SOC_APB_I2C_BASE + I2C_CTRL, I2C_CTRL_ENABLE | I2C_CTRL_CORE_RESET);
    mmio_write32(SOC_APB_I2C_BASE + I2C_CTRL, I2C_CTRL_ENABLE);
    demo_show_array();
}

static void slave_set_display_mode(uint8_t mode)
{
    if (mode >= SLAVE_DISPLAY_MODE_COUNT) {
        mode = SLAVE_DISPLAY_MODE_PASS;
    }
    g_slave_display_mode = mode;

    if (g_slave_online
        && (!g_slave_display_mode_applied_valid
            || (g_slave_display_mode_applied != g_slave_display_mode))) {
        if (!i2c_write_reg(SORT_SLAVE_REG_DISPLAY_MODE, g_slave_display_mode, 1u)) {
            slave_disable_link();
        } else {
            g_slave_display_mode_applied = g_slave_display_mode;
            g_slave_display_mode_applied_valid = true;
        }
    }
}

static void slave_probe_init(void)
{
    uint32_t slave_id = 0u;

    g_slave_online = false;
    g_slave_display_mode_applied_valid = false;
    mmio_write32(SOC_APB_I2C_BASE + I2C_IRQ_STATUS, 0xFFFFFFFFu);

    if (i2c_read_reg(SORT_SLAVE_REG_SLAVE_ID, 4u, &slave_id)
        && i2c_write_reg(SORT_SLAVE_REG_BRIGHTNESS, 0x0Fu, 1u)) {
        g_slave_online = true;
        slave_set_display_mode(g_slave_display_mode);
    }

    if (!g_slave_online) {
        slave_disable_link();
    }
}

static void intc_set_priority(uint32_t source_id, uint32_t priority)
{
    mmio_write32(SOC_APB_INTC_BASE + intc_priority_offset(source_id), priority);
}

static uint32_t intc_claim(void)
{
    return mmio_read32(SOC_APB_INTC_BASE + INTC_CLAIM);
}

static void intc_complete(uint32_t source_id)
{
    mmio_write32(SOC_APB_INTC_BASE + INTC_COMPLETE, source_id);
}

static void intc_init(void)
{
    intc_set_priority(INTC_SRC_GPIO, 3u);
    intc_set_priority(INTC_SRC_UART_RX, 3u);
    intc_set_priority(INTC_SRC_I2C_EVENT, 2u);
    intc_set_priority(INTC_SRC_I2C_ERROR, 5u);
    intc_set_priority(INTC_SRC_SPI_EVENT, 1u);
    intc_set_priority(INTC_SRC_SPI_ERROR, 5u);
    mmio_write32(SOC_APB_INTC_BASE + INTC_THRESHOLD, 0u);
    mmio_write32(SOC_APB_INTC_BASE + INTC_ENABLE, 0x3Fu);
}

static void peripheral_init(void)
{
    mmio_write32(SOC_APB_UART_BASE + UART_CTRL, 3u);
    mmio_write32(SOC_APB_UART_BASE + UART_IRQ_EN, 1u);

    mmio_write32(SOC_APB_GPIO_BASE + GPIO_IRQ_RISE_EN, GPIO_BUTTON_MASK);
    mmio_write32(SOC_APB_GPIO_BASE + GPIO_IRQ_FALL_EN, 0x00u);
    g_gpio_prev_sample = mmio_read32(SOC_APB_GPIO_BASE + GPIO_DATA_IN) & GPIO_BUTTON_MASK;
    g_gpio_debounced_sample = g_gpio_prev_sample;
    g_gpio_irq_pending = 0u;
    g_gpio_stable_ticks = 0u;

    mmio_write32(SOC_APB_I2C_BASE + I2C_CLKDIV, 99u);
    mmio_write32(SOC_APB_I2C_BASE + I2C_CTRL, I2C_CTRL_ENABLE | I2C_CTRL_CORE_RESET);
    mmio_write32(SOC_APB_I2C_BASE + I2C_CTRL, I2C_CTRL_ENABLE);
    mmio_write32(SOC_APB_I2C_BASE + I2C_IRQ_STATUS, 0xFFFFFFFFu);
    mmio_write32(SOC_APB_I2C_BASE + I2C_IRQ_ENABLE, I2C_IRQ_NACK | I2C_IRQ_ARB_LOST | I2C_IRQ_BUS_ERROR | I2C_IRQ_TIMEOUT);

    mmio_write32(SOC_APB_SPI_BASE + SPI_CLKDIV, SPI_DEMO_CLKDIV);
    mmio_write32(SOC_APB_SPI_BASE + SPI_CS_CTRL, 1u);
    mmio_write32(SOC_APB_SPI_BASE + SPI_FRAME_LEN, SORT_TRACE_FRAME_BYTES);
    mmio_write32(SOC_APB_SPI_BASE + SPI_CTRL, SPI_CTRL_ENABLE | SPI_CTRL_TX_FIFO_CLR | SPI_CTRL_RX_FIFO_CLR);
    mmio_write32(SOC_APB_SPI_BASE + SPI_CTRL, SPI_CTRL_ENABLE);
    mmio_write32(SOC_APB_SPI_BASE + SPI_IRQ_STATUS, 0xFFFFFFFFu);
    mmio_write32(SOC_APB_SPI_BASE + SPI_IRQ_ENABLE, SPI_IRQ_RX_OVERFLOW | SPI_IRQ_TX_UNDERFLOW | SPI_IRQ_MODE_ERROR | SPI_IRQ_FRAME_DROP);

    demo_show_array();
    slave_probe_init();
}

static void trap_enable(void)
{
#if defined(__riscv)
    uintptr_t handler = (uintptr_t)&trap_entry;
    __asm__ volatile("csrw mtvec, %0" :: "r"(handler));
    __asm__ volatile("csrs mie, %0" :: "r"(MIE_MTIE | MIE_MEIE));
    __asm__ volatile("csrs mstatus, %0" :: "r"(MSTATUS_MIE));
#endif
}

static void uart_putc(uint8_t value)
{
    while ((mmio_read32(SOC_APB_UART_BASE + UART_STATUS) & (1u << 1)) == 0u) {
    }
    mmio_write32(SOC_APB_UART_BASE + UART_TXDATA, value);
}

static void uart_put_result(void)
{
    for (uint32_t idx = 0; idx < DEMO_ARRAY_LEN; idx++) {
        if (idx != 0u) {
            uart_putc((uint8_t)' ');
        }
        uart_putc((uint8_t)'0');
        uart_putc((uint8_t)('0' + (g_array[idx] & 0x0Fu)));
    }
}

static void demo_reset(void)
{
    for (uint32_t idx = 0; idx < DEMO_ARRAY_LEN; idx++) {
        g_array[idx] = 0u;
    }

    g_state = DEMO_IDLE;
    g_pass_idx = 0u;
    g_compare_idx = 0u;
    g_compare_count = 0u;
    g_swap_count = 0u;
    g_total_count = 0u;
    g_frame_id = 0u;
    g_sort_last_tick = timer_ticks();
    demo_show_array();
    slave_set_display_mode(g_slave_display_mode);
}

static void demo_load_value(uint8_t value)
{
    if ((g_state != DEMO_SORTING) && (g_state != DEMO_PAUSED)) {
        g_array[0] = g_array[1];
        g_array[1] = g_array[2];
        g_array[2] = g_array[3];
        g_array[3] = (uint8_t)(value & 0x0Fu);
        g_state = DEMO_LOADED;
        demo_show_array();
        spi_send_trace(TRACE_LOAD, 0xFFu, 0xFFu, value, 0u, 0xFFu, 0u, false);
    }
}

static void demo_start(void)
{
    if ((g_state != DEMO_SORTING) && (g_state != DEMO_PAUSED)) {
        g_pass_idx = 0u;
        g_compare_idx = 0u;
        g_compare_count = 0u;
        g_swap_count = 0u;
        g_total_count = 0u;
        g_state = DEMO_SORTING;
        g_sort_last_tick = timer_ticks();
        demo_show_array();
        slave_set_display_mode(SLAVE_DISPLAY_MODE_PASS);
    }
}

static void demo_pause(void)
{
    if (g_state == DEMO_SORTING) {
        g_state = DEMO_PAUSED;
        spi_send_trace(TRACE_PAUSED, 0xFFu, 0xFFu, 0u, 0u, 0xFFu, 0u, false);
    }
}

static void demo_resume(void)
{
    if (g_state == DEMO_PAUSED) {
        g_state = DEMO_SORTING;
        g_sort_last_tick = timer_ticks();
    }
}

static void demo_toggle_pause(void)
{
    if (g_state == DEMO_SORTING) {
        demo_pause();
    } else if (g_state == DEMO_PAUSED) {
        demo_resume();
    }
}

static void demo_step_paused(void)
{
    if (g_state == DEMO_PAUSED) {
        demo_sort_step();
    }
}

static void handle_gpio_buttons(uint32_t status)
{
    if ((status & GPIO_BTN_RESET) != 0u) {
        demo_reset();
    }

    if ((status & GPIO_BTN_PAUSE) != 0u) {
        demo_toggle_pause();
    }

    if ((status & GPIO_BTN_STEP) != 0u) {
        demo_step_paused();
    }

    if ((status & GPIO_BTN_SORT) != 0u) {
        demo_start();
    }
}

static void demo_finish_sort(void)
{
    g_state = DEMO_DONE;
    spi_send_trace(TRACE_DONE, 0u, (uint8_t)(DEMO_ARRAY_LEN - 1u), g_array[0], g_array[DEMO_ARRAY_LEN - 1u], 0xFFu, 0u, false);
    demo_show_array();
    slave_set_display_mode(SLAVE_DISPLAY_MODE_TOTAL);
    uart_put_result();
}

static void demo_sort_step(void)
{
    uint8_t left_idx = (uint8_t)g_compare_idx;
    uint8_t right_idx = (uint8_t)(g_compare_idx + 1u);
    uint8_t left = g_array[g_compare_idx];
    uint8_t right = g_array[g_compare_idx + 1u];
    bool swapped = false;

    g_compare_count++;
    g_total_count++;
    spi_send_trace(TRACE_COMPARE, left_idx, right_idx, left, right, 0xFFu, 0u, false);

    if (left > right) {
        g_array[g_compare_idx] = right;
        g_array[g_compare_idx + 1u] = left;
        g_swap_count++;
        g_total_count++;
        swapped = true;
        spi_send_trace(TRACE_SWAP, left_idx, right_idx, right, left, left_idx, 0u, true);
    }

    demo_show_array();

    g_compare_idx++;
    if (g_compare_idx >= (DEMO_ARRAY_LEN - 1u - g_pass_idx)) {
        g_compare_idx = 0u;
        g_pass_idx++;
        spi_send_trace(TRACE_PASS_DONE, 0xFFu, 0xFFu, (uint8_t)g_pass_idx, 0u, 0xFFu, 0u, swapped);
        slave_set_display_mode((uint8_t)(g_pass_idx & 3u));
    }

    if (g_pass_idx >= (DEMO_ARRAY_LEN - 1u)) {
        demo_finish_sort();
    }
}

static void demo_sort_tick(void)
{
    if ((g_state == DEMO_SORTING) && ticks_elapsed(g_sort_last_tick, SORT_STEP_TICKS)) {
        g_sort_last_tick = timer_ticks();
        demo_sort_step();
    }
}

static void service_uart(void)
{
    uint8_t value = (uint8_t)mmio_read32(SOC_APB_UART_BASE + UART_RXDATA);

    if (value >= '0' && value <= '9') {
        demo_load_value((uint8_t)(value - '0'));
    } else if ((value == 's') || (value == 'S')) {
        demo_start();
    } else if ((value == 'p') || (value == 'P')) {
        demo_toggle_pause();
    } else if ((value == 'n') || (value == 'N')) {
        demo_step_paused();
    } else if ((value == 'r') || (value == 'R')) {
        demo_reset();
    }
}

static void service_gpio(void)
{
    uint32_t status = mmio_read32(SOC_APB_GPIO_BASE + GPIO_IRQ_STATUS) & GPIO_BUTTON_MASK;
    mmio_write32(SOC_APB_GPIO_BASE + GPIO_IRQ_STATUS, status);
    if (status != 0u) {
        g_gpio_prev_sample |= status;
        g_gpio_debounced_sample |= status;
        g_gpio_stable_ticks = 0u;
        handle_gpio_buttons(status);
    }
}

static void gpio_debounce_tick(void)
{
    uint32_t irq_status = mmio_read32(SOC_APB_GPIO_BASE + GPIO_IRQ_STATUS) & GPIO_BUTTON_MASK;
    uint32_t sample = mmio_read32(SOC_APB_GPIO_BASE + GPIO_DATA_IN) & GPIO_BUTTON_MASK;
    uint32_t debounced_rise = 0u;
    uint32_t pending_buttons;

    if (irq_status != 0u) {
        mmio_write32(SOC_APB_GPIO_BASE + GPIO_IRQ_STATUS, irq_status);
        g_gpio_irq_pending |= irq_status;
    }

    if (sample == g_gpio_prev_sample) {
        if (g_gpio_stable_ticks < GPIO_DEBOUNCE_TICKS) {
            g_gpio_stable_ticks++;
        }
    } else {
        g_gpio_prev_sample = sample;
        g_gpio_stable_ticks = 0u;
    }

    if ((g_gpio_stable_ticks >= GPIO_DEBOUNCE_TICKS) && (sample != g_gpio_debounced_sample)) {
        debounced_rise = sample & ~g_gpio_debounced_sample;
        g_gpio_debounced_sample = sample;
    }

    pending_buttons = g_gpio_irq_pending | debounced_rise;
    g_gpio_irq_pending = 0u;

    if (pending_buttons != 0u) {
        handle_gpio_buttons(pending_buttons);
    }
}

static void service_i2c(uint32_t source_id)
{
    uint32_t status = mmio_read32(SOC_APB_I2C_BASE + I2C_IRQ_STATUS);
    mmio_write32(SOC_APB_I2C_BASE + I2C_IRQ_STATUS, status);
    if (source_id == INTC_SRC_I2C_ERROR) {
        slave_disable_link();
    }
}

static void service_spi(uint32_t source_id)
{
    uint32_t status = mmio_read32(SOC_APB_SPI_BASE + SPI_IRQ_STATUS);
    mmio_write32(SOC_APB_SPI_BASE + SPI_IRQ_STATUS, status);
    if (source_id == INTC_SRC_SPI_ERROR) {
        fnd_show_hex16((uint16_t)(0xE200u | (status & 0xFFu)));
    }
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

void trap_handler(void)
{
    uint32_t cause = csr_read_mcause();

    if (cause == MCAUSE_MACHINE_TIMER_INT) {
        uint32_t status = mmio_read32(SOC_APB_TIMER_BASE + TIMER_STATUS);
        uint32_t clear_mask = status & (TIMER_STATUS_IRQ_PENDING
                                      | TIMER_STATUS_MATCH
                                      | TIMER_STATUS_OVERFLOW);

        if (clear_mask != 0u) {
            mmio_write32(SOC_APB_TIMER_BASE + TIMER_STATUS, clear_mask);
        }

        g_ticks++;
        g_timer_tick_pending = true;
    } else if (cause == MCAUSE_MACHINE_EXT_INT) {
        service_claim();
    } else {
        fnd_show_hex16((uint16_t)(0xE000u | (cause & 0x0FFFu)));
    }
}

static void slave_health_tick(void)
{
    if (!ticks_elapsed(g_slave_health_last_tick, SLAVE_HEALTH_TICKS)) {
        return;
    }

    g_slave_health_last_tick = timer_ticks();
    if (!g_slave_online) {
        slave_probe_init();
    } else {
        slave_set_display_mode(g_slave_display_mode);
    }
}

int main(void)
{
    demo_reset();
    timer_init_100hz();
    trap_enable();
    peripheral_init();
    intc_init();

    while (1) {
        service_claim();
        if (g_timer_tick_pending) {
            g_timer_tick_pending = false;
            demo_sort_tick();
            gpio_debounce_tick();
            slave_health_tick();
        }
    }

    return 0;
}
