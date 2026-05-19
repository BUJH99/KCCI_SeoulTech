/*
[MODULE_INFO_START]
Name: APB_UART
Role: CPU-facing APB register frontend for the shared UART subsystem
Summary:
  - Delegates APB register decode and sticky status tracking to UartRegs
  - Converts RXDATA reads and TXDATA writes into byte requests for UartSubsystem
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APB_UART #(
  parameter int unsigned P_CLK_HZ = 100_000_000,
  parameter int unsigned P_BAUD   = 115_200
) (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iPsel,
  input  logic        iPenable,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic        iCpuRxValid,
  input  logic [7:0]  iCpuRxData,
  input  logic        iCpuTxReady,
  input  logic        iUartTxBusy,
  input  logic        iRxOverflowSet,

  output logic [31:0] oPrdata,
  output logic        oPready,
  output logic        oPslverr,
  output logic        oCpuPop,
  output logic        oCpuTxValid,
  output logic [7:0]  oCpuTxData,
  output logic        oRxEn,
  output logic        oTxEn,
  output logic        oIrq
);

  logic       RxEn;
  logic       TxEn;
  logic       RxIrqEn;
  logic       RxOverflow;
  logic       RxFifoEmpty;
  logic       TxFifoFull;
  logic       TxBusy;
  logic       TxDataWrReq;
  logic       RxDataRdReq;
  logic       AccessEn;

  assign AccessEn          = iPsel && iPenable && oPready;
  assign RxFifoEmpty       = !iCpuRxValid;
  assign TxFifoFull        = !iCpuTxReady;
  assign TxBusy            = iUartTxBusy;
  assign oCpuPop           = RxDataRdReq && RxEn && iCpuRxValid;
  assign oCpuTxValid       = TxDataWrReq && TxEn;
  assign oCpuTxData        = iPwdata[7:0];
  assign oRxEn             = RxEn;
  assign oTxEn             = TxEn;

  UartRegs uUartRegs (
    .iClk(iClk),
    .iRst(iRst),
    .iAccessEn(AccessEn),
    .iPwrite(iPwrite),
    .iPaddr(iPaddr),
    .iPstrb(iPstrb),
    .iPwdata(iPwdata),
    .iTxBusy(TxBusy),
    .iTxFifoFull(TxFifoFull),
    .iRxFifoEmpty(RxFifoEmpty),
    .iRxFifoData(iCpuRxData),
    .iRxOverflowSet(iRxOverflowSet),
    .oPrdata(oPrdata),
    .oPslverr(oPslverr),
    .oRxEn(RxEn),
    .oTxEn(TxEn),
    .oRxIrqEn(RxIrqEn),
    .oRxOverflow(RxOverflow),
    .oTxDataWrReq(TxDataWrReq),
    .oRxDataRdReq(RxDataRdReq)
  );

  assign oPready = 1'b1;
  assign oIrq    = iCpuRxValid && RxIrqEn;

endmodule
