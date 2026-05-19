/*
[MODULE_INFO_START]
Name: InstrFetchMemory
Role: Instruction memory front-end for BootRom, ProgramRam, and sweep variants
Summary:
  - Keeps BootRom, ProgramRam, and InstrBusMux under one parameterized wrapper
  - Provides direct, synchronous, and synchronous-prefetch response-ready behavior to the core
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstrFetchMemory #(
  parameter int unsigned P_BOOT_ADDR_WIDTH     = 10,
  parameter int unsigned P_BOOT_DEPTH_WORDS    = (1 << P_BOOT_ADDR_WIDTH),
  parameter string       P_BOOT_INIT_FILE      = "C:/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_5STAGE/src/timing_programs/uart_bootrom.mem",
  parameter int unsigned P_PROGRAM_ADDR_WIDTH  = 14,
  parameter int unsigned P_PROGRAM_DEPTH_WORDS = (1 << P_PROGRAM_ADDR_WIDTH),
  parameter string       P_PROGRAM_INIT_FILE   = "",
  parameter int unsigned P_PROGRAM_READ_ONLY_INIT = 0,
  parameter int unsigned P_INSTR_MEM_IMPL      = 0,
  parameter int unsigned P_INSTR_MEM_LATENCY   = 0,
  parameter int unsigned P_PREFETCH_DEPTH      = 0
) (
  input  logic                       iClk,
  input  logic                       iRst,
  input  rv32i_pkg::InstrBusReq_t    iInstrBusReq,
  input  logic                       iInstDmaWrEn,
  input  logic [31:0]                iInstDmaAddr,
  input  logic [31:0]                iInstDmaWdata,
  input  logic [3:0]                 iInstDmaWstrb,

  output rv32i_pkg::InstrBusRsp_t    oInstrBusRsp,
  output logic [31:0]                oInstDmaRdData,
  output logic                       oPrefetchHitPulse,
  output logic                       oPrefetchEmptyPulse,
  output logic                       oDiscardPulse
);

  import rv32i_pkg::*;

  logic [31:0] MemReqAddr;
  logic [31:0] BootInstrRdWord;
  logic        BootInstrValid;
  logic [31:0] BootInstrAddr;
  logic [31:0] ProgramInstrRdWord;
  logic        ProgramInstrValid;
  logic [31:0] ProgramInstrAddr;
  logic [31:0] MuxInstrRdWord;
  logic        MemRspValid;
  logic [31:0] MemRspAddr;

  (* keep_hierarchy = "yes", dont_touch = "yes" *) BootRom #(
    .P_ADDR_WIDTH  (P_BOOT_ADDR_WIDTH),
    .P_DEPTH_WORDS (P_BOOT_DEPTH_WORDS),
    .P_BASE_ADDR   (LP_BOOT_ROM_BASE),
    .P_INIT_FILE   (P_BOOT_INIT_FILE),
    .P_MEM_IMPL    (P_INSTR_MEM_IMPL),
    .P_READ_LATENCY(P_INSTR_MEM_LATENCY)
  ) uInstrRom (
    .iClk        (iClk),
    .iAddr       (MemReqAddr),
    .oInstr      (BootInstrRdWord),
    .oInstrValid (BootInstrValid),
    .oInstrAddr  (BootInstrAddr)
  );

  (* keep_hierarchy = "yes", dont_touch = "yes" *) ProgramRam #(
    .P_ADDR_WIDTH  (P_PROGRAM_ADDR_WIDTH),
    .P_DEPTH_WORDS (P_PROGRAM_DEPTH_WORDS),
    .P_BASE_ADDR   (LP_PROGRAM_RAM_BASE),
    .P_INIT_FILE   (P_PROGRAM_INIT_FILE),
    .P_MEM_IMPL    (P_INSTR_MEM_IMPL),
    .P_READ_LATENCY(P_INSTR_MEM_LATENCY),
    .P_READ_ONLY_INIT(P_PROGRAM_READ_ONLY_INIT)
  ) uProgramRam (
    .iClk          (iClk),
    .iInstrAddr    (MemReqAddr),
    .iInstDmaWrEn  (iInstDmaWrEn),
    .iInstDmaAddr  (iInstDmaAddr),
    .iInstDmaWdata (iInstDmaWdata),
    .iInstDmaWstrb (iInstDmaWstrb),
    .iInstDmaRdEn  (1'b0),
    .iInstDmaRdAddr(32'd0),
    .oInstr        (ProgramInstrRdWord),
    .oInstrValid   (ProgramInstrValid),
    .oInstrAddr    (ProgramInstrAddr),
    .oInstDmaRdData(oInstDmaRdData)
  );

  assign MemRspValid = (BootInstrValid == 1'b1) && (ProgramInstrValid == 1'b1);
  assign MemRspAddr  = BootInstrAddr;

  (* keep_hierarchy = "yes", dont_touch = "yes" *) InstrBusMux uInstrBusMux (
    .iInstrAddr   (MemRspAddr),
    .iBootInstr   (BootInstrRdWord),
    .iProgramInstr(ProgramInstrRdWord),
    .oInstr       (MuxInstrRdWord)
  );

  generate
    if (P_PREFETCH_DEPTH == 0) begin : gen_no_prefetch
      assign MemReqAddr              = iInstrBusReq.ReqAddr;
      assign oInstrBusRsp.RspRdata   = MuxInstrRdWord;
      assign oInstrBusRsp.RspReady   = (P_INSTR_MEM_LATENCY == 0)
                                     ? 1'b1
                                     : (MemRspValid && (MemRspAddr == iInstrBusReq.ReqAddr));
      assign oPrefetchHitPulse       = 1'b0;
      assign oPrefetchEmptyPulse     = iInstrBusReq.ReqValid && !oInstrBusRsp.RspReady;
      assign oDiscardPulse           = 1'b0;
    end else begin : gen_prefetch
      InstrPrefetchQueue #(
        .P_DEPTH(P_PREFETCH_DEPTH)
      ) uInstrPrefetchQueue (
        .iClk                (iClk),
        .iRst                (iRst),
        .iCoreReqValid       (iInstrBusReq.ReqValid),
        .iCoreReqAddr        (iInstrBusReq.ReqAddr),
        .iMemRspValid        (MemRspValid),
        .iMemRspAddr         (MemRspAddr),
        .iMemRspData         (MuxInstrRdWord),
        .oMemReqAddr         (MemReqAddr),
        .oCoreRspReady       (oInstrBusRsp.RspReady),
        .oCoreRspData        (oInstrBusRsp.RspRdata),
        .oPrefetchHitPulse   (oPrefetchHitPulse),
        .oPrefetchEmptyPulse (oPrefetchEmptyPulse),
        .oDiscardPulse       (oDiscardPulse)
      );
    end
  endgenerate

endmodule
