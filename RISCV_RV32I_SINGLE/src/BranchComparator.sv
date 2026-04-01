/*
[MODULE_INFO_START]
Name: BranchComparator
Role: RV32I branch condition comparator
Summary:
  - Compares register operands according to the decoded branch operation
  - Emits the branch-taken decision for signed and unsigned RV32I branches
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module BranchComparator (
  input  logic [31:0]         iRs1Data,
  input  logic [31:0]         iRs2Data,
  input  rv32i_pkg::branch_e  iBranchOp,
  output logic                oBranchTaken
);

  always_comb begin
    oBranchTaken = 1'b0;

    unique case (iBranchOp)
      rv32i_pkg::BR_NONE: oBranchTaken = 1'b0;
      rv32i_pkg::BR_EQ:   oBranchTaken = (iRs1Data == iRs2Data);
      rv32i_pkg::BR_NE:   oBranchTaken = (iRs1Data != iRs2Data);
      rv32i_pkg::BR_LT:   oBranchTaken = ($signed(iRs1Data) < $signed(iRs2Data));
      rv32i_pkg::BR_GE:   oBranchTaken = ($signed(iRs1Data) >= $signed(iRs2Data));
      rv32i_pkg::BR_LTU:  oBranchTaken = (iRs1Data < iRs2Data);
      rv32i_pkg::BR_GEU:  oBranchTaken = (iRs1Data >= iRs2Data);
      default:            oBranchTaken = 1'b0;
    endcase
  end

endmodule
