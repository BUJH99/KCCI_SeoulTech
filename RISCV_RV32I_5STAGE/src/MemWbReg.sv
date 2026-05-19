/*
[MODULE_INFO_START]
Name: MemWbReg
Role: MEM/WB pipeline register
Summary:
  - Provides a dedicated MEM/WB register boundary without extra top-level sequential logic
  - Keeps the MEM/WB bundle visible at top-level hierarchy for debug and TB checks
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module MemWbReg (
  input  logic                iClk,
  input  logic                iRst,
  input  rv32i_pkg::MEMWB_t   iData,
  
  output rv32i_pkg::MEMWB_t   oData
);

  import rv32i_pkg::*;

  // ==== 1. Pipeline Register Storage ====
  
  MEMWB_t MEMWBReg;

  // ==== 2. Synchronous Update Logic ====

  // Captures Memory Stage results into Writeback architectural boundary.
  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      MEMWBReg <= '0;
    end else begin
      MEMWBReg <= iData;
    end
  end

  assign oData = MEMWBReg;

endmodule
