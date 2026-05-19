/*
[MODULE_INFO_START]
Name: UartTxRouter
Role: TX FIFO source router between CPU-facing UART registers and InstDma responses
Summary:
  - Selects InstDma ACK/ERR bytes in DMA mode and APB_UART TXDATA bytes in CPU mode
  - Presents ready only to the source currently allowed to push into the shared TX FIFO
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module UartTxRouter (
  input  rv32i_pkg::UartModeE iMode,
  input  logic                iTxFifoFull,
  input  logic                iCpuTxValid,
  input  logic [7:0]          iCpuTxData,
  input  logic                iDmaTxValid,
  input  logic [7:0]          iDmaTxData,

  output logic                oCpuTxReady,
  output logic                oDmaTxReady,
  output logic                oTxFifoPush,
  output logic [7:0]          oTxFifoData
);

  import rv32i_pkg::*;

  logic CpuMode;
  logic DmaMode;
  logic TxReady;

  assign CpuMode = (iMode == UART_MODE_CPU);
  assign DmaMode = (iMode == UART_MODE_DMA);
  assign TxReady = !iTxFifoFull;

  assign oCpuTxReady = CpuMode && TxReady;
  assign oDmaTxReady = DmaMode && TxReady;
  assign oTxFifoPush = (CpuMode && iCpuTxValid && TxReady)
                    || (DmaMode && iDmaTxValid && TxReady);

  always_comb begin
    if (DmaMode) begin
      oTxFifoData = iDmaTxData;
    end else begin
      oTxFifoData = iCpuTxData;
    end
  end

endmodule
