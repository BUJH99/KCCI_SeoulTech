#ifndef SOC_MMIO_H
#define SOC_MMIO_H

#include <stdint.h>

#define SOC_APB_UART_BASE 0x40000000u
#define SOC_APB_GPIO_BASE 0x40001000u
#define SOC_APB_I2C_BASE  0x40002000u
#define SOC_APB_INTC_BASE 0x40003000u
#define SOC_APB_SPI_BASE  0x40004000u
#define SOC_APB_FND_BASE  0x40005000u

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

#define UART_CTRL   0x000u
#define UART_STATUS 0x004u
#define UART_TXDATA 0x008u
#define UART_RXDATA 0x00Cu
#define UART_IRQ_EN 0x010u

#define GPIO_DATA_OUT    0x000u
#define GPIO_DATA_IN     0x004u
#define GPIO_DIR         0x008u
#define GPIO_IRQ_RISE_EN 0x00Cu
#define GPIO_IRQ_FALL_EN 0x010u
#define GPIO_IRQ_STATUS  0x014u

#define I2C_CTRL       0x000u
#define I2C_STATUS     0x004u
#define I2C_TXDATA     0x008u
#define I2C_RXDATA     0x00Cu
#define I2C_CLKDIV     0x010u
#define I2C_ADDR       0x014u
#define I2C_IRQ_STATUS 0x018u
#define I2C_IRQ_ENABLE 0x01Cu

#define SPI_CTRL       0x000u
#define SPI_STATUS     0x004u
#define SPI_TXDATA     0x008u
#define SPI_RXDATA     0x00Cu
#define SPI_CLKDIV     0x010u
#define SPI_CS         0x014u
#define SPI_IRQ_STATUS 0x018u
#define SPI_IRQ_ENABLE 0x01Cu

#define FND_DIGITS_BCD 0x000u
#define FND_BLINK_MASK 0x004u
#define FND_DP_MASK    0x008u
#define FND_CTRL       0x00Cu

static inline void mmio_write32(uintptr_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
}

static inline uint32_t mmio_read32(uintptr_t addr)
{
    return *(volatile uint32_t *)addr;
}

static inline uint32_t intc_priority_offset(uint32_t source_id)
{
    return INTC_PRIORITY0 + (source_id * 4u);
}

static inline uint32_t intc_vector_offset(uint32_t source_id)
{
    return INTC_VECTOR0 + (source_id * 4u);
}

#endif
