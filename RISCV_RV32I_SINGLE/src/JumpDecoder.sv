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
  output rv32i_pkg::alu_a_sel_e     oAluASel,
  output rv32i_pkg::imm_sel_e       oImmSel,
  output rv32i_pkg::pc_sel_e        oPcSel,
  output logic                      oIllegal
);

  always_comb begin
    oAluASel = rv32i_pkg::ALUA_RS1;
    oImmSel  = rv32i_pkg::IMM_NONE;
    oPcSel   = rv32i_pkg::PC_PLUS4;
    oIllegal = 1'b0;

    unique case (iOpcode)
      rv32i_pkg::LP_OPCODE_JAL: begin
        oAluASel = rv32i_pkg::ALUA_PC;
        oImmSel  = rv32i_pkg::IMM_J;
        oPcSel   = rv32i_pkg::PC_JAL;
      end
      rv32i_pkg::LP_OPCODE_JALR: begin
        oAluASel = rv32i_pkg::ALUA_RS1;
        oImmSel  = rv32i_pkg::IMM_I;
        oPcSel   = rv32i_pkg::PC_JALR;
        oIllegal = (iFunct3 != 3'b000);
      end
      default: oIllegal = 1'b1;
    endcase
  end

endmodule
