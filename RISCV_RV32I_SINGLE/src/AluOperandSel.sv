/*
[MODULE_INFO_START]
Name: AluOperandSel
Role: ALU operand source selector
Summary:
  - Selects the ALU A operand from RS1, PC, or zero based on control decode
  - Selects the ALU B operand from RS2 or the decoded immediate value
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module AluOperandSel (
  input  logic [31:0]             iRs1Data,
  input  logic [31:0]             iRs2Data,
  input  logic [31:0]             iPc,
  input  logic [31:0]             iImm,
  input  rv32i_pkg::alu_a_sel_e   iAluASel,
  input  rv32i_pkg::alu_b_sel_e   iAluBSel,
  output logic [31:0]             oAluA,
  output logic [31:0]             oAluB
);

  always_comb begin
    oAluA = iRs1Data;
    oAluB = iRs2Data;

    unique case (iAluASel)
      rv32i_pkg::ALUA_RS1:  oAluA = iRs1Data;
      rv32i_pkg::ALUA_PC:   oAluA = iPc;
      rv32i_pkg::ALUA_ZERO: oAluA = '0;
      default:              oAluA = iRs1Data;
    endcase

    unique case (iAluBSel)
      rv32i_pkg::ALUB_RS2: oAluB = iRs2Data;
      rv32i_pkg::ALUB_IMM: oAluB = iImm;
      default:             oAluB = iRs2Data;
    endcase
  end

endmodule
