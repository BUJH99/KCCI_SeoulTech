  /*
  [MODULE_INFO_START]
  Name: AluDecoder
  Role: RV32I ALU operation decoder
  Summary:
    - Decodes R-Type and OP-IMM funct fields into ALU operations
    - Flags unsupported arithmetic encodings as illegal
  [MODULE_INFO_END]
  */

  `timescale 1ns / 1ps

  module AluDecoder (
    input  logic [6:0]         iOpcode,
    input  logic [2:0]         iFunct3,
    input  logic [6:0]         iFunct7,
    output rv32i_pkg::alu_op_e oAluOp,
    output logic               oIllegal
  );

    always_comb begin
      oAluOp   = rv32i_pkg::ALU_ADD;
      oIllegal = 1'b0;

      unique case (iOpcode)
        rv32i_pkg::LP_OPCODE_RTYPE: begin
          unique case ({iFunct7, iFunct3})
            10'b0000000_000: oAluOp = rv32i_pkg::ALU_ADD;
            10'b0100000_000: oAluOp = rv32i_pkg::ALU_SUB;
            10'b0000000_001: oAluOp = rv32i_pkg::ALU_SLL;
            10'b0000000_010: oAluOp = rv32i_pkg::ALU_SLT;
            10'b0000000_011: oAluOp = rv32i_pkg::ALU_SLTU;
            10'b0000000_100: oAluOp = rv32i_pkg::ALU_XOR;
            10'b0000000_101: oAluOp = rv32i_pkg::ALU_SRL;
            10'b0100000_101: oAluOp = rv32i_pkg::ALU_SRA;
            10'b0000000_110: oAluOp = rv32i_pkg::ALU_OR;
            10'b0000000_111: oAluOp = rv32i_pkg::ALU_AND;
            default:         oIllegal = 1'b1;
          endcase
        end
        rv32i_pkg::LP_OPCODE_OPIMM: begin
          unique case (iFunct3)
            3'b000: oAluOp = rv32i_pkg::ALU_ADD;
            3'b010: oAluOp = rv32i_pkg::ALU_SLT;
            3'b011: oAluOp = rv32i_pkg::ALU_SLTU;
            3'b100: oAluOp = rv32i_pkg::ALU_XOR;
            3'b110: oAluOp = rv32i_pkg::ALU_OR;
            3'b111: oAluOp = rv32i_pkg::ALU_AND;
            3'b001: begin
              oAluOp   = rv32i_pkg::ALU_SLL;
              oIllegal = (iFunct7 != 7'b0000000);
            end
            3'b101: begin
              unique case (iFunct7)
                7'b0000000: oAluOp = rv32i_pkg::ALU_SRL;
                7'b0100000: oAluOp = rv32i_pkg::ALU_SRA;
                default:    oIllegal = 1'b1;
              endcase
            end
            default: oIllegal = 1'b1;
          endcase
        end
        default: oIllegal = 1'b1;
      endcase
    end

  endmodule
