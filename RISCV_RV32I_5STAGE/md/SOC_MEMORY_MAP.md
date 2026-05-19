# SoC Memory Map

| Region | Bus | Base | Size | Notes |
|---|---:|---:|---:|---|
| BootRom | I-bus | `0x0000_0000` | `0x0000_1000` | Fixed boot control image |
| ProgramRam | I-bus, InstDma | `0x0000_1000` | `0x0000_F000` | UART-loaded executable app image |
| DataRam | D-bus | `0x0000_0000` | `0x0000_0400` | Load/store data and stack |
| APB MMIO | D-bus | `0x4000_0000` | `0x0001_0000` | Routed through DataBusInterconnect and AXI/APB bridge |

| Peripheral | Base | Size |
|---|---:|---:|
| UART0 | `0x40000000` | `0x00001000` |
| GPIO0 | `0x40001000` | `0x00001000` |
| I2C0 | `0x40002000` | `0x00001000` |
| INTC0 | `0x40003000` | `0x00001000` |
| SPI0 | `0x40004000` | `0x00001000` |
| FND0 | `0x40005000` | `0x00001000` |
| TIMER0 | `0x40006000` | `0x00001000` |
| InstDmaRegs | `0x40007000` | `0x00001000` |
