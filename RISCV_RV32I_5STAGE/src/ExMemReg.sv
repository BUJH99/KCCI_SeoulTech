/*
[MODULE_INFO_START]
Name: ExMemReg
Role: EX/MEM pipeline register with explicit flush control
Summary:
  - Preserves the precise-halt rule by clearing only the valid bit of younger EX results
  - Keeps the EX/MEM bundle visible at top-level hierarchy for debug and TB checks
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ExMemReg (
  input  logic                iClk,
  input  logic                iRstn,
  input  logic                iFlush,
  input  logic                iHold,
  input  rv32i_pkg::EXMEM_t   iData,
  
  output rv32i_pkg::EXMEM_t   oData
);

  import rv32i_pkg::*;

  // ==== 1. Pipeline Register Storage ====
  
  EXMEM_t EXMEMReg;
  EXMEM_t EXMEMRegNext;

  always_comb begin
    EXMEMRegNext = EXMEMReg;

    if (!iHold) begin
      EXMEMRegNext = iData;
    end

    if (iFlush) begin
      EXMEMRegNext.Valid = 1'b0;
    end
  end

  // ==== 2. Synchronous Update Logic ====
  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      EXMEMReg <= '0;
    end else begin
      EXMEMReg <= EXMEMRegNext;
    end
  end

  assign oData = EXMEMReg;

endmodule
