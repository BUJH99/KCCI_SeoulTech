/*
[MODULE_INFO_START]
Name: SpiMasterInputSync
Role: Synchronizes the asynchronous SPI MISO input into the 100MHz fabric clock domain
Summary:
  - Uses a two-stage flip-flop synchronizer for the incoming MISO line
  - Prevents the SPI controller from consuming metastable asynchronous pin samples
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

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      Miso_d1 <= 1'b0;
      Miso_d2 <= 1'b0;
    end else begin
      Miso_d1 <= iMiso;
      Miso_d2 <= Miso_d1;
    end
  end

  assign oMisoSync = Miso_d2;

endmodule
