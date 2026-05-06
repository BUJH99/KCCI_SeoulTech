/*
[MODULE_INFO_START]
Name: UtypeDecoder
Role: RV32I U-type decoder
Summary:
  - Distinguishes LUI from AUIPC inside the shared U-type opcode class
  - Emits only the datapath select that differs between the two instructions
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module UtypeDecoder (
  input  logic [6:0]                  iOpcode,

  output rv32i_pkg::CTRL_DEC_t        oCtrlDec
);

  // ==== 1. Upper Immediate ALU input Routing ====

  // U-Type instructions either add the immediate to zero (LUI) or PC (AUIPC)
  always_comb begin
    oCtrlDec               = rv32i_pkg::LP_CTRL_DEC_DEFAULT;
    oCtrlDec.Ctrl.RegWrite = 1'b1;
    oCtrlDec.Ctrl.AluBSel  = rv32i_pkg::ALUB_IMM;
    oCtrlDec.Ctrl.ImmSel   = rv32i_pkg::IMM_U;

    unique case (iOpcode)
      rv32i_pkg::LP_OPCODE_LUI:   oCtrlDec.Ctrl.AluASel = rv32i_pkg::ALUA_ZERO;
      rv32i_pkg::LP_OPCODE_AUIPC: oCtrlDec.Ctrl.AluASel = rv32i_pkg::ALUA_PC;
      default:                    oCtrlDec.Illegal      = 1'b1;
    endcase
  end

endmodule
