/*
[MODULE_INFO_START]
Name: FndBlinkEffect
Role: FND blink and decimal-point post processor
Summary:
  - Toggles a blink phase with the 2Hz tick
  - Applies active-low blanking and decimal-point behavior
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module FndBlinkEffect (
  input  logic iClk,
  input  logic iRstn,
  input  logic iTick2Hz,
  input  logic iCurBlink,
  input  logic iCurDp,

  output logic oBlanking,
  output logic oFinalDp
);

  logic blinkToggle;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      blinkToggle <= 1'b0;
    end else if (iTick2Hz) begin
      blinkToggle <= ~blinkToggle;
    end
  end

  assign oBlanking = iCurBlink && !blinkToggle;
  assign oFinalDp  = iCurDp ? ~blinkToggle : 1'b1;

endmodule
