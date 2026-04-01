/*
[MODULE_INFO_START]
Name: LoadDecoder
Role: RV32I load attribute decoder
Summary:
  - Maps load funct3 encodings to access size and sign behavior
  - Keeps load-specific legality checks local to the load ISA space
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module LoadDecoder (
  input  logic [2:0]           iFunct3,
  
  output rv32i_pkg::CTRL_DEC_t oCtrlDec
);

  // ==== 1. Load Size and Extension Decoding ====

  // Maps the 3-bit func3 field into memory width and sign-extension policies
  always_comb begin
    oCtrlDec                   = rv32i_pkg::LP_CTRL_DEC_DEFAULT;
    oCtrlDec.Ctrl.RegWrite     = 1'b1;
    oCtrlDec.Ctrl.MemRead      = 1'b1;
    oCtrlDec.Ctrl.AluBSel      = rv32i_pkg::ALUB_IMM;
    oCtrlDec.Ctrl.ImmSel       = rv32i_pkg::IMM_I;
    oCtrlDec.Ctrl.WbSel        = rv32i_pkg::WB_MEM;

    unique case (iFunct3)
      3'b000: oCtrlDec.Ctrl.MemSize = rv32i_pkg::MEM_BYTE;
      3'b001: oCtrlDec.Ctrl.MemSize = rv32i_pkg::MEM_HALF;
      3'b010: oCtrlDec.Ctrl.MemSize = rv32i_pkg::MEM_WORD;
      
      // Unsigned loads (zero-extend instead of sign-extend)
      3'b100: begin
        oCtrlDec.Ctrl.MemSize      = rv32i_pkg::MEM_BYTE;
        oCtrlDec.Ctrl.LoadUnsigned = 1'b1;
      end
      
      3'b101: begin
        oCtrlDec.Ctrl.MemSize      = rv32i_pkg::MEM_HALF;
        oCtrlDec.Ctrl.LoadUnsigned = 1'b1;
      end
      
      default: oCtrlDec.Illegal = 1'b1;
    endcase
  end

endmodule
