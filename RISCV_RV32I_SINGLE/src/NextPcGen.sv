/*
[MODULE_INFO_START]
Name: NextPcGen
Role: Next-PC selection and instruction alignment checking
Summary:
  - Chooses between PC+4, branch, JAL, and JALR targets
  - Flags instruction-address misalignment from the selected control-flow target
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module NextPcGen (
  input  logic [31:0]        iPc,
  input  rv32i_pkg::pc_sel_e iPcSel,
  input  logic               iBranchTaken,
  input  logic [31:0]        iPcTarget,
  input  logic [31:0]        iJalrTarget,
  output logic [31:0]        oNextPc,
  output logic               oInstrAddrMisaligned
);

  logic [31:0] pcPlus4;
  logic        pcUseBranch;
  logic        pcUseJal;
  logic        pcUseJalr;
  logic        pcUsePlus4;
  logic [31:0] pcPlus4Qualified;
  logic [31:0] pcBranchQualified;
  logic [31:0] pcJalQualified;
  logic [31:0] pcJalrQualified;
  logic [31:0] pcControlTarget;

  assign pcPlus4 = iPc + 32'd4;

  assign pcUseBranch = (iPcSel == rv32i_pkg::PC_BRANCH) && iBranchTaken;
  assign pcUseJal    = (iPcSel == rv32i_pkg::PC_JAL);
  assign pcUseJalr   = (iPcSel == rv32i_pkg::PC_JALR);
  assign pcUsePlus4  = !pcUseBranch && !pcUseJal && !pcUseJalr;

  assign pcPlus4Qualified = pcUsePlus4  ? pcPlus4     : '0;
  assign pcBranchQualified = pcUseBranch ? iPcTarget   : '0;
  assign pcJalQualified    = pcUseJal    ? iPcTarget   : '0;
  assign pcJalrQualified   = pcUseJalr   ? iJalrTarget : '0;
  assign pcControlTarget   = pcBranchQualified | pcJalQualified | pcJalrQualified;

  assign oNextPc              = pcPlus4Qualified | pcControlTarget;
  assign oInstrAddrMisaligned = !pcUsePlus4 && (pcControlTarget[1:0] != 2'b00);

endmodule
