# SLAVE FPGA RTL

This directory is reserved for the separate SLAVE FPGA design used by the Bubble Sort display demo.

The MASTER RV32I SoC must not instantiate this SLAVE design internally for the real hardware demo. MASTER and SLAVE communicate through external SPI and I2C pins:

```text
MASTER FPGA
  APB_SPI master  -> SPI trace frames -> SLAVE FPGA
  APB_I2C master  -> display/status registers -> SLAVE FPGA

SLAVE FPGA
  SPI trace receiver
  I2C register target
  FND display controller
```

Planned synthesizable modules:

```text
SortDisplaySlaveTop.sv
SpiTraceSlave.sv
SortTraceFrameDecoder.sv
I2cSlaveRegTarget.sv
SortSlaveRegs.sv
SlaveFndController.sv
```

Simulation-only protocol models should live under `tb/`.

Build boundary:

```text
MASTER FPGA top = current project top `Top`
SLAVE FPGA top  = planned `SortDisplaySlaveTop`
```

The current project manifest targets the MASTER top. A later SLAVE build flow should select `SortDisplaySlaveTop` explicitly or use a SLAVE-specific manifest/build target.
