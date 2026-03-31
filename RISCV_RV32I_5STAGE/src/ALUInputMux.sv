/*
[MODULE_INFO_START]
Name: ALUInputMux
Role: Execute-stage ALU operand multiplexer
Summary:
  - Selects ALU A and B inputs from forwarded register operands, PC, or immediate values
  - Keeps ALU-local operand selection separate from forwarding source resolution
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ALUInputMux (
  input  logic [31:0]                    iRs1Data,
  input  logic [31:0]                    iRs2Data,
  input  logic [31:0]                    iPc,
  input  logic [31:0]                    iImm,
  input  rv32i_pkg::AluASelE          iAluASel,
  input  rv32i_pkg::AluBSelE          iAluBSel,

  output logic [31:0]                    oAluA,
  output logic [31:0]                    oAluB
);

  import rv32i_pkg::*;

  always_comb begin
    // ALU A input selection
    unique case (iAluASel)
      ALUA_RS1:  oAluA = iRs1Data;
      ALUA_PC:   oAluA = iPc;
      ALUA_ZERO: oAluA = '0;
      default:   oAluA = iRs1Data;
    endcase

    // ALU B input selection
    unique case (iAluBSel)
      ALUB_RS2:  oAluB = iRs2Data;
      ALUB_IMM:  oAluB = iImm;
      default:   oAluB = iRs2Data;
    endcase
  end

endmodule
