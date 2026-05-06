/*
[MODULE_INFO_START]
Name: APB_FND
Role: APB FND wrapper that composes register, tick-generation, and display-control submodules
Summary:
  - Delegates APB register decode and storage to FndRegs
  - Delegates local scan/blink tick generation to FndTickGen and rendering to FndController
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APB_FND #(
  parameter int unsigned P_CLK_HZ = 100_000_000
) (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iPsel,
  input  logic        iPenable,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,

  output logic [31:0] oPrdata,
  output logic        oPready,
  output logic        oPslverr,
  output logic [6:0]  oSeg,
  output logic        oDp,
  output logic [3:0]  oDigitSel
);
  logic        Rst;
  logic [15:0] DigitsBcd;
  logic [3:0] BlinkMask;
  logic [3:0] DpMask;
  logic       DisplayEn;
  logic       Tick1kHz;
  logic       Tick2Hz;
  logic [6:0] SegInt;
  logic       DpInt;
  logic [3:0] DigitSelInt;
  logic       AccessEn;

  assign Rst      = !iRstn;
  assign oPready  = 1'b1;
  assign AccessEn = iPsel && iPenable && oPready;

  FndRegs uFndRegs (
    .iClk(iClk),
    .iRstn(iRstn),
    .iAccessEn(AccessEn),
    .iPwrite(iPwrite),
    .iPaddr(iPaddr),
    .iPstrb(iPstrb),
    .iPwdata(iPwdata),
    .oPrdata(oPrdata),
    .oPslverr(oPslverr),
    .oDigitsBcd(DigitsBcd),
    .oBlinkMask(BlinkMask),
    .oDpMask(DpMask),
    .oDisplayEn(DisplayEn)
  );

  FndTickGen #(
    .P_CLK_HZ(P_CLK_HZ)
  ) uFndTickGen (
    .iClk(iClk),
    .iRstn(iRstn),
    .oTick1kHz(Tick1kHz),
    .oTick2Hz(Tick2Hz)
  );

  FndController uFndController (
    .iClk      (iClk),
    .iRst      (Rst),
    .iTick1kHz (Tick1kHz),
    .iTick2Hz  (Tick2Hz),
    .iDigitsBcd(DigitsBcd),
    .iBlinkMask(BlinkMask),
    .iDpMask   (DpMask),
    .oSeg      (SegInt),
    .oDp       (DpInt),
    .oDigitSel (DigitSelInt)
  );

  assign oSeg      = DisplayEn ? SegInt : 7'b111_1111;
  assign oDp       = DisplayEn ? DpInt : 1'b1;
  assign oDigitSel = DisplayEn ? DigitSelInt : 4'b1111;

endmodule
