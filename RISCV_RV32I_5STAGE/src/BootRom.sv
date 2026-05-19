/*
[MODULE_INFO_START]
Name: BootRom
Role: Fixed boot instruction memory for the UART instruction DMA flow
Summary:
  - Provides the reset-time instruction image from a $readmemh initialized ROM
  - Supports direct distributed read and synchronous block-read sweep variants
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module BootRom #(
  parameter int unsigned P_ADDR_WIDTH   = 10,
  parameter int unsigned P_DEPTH_WORDS  = (1 << P_ADDR_WIDTH),
  parameter int unsigned P_DATA_WIDTH   = 32,
  parameter logic [31:0] P_BASE_ADDR    = 32'h0000_0000,
  parameter string       P_INIT_FILE    = "C:/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_5STAGE/src/timing_programs/uart_bootrom.mem",
  parameter int unsigned P_MEM_IMPL     = 0,
  parameter int unsigned P_READ_LATENCY = 0
) (
  input  logic                    iClk,
  input  logic [31:0]             iAddr,
  output logic [P_DATA_WIDTH-1:0] oInstr,
  output logic                    oInstrValid,
  output logic [31:0]             oInstrAddr
);

  localparam int unsigned             LP_DEPTH     = P_DEPTH_WORDS;
  localparam logic [P_DATA_WIDTH-1:0] LP_NOP_INSTR = 32'h0000_0013;

  logic [31:0]             OffsetAddr;
  logic [31:0]             WordIdx;
  logic [P_ADDR_WIDTH-1:0] WordAddr;
  logic                    AddrInRange;
  logic                    AddrWordAligned;

  assign OffsetAddr      = iAddr - P_BASE_ADDR;
  assign WordIdx       = {2'b00, OffsetAddr[31:2]};
  assign WordAddr        = OffsetAddr[P_ADDR_WIDTH+1:2];
  assign AddrInRange     = (iAddr >= P_BASE_ADDR) && (WordIdx < LP_DEPTH);
  assign AddrWordAligned = (iAddr[1:0] == 2'b00);

  generate
    if (P_READ_LATENCY == 0) begin : gen_direct_rom
      (* rom_style = "distributed" *) logic [P_DATA_WIDTH-1:0] MemRom [0:LP_DEPTH-1];
      integer idx;

      assign oInstr      = (AddrInRange && AddrWordAligned) ? MemRom[WordAddr] : LP_NOP_INSTR;
      assign oInstrValid = 1'b1;
      assign oInstrAddr  = iAddr;

      initial begin : init_mem_rom
        for (idx = 0; idx < LP_DEPTH; idx = idx + 1) begin
          MemRom[idx] = LP_NOP_INSTR;
        end

        if (P_INIT_FILE != "") begin
          $readmemh(P_INIT_FILE, MemRom);
        end
      end
    end else begin : gen_sync_rom
      (* rom_style = "block" *) logic [P_DATA_WIDTH-1:0] MemRom [0:LP_DEPTH-1];
      integer idx;

      always_ff @(posedge iClk) begin
        oInstr      <= (AddrInRange && AddrWordAligned) ? MemRom[WordAddr] : LP_NOP_INSTR;
        oInstrValid <= 1'b1;
        oInstrAddr  <= iAddr;
      end

      initial begin : init_mem_rom
        for (idx = 0; idx < LP_DEPTH; idx = idx + 1) begin
          MemRom[idx] = LP_NOP_INSTR;
        end

        if (P_INIT_FILE != "") begin
          $readmemh(P_INIT_FILE, MemRom);
        end
      end
    end
  endgenerate

endmodule
