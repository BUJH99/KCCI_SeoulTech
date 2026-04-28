/*
[MODULE_INFO_START]
Name: Top
Role: SW_GPIO project top-level wrapper
Summary:
  - Exposes a simple GPIO control/status boundary for Vitis software
  - Drives a four-digit active-low FND up-counter display
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module Top #(
  parameter int unsigned P_CLK_HZ   = 100_000_000,
  parameter int unsigned P_COUNT_HZ = 1
) (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic [1:0]  iGpioCtrl,

  output logic [6:0]  oSeg,
  output logic        oDp,
  output logic [3:0]  oDigitSel,
  output logic [31:0] oGpioStatus
);

  SwGpioCounterFnd #(
    .P_CLK_HZ   (P_CLK_HZ),
    .P_COUNT_HZ (P_COUNT_HZ)
  ) uSwGpioCounterFnd (
    .iClk         (iClk),
    .iRstn        (iRstn),
    .iGpioCtrl    (iGpioCtrl),
    .oSeg         (oSeg),
    .oDp          (oDp),
    .oDigitSel    (oDigitSel),
    .oGpioStatus  (oGpioStatus)
  );

endmodule
