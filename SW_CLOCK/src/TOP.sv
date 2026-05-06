/*
[MODULE_INFO_START]
Name: TOP
Role: SW_CLOCK RTL top wrapper
Summary:
  - Keeps the project top as a thin wrapper around SwClockCore
  - Provides FND display and debounced button status boundaries for the Vivado block design
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TOP #(
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

  SwClockCore #(
    .P_CLK_HZ      (P_CLK_HZ),
    .P_SCAN_HZ     (P_SCAN_HZ),
    .P_DEBOUNCE_MS (P_DEBOUNCE_MS)
  ) uSwClockCore (
    .iClk          (iClk),
    .iRstn         (iRstn),
    .iDisplayWord  (iDisplayWord),
    .iBtnRaw       (iBtnRaw),
    .oButtonStatus (oButtonStatus),
    .oSeg          (oSeg),
    .oDp           (oDp),
    .oDigitSel     (oDigitSel)
  );

endmodule
