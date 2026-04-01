/*
[MODULE_INFO_START]
Name: UtypeDecoder
Role: RV32I U-type decoder
Summary:
  - Distinguishes LUI from AUIPC inside the shared U-type opcode class
  - Emits only the datapath select that differs between the two instructions
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module UtypeDecoder (
  input  logic [6:0]                  iOpcode,
  output rv32i_pkg::alu_a_sel_e       oAluASel,
  output logic                        oIllegal
);

  always_comb begin
    oAluASel = rv32i_pkg::ALUA_RS1;
    oIllegal = 1'b0;

    unique case (iOpcode)
      rv32i_pkg::LP_OPCODE_LUI:   oAluASel = rv32i_pkg::ALUA_ZERO;
      rv32i_pkg::LP_OPCODE_AUIPC: oAluASel = rv32i_pkg::ALUA_PC;
      default:                    oIllegal = 1'b1;
    endcase
  end

endmodule
