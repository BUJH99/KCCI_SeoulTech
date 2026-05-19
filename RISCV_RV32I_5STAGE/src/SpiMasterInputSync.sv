/*
[MODULE_INFO_START]
Name: SpiMasterInputSync
Role: MISO input synchronizer for the SPI master core
Summary:
  - Captures asynchronous MISO through two flip-flops in the system clock domain
  - Exposes only the synchronized sample to byte-shifting logic
  - Keeps CDC handling separate from SPI frame sequencing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiMasterInputSync (
  input  logic iClk,
  input  logic iRst,
  input  logic iMiso,

  output logic oMisoSync
);

  logic Miso_d1;
  logic Miso_d2;

  assign oMisoSync = Miso_d2;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      Miso_d1 <= 1'b0;
      Miso_d2 <= 1'b0;
    end else begin
      Miso_d1 <= iMiso;
      Miso_d2 <= Miso_d1;
    end
  end

endmodule
