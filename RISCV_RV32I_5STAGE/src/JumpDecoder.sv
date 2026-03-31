/*
[MODULE_INFO_START]
Name: JumpDecoder
Role: RV32I jump decoder
Summary:
  - Distinguishes JAL from JALR inside the shared jump opcode class
  - Applies JALR-specific funct3 legality rules while emitting jump control selects
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module JumpDecoder (
  input  logic [6:0]                iOpcode,
  input  logic [2:0]                iFunct3,
  
  output rv32i_pkg::CTRL_DEC_t      oCtrlDec
);

  // ==== 1. Jump Type & Target Decoding ====

  // Routes the Datapath multiplexers depending on JAL (PC-relative) or JALR (Register-relative)
  always_comb begin
    oCtrlDec               = rv32i_pkg::LP_CTRL_DEC_DEFAULT;
    oCtrlDec.Ctrl.RegWrite = 1'b1;
    oCtrlDec.Ctrl.AluBSel  = rv32i_pkg::ALUB_IMM;
    oCtrlDec.Ctrl.WbSel    = rv32i_pkg::WB_PC4;

    unique case (iOpcode)
      rv32i_pkg::LP_OPCODE_JAL: begin
        oCtrlDec.Ctrl.AluASel = rv32i_pkg::ALUA_PC;
        oCtrlDec.Ctrl.ImmSel  = rv32i_pkg::IMM_J;
        oCtrlDec.Ctrl.PcSel   = rv32i_pkg::PC_JAL;
      end
      
      rv32i_pkg::LP_OPCODE_JALR: begin
        oCtrlDec.Ctrl.AluASel = rv32i_pkg::ALUA_RS1;
        oCtrlDec.Ctrl.ImmSel  = rv32i_pkg::IMM_I;
        oCtrlDec.Ctrl.PcSel   = rv32i_pkg::PC_JALR;
        
        // JALR strictly requires funct3 to be 000
        oCtrlDec.Illegal = (iFunct3 != 3'b000);
      end
      
      default: oCtrlDec.Illegal = 1'b1;
    endcase
  end

endmodule
