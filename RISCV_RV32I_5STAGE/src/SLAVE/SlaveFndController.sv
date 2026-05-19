/*
[MODULE_INFO_START]
Name: SlaveFndController
Role: FND renderer for the SLAVE Bubble Sort display target
Summary:
  - Converts the selected pass/compare/swap/total counter into four hexadecimal digits
  - Reuses the project FndController scan/blink pipeline
  - Keeps SLAVE display updates local and interrupt-free
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SlaveFndController #(
  parameter int unsigned P_CLK_HZ = 100_000_000
) (
  input  logic        iClk,
  input  logic        iRst,
  input  logic [15:0] iSelCnt,
  input  logic [7:0]  iBrightness,

  output logic [6:0]  oSeg,
  output logic        oDp,
  output logic [3:0]  oDigitSel
);

  logic       Tick1kHz;
  logic       Tick2Hz;
  logic [3:0] BlinkMask;
  logic [3:0] DpMask;

  assign BlinkMask = (iBrightness == 8'd0) ? 4'hF : 4'h0;
  assign DpMask    = 4'h0;

  FndTickGen #(
    .P_CLK_HZ(P_CLK_HZ)
  ) uFndTickGen (
    .iClk      (iClk),
    .iRst      (iRst),
    .oTick1kHz (Tick1kHz),
    .oTick2Hz  (Tick2Hz)
  );

  FndController uFndController (
    .iClk       (iClk),
    .iRst       (iRst),
    .iTick1kHz  (Tick1kHz),
    .iTick2Hz   (Tick2Hz),
    .iDigitsBcd (iSelCnt),
    .iBlinkMask (BlinkMask),
    .iDpMask    (DpMask),
    .oSeg       (oSeg),
    .oDp        (oDp),
    .oDigitSel  (oDigitSel)
  );

endmodule
