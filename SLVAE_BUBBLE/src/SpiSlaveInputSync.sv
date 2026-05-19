/*
[MODULE_INFO_START]
Name: SpiSlaveInputSync
Role: SPI SLAVE input synchronizer and edge detector
Summary:
  - Synchronizes external SCLK, MOSI, and CSn into the system clock domain
  - Generates mode0 sample edge and frame boundary pulses
  - Exposes synchronized frame-active and MOSI sample signals to downstream blocks
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiSlaveInputSync (
  input  logic iClk,
  input  logic iRstn,
  input  logic iSpiSclk,
  input  logic iSpiMosi,
  input  logic iSpiCsN,

  output logic oSclkRise,
  output logic oCsRise,
  output logic oCsFall,
  output logic oMosiSync,
  output logic oFrameActive
);

  logic sclk_d1;
  logic sclk_d2;
  logic csn_d1;
  logic csn_d2;
  logic mosi_d1;
  logic mosi_d2;

  assign oSclkRise    = sclk_d1 && !sclk_d2;
  assign oCsRise      = csn_d1 && !csn_d2;
  assign oCsFall      = !csn_d1 && csn_d2;
  assign oMosiSync    = mosi_d2;
  assign oFrameActive = !csn_d2;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      sclk_d1 <= 1'b0;
      sclk_d2 <= 1'b0;
      csn_d1  <= 1'b1;
      csn_d2  <= 1'b1;
      mosi_d1 <= 1'b0;
      mosi_d2 <= 1'b0;
    end else begin
      sclk_d1 <= iSpiSclk;
      sclk_d2 <= sclk_d1;
      csn_d1  <= iSpiCsN;
      csn_d2  <= csn_d1;
      mosi_d1 <= iSpiMosi;
      mosi_d2 <= mosi_d1;
    end
  end

endmodule
