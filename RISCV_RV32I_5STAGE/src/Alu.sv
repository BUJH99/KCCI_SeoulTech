/*
[MODULE_INFO_START]
Name: Alu
Role: R-Type arithmetic and logic unit
Summary:
  - Executes the supported RV32I ALU operations
  - Preserves signed and unsigned behavior per instruction definition
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module Alu (
  input  logic [31:0]        iA,
  input  logic [31:0]        iB,
  input  rv32i_pkg::AluOpE iAluOp,
  
  output logic [31:0]        oResult
);

  // ==== 1. Arithmetic & Logic Evaluation ====
  
  // Processes numeric or logical operations based on control signals from ID.
  always_comb begin
    oResult = '0;

    unique case (iAluOp)
      rv32i_pkg::ALU_ADD:  oResult = iA + iB;
      rv32i_pkg::ALU_SUB:  oResult = iA - iB;
      rv32i_pkg::ALU_SLL:  oResult = iA << iB[4:0];
      
      // Signed comparison natively handles negative numbers via $signed cast
      rv32i_pkg::ALU_SLT:  oResult = { 31'd0, ($signed(iA) < $signed(iB)) };
      
      // Unsigned comparison treats raw bits as magnitude
      rv32i_pkg::ALU_SLTU: oResult = { 31'd0, (iA < iB) };
      
      rv32i_pkg::ALU_XOR:  oResult = iA ^ iB;
      rv32i_pkg::ALU_SRL:  oResult = iA >> iB[4:0];
      
      // Arithmetic shift right preserves the sign bit (MSB) via $signed cast
      rv32i_pkg::ALU_SRA:  oResult = $signed(iA) >>> iB[4:0];
      
      rv32i_pkg::ALU_OR:   oResult = iA | iB;
      rv32i_pkg::ALU_AND:  oResult = iA & iB;
      
      default:             oResult = '0;
    endcase
  end

endmodule
