#include <stdint.h>

#define INST_DMA_BASE          0x40007000u
#define INST_DMA_CTRL          0x000u
#define INST_DMA_STATUS        0x004u
#define INST_DMA_ENTRY_ADDR    0x014u

#define INST_DMA_CTRL_START        (1u << 0)
#define INST_DMA_CTRL_CLEAR_ERROR  (1u << 1)
#define INST_DMA_CTRL_APP_MODE_REQ (1u << 3)

#define INST_DMA_STATUS_DONE       (1u << 2)
#define INST_DMA_STATUS_ERROR      (1u << 3)

#define MMIO32(addr) (*(volatile uint32_t *)(uintptr_t)(addr))

typedef void (*entry_fn_t)(void);

static uint32_t inst_dma_read(uint32_t offset)
{
    return MMIO32(INST_DMA_BASE + offset);
}

static void inst_dma_write(uint32_t offset, uint32_t value)
{
    MMIO32(INST_DMA_BASE + offset) = value;
}

void bootrom_main(void)
{
    inst_dma_write(INST_DMA_CTRL, INST_DMA_CTRL_CLEAR_ERROR);
    inst_dma_write(INST_DMA_CTRL, INST_DMA_CTRL_START);

    while (1) {
        uint32_t status = inst_dma_read(INST_DMA_STATUS);

        if ((status & INST_DMA_STATUS_ERROR) != 0u) {
            while (1) {
            }
        }

        if ((status & INST_DMA_STATUS_DONE) != 0u) {
            uint32_t entry_addr = inst_dma_read(INST_DMA_ENTRY_ADDR);

            inst_dma_write(INST_DMA_CTRL, INST_DMA_CTRL_APP_MODE_REQ);
            __asm__ volatile (".word 0x0000100f" ::: "memory");
            ((entry_fn_t)(uintptr_t)entry_addr)();
        }
    }
}
