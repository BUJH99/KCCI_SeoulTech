/*
[MODULE_INFO_START]
Name: SpiMasterIo
Role: Pin-level output adapter for the SPI master subsystem
Summary:
  - Maps abstract chip-select, clock, and MOSI control signals to board pins
  - Forces idle bus values when the SPI engine is not active
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiMasterIo (
  input  logic iCsActive,
  input  logic iSclkLevel,
  input  logic iMosiBit,
  output logic oJaCs,
  output logic oJaMosi,
  output logic oJaSclk
);

  always_comb begin
    oJaCs   = !iCsActive;
    oJaSclk = iCsActive ? iSclkLevel : 1'b0;
    oJaMosi = iCsActive ? iMosiBit   : 1'b0;
  end

endmodule
