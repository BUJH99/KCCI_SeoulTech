/*
[MODULE_INFO_START]
Name: InstrFields
Role: Decode-stage instruction field extractor
Summary:
  - Breaks a 32-bit RV32I instruction into standard ISA field names
  - Keeps DecodeStage wiring semantic without reusing raw bit-index names downstream
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstrFields (
  input  logic [31:0] iInstr,

  output logic [6:0]  oOpcode,
  output logic [4:0]  oRd,
  output logic [2:0]  oFunct3,
  output logic [4:0]  oRs1,
  output logic [4:0]  oRs2,
  output logic [6:0]  oFunct7,
  output logic [11:0] oImm12
);

  assign oOpcode = iInstr[6:0];
  assign oRd     = iInstr[11:7];
  assign oFunct3 = iInstr[14:12];
  assign oRs1    = iInstr[19:15];
  assign oRs2    = iInstr[24:20];
  assign oFunct7 = iInstr[31:25];
  assign oImm12  = iInstr[31:20];

endmodule
