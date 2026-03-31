/*
[MODULE_INFO_START]
Name: APB_UART
Role: APB UART wrapper that composes register and serial-datapath submodules
Summary:
  - Delegates APB register decode and sticky status tracking to UartRegs
  - Delegates baud generation, FIFOs, and UART RX/TX engines to UartCore
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APB_UART #(
  parameter int unsigned P_CLK_HZ     = 100_000_000,
  parameter int unsigned P_BAUD       = 9_600,
  parameter int unsigned P_FIFO_DEPTH = 16
) (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iPsel,
  input  logic        iPenable,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic        iUartRx,

  output logic [31:0] oPrdata,
  output logic        oPready,
  output logic        oPslverr,
  output logic        oUartTx,
  output logic        oIrq
);

  logic       RxEn;
  logic       TxEn;
  logic       RxIrqEn;
  logic       RxOverflow;
  logic [7:0] RxFifoData;
  logic       RxFifoEmpty;
  logic       RxFifoFull;
  logic       TxFifoEmpty;
  logic       TxFifoFull;
  logic       TxBusy;
  logic       TxDataWriteReq;
  logic       RxDataReadReq;
  logic       RxOverflowSet;
  logic       AccessEn;

  assign AccessEn          = iPsel && iPenable && oPready;

  UartRegs uUartRegs (
    .iClk(iClk),
    .iRstn(iRstn),
    .iAccessEn(AccessEn),
    .iPwrite(iPwrite),
    .iPaddr(iPaddr),
    .iPstrb(iPstrb),
    .iPwdata(iPwdata),
    .iTxBusy(TxBusy),
    .iTxFifoFull(TxFifoFull),
    .iRxFifoEmpty(RxFifoEmpty),
    .iRxFifoData(RxFifoData),
    .iRxOverflowSet(RxOverflowSet),
    .oPrdata(oPrdata),
    .oPslverr(oPslverr),
    .oRxEn(RxEn),
    .oTxEn(TxEn),
    .oRxIrqEn(RxIrqEn),
    .oRxOverflow(RxOverflow),
    .oTxDataWriteReq(TxDataWriteReq),
    .oRxDataReadReq(RxDataReadReq)
  );

  UartCore #(
    .P_CLK_HZ(P_CLK_HZ),
    .P_BAUD(P_BAUD),
    .P_FIFO_DEPTH(P_FIFO_DEPTH)
  ) uUartCore (
    .iClk(iClk),
    .iRstn(iRstn),
    .iRxEn(RxEn),
    .iTxEn(TxEn),
    .iTxDataWriteReq(TxDataWriteReq),
    .iRxDataReadReq(RxDataReadReq),
    .iTxData(iPwdata[7:0]),
    .iUartRx(iUartRx),
    .oRxFifoData(RxFifoData),
    .oRxFifoEmpty(RxFifoEmpty),
    .oRxFifoFull(RxFifoFull),
    .oTxFifoEmpty(TxFifoEmpty),
    .oTxFifoFull(TxFifoFull),
    .oTxBusy(TxBusy),
    .oRxOverflowSet(RxOverflowSet),
    .oUartTx(oUartTx)
  );

  assign oPready = 1'b1;
  assign oIrq    = !RxFifoEmpty && RxIrqEn;

endmodule
