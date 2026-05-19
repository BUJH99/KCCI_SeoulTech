/*
[MODULE_INFO_START]
Name: UartRxRouter
Role: RX FIFO pop router between CPU-facing UART registers and InstDma
Summary:
  - Routes received UART bytes to InstDma in DMA mode and APB_UART RXDATA in CPU mode
  - Ensures only the selected consumer can pop the shared RX FIFO
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module UartRxRouter (
  input  rv32i_pkg::UartModeE iMode,
  input  logic                iRxFifoEmpty,
  input  logic [7:0]          iRxFifoData,
  input  logic                iCpuPop,
  input  logic                iDmaReady,

  output logic                oRxFifoPop,
  output logic                oCpuValid,
  output logic [7:0]          oCpuData,
  output logic                oDmaValid,
  output logic [7:0]          oDmaData
);

  import rv32i_pkg::*;

  logic CpuMode;
  logic DmaMode;
  logic RxValid;

  assign CpuMode = (iMode == UART_MODE_CPU);
  assign DmaMode = (iMode == UART_MODE_DMA);
  assign RxValid = !iRxFifoEmpty;

  assign oCpuValid = CpuMode && RxValid;
  assign oCpuData  = iRxFifoData;
  assign oDmaValid = DmaMode && RxValid;
  assign oDmaData  = iRxFifoData;
  assign oRxFifoPop = (CpuMode && iCpuPop && RxValid)
                   || (DmaMode && iDmaReady && RxValid);

endmodule
