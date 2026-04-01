/*
[MODULE_INFO_START]
Name: MemReadQualifier
Role: Architectural data-memory read qualification helper
Summary:
  - Masks memory readback when no read is requested or the access is misaligned
  - Keeps the top wrapper free of local combinational qualification logic
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module MemReadQualifier (
  input  logic [31:0] iMemRdData,
  input  logic        iMemRead,
  input  logic        iDataMisaligned,
  output logic [31:0] oMemRdDataQualified
);

  assign oMemRdDataQualified = (iMemRead && !iDataMisaligned) ? iMemRdData : '0;

endmodule
