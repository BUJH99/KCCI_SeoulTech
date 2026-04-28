/*
[MODULE_INFO_START]
Name: InstrRom
Role: Instruction ROM wrapper for the 5-stage pipeline project
Summary:
  - Keeps the same inferred distributed-ROM storage model as the single-cycle core
  - Uses a continuous read path so TB-driven ROM reloads are visible before the first fetch after reset
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstrRom #(
  parameter int unsigned P_ADDR_WIDTH = 8,
  parameter int unsigned P_DATA_WIDTH = 32,
  parameter string       P_INIT_FILE  = "C:/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_5STAGE/src/InstructionFORTIMING.mem"
)(
  input  logic [31:0]             iAddr,
  output logic [P_DATA_WIDTH-1:0] oInstr
);

  // ==== 1. Parameters & Constants ====
  
  localparam int unsigned             LP_DEPTH     = (1 << P_ADDR_WIDTH);
  localparam logic [P_DATA_WIDTH-1:0] LP_NOP_INSTR = 32'h0000_0013;

  // ==== 2. Memory Array Definition ====
  
  (* rom_style = "distributed" *) logic [P_DATA_WIDTH-1:0] MemRom [0:LP_DEPTH-1];
  
  logic [P_ADDR_WIDTH-1:0] WordAddr;
  logic                    AddrInRange;
  logic                    AddrWordAligned;
  integer                  Idx;

  // ==== 3. Read Address Logic ====
  
  // Convert byte address to word address
  assign WordAddr        = iAddr[P_ADDR_WIDTH+1:2];
  
  // Ensure the requested address falls within the initialized depth
  assign AddrInRange     = ({2'b00, iAddr[31:2]} < LP_DEPTH);
  
  // Instructions must be aligned to 4-byte boundaries (last two bits = 0)
  assign AddrWordAligned = (iAddr[1:0] == 2'b00);

  // Read data mapping: Output NOP if out of range or unaligned, else ROM data
  assign oInstr          = (AddrInRange && AddrWordAligned) 
                         ? MemRom[WordAddr] 
                         : LP_NOP_INSTR;

  // ==== 4. Initial Memory Loading ====
  
  initial begin : init_mem_rom
    // Zero-out or NOP-fill the memory first
    for (Idx = 0; Idx < LP_DEPTH; Idx = Idx + 1) begin
      MemRom[Idx] = LP_NOP_INSTR;
    end

    // Load instructions from text file for simulation/synthesis
    $readmemh(P_INIT_FILE, MemRom);
  end

endmodule
