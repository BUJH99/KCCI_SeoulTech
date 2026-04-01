/*
[MODULE_INFO_START]
Name: InstrFields
Role: Instruction bit-field extractor
Summary:
  - Breaks a 32-bit instruction into opcode/funct/register fields
  - Centralizes common bit-slice extraction for decode and datapath reuse
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstrFields (
  input  logic [31:0] iInstr,
  output logic [6:0]  oOpcode,
  output logic [2:0]  oFunct3,
  output logic [6:0]  oInstr31To25,
  output logic [11:0] oInstr31To20,
  output logic [4:0]  oRs1,
  output logic [4:0]  oRs2,
  output logic [4:0]  oRd
);

  assign oOpcode      = iInstr[6:0];
  assign oRd          = iInstr[11:7];
  assign oFunct3      = iInstr[14:12];
  assign oRs1         = iInstr[19:15];
  assign oRs2         = iInstr[24:20];
  assign oInstr31To25 = iInstr[31:25];
  assign oInstr31To20 = iInstr[31:20];

endmodule
