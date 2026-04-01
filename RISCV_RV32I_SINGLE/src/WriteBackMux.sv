/*
[MODULE_INFO_START]
Name: WriteBackMux
Role: Register-file write-back data selector
Summary:
  - Merges one-hot-qualified ALU, memory, or PC+4 write-back sources
  - Keeps source qualification separate from the final destination bus
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module WriteBackMux (
  input  logic [31:0]        iAluResult,
  input  logic [31:0]        iMemRdData,
  input  logic [31:0]        iPcPlus4,
  output logic [31:0]        oRdWrData
);

  assign oRdWrData = iAluResult | iMemRdData | iPcPlus4;

endmodule
