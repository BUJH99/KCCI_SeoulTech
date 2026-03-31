/*
[MODULE_INFO_START]
Name: BranchDecoder
Role: Branch condition decoder
Summary:
  - Maps branch funct3 encodings to compare operations
  - Flags unsupported branch sub-encodings as illegal
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module BranchDecoder (
  input  logic [2:0]          iFunct3,
  
  output rv32i_pkg::CTRL_DEC_t oCtrlDec
);

  // ==== 1. Branch Condition Decoding ====

  // Maps funct3 to the specific ALU comparison required to evaluate the branch
  always_comb begin
    oCtrlDec                = rv32i_pkg::LP_CTRL_DEC_DEFAULT;
    oCtrlDec.Ctrl.AluASel   = rv32i_pkg::ALUA_PC;
    oCtrlDec.Ctrl.AluBSel   = rv32i_pkg::ALUB_IMM;
    oCtrlDec.Ctrl.ImmSel    = rv32i_pkg::IMM_B;
    oCtrlDec.Ctrl.PcSel     = rv32i_pkg::PC_BRANCH;

    unique case (iFunct3)
      3'b000:  oCtrlDec.Ctrl.BranchOp = rv32i_pkg::BR_EQ;
      3'b001:  oCtrlDec.Ctrl.BranchOp = rv32i_pkg::BR_NE;
      3'b100:  oCtrlDec.Ctrl.BranchOp = rv32i_pkg::BR_LT;
      3'b101:  oCtrlDec.Ctrl.BranchOp = rv32i_pkg::BR_GE;
      3'b110:  oCtrlDec.Ctrl.BranchOp = rv32i_pkg::BR_LTU;
      3'b111:  oCtrlDec.Ctrl.BranchOp = rv32i_pkg::BR_GEU;
      default: oCtrlDec.Illegal       = 1'b1;
    endcase
  end

endmodule
