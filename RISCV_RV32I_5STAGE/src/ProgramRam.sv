/*
[MODULE_INFO_START]
Name: ProgramRam
Role: Executable RAM loaded by InstDma and fetched by the core instruction bus
Summary:
  - Exposes instruction fetch read variants for downloaded application code
  - Restricts writes to the dedicated InstDma byte-strobe port
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ProgramRam #(
  parameter int unsigned P_ADDR_WIDTH   = 14,
  parameter int unsigned P_DEPTH_WORDS  = (1 << P_ADDR_WIDTH),
  parameter int unsigned P_DATA_WIDTH   = 32,
  parameter logic [31:0] P_BASE_ADDR    = 32'h0000_1000,
  parameter string       P_INIT_FILE    = "",
  parameter int unsigned P_MEM_IMPL     = 0,
  parameter int unsigned P_READ_LATENCY = 0,
  parameter int unsigned P_READ_ONLY_INIT = 0
) (
  input  logic                    iClk,
  input  logic [31:0]             iInstrAddr,
  input  logic                    iInstDmaWrEn,
  input  logic [31:0]             iInstDmaAddr,
  input  logic [P_DATA_WIDTH-1:0] iInstDmaWdata,
  input  logic [(P_DATA_WIDTH/8)-1:0] iInstDmaWstrb,
  input  logic                    iInstDmaRdEn,
  input  logic [31:0]             iInstDmaRdAddr,

  output logic [P_DATA_WIDTH-1:0] oInstr,
  output logic                    oInstrValid,
  output logic [31:0]             oInstrAddr,
  output logic [P_DATA_WIDTH-1:0] oInstDmaRdData
);

  localparam int unsigned             LP_DEPTH      = P_DEPTH_WORDS;
  localparam int unsigned             LP_BYTE_COUNT = (P_DATA_WIDTH / 8);
  localparam logic [P_DATA_WIDTH-1:0] LP_NOP_INSTR = 32'h0000_0013;

  logic [31:0]             InstrOffsetAddr;
  logic [31:0]             WrOffsetAddr;
  logic [31:0]             RdOffsetAddr;
  logic [31:0]             InstrWordIdx;
  logic [31:0]             WrWordIdx;
  logic [31:0]             RdWordIdx;
  logic [P_ADDR_WIDTH-1:0] InstrWordAddr;
  logic [P_ADDR_WIDTH-1:0] WrWordAddr;
  logic [P_ADDR_WIDTH-1:0] RdWordAddr;
  logic                    InstrAddrInRange;
  logic                    InstrAddrWordAligned;
  logic                    WrAddrInRange;
  logic                    RdAddrInRange;
  integer                  byteIdx;
  integer                  initIdx;

  assign InstrOffsetAddr      = iInstrAddr - P_BASE_ADDR;
  assign WrOffsetAddr         = iInstDmaAddr - P_BASE_ADDR;
  assign RdOffsetAddr         = iInstDmaRdAddr - P_BASE_ADDR;
  assign InstrWordIdx       = {2'b00, InstrOffsetAddr[31:2]};
  assign WrWordIdx          = {2'b00, WrOffsetAddr[31:2]};
  assign RdWordIdx          = {2'b00, RdOffsetAddr[31:2]};
  assign InstrWordAddr        = InstrOffsetAddr[P_ADDR_WIDTH+1:2];
  assign WrWordAddr           = WrOffsetAddr[P_ADDR_WIDTH+1:2];
  assign RdWordAddr           = RdOffsetAddr[P_ADDR_WIDTH+1:2];
  assign InstrAddrInRange     = (iInstrAddr >= P_BASE_ADDR) && (InstrWordIdx < LP_DEPTH);
  assign InstrAddrWordAligned = (iInstrAddr[1:0] == 2'b00);
  assign WrAddrInRange        = (iInstDmaAddr >= P_BASE_ADDR) && (WrWordIdx < LP_DEPTH);
  assign RdAddrInRange        = (iInstDmaRdAddr >= P_BASE_ADDR) && (RdWordIdx < LP_DEPTH);

  generate
    if ((P_READ_LATENCY == 0) && (P_READ_ONLY_INIT != 0)) begin : gen_direct_read_only_ram
      (* rom_style = "distributed" *) logic [P_DATA_WIDTH-1:0] MemRam [0:LP_DEPTH-1];

      assign oInstr         = (InstrAddrInRange && InstrAddrWordAligned) ? MemRam[InstrWordAddr] : LP_NOP_INSTR;
      assign oInstrValid    = 1'b1;
      assign oInstrAddr     = iInstrAddr;
      assign oInstDmaRdData = '0;

      initial begin : init_program_ram
        for (initIdx = 0; initIdx < LP_DEPTH; initIdx = initIdx + 1) begin
          MemRam[initIdx] = LP_NOP_INSTR;
        end

        if (P_INIT_FILE != "") begin
          $readmemh(P_INIT_FILE, MemRam);
        end
      end
    end else if (P_READ_LATENCY == 0) begin : gen_direct_ram
      (* ram_style = "distributed" *) logic [P_DATA_WIDTH-1:0] MemRam [0:LP_DEPTH-1];

      assign oInstr         = (InstrAddrInRange && InstrAddrWordAligned) ? MemRam[InstrWordAddr] : LP_NOP_INSTR;
      assign oInstrValid    = 1'b1;
      assign oInstrAddr     = iInstrAddr;
      assign oInstDmaRdData = (iInstDmaRdEn && RdAddrInRange) ? MemRam[RdWordAddr] : '0;

      initial begin : init_program_ram
        for (initIdx = 0; initIdx < LP_DEPTH; initIdx = initIdx + 1) begin
          MemRam[initIdx] = LP_NOP_INSTR;
        end

        if (P_INIT_FILE != "") begin
          $readmemh(P_INIT_FILE, MemRam);
        end
      end

      always_ff @(posedge iClk) begin
        if (iInstDmaWrEn && WrAddrInRange) begin
          for (byteIdx = 0; byteIdx < LP_BYTE_COUNT; byteIdx = byteIdx + 1) begin
            if (iInstDmaWstrb[byteIdx]) begin
              MemRam[WrWordAddr][(byteIdx * 8) +: 8] <= iInstDmaWdata[(byteIdx * 8) +: 8];
            end
          end
        end
      end
    end else if (P_READ_ONLY_INIT != 0) begin : gen_sync_read_only_ram
      (* rom_style = "block" *) logic [P_DATA_WIDTH-1:0] MemRam [0:LP_DEPTH-1];

      initial begin : init_program_ram
        for (initIdx = 0; initIdx < LP_DEPTH; initIdx = initIdx + 1) begin
          MemRam[initIdx] = LP_NOP_INSTR;
        end

        if (P_INIT_FILE != "") begin
          $readmemh(P_INIT_FILE, MemRam);
        end
      end

      always_ff @(posedge iClk) begin
        oInstr         <= (InstrAddrInRange && InstrAddrWordAligned) ? MemRam[InstrWordAddr] : LP_NOP_INSTR;
        oInstrValid    <= 1'b1;
        oInstrAddr     <= iInstrAddr;
        oInstDmaRdData <= '0;
      end
    end else begin : gen_sync_ram
      (* ram_style = "block" *) logic [P_DATA_WIDTH-1:0] MemRam [0:LP_DEPTH-1];

      initial begin : init_program_ram
        for (initIdx = 0; initIdx < LP_DEPTH; initIdx = initIdx + 1) begin
          MemRam[initIdx] = LP_NOP_INSTR;
        end

        if (P_INIT_FILE != "") begin
          $readmemh(P_INIT_FILE, MemRam);
        end
      end

      always_ff @(posedge iClk) begin
        oInstr      <= (InstrAddrInRange && InstrAddrWordAligned) ? MemRam[InstrWordAddr] : LP_NOP_INSTR;
        oInstrValid <= 1'b1;
        oInstrAddr  <= iInstrAddr;
        oInstDmaRdData <= (iInstDmaRdEn && RdAddrInRange) ? MemRam[RdWordAddr] : '0;

        if (iInstDmaWrEn && WrAddrInRange) begin
          for (byteIdx = 0; byteIdx < LP_BYTE_COUNT; byteIdx = byteIdx + 1) begin
            if (iInstDmaWstrb[byteIdx]) begin
              MemRam[WrWordAddr][(byteIdx * 8) +: 8] <= iInstDmaWdata[(byteIdx * 8) +: 8];
            end
          end
        end
      end
    end
  endgenerate

endmodule
