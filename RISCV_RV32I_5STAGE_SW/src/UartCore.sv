/*
[MODULE_INFO_START]
Name: UartCore
Role: UART serial datapath wrapper for baud generation, FIFOs, and RX/TX engines
Summary:
  - Owns the baud-rate generator plus RX/TX FIFO flow control around the UART leaf FSMs
  - Exposes FIFO/status signals back to the APB register block and raises RX overflow events
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module UartCore #(
  parameter int unsigned P_CLK_HZ     = 100_000_000,
  parameter int unsigned P_BAUD       = 9_600,
  parameter int unsigned P_FIFO_DEPTH = 16
) (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic       iRxEn,
  input  logic       iTxEn,
  input  logic       iTxDataWriteReq,
  input  logic       iRxDataReadReq,
  input  logic [7:0] iTxData,
  input  logic       iUartRx,

  output logic [7:0] oRxFifoData,
  output logic       oRxFifoEmpty,
  output logic       oRxFifoFull,
  output logic       oTxFifoEmpty,
  output logic       oTxFifoFull,
  output logic       oTxBusy,
  output logic       oRxOverflowSet,
  output logic       oUartTx
);

  logic       Rst;
  logic       SampleTick;
  logic       RxValid;
  logic [7:0] RxByte;
  logic [7:0] TxFifoData;
  logic       TxDone;
  logic       TxStart;
  logic       TxFifoPush;
  logic       TxFifoPop;
  logic       RxFifoPush;
  logic       RxFifoPop;

  assign Rst            = !iRstn;
  assign TxFifoPush     = iTxDataWriteReq && !oTxFifoFull;
  assign TxFifoPop      = iTxEn && !oTxBusy && !oTxFifoEmpty;
  assign TxStart        = TxFifoPop;
  assign RxFifoPush     = iRxEn && RxValid && !oRxFifoFull;
  assign RxFifoPop      = iRxDataReadReq && !oRxFifoEmpty;
  assign oRxOverflowSet = iRxEn && RxValid && oRxFifoFull;

  baud_rate_generator #(
    .P_CLK_HZ     (P_CLK_HZ),
    .P_BAUD       (P_BAUD),
    .P_OVERSAMPLE (16)
  ) uBaudRateGenerator (
    .iClk        (iClk),
    .iRst        (Rst),
    .oSampleTick (SampleTick)
  );

  uart_rx uUartRx (
    .iClk        (iClk),
    .iRst        (Rst),
    .iSampleTick (SampleTick),
    .iUartRx     (iUartRx),
    .oRxValid    (RxValid),
    .oRxData     (RxByte)
  );

  rx_fifo #(
    .P_DEPTH (P_FIFO_DEPTH)
  ) uRxFifo (
    .iClk    (iClk),
    .iRst    (Rst),
    .iWrEn   (RxFifoPush),
    .iWrData (RxByte),
    .iRdEn   (RxFifoPop),
    .oRdData (oRxFifoData),
    .oEmpty  (oRxFifoEmpty),
    .oFull   (oRxFifoFull)
  );

  tx_fifo #(
    .P_DEPTH (P_FIFO_DEPTH)
  ) uTxFifo (
    .iClk    (iClk),
    .iRst    (Rst),
    .iWrEn   (TxFifoPush),
    .iWrData (iTxData),
    .iRdEn   (TxFifoPop),
    .oRdData (TxFifoData),
    .oEmpty  (oTxFifoEmpty),
    .oFull   (oTxFifoFull)
  );

  uart_tx uUartTx (
    .iClk        (iClk),
    .iRst        (Rst),
    .iSampleTick (SampleTick),
    .iTxStart    (TxStart),
    .iTxData     (TxFifoData),
    .oUartTx     (oUartTx),
    .oTxBusy     (oTxBusy),
    .oTxDone     (TxDone)
  );

endmodule
