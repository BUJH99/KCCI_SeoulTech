/*
[MODULE_INFO_START]
Name: IdExReg
Role: ID/EX pipeline register with explicit flush control
Summary:
  - Clears only the valid bit for bubbles and squashes while leaving payload bits as don't-care
  - Keeps the ID/EX bundle visible at top-level hierarchy for debug and TB checks
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module IdExReg (
  input  logic               iClk,
  input  logic               iRstn,
  input  logic               iFlush,
  input  logic               iHold,
  input  rv32i_pkg::IDEX_t   iData,

  output rv32i_pkg::IDEX_t   oData
);

  import rv32i_pkg::*;

  // ==== 1. Pipeline Register Storage ====

  IDEX_t IDEXReg;
  IDEX_t IDEXRegNext;

  always_comb begin
    IDEXRegNext = IDEXReg;

    if (!iHold) begin
      IDEXRegNext = iData;
    end

    if (iFlush) begin
      IDEXRegNext.Valid = 1'b0;
    end
  end

  // ==== 2. Synchronous Update Logic ====
  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      IDEXReg <= '0;
    end else begin
      IDEXReg <= IDEXRegNext;
    end
  end

  assign oData = IDEXReg;

endmodule
