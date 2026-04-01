/*
[MODULE_INFO_START]
Name: LoadDecoder
Role: RV32I load attribute decoder
Summary:
  - Maps load funct3 encodings to access size and sign behavior
  - Keeps load-specific legality checks local to the load ISA space
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module LoadDecoder (
  input  logic [2:0]           iFunct3,
  output rv32i_pkg::mem_size_e oMemSize,
  output logic                 oLoadUnsigned,
  output logic                 oIllegal
);

  always_comb begin
    oMemSize      = rv32i_pkg::MEM_WORD;
    oLoadUnsigned = 1'b0;
    oIllegal      = 1'b0;

    unique case (iFunct3)
      3'b000: oMemSize = rv32i_pkg::MEM_BYTE;
      3'b001: oMemSize = rv32i_pkg::MEM_HALF;
      3'b010: oMemSize = rv32i_pkg::MEM_WORD;
      3'b100: begin
        oMemSize      = rv32i_pkg::MEM_BYTE;
        oLoadUnsigned = 1'b1;
      end
      3'b101: begin
        oMemSize      = rv32i_pkg::MEM_HALF;
        oLoadUnsigned = 1'b1;
      end
      default: oIllegal = 1'b1;
    endcase
  end

endmodule
