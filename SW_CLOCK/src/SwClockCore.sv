/*
[MODULE_INFO_START]
Name: SwClockCore
Role: SW_CLOCK RTL peripheral core
Summary:
  - Bridges software display frames to hardware FND scan outputs
  - Debounces physical buttons and exposes stable status to MicroBlaze through AXI GPIO
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SwClockCore #(
  parameter int unsigned P_CLK_HZ      = 100_000_000,
  parameter int unsigned P_SCAN_HZ     = 1000,
  parameter int unsigned P_DEBOUNCE_MS = 20
) (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic [31:0] iDisplayWord,
  input  logic [3:0]  iBtnRaw,

  output logic [7:0]  oButtonStatus,
  output logic [6:0]  oSeg,
  output logic        oDp,
  output logic [3:0]  oDigitSel
);

  logic [3:0] wButtonDebounce2Core_BtnStable;
  logic [3:0] wButtonDebounce2Core_BtnRawSync;

  assign oButtonStatus = {
    wButtonDebounce2Core_BtnRawSync,
    wButtonDebounce2Core_BtnStable
  };

  ButtonDebounce #(
    .P_WIDTH       (4),
    .P_CLK_HZ      (P_CLK_HZ),
    .P_DEBOUNCE_MS (P_DEBOUNCE_MS)
  ) uButtonDebounce (
    .iClk        (iClk),
    .iRstn       (iRstn),
    .iBtnRaw     (iBtnRaw),
    .oBtnStable  (wButtonDebounce2Core_BtnStable),
    .oBtnRawSync (wButtonDebounce2Core_BtnRawSync)
  );

  FndDisplayCore #(
    .P_CLK_HZ  (P_CLK_HZ),
    .P_SCAN_HZ (P_SCAN_HZ)
  ) uFndDisplayCore (
    .iClk         (iClk),
    .iRstn        (iRstn),
    .iDisplayWord (iDisplayWord),
    .oSeg         (oSeg),
    .oDp          (oDp),
    .oDigitSel    (oDigitSel)
  );

endmodule
