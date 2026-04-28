/*
[MODULE_INFO_START]
Name: FndScanCounter
Role: Four-digit FND scan index counter
Summary:
  - Advances the active digit index on each 1kHz scan tick
  - Resets to digit 0 on active-low reset
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module FndScanCounter (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic       iTick1kHz,

  output logic [1:0] oScanIdx
);

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oScanIdx <= '0;
    end else if (iTick1kHz) begin
      oScanIdx <= oScanIdx + 1'b1;
    end
  end

endmodule
