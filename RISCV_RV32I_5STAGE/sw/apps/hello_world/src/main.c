#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "soc_mmio.h"

#define DEMO_ARRAY_MAX 8u
#define SLAVE_I2C_ADDR_WRITE 0x84u

typedef enum {
    DEMO_IDLE = 0,
    DEMO_LOADED,
    DEMO_SORTING,
    DEMO_PAUSED,
    DEMO_DONE
} demo_state_t;

typedef enum {
    TRACE_LOAD = 0,
    TRACE_COMPARE,
    TRACE_SWAP,
    TRACE_PASS_DONE,
    TRACE_DONE
} trace_phase_t;

static volatile demo_state_t g_state = DEMO_IDLE;
static volatile uint8_t g_array[DEMO_ARRAY_MAX];
static volatile uint32_t g_len = 0;
static volatile uint32_t g_pass_idx = 0;
static volatile uint32_t g_compare_idx = 0;
static volatile uint32_t g_compare_count = 0;
static volatile uint32_t g_swap_count = 0;
static volatile uint32_t g_total_count = 0;
static volatile uint32_t g_frame_id = 0;
static volatile bool g_step_once = false;

void trap_handler(void);

static void uart_putc(uint8_t value)
{
    while ((mmio_read32(SOC_APB_UART_BASE + UART_STATUS) & (1u << 1)) == 0u) {
    }
    mmio_write32(SOC_APB_UART_BASE + UART_TXDATA, value);
}

static void uart_put_hex_nibble(uint8_t value)
{
    value &= 0x0Fu;
    uart_putc((uint8_t)(value < 10u ? (uint8_t)('0' + value) : (uint8_t)('A' + value - 10u)));
}

static void uart_put_hex8(uint8_t value)
{
    uart_put_hex_nibble((uint8_t)(value >> 4));
    uart_put_hex_nibble(value);
}

static void fnd_show_hex16(uint16_t value)
{
    mmio_write32(SOC_APB_FND_BASE + FND_DIGITS_BCD, value);
    mmio_write32(SOC_APB_FND_BASE + FND_BLINK_MASK, 0u);
    mmio_write32(SOC_APB_FND_BASE + FND_DP_MASK, 0u);
    mmio_write32(SOC_APB_FND_BASE + FND_CTRL, 1u);
}

static uint8_t trace_checksum(const uint8_t *frame)
{
    uint8_t checksum = 0u;
    for (uint32_t idx = 0; idx < 11u; idx++) {
        checksum ^= frame[idx];
    }
    return checksum;
}

static void spi_send_byte(uint8_t value)
{
    while ((mmio_read32(SOC_APB_SPI_BASE + SPI_STATUS) & (1u << 2)) == 0u) {
    }
    mmio_write32(SOC_APB_SPI_BASE + SPI_TXDATA, value);
    mmio_write32(SOC_APB_SPI_BASE + SPI_CTRL, (1u << 1) | 1u);
}

static void spi_send_trace(trace_phase_t phase, uint8_t left, uint8_t right, bool swapped)
{
    uint8_t frame[12];
    frame[0] = (uint8_t)g_frame_id++;
    frame[1] = (uint8_t)phase;
    frame[2] = (uint8_t)g_pass_idx;
    frame[3] = (uint8_t)g_compare_idx;
    frame[4] = left;
    frame[5] = right;
    frame[6] = swapped ? 1u : 0u;
    frame[7] = (uint8_t)g_compare_idx;
    frame[8] = (uint8_t)g_compare_count;
    frame[9] = (uint8_t)g_swap_count;
    frame[10] = (uint8_t)g_total_count;
    frame[11] = trace_checksum(frame);

    for (uint32_t idx = 0; idx < sizeof(frame); idx++) {
        spi_send_byte(frame[idx]);
    }
}

static void i2c_start_write(uint8_t addr_rw, uint8_t reg, uint8_t value)
{
    mmio_write32(SOC_APB_I2C_BASE + I2C_ADDR, addr_rw);
    mmio_write32(SOC_APB_I2C_BASE + I2C_TXDATA, reg);
    mmio_write32(SOC_APB_I2C_BASE + I2C_CTRL, (1u << 1) | 1u);
    mmio_write32(SOC_APB_I2C_BASE + I2C_TXDATA, value);
    mmio_write32(SOC_APB_I2C_BASE + I2C_CTRL, (1u << 2) | (1u << 1) | 1u);
}

static void slave_set_display_mode(uint8_t mode)
{
    i2c_start_write(SLAVE_I2C_ADDR_WRITE, 0x04u, mode & 3u);
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

    mmio_write32(SOC_APB_GPIO_BASE + GPIO_IRQ_RISE_EN, 0x0Fu);
    mmio_write32(SOC_APB_GPIO_BASE + GPIO_IRQ_FALL_EN, 0x00u);

    mmio_write32(SOC_APB_I2C_BASE + I2C_CLKDIV, 99u);
    mmio_write32(SOC_APB_I2C_BASE + I2C_CTRL, 1u);
    mmio_write32(SOC_APB_I2C_BASE + I2C_IRQ_ENABLE, 0x0000070Bu);

    mmio_write32(SOC_APB_SPI_BASE + SPI_CLKDIV, 3u);
    mmio_write32(SOC_APB_SPI_BASE + SPI_CS, 1u);
    mmio_write32(SOC_APB_SPI_BASE + SPI_CTRL, 1u);
    mmio_write32(SOC_APB_SPI_BASE + SPI_IRQ_ENABLE, 0x00000F05u);

    fnd_show_hex16(0u);
    slave_set_display_mode(0u);
}

static void trap_enable(void)
{
#if defined(__riscv)
    uintptr_t handler = (uintptr_t)&trap_handler;
    __asm__ volatile("csrw mtvec, %0" :: "r"(handler));
    __asm__ volatile("csrs mie, %0" :: "r"(1u << 11));
    __asm__ volatile("csrs mstatus, %0" :: "r"(1u << 3));
#endif
}

static void demo_reset(void)
{
    g_state = DEMO_IDLE;
    g_len = 0u;
    g_pass_idx = 0u;
    g_compare_idx = 0u;
    g_compare_count = 0u;
    g_swap_count = 0u;
    g_total_count = 0u;
    g_frame_id = 0u;
    g_step_once = false;
    fnd_show_hex16(0u);
    slave_set_display_mode(0u);
}

static void demo_load_value(uint8_t value)
{
    if (g_len < DEMO_ARRAY_MAX) {
        g_array[g_len++] = value;
        g_state = DEMO_LOADED;
        fnd_show_hex16((uint16_t)((g_len << 8) | value));
        spi_send_trace(TRACE_LOAD, value, 0u, false);
    }
}

static void demo_start(void)
{
    if ((g_state == DEMO_LOADED) || (g_state == DEMO_PAUSED)) {
        g_state = DEMO_SORTING;
    }
}

static void demo_pause_resume(void)
{
    if (g_state == DEMO_SORTING) {
        g_state = DEMO_PAUSED;
    } else if (g_state == DEMO_PAUSED) {
        g_state = DEMO_SORTING;
    }
}

static void demo_step(void)
{
    if (g_state == DEMO_PAUSED) {
        g_step_once = true;
    }
}

static void demo_report_done(void)
{
    uart_putc('\n');
    for (uint32_t idx = 0; idx < g_len; idx++) {
        uart_put_hex8(g_array[idx]);
        uart_putc(idx + 1u == g_len ? '\n' : ' ');
    }
}

static void demo_sort_tick(void)
{
    if (g_state != DEMO_SORTING && !(g_state == DEMO_PAUSED && g_step_once)) {
        return;
    }

    if (g_len < 2u) {
        g_state = DEMO_DONE;
        return;
    }

    uint8_t left = g_array[g_compare_idx];
    uint8_t right = g_array[g_compare_idx + 1u];
    bool swapped = false;

    g_compare_count++;
    g_total_count++;
    spi_send_trace(TRACE_COMPARE, left, right, false);

    if (left > right) {
        g_array[g_compare_idx] = right;
        g_array[g_compare_idx + 1u] = left;
        g_swap_count++;
        g_total_count++;
        swapped = true;
        spi_send_trace(TRACE_SWAP, right, left, true);
    }

    fnd_show_hex16((uint16_t)((g_array[g_compare_idx] << 8) | g_array[g_compare_idx + 1u]));

    g_compare_idx++;
    if (g_compare_idx >= (g_len - 1u - g_pass_idx)) {
        g_compare_idx = 0u;
        g_pass_idx++;
        spi_send_trace(TRACE_PASS_DONE, (uint8_t)g_pass_idx, 0u, swapped);
        slave_set_display_mode((uint8_t)(g_pass_idx & 3u));
    }

    if (g_pass_idx >= (g_len - 1u)) {
        g_state = DEMO_DONE;
        spi_send_trace(TRACE_DONE, g_array[0], g_array[g_len - 1u], false);
        fnd_show_hex16((uint16_t)((g_array[0] << 8) | g_array[g_len - 1u]));
        demo_report_done();
    }

    g_step_once = false;
}

static void service_uart(void)
{
    uint8_t value = (uint8_t)mmio_read32(SOC_APB_UART_BASE + UART_RXDATA);

    if (value >= '0' && value <= '9') {
        demo_load_value((uint8_t)(value - '0'));
    } else if (value == 's' || value == 'S') {
        demo_start();
    } else if (value == 'p' || value == 'P') {
        demo_pause_resume();
    } else if (value == 'n' || value == 'N') {
        demo_step();
    } else if (value == 'r' || value == 'R') {
        demo_reset();
    }
}

static void service_gpio(void)
{
    uint32_t status = mmio_read32(SOC_APB_GPIO_BASE + GPIO_IRQ_STATUS);
    mmio_write32(SOC_APB_GPIO_BASE + GPIO_IRQ_STATUS, status);

    if ((status & (1u << 0)) != 0u) {
        demo_start();
    }
    if ((status & (1u << 1)) != 0u) {
        demo_pause_resume();
    }
    if ((status & (1u << 2)) != 0u) {
        demo_step();
    }
    if ((status & (1u << 3)) != 0u) {
        demo_reset();
    }
}

static void service_i2c(uint32_t source_id)
{
    uint32_t status = mmio_read32(SOC_APB_I2C_BASE + I2C_IRQ_STATUS);
    mmio_write32(SOC_APB_I2C_BASE + I2C_IRQ_STATUS, status);
    if (source_id == INTC_SRC_I2C_ERROR) {
        fnd_show_hex16((uint16_t)(0xE100u | (status & 0xFFu)));
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
    service_claim();
}

int main(void)
{
    demo_reset();
    peripheral_init();
    intc_init();
    trap_enable();

    while (1) {
        demo_sort_tick();
        service_claim();
    }

    return 0;
}
