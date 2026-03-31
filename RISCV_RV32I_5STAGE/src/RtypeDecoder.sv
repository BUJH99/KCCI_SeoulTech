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
  
  output rv32i_pkg::CTRL_DEC_t oCtrlDec
);

  // ==== 1. Opcode to ALU Mapping ====
  
  // R-type instructions use funct7 and funct3 to determine the exact ALU operation.
  // The decode ensures unsupported bit combinations raise an exception.
  always_comb begin
    oCtrlDec                = rv32i_pkg::LP_CTRL_DEC_DEFAULT;
    oCtrlDec.Ctrl.RegWrite  = 1'b1;

    unique case ({iFunct7, iFunct3})
      10'b0000000_000: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_ADD;
      10'b0100000_000: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SUB;
      10'b0000000_001: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SLL;
      10'b0000000_010: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SLT;
      10'b0000000_011: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SLTU;
      10'b0000000_100: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_XOR;
      10'b0000000_101: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SRL;
      10'b0100000_101: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SRA;
      10'b0000000_110: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_OR;
      10'b0000000_111: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_AND;
      default:         oCtrlDec.Illegal    = 1'b1;
    endcase
  end

endmodule
