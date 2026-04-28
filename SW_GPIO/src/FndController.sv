/*
[MODULE_INFO_START]
Name: FndController
Role: Four-digit FND scan controller
Summary:
  - Reuses the SENSOR_HUB FND flow: scan counter, digit selector, blink, decoder
  - Drives active-low segment, decimal-point, and digit-select outputs
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module FndController (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iTick1kHz,
  input  logic        iTick2Hz,
  input  logic [15:0] iDigitsBcd,
  input  logic [3:0]  iBlinkMask,
  input  logic [3:0]  iDpMask,

  output logic [6:0]  oSeg,
  output logic        oDp,
  output logic [3:0]  oDigitSel
);

  logic [1:0] scanIdx;
  logic [3:0] curBcd;
  logic       curBlink;
  logic       curDp;
  logic       blanking;

  FndScanCounter uFndScanCounter (
    .iClk      (iClk),
    .iRstn     (iRstn),
    .iTick1kHz (iTick1kHz),
    .oScanIdx  (scanIdx)
  );

  FndDigitSelector uFndDigitSelector (
    .iScanIdx   (scanIdx),
    .iDigitsBcd (iDigitsBcd),
    .iBlinkMask (iBlinkMask),
    .iDpMask    (iDpMask),
    .oDigitSel  (oDigitSel),
    .oCurBcd    (curBcd),
    .oCurBlink  (curBlink),
    .oCurDp     (curDp)
  );

  FndBlinkEffect uFndBlinkEffect (
    .iClk       (iClk),
    .iRstn      (iRstn),
    .iTick2Hz   (iTick2Hz),
    .iCurBlink  (curBlink),
    .iCurDp     (curDp),
    .oBlanking  (blanking),
    .oFinalDp   (oDp)
  );

  FndBcdDecoder uFndBcdDecoder (
    .iCurBcd    (curBcd),
    .iBlanking  (blanking),
    .oSeg       (oSeg)
  );

endmodule
