/*
[MODULE_INFO_START]
Name: Pc
Role: Program counter register
Summary:
  - Stores the current instruction address
  - Updates on clock edge when write enable is asserted
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module Pc (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iPcWe,
  input  logic [31:0] iNextPc,
  output logic [31:0] oPc
);

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oPc <= '0;
    end else if (iPcWe) begin
      oPc <= iNextPc;
    end
  end

endmodule
