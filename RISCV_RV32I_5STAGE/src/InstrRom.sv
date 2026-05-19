/*
[MODULE_INFO_START]
Name: InstrRom
Role: Instruction ROM wrapper for the 5-stage pipeline project
Summary:
  - Keeps the same inferred distributed-ROM storage model as the single-cycle core
  - Supports direct distributed read and synchronous block-read sweep variants
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstrRom #(
  parameter int unsigned P_ADDR_WIDTH = 8,
  parameter int unsigned P_DATA_WIDTH = 32,
  parameter string       P_INIT_FILE  = "C:/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_5STAGE/src/InstructionFORTIMING.mem",
  parameter int unsigned P_MEM_IMPL   = 0,
  parameter int unsigned P_READ_LATENCY = 0
)(
  input  logic                    iClk,
  input  logic [31:0]             iAddr,
  output logic [P_DATA_WIDTH-1:0] oInstr,
  output logic                    oInstrValid,
  output logic [31:0]             oInstrAddr
);

  // ==== 1. Parameters & Constants ====
  
  localparam int unsigned             LP_DEPTH     = (1 << P_ADDR_WIDTH);
  localparam logic [P_DATA_WIDTH-1:0] LP_NOP_INSTR = 32'h0000_0013;

  logic [P_ADDR_WIDTH-1:0] WordAddr;
  logic                    AddrInRange;
  logic                    AddrWordAligned;

  // ==== 3. Read Address Logic ====
  
  // Convert byte address to word address
  assign WordAddr        = iAddr[P_ADDR_WIDTH+1:2];
  
  // Ensure the requested address falls within the initialized depth
  assign AddrInRange     = ({2'b00, iAddr[31:2]} < LP_DEPTH);
  
  // Instructions must be aligned to 4-byte boundaries (last two bits = 0)
  assign AddrWordAligned = (iAddr[1:0] == 2'b00);

  generate
    if (P_READ_LATENCY == 0) begin : gen_direct_rom
      (* rom_style = "distributed" *) logic [P_DATA_WIDTH-1:0] MemRom [0:LP_DEPTH-1];
      integer Idx;

      assign oInstr      = (AddrInRange && AddrWordAligned) ? MemRom[WordAddr] : LP_NOP_INSTR;
      assign oInstrValid = 1'b1;
      assign oInstrAddr  = iAddr;

      initial begin : init_mem_rom
        for (Idx = 0; Idx < LP_DEPTH; Idx = Idx + 1) begin
          MemRom[Idx] = LP_NOP_INSTR;
        end

        if (P_INIT_FILE != "") begin
          $readmemh(P_INIT_FILE, MemRom);
        end
      end
    end else begin : gen_sync_rom
      (* rom_style = "block" *) logic [P_DATA_WIDTH-1:0] MemRom [0:LP_DEPTH-1];
      integer Idx;

      always_ff @(posedge iClk) begin
        oInstr      <= (AddrInRange && AddrWordAligned) ? MemRom[WordAddr] : LP_NOP_INSTR;
        oInstrValid <= 1'b1;
        oInstrAddr  <= iAddr;
      end

      initial begin : init_mem_rom
        for (Idx = 0; Idx < LP_DEPTH; Idx = Idx + 1) begin
          MemRom[Idx] = LP_NOP_INSTR;
        end

        if (P_INIT_FILE != "") begin
          $readmemh(P_INIT_FILE, MemRom);
        end
      end
    end
  endgenerate

endmodule
