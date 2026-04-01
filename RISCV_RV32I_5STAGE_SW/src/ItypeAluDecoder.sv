/*
[MODULE_INFO_START]
Name: ItypeAluDecoder
Role: RV32I I-type ALU decoder
Summary:
  - Decodes I-type arithmetic immediates into ALU operations
  - Uses the standard funct7 field name for shift-immediate legality checks
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ItypeAluDecoder (
  input  logic [2:0]         iFunct3,
  input  logic [6:0]         iFunct7,
  
  output rv32i_pkg::CTRL_DEC_t oCtrlDec
);

  // ==== 1. Opcode to ALU Mapping for I-Type ====

  // Decodes arithmetic immediate operations. Shifts require special handling 
  // because the upper 7 bits define logical vs arithmetic shift.
  always_comb begin
    oCtrlDec               = rv32i_pkg::LP_CTRL_DEC_DEFAULT;
    oCtrlDec.Ctrl.RegWrite = 1'b1;
    oCtrlDec.Ctrl.AluBSel  = rv32i_pkg::ALUB_IMM;
    oCtrlDec.Ctrl.ImmSel   = rv32i_pkg::IMM_I;

    unique case (iFunct3)
      3'b000: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_ADD;
      3'b010: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SLT;
      3'b011: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SLTU;
      3'b100: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_XOR;
      3'b110: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_OR;
      3'b111: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_AND;
      
      // Shift Left Logical (SLLI verifies top bits are 0)
      3'b001: begin
        oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SLL;
        oCtrlDec.Illegal    = (iFunct7 != 7'b0000000);
      end
      
      // Shift Right Logical/Arithmetic (SRLI/SRAI branch based on bit 30)
      3'b101: begin
        unique case (iFunct7)
          7'b0000000: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SRL;
          7'b0100000: oCtrlDec.Ctrl.AluOp = rv32i_pkg::ALU_SRA;
          default:    oCtrlDec.Illegal    = 1'b1;
        endcase
      end
      
      default: oCtrlDec.Illegal = 1'b1;
    endcase
  end

endmodule
