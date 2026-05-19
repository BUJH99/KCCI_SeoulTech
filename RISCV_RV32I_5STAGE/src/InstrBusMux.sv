/*
[MODULE_INFO_START]
Name: InstrBusMux
Role: Instruction-bus read mux for boot ROM and downloaded program RAM
Summary:
  - Selects BootRom for reset/boot address range and ProgramRam for application range
  - Returns an RV32I NOP for unmapped instruction addresses
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstrBusMux (
  input  logic [31:0] iInstrAddr,
  input  logic [31:0] iBootInstr,
  input  logic [31:0] iProgramInstr,

  output logic [31:0] oInstr
);

  import rv32i_pkg::*;

  localparam logic [31:0] LP_NOP_INSTR = 32'h0000_0013;

  logic BootSel;
  logic ProgramSel;

  assign BootSel    = (iInstrAddr <= LP_BOOT_ROM_LAST);
  assign ProgramSel = (iInstrAddr >= LP_PROGRAM_RAM_BASE) && (iInstrAddr <= LP_PROGRAM_RAM_LAST);

  always_comb begin
    if (BootSel) begin
      oInstr = iBootInstr;
    end else if (ProgramSel) begin
      oInstr = iProgramInstr;
    end else begin
      oInstr = LP_NOP_INSTR;
    end
  end

endmodule
