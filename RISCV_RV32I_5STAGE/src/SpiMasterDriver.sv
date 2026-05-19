/*
[MODULE_INFO_START]
Name: SpiMasterDriver
Role: SPI master output driver adapter
Summary:
  - Converts frame-active, SCLK phase, and MOSI bit signals into external SPI pins
  - Forces SCLK and MOSI low while CS is inactive
  - Keeps pin-drive policy separate from frame control and byte datapath logic
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiMasterDriver (
  input  logic iCsActive,
  input  logic iSclkLevel,
  input  logic iMosiBit,

  output logic oSclk,
  output logic oMosi,
  output logic oCsN
);

  assign oSclk = iCsActive ? iSclkLevel : 1'b0;
  assign oMosi = iCsActive ? iMosiBit : 1'b0;
  assign oCsN  = !iCsActive;

endmodule
