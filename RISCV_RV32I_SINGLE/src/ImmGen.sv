/*
[MODULE_INFO_START]
Name: ImmGen
Role: RV32I immediate generator
Summary:
  - Expands instruction immediates for I/S/B/U/J formats
  - Keeps immediate decode centralized away from control and top-level logic
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ImmGen (
  input  logic [31:0]           iInstr,
  input  rv32i_pkg::imm_sel_e   iImmSel,
  output logic [31:0]           oImm
);

  always_comb begin
    oImm = '0;

    unique case (iImmSel)
      rv32i_pkg::IMM_I: oImm = {{20{iInstr[31]}}, iInstr[31:20]};
      rv32i_pkg::IMM_S: oImm = {{20{iInstr[31]}}, iInstr[31:25], iInstr[11:7]};
      rv32i_pkg::IMM_B: oImm = {{19{iInstr[31]}}, iInstr[31], iInstr[7], iInstr[30:25], iInstr[11:8], 1'b0};
      rv32i_pkg::IMM_U: oImm = {iInstr[31:12], 12'b0};
      rv32i_pkg::IMM_J: oImm = {{11{iInstr[31]}}, iInstr[31], iInstr[19:12], iInstr[20], iInstr[30:21], 1'b0};
      default:          oImm = '0;
    endcase
  end

endmodule
