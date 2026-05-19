/*
[MODULE_INFO_START]
Name: UartSubsystem
Role: Shared UART transport wrapper for APB UART and instruction DMA paths
Summary:
  - Owns the single physical UART core connected to FPGA pins
  - Routes RX/TX byte streams between CPU_MODE and DMA_MODE without duplicating UART PHY logic
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module UartSubsystem #(
  parameter int unsigned P_CLK_HZ     = 100_000_000,
  parameter int unsigned P_BAUD       = 115_200,
  parameter int unsigned P_FIFO_DEPTH = 16
) (
  input  logic                iClk,
  input  logic                iRst,
  input  logic                iUartRx,
  input  rv32i_pkg::UartModeE iMode,
  input  logic                iRxFlushReq,
  input  logic                iCpuRxEn,
  input  logic                iCpuTxEn,
  input  logic                iCpuPop,
  input  logic                iCpuTxValid,
  input  logic [7:0]          iCpuTxData,
  input  logic                iDmaReady,
  input  logic                iDmaTxValid,
  input  logic [7:0]          iDmaTxData,

  output logic                oUartTx,
  output logic                oCpuValid,
  output logic [7:0]          oCpuData,
  output logic                oCpuTxReady,
  output logic                oDmaValid,
  output logic [7:0]          oDmaData,
  output logic                oDmaTxReady,
  output logic                oTxBusy,
  output logic                oTxIdle,
  output logic                oRxOverflowSet
);

  import rv32i_pkg::*;

  logic       RxFifoPop;
  logic       RxFifoEmpty;
  logic       RxFifoFull;
  logic [7:0] RxFifoData;
  logic       TxFifoPush;
  logic [7:0] TxFifoData;
  logic       TxFifoEmpty;
  logic       TxFifoFull;
  logic       UartRxEn;
  logic       UartTxEn;

  assign UartRxEn = (iMode == UART_MODE_DMA) || ((iMode == UART_MODE_CPU) && iCpuRxEn);
  assign UartTxEn = (iMode == UART_MODE_DMA) || ((iMode == UART_MODE_CPU) && iCpuTxEn);

  UartCore #(
    .P_CLK_HZ(P_CLK_HZ),
    .P_BAUD(P_BAUD),
    .P_FIFO_DEPTH(P_FIFO_DEPTH)
  ) uUartCore (
    .iClk(iClk),
    .iRst(iRst),
    .iRxEn(UartRxEn),
    .iTxEn(UartTxEn),
    .iRxFifoClear(iRxFlushReq),
    .iRxFifoPop(RxFifoPop),
    .iTxFifoPush(TxFifoPush),
    .iTxData(TxFifoData),
    .iUartRx(iUartRx),
    .oRxFifoData(RxFifoData),
    .oRxFifoEmpty(RxFifoEmpty),
    .oRxFifoFull(RxFifoFull),
    .oTxFifoEmpty(TxFifoEmpty),
    .oTxFifoFull(TxFifoFull),
    .oTxBusy(oTxBusy),
    .oTxIdle(oTxIdle),
    .oRxOverflowSet(oRxOverflowSet),
    .oUartTx(oUartTx)
  );

  UartRxRouter uUartRxRouter (
    .iMode(iMode),
    .iRxFifoEmpty(RxFifoEmpty),
    .iRxFifoData(RxFifoData),
    .iCpuPop(iCpuPop),
    .iDmaReady(iDmaReady),
    .oRxFifoPop(RxFifoPop),
    .oCpuValid(oCpuValid),
    .oCpuData(oCpuData),
    .oDmaValid(oDmaValid),
    .oDmaData(oDmaData)
  );

  UartTxRouter uUartTxRouter (
    .iMode(iMode),
    .iTxFifoFull(TxFifoFull),
    .iCpuTxValid(iCpuTxValid),
    .iCpuTxData(iCpuTxData),
    .iDmaTxValid(iDmaTxValid),
    .iDmaTxData(iDmaTxData),
    .oCpuTxReady(oCpuTxReady),
    .oDmaTxReady(oDmaTxReady),
    .oTxFifoPush(TxFifoPush),
    .oTxFifoData(TxFifoData)
  );

endmodule
