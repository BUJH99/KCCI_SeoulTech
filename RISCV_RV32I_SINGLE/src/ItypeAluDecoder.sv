/*
[MODULE_INFO_START]
Name: ItypeAluDecoder
Role: RV32I I-type ALU decoder
Summary:
  - Decodes I-type arithmetic immediates into ALU operations
  - Uses shift-immediate upper bits by their ISA meaning instead of a generic funct7 label
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ItypeAluDecoder (
  input  logic [2:0]         iFunct3,
  input  logic [6:0]         iInstr31To25,
  output rv32i_pkg::alu_op_e oAluOp,
  output logic               oIllegal
);

  always_comb begin
    oAluOp   = rv32i_pkg::ALU_ADD;
    oIllegal = 1'b0;

    unique case (iFunct3)
      3'b000: oAluOp = rv32i_pkg::ALU_ADD;
      3'b010: oAluOp = rv32i_pkg::ALU_SLT;
      3'b011: oAluOp = rv32i_pkg::ALU_SLTU;
      3'b100: oAluOp = rv32i_pkg::ALU_XOR;
      3'b110: oAluOp = rv32i_pkg::ALU_OR;
      3'b111: oAluOp = rv32i_pkg::ALU_AND;
      3'b001: begin
        oAluOp   = rv32i_pkg::ALU_SLL;
        oIllegal = (iInstr31To25 != 7'b0000000);
      end
      3'b101: begin
        unique case (iInstr31To25)
          7'b0000000: oAluOp = rv32i_pkg::ALU_SRL;
          7'b0100000: oAluOp = rv32i_pkg::ALU_SRA;
          default:    oIllegal = 1'b1;
        endcase
      end
      default: oIllegal = 1'b1;
    endcase
  end

endmodule
