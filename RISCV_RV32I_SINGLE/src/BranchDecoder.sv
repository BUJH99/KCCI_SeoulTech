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
  output rv32i_pkg::branch_e  oBranchOp,
  output logic                oIllegal
);

  always_comb begin
    oBranchOp = rv32i_pkg::BR_NONE;
    oIllegal  = 1'b0;

    unique case (iFunct3)
      3'b000: oBranchOp = rv32i_pkg::BR_EQ;
      3'b001: oBranchOp = rv32i_pkg::BR_NE;
      3'b100: oBranchOp = rv32i_pkg::BR_LT;
      3'b101: oBranchOp = rv32i_pkg::BR_GE;
      3'b110: oBranchOp = rv32i_pkg::BR_LTU;
      3'b111: oBranchOp = rv32i_pkg::BR_GEU;
      default: oIllegal = 1'b1;
    endcase
  end

endmodule
