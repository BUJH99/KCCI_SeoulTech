#ifndef SOC_MMIO_H
#define SOC_MMIO_H

#include <stdint.h>

#define SOC_APB_UART_BASE 0x40000000u
#define SOC_APB_GPIO_BASE 0x40001000u
#define SOC_APB_I2C_BASE  0x40002000u
#define SOC_APB_INTC_BASE 0x40003000u
#define SOC_APB_SPI_BASE  0x40004000u
#define SOC_APB_FND_BASE  0x40005000u
#define SOC_APB_TIMER_BASE 0x40006000u
#define SOC_APB_INST_DMA_BASE 0x40007000u

#define SOC_BOOT_ROM_BASE    0x00000000u
#define SOC_BOOT_ROM_SIZE    0x00001000u
#define SOC_PROGRAM_RAM_BASE 0x00001000u
#define SOC_PROGRAM_RAM_SIZE 0x0000F000u
#define SOC_DATA_RAM_BASE    0x00000000u
#define SOC_DATA_RAM_SIZE    0x00000400u

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

#define UART_STATUS_RX_VALID     (1u << 0)
#define UART_STATUS_TX_HAS_SPACE (1u << 1)
#define UART_STATUS_TX_BUSY      (1u << 2)
#define UART_STATUS_RX_OVERFLOW  (1u << 3)

#define INST_DMA_CTRL              0x000u
#define INST_DMA_STATUS            0x004u
#define INST_DMA_ERROR_CODE        0x008u
#define INST_DMA_LOAD_ADDR         0x00Cu
#define INST_DMA_BYTE_COUNT        0x010u
#define INST_DMA_ENTRY_ADDR        0x014u
#define INST_DMA_EXPECTED_CHECKSUM 0x018u
#define INST_DMA_ACTUAL_CHECKSUM   0x01Cu
#define INST_DMA_WORDS_WRITTEN     0x020u

#define INST_DMA_CTRL_START        (1u << 0)
#define INST_DMA_CTRL_CLEAR_ERROR  (1u << 1)
#define INST_DMA_CTRL_AUTO_ARM     (1u << 2)
#define INST_DMA_CTRL_APP_MODE_REQ (1u << 3)

#define INST_DMA_STATUS_ARMED         (1u << 0)
#define INST_DMA_STATUS_BUSY          (1u << 1)
#define INST_DMA_STATUS_DONE          (1u << 2)
#define INST_DMA_STATUS_ERROR         (1u << 3)
#define INST_DMA_STATUS_APP_VALID     (1u << 4)
#define INST_DMA_STATUS_UART_CPU_MODE (1u << 5)

#define GPIO_DATA_OUT    0x000u
#define GPIO_DATA_IN     0x004u
#define GPIO_DIR         0x008u
#define GPIO_IRQ_RISE_EN 0x00Cu
#define GPIO_IRQ_FALL_EN 0x010u
#define GPIO_IRQ_STATUS  0x014u

#define I2C_CTRL       0x000u
#define I2C_STATUS     0x004u
#define I2C_SLAVE_ADDR 0x008u
#define I2C_REG_ADDR   0x00Cu
#define I2C_WDATA      0x010u
#define I2C_RDATA      0x014u
#define I2C_LEN        0x018u
#define I2C_CLKDIV     0x01Cu
#define I2C_IRQ_STATUS 0x020u
#define I2C_IRQ_ENABLE 0x024u

#define I2C_CTRL_ENABLE     (1u << 0)
#define I2C_CTRL_START      (1u << 1)
#define I2C_CTRL_RW         (1u << 2)
#define I2C_CTRL_CORE_RESET (1u << 3)

#define I2C_STATUS_BUSY     (1u << 0)
#define I2C_STATUS_DONE     (1u << 1)
#define I2C_STATUS_ACK_OK   (1u << 2)
#define I2C_STATUS_RX_VALID (1u << 3)
#define I2C_STATUS_ERROR    (1u << 4)

#define I2C_IRQ_DONE               (1u << 0)
#define I2C_IRQ_RX_VALID           (1u << 1)
#define I2C_IRQ_TX_READY           (1u << 2)
#define I2C_IRQ_SLAVE_STATUS_READY (1u << 3)
#define I2C_IRQ_NACK               (1u << 8)
#define I2C_IRQ_ARB_LOST           (1u << 9)
#define I2C_IRQ_BUS_ERROR          (1u << 10)
#define I2C_IRQ_TIMEOUT            (1u << 11)

#define SPI_CTRL       0x000u
#define SPI_STATUS     0x004u
#define SPI_TXDATA     0x008u
#define SPI_RXDATA     0x00Cu
#define SPI_CLKDIV     0x010u
#define SPI_CS_CTRL    0x014u
#define SPI_FRAME_LEN  0x018u
#define SPI_IRQ_STATUS 0x01Cu
#define SPI_IRQ_ENABLE 0x020u

#define SPI_CTRL_ENABLE      (1u << 0)
#define SPI_CTRL_START       (1u << 1)
#define SPI_CTRL_TX_FIFO_CLR (1u << 2)
#define SPI_CTRL_RX_FIFO_CLR (1u << 3)
#define SPI_CTRL_CPOL        (1u << 4)
#define SPI_CTRL_CPHA        (1u << 5)
#define SPI_CTRL_LSB_FIRST   (1u << 6)

#define SPI_STATUS_BUSY       (1u << 0)
#define SPI_STATUS_TX_READY   (1u << 1)
#define SPI_STATUS_TX_EMPTY   (1u << 2)
#define SPI_STATUS_RX_VALID   (1u << 3)
#define SPI_STATUS_FRAME_DONE (1u << 4)
#define SPI_STATUS_ERROR      (1u << 5)

#define SPI_IRQ_FRAME_DONE   (1u << 0)
#define SPI_IRQ_TX_READY     (1u << 1)
#define SPI_IRQ_RX_VALID     (1u << 2)
#define SPI_IRQ_RX_OVERFLOW  (1u << 8)
#define SPI_IRQ_TX_UNDERFLOW (1u << 9)
#define SPI_IRQ_MODE_ERROR   (1u << 10)
#define SPI_IRQ_FRAME_DROP   (1u << 11)

#define SORT_TRACE_FRAME_BYTES 24u
#define SORT_FRAME_MAGIC0      0xA5u
#define SORT_FRAME_MAGIC1      0x5Au
#define SORT_FRAME_VERSION     0x01u
#define SORT_FRAME_TYPE_TRACE  0x01u

#define SORT_SLAVE_I2C_ADDR 0x42u
#define SORT_SLAVE_REG_SLAVE_ID      0x00u
#define SORT_SLAVE_REG_DISPLAY_MODE  0x04u
#define SORT_SLAVE_REG_STATUS        0x08u
#define SORT_SLAVE_REG_LAST_FRAME_ID 0x0Cu
#define SORT_SLAVE_REG_ERROR_CODE    0x10u
#define SORT_SLAVE_REG_BRIGHTNESS    0x14u
#define SORT_SLAVE_REG_COMPARE_COUNT 0x18u
#define SORT_SLAVE_REG_SWAP_COUNT    0x1Cu
#define SORT_SLAVE_REG_TOTAL_COUNT   0x20u

#define FND_DIGITS_BCD 0x000u
#define FND_BLINK_MASK 0x004u
#define FND_DP_MASK    0x008u
#define FND_CTRL       0x00Cu

#define TIMER_CTRL     0x000u
#define TIMER_STATUS   0x004u
#define TIMER_PRESCALE 0x008u
#define TIMER_PERIOD   0x00Cu
#define TIMER_COUNT    0x010u
#define TIMER_COMPARE  0x014u
#define TIMER_INFO     0x018u

#define TIMER_CTRL_ENABLE      (1u << 0)
#define TIMER_CTRL_PERIODIC    (1u << 1)
#define TIMER_CTRL_INT_ENABLE  (1u << 2)
#define TIMER_CTRL_CLEAR_COUNT (1u << 3)
#define TIMER_CTRL_START       (1u << 4)
#define TIMER_CTRL_STOP        (1u << 5)

#define TIMER_STATUS_IRQ_PENDING (1u << 0)
#define TIMER_STATUS_MATCH       (1u << 1)
#define TIMER_STATUS_OVERFLOW    (1u << 2)
#define TIMER_STATUS_RUNNING     (1u << 8)

#define MCAUSE_MACHINE_TIMER_INT 0x80000007u
#define MCAUSE_MACHINE_EXT_INT   0x8000000Bu

#define MIE_MTIE     (1u << 7)
#define MIE_MEIE     (1u << 11)
#define MSTATUS_MIE  (1u << 3)

static inline void mmio_write32(uintptr_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
}

static inline uint32_t mmio_read32(uintptr_t addr)
{
    return *(volatile uint32_t *)addr;
}

static inline uint32_t csr_read_mcause(void)
{
    uint32_t value = 0u;
#if defined(__riscv)
    __asm__ volatile("csrr %0, mcause" : "=r"(value));
#endif
    return value;
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
