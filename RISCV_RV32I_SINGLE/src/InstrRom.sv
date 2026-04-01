/*
[MODULE_INFO_START]
Name: InstrRom
Role: Instruction ROM wrapper
Summary:
  - Provides word-aligned combinational instruction fetch
  - Keeps storage as an inferred ROM array for bring-up
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstrRom #(
  parameter int unsigned P_ADDR_WIDTH = 8,
  parameter int unsigned P_DATA_WIDTH = 32,
  parameter string       P_INIT_FILE  = "Project/RISCV_32I_SINGLE/src/InstructionFORTIMING.mem"
)(
  input  logic [31:0]             iAddr,
  output logic [P_DATA_WIDTH-1:0] oInstr
);

  localparam int unsigned           LP_DEPTH     = (1 << P_ADDR_WIDTH);
  localparam logic [P_DATA_WIDTH-1:0] LP_NOP_INSTR = 32'h0000_0013;

  (* rom_style = "distributed" *) logic [P_DATA_WIDTH-1:0] memRom [0:LP_DEPTH-1];
  logic [P_ADDR_WIDTH-1:0] wordAddr;
  logic [31:0]             wordAddrWide;
  logic                    addrInRange;
  logic                    addrWordAligned;
  integer                  idx;

  assign wordAddr         = iAddr[P_ADDR_WIDTH+1:2];
  assign wordAddrWide     = {2'd0, iAddr[31:2]};
  assign addrInRange      = (wordAddrWide < LP_DEPTH);
  assign addrWordAligned  = (iAddr[1:0] == 2'b00);

  initial begin : init_mem_rom
    for (idx = 0; idx < LP_DEPTH; idx = idx + 1) begin
      memRom[idx] = LP_NOP_INSTR;
    end

    $readmemh(P_INIT_FILE, memRom);
  end

  always_comb begin
    oInstr = LP_NOP_INSTR;
    if (addrInRange && addrWordAligned) begin
      oInstr = memRom[wordAddr];
    end
  end

endmodule
