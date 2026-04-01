/*
[MODULE_INFO_START]
Name: StoreDecoder
Role: RV32I store attribute decoder
Summary:
  - Maps store funct3 encodings to access size
  - Keeps store-specific legality checks local to the store ISA space
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module StoreDecoder (
  input  logic [2:0]           iFunct3,
  output rv32i_pkg::mem_size_e oMemSize,
  output logic                 oIllegal
);

  always_comb begin
    oMemSize = rv32i_pkg::MEM_WORD;
    oIllegal = 1'b0;

    unique case (iFunct3)
      3'b000: oMemSize = rv32i_pkg::MEM_BYTE;
      3'b001: oMemSize = rv32i_pkg::MEM_HALF;
      3'b010: oMemSize = rv32i_pkg::MEM_WORD;
      default: oIllegal = 1'b1;
    endcase
  end

endmodule
