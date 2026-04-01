/*
[MODULE_INFO_START]
Name: RtypeDecoder
Role: RV32I R-type ALU decoder
Summary:
  - Decodes R-type funct fields into ALU operations
  - Keeps register-register arithmetic decode aligned with ISA field naming
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module RtypeDecoder (
  input  logic [2:0]         iFunct3,
  input  logic [6:0]         iFunct7,
  output rv32i_pkg::alu_op_e oAluOp,
  output logic               oIllegal
);

  always_comb begin
    oAluOp   = rv32i_pkg::ALU_ADD;
    oIllegal = 1'b0;

    unique case ({iFunct7, iFunct3})
      10'b0000000_000: oAluOp = rv32i_pkg::ALU_ADD;
      10'b0100000_000: oAluOp = rv32i_pkg::ALU_SUB;
      10'b0000000_001: oAluOp = rv32i_pkg::ALU_SLL;
      10'b0000000_010: oAluOp = rv32i_pkg::ALU_SLT;
      10'b0000000_011: oAluOp = rv32i_pkg::ALU_SLTU;
      10'b0000000_100: oAluOp = rv32i_pkg::ALU_XOR;
      10'b0000000_101: oAluOp = rv32i_pkg::ALU_SRL;
      10'b0100000_101: oAluOp = rv32i_pkg::ALU_SRA;
      10'b0000000_110: oAluOp = rv32i_pkg::ALU_OR;
      10'b0000000_111: oAluOp = rv32i_pkg::ALU_AND;
      default:         oIllegal = 1'b1;
    endcase
  end

endmodule
