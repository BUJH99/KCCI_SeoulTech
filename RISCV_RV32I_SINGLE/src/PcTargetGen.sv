/*
[MODULE_INFO_START]
Name: PcTargetGen
Role: Branch and jump target address generator
Summary:
  - Builds PC-relative branch or JAL targets from PC plus immediate
  - Builds the aligned JALR target and exposes PC+4 for write-back use
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module PcTargetGen (
  input  logic [31:0] iPc,
  input  logic [31:0] iRs1Data,
  input  logic [31:0] iImm,
  output logic [31:0] oPcTarget,
  output logic [31:0] oJalrTarget,
  output logic [31:0] oPcPlus4
);

  assign oPcTarget   = iPc + iImm;
  assign oJalrTarget = (iRs1Data + iImm) & 32'hFFFF_FFFE;
  assign oPcPlus4    = iPc + 32'd4;

endmodule
