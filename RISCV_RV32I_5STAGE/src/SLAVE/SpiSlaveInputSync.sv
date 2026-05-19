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
  input  logic iRst,
  input  logic iSpiSclk,
  input  logic iSpiMosi,
  input  logic iSpiCsN,

  output logic oSclkRise,
  output logic oCsRise,
  output logic oCsFall,
  output logic oMosiSync,
  output logic oFrameActive
);

  logic Sclk_d1;
  logic Sclk_d2;
  logic Csn_d1;
  logic Csn_d2;
  logic Mosi_d1;
  logic Mosi_d2;

  assign oSclkRise    = Sclk_d1 && !Sclk_d2;
  assign oCsRise      = Csn_d1 && !Csn_d2;
  assign oCsFall      = !Csn_d1 && Csn_d2;
  assign oMosiSync    = Mosi_d2;
  assign oFrameActive = !Csn_d2;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      Sclk_d1 <= 1'b0;
      Sclk_d2 <= 1'b0;
      Csn_d1  <= 1'b1;
      Csn_d2  <= 1'b1;
      Mosi_d1 <= 1'b0;
      Mosi_d2 <= 1'b0;
    end else begin
      Sclk_d1 <= iSpiSclk;
      Sclk_d2 <= Sclk_d1;
      Csn_d1  <= iSpiCsN;
      Csn_d2  <= Csn_d1;
      Mosi_d1 <= iSpiMosi;
      Mosi_d2 <= Mosi_d1;
    end
  end

endmodule
