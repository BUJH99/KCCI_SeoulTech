/*
[MODULE_INFO_START]
Name: StoreDecoder
Role: RV32I store attribute decoder
Summary:
  - Maps store funct3 encodings to access size
  - Keeps store-specific legality checks local to the store ISA space
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module StoreDecoder (
  input  logic [2:0]           iFunct3,
  
  output rv32i_pkg::CTRL_DEC_t oCtrlDec
);

  // ==== 1. Store Size Decoding ====

  // Determines the width of the memory write operation from funct3
  always_comb begin
    oCtrlDec                = rv32i_pkg::LP_CTRL_DEC_DEFAULT;
    oCtrlDec.Ctrl.MemWrite  = 1'b1;
    oCtrlDec.Ctrl.AluBSel   = rv32i_pkg::ALUB_IMM;
    oCtrlDec.Ctrl.ImmSel    = rv32i_pkg::IMM_S;

    unique case (iFunct3)
      3'b000:  oCtrlDec.Ctrl.MemSize = rv32i_pkg::MEM_BYTE;
      3'b001:  oCtrlDec.Ctrl.MemSize = rv32i_pkg::MEM_HALF;
      3'b010:  oCtrlDec.Ctrl.MemSize = rv32i_pkg::MEM_WORD;
      default: oCtrlDec.Illegal      = 1'b1;
    endcase
  end

endmodule
