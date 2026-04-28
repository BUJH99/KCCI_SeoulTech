/*
[MODULE_INFO_START]
Name: SpiSlaveInputSync
Role: Synchronizes asynchronous SPI inputs into the slave fabric clock domain
Summary:
  - Applies independent two-stage synchronizers to CS, SCLK, and MOSI
  - Provides stable fabric-clocked signal levels for the edge detector and slave FSM
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiSlaveInputSync (
  input  logic iClk,
  input  logic iRst,
  input  logic iCs,
  input  logic iSclk,
  input  logic iMosi,
  output logic oCsSync,
  output logic oSclkSync,
  output logic oMosiSync
);

  logic Cs_d1;
  logic Sclk_d1;
  logic Mosi_d1;
  logic Cs_d2;
  logic Sclk_d2;
  logic Mosi_d2;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      Cs_d1   <= 1'b1;
      Sclk_d1 <= 1'b0;
      Mosi_d1 <= 1'b0;
      Cs_d2   <= 1'b1;
      Sclk_d2 <= 1'b0;
      Mosi_d2 <= 1'b0;
    end else begin
      Cs_d1   <= iCs;
      Sclk_d1 <= iSclk;
      Mosi_d1 <= iMosi;
      Cs_d2   <= Cs_d1;
      Sclk_d2 <= Sclk_d1;
      Mosi_d2 <= Mosi_d1;
    end
  end

  assign oCsSync   = Cs_d2;
  assign oSclkSync = Sclk_d2;
  assign oMosiSync = Mosi_d2;

endmodule
