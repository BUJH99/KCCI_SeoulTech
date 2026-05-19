`timescale 1ns / 1ps

`include "sweep_defines.svh"

module TbTop;
  import rv32i_pkg::*;

  localparam int unsigned LP_CLK_PERIOD_NS = 10;
  localparam int unsigned LP_MAX_CYCLES    = `INSTR_SWEEP_MAX_CYCLES;
  localparam int unsigned LP_TARGET_RETIRES = `INSTR_SWEEP_TARGET_RETIRES;

  logic         iClk;
  logic         iRst;
  InstrBusReq_t InstrBusReq;
  InstrBusRsp_t InstrBusRsp;
  DataBusReq_t  DataBusReq;
  DataBusRsp_t  DataBusRsp;
  logic         TimingProbe;
  logic         PrefetchHitPulse;
  logic         PrefetchEmptyPulse;
  logic         DiscardPulse;

  int unsigned CycleCount;
  int unsigned RetiredInstrCount;
  int unsigned FetchWaitCycles;
  int unsigned FetchRequestCount;
  int unsigned FetchResponseCount;
  int unsigned RedirectFlushCount;
  int unsigned PrefetchHitCount;
  int unsigned PrefetchEmptyCount;
  int unsigned DiscardedPrefetchCount;
  int unsigned FetchBootRequestCount;
  int unsigned FetchProgramRequestCount;
  int unsigned FetchUnmappedRequestCount;
  int unsigned RetireBootInstrCount;
  int unsigned RetireProgramInstrCount;
  int unsigned RetireUnmappedInstrCount;
  logic [31:0] FetchMinAddr;
  logic [31:0] FetchMaxAddr;
  logic [31:0] RetireMinPc;
  logic [31:0] RetireMaxPc;
  bit          FetchAddrSeen;
  bit          RetirePcSeen;
  bit          DoneWritten;

  Rv32iCore uRv32iCore (
    .iClk            (iClk),
    .iRst            (iRst),
    .iInstrBusRsp    (InstrBusRsp),
    .iDataBusRsp     (DataBusRsp),
    .iExtIrqPending  (1'b0),
    .iTimerIrqPending(1'b0),
    .iIntcVectorValid(1'b0),
    .iIntcVectorPc   (32'd0),
    .oInstrBusReq    (InstrBusReq),
    .oDataBusReq     (DataBusReq),
    .oTimingProbe    (TimingProbe)
  );

  InstrFetchMemory #(
    .P_BOOT_ADDR_WIDTH   (`INSTR_SWEEP_BOOT_ADDR_WIDTH),
    .P_BOOT_DEPTH_WORDS  (`INSTR_SWEEP_BOOT_DEPTH_WORDS),
    .P_BOOT_INIT_FILE    (`INSTR_SWEEP_BOOT_INIT_FILE),
    .P_PROGRAM_ADDR_WIDTH(`INSTR_SWEEP_PROGRAM_ADDR_WIDTH),
    .P_PROGRAM_DEPTH_WORDS(`INSTR_SWEEP_PROGRAM_DEPTH_WORDS),
    .P_PROGRAM_INIT_FILE (`INSTR_SWEEP_PROGRAM_INIT_FILE),
    .P_PROGRAM_READ_ONLY_INIT(`INSTR_SWEEP_PROGRAM_READ_ONLY_INIT),
    .P_INSTR_MEM_IMPL    (`INSTR_SWEEP_MEM_IMPL),
    .P_INSTR_MEM_LATENCY (`INSTR_SWEEP_MEM_LATENCY),
    .P_PREFETCH_DEPTH    (`INSTR_SWEEP_PREFETCH_DEPTH)
  ) uInstrFetchMemory (
    .iClk                (iClk),
    .iRst                (iRst),
    .iInstrBusReq        (InstrBusReq),
    .iInstDmaWrEn        (1'b0),
    .iInstDmaAddr        (32'd0),
    .iInstDmaWdata       (32'd0),
    .iInstDmaWstrb       (4'd0),
    .oInstrBusRsp        (InstrBusRsp),
    .oInstDmaRdData      (),
    .oPrefetchHitPulse   (PrefetchHitPulse),
    .oPrefetchEmptyPulse (PrefetchEmptyPulse),
    .oDiscardPulse       (DiscardPulse)
  );

  assign DataBusRsp.RspRdata = 32'd0;
  assign DataBusRsp.RspReady = 1'b1;
  assign DataBusRsp.RspErr   = 1'b0;

  function automatic bit IsBootAddr(input logic [31:0] Addr);
    IsBootAddr = (Addr >= LP_BOOT_ROM_BASE) && (Addr <= LP_BOOT_ROM_LAST);
  endfunction

  function automatic bit IsProgramAddr(input logic [31:0] Addr);
    IsProgramAddr = (Addr >= LP_PROGRAM_RAM_BASE) && (Addr <= LP_PROGRAM_RAM_LAST);
  endfunction

  initial begin : gen_clock
    iClk = 1'b0;
    forever #(LP_CLK_PERIOD_NS / 2) iClk = ~iClk;
  end

  initial begin : gen_reset
    iRst = 1'b1;
    repeat (8) @(posedge iClk);
    iRst = 1'b0;
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      CycleCount            <= 0;
      RetiredInstrCount     <= 0;
      FetchWaitCycles       <= 0;
      FetchRequestCount     <= 0;
      FetchResponseCount    <= 0;
      RedirectFlushCount    <= 0;
      PrefetchHitCount      <= 0;
      PrefetchEmptyCount    <= 0;
      DiscardedPrefetchCount <= 0;
      FetchBootRequestCount <= 0;
      FetchProgramRequestCount <= 0;
      FetchUnmappedRequestCount <= 0;
      RetireBootInstrCount <= 0;
      RetireProgramInstrCount <= 0;
      RetireUnmappedInstrCount <= 0;
      FetchMinAddr <= '1;
      FetchMaxAddr <= '0;
      RetireMinPc <= '1;
      RetireMaxPc <= '0;
      FetchAddrSeen <= 1'b0;
      RetirePcSeen <= 1'b0;
    end else begin
      CycleCount <= CycleCount + 1;

      if (InstrBusReq.ReqValid) begin
        FetchRequestCount <= FetchRequestCount + 1;
        if (IsBootAddr(InstrBusReq.ReqAddr)) begin
          FetchBootRequestCount <= FetchBootRequestCount + 1;
        end else if (IsProgramAddr(InstrBusReq.ReqAddr)) begin
          FetchProgramRequestCount <= FetchProgramRequestCount + 1;
        end else begin
          FetchUnmappedRequestCount <= FetchUnmappedRequestCount + 1;
        end
        if (!FetchAddrSeen) begin
          FetchAddrSeen <= 1'b1;
          FetchMinAddr  <= InstrBusReq.ReqAddr;
          FetchMaxAddr  <= InstrBusReq.ReqAddr;
        end else begin
          if (InstrBusReq.ReqAddr < FetchMinAddr) begin
            FetchMinAddr <= InstrBusReq.ReqAddr;
          end
          if (InstrBusReq.ReqAddr > FetchMaxAddr) begin
            FetchMaxAddr <= InstrBusReq.ReqAddr;
          end
        end

        if (InstrBusRsp.RspReady) begin
          FetchResponseCount <= FetchResponseCount + 1;
        end else begin
          FetchWaitCycles <= FetchWaitCycles + 1;
        end
      end

      if (uRv32iCore.RetireValid) begin
        RetiredInstrCount <= RetiredInstrCount + 1;
        if (IsBootAddr(uRv32iCore.RetirePc)) begin
          RetireBootInstrCount <= RetireBootInstrCount + 1;
        end else if (IsProgramAddr(uRv32iCore.RetirePc)) begin
          RetireProgramInstrCount <= RetireProgramInstrCount + 1;
        end else begin
          RetireUnmappedInstrCount <= RetireUnmappedInstrCount + 1;
        end
        if (!RetirePcSeen) begin
          RetirePcSeen <= 1'b1;
          RetireMinPc  <= uRv32iCore.RetirePc;
          RetireMaxPc  <= uRv32iCore.RetirePc;
        end else begin
          if (uRv32iCore.RetirePc < RetireMinPc) begin
            RetireMinPc <= uRv32iCore.RetirePc;
          end
          if (uRv32iCore.RetirePc > RetireMaxPc) begin
            RetireMaxPc <= uRv32iCore.RetirePc;
          end
        end
      end

      if (uRv32iCore.TrapRedirectValid || uRv32iCore.IdRedirectValidCtrl || uRv32iCore.ExRedirectValidCtrl) begin
        RedirectFlushCount <= RedirectFlushCount + 1;
      end

      if (PrefetchHitPulse) begin
        PrefetchHitCount <= PrefetchHitCount + 1;
      end
      if (PrefetchEmptyPulse) begin
        PrefetchEmptyCount <= PrefetchEmptyCount + 1;
      end
      if (DiscardPulse) begin
        DiscardedPrefetchCount <= DiscardedPrefetchCount + 1;
      end
    end
  end

  task automatic WriteCounters(input bit iProgramDone, input bit iWatchdogTimeout);
    int fd;
    begin
      fd = $fopen("counters.json", "w");
      if (fd == 0) begin
        $fatal(1, "[INSTR_SWEEP] failed to open counters.json");
      end

      $fdisplay(fd, "{");
      $fdisplay(fd, "  \"cycle_count\": %0d,", CycleCount);
      $fdisplay(fd, "  \"retired_instr_count\": %0d,", RetiredInstrCount);
      $fdisplay(fd, "  \"fetch_wait_cycles\": %0d,", FetchWaitCycles);
      $fdisplay(fd, "  \"fetch_request_count\": %0d,", FetchRequestCount);
      $fdisplay(fd, "  \"fetch_response_count\": %0d,", FetchResponseCount);
      $fdisplay(fd, "  \"redirect_flush_count\": %0d,", RedirectFlushCount);
      $fdisplay(fd, "  \"prefetch_hit_count\": %0d,", PrefetchHitCount);
      $fdisplay(fd, "  \"prefetch_empty_count\": %0d,", PrefetchEmptyCount);
      $fdisplay(fd, "  \"prefetch_miss_or_empty_count\": %0d,", PrefetchEmptyCount);
      $fdisplay(fd, "  \"discarded_prefetch_count\": %0d,", DiscardedPrefetchCount);
      $fdisplay(fd, "  \"fetch_boot_request_count\": %0d,", FetchBootRequestCount);
      $fdisplay(fd, "  \"fetch_program_request_count\": %0d,", FetchProgramRequestCount);
      $fdisplay(fd, "  \"fetch_unmapped_request_count\": %0d,", FetchUnmappedRequestCount);
      $fdisplay(fd, "  \"retire_boot_instr_count\": %0d,", RetireBootInstrCount);
      $fdisplay(fd, "  \"retire_program_instr_count\": %0d,", RetireProgramInstrCount);
      $fdisplay(fd, "  \"retire_unmapped_instr_count\": %0d,", RetireUnmappedInstrCount);
      $fdisplay(fd, "  \"fetch_min_addr\": %0d,", FetchAddrSeen ? FetchMinAddr : 32'd0);
      $fdisplay(fd, "  \"fetch_max_addr\": %0d,", FetchAddrSeen ? FetchMaxAddr : 32'd0);
      $fdisplay(fd, "  \"retire_min_pc\": %0d,", RetirePcSeen ? RetireMinPc : 32'd0);
      $fdisplay(fd, "  \"retire_max_pc\": %0d,", RetirePcSeen ? RetireMaxPc : 32'd0);
      $fdisplay(fd, "  \"program_done\": %s,", iProgramDone ? "true" : "false");
      $fdisplay(fd, "  \"watchdog_timeout\": %s", iWatchdogTimeout ? "true" : "false");
      $fdisplay(fd, "}");
      $fclose(fd);

      $display("[INSTR_SWEEP] cycle_count=%0d", CycleCount);
      $display("[INSTR_SWEEP] retired_instr_count=%0d", RetiredInstrCount);
      $display("[INSTR_SWEEP] fetch_wait_cycles=%0d", FetchWaitCycles);
      $display("[INSTR_SWEEP] fetch_request_count=%0d", FetchRequestCount);
      $display("[INSTR_SWEEP] fetch_response_count=%0d", FetchResponseCount);
    end
  endtask

  initial begin : run_test
    DoneWritten = 1'b0;
    wait (!iRst);
    while (!DoneWritten) begin
      @(posedge iClk);
      if (RetiredInstrCount >= LP_TARGET_RETIRES) begin
        DoneWritten = 1'b1;
        WriteCounters(1'b1, 1'b0);
        $finish;
      end
      if (CycleCount >= LP_MAX_CYCLES) begin
        DoneWritten = 1'b1;
        WriteCounters(1'b0, 1'b1);
        $finish;
      end
    end
  end

endmodule
