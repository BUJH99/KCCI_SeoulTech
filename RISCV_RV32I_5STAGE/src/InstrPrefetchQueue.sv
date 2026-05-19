/*
[MODULE_INFO_START]
Name: InstrPrefetchQueue
Role: Sequential instruction prefetch queue for synchronous instruction memory sweeps
Summary:
  - Tracks core fetch addresses and stores returned instruction words by address
  - Discards queued and pending words when the core redirects to a non-sequential address
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstrPrefetchQueue #(
  parameter int unsigned P_DEPTH = 4
) (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iCoreReqValid,
  input  logic [31:0] iCoreReqAddr,
  input  logic        iMemRspValid,
  input  logic [31:0] iMemRspAddr,
  input  logic [31:0] iMemRspData,

  output logic [31:0] oMemReqAddr,
  output logic        oCoreRspReady,
  output logic [31:0] oCoreRspData,
  output logic        oPrefetchHitPulse,
  output logic        oPrefetchEmptyPulse,
  output logic        oDiscardPulse
);

  localparam int unsigned LP_COUNT_WIDTH = (P_DEPTH <= 1) ? 1 : $clog2(P_DEPTH + 1);

  logic [31:0]                 QueueAddr [0:P_DEPTH-1];
  logic [31:0]                 QueueData [0:P_DEPTH-1];
  logic [LP_COUNT_WIDTH-1:0]   QueueCount;
  logic                        PendingValid;
  logic [31:0]                 PendingAddr;
  logic [31:0]                 MemReqAddr;
  logic [31:0]                 NextReqAddr;
  logic                        CoreHit;
  logic                        RspAccepted;
  logic                        RedirectReq;
  logic                        IssueReq;
  logic                        StreamMismatch;
  integer                      Idx;

  assign CoreHit       = iCoreReqValid && (QueueCount != '0) && (QueueAddr[0] == iCoreReqAddr);
  assign RspAccepted   = PendingValid && iMemRspValid && (iMemRspAddr == PendingAddr);
  assign StreamMismatch = (QueueCount != '0) ? (QueueAddr[0] != iCoreReqAddr)
                        : PendingValid       ? (PendingAddr != iCoreReqAddr)
                        :                      (MemReqAddr != iCoreReqAddr);
  assign RedirectReq   = iCoreReqValid
                       && !CoreHit
                       && StreamMismatch;
  assign IssueReq      = iCoreReqValid
                       && !RedirectReq
                       && ((!PendingValid) || RspAccepted)
                       && (QueueCount < P_DEPTH);
  assign oMemReqAddr   = MemReqAddr;
  assign oCoreRspReady = CoreHit;
  assign oCoreRspData  = CoreHit ? QueueData[0] : 32'h0000_0013;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      QueueCount          <= '0;
      PendingValid        <= 1'b0;
      PendingAddr         <= '0;
      MemReqAddr          <= '0;
      NextReqAddr         <= 32'd4;
      oPrefetchHitPulse   <= 1'b0;
      oPrefetchEmptyPulse <= 1'b0;
      oDiscardPulse       <= 1'b0;
      for (Idx = 0; Idx < P_DEPTH; Idx = Idx + 1) begin
        QueueAddr[Idx] <= '0;
        QueueData[Idx] <= '0;
      end
    end else begin : update_queue
      logic [LP_COUNT_WIDTH-1:0] CountNext;

      CountNext           = QueueCount;
      oPrefetchHitPulse   <= CoreHit;
      oPrefetchEmptyPulse <= iCoreReqValid && !CoreHit;
      oDiscardPulse       <= 1'b0;

      if (RedirectReq) begin
        QueueCount    <= '0;
        PendingValid  <= 1'b0;
        PendingAddr   <= '0;
        MemReqAddr    <= iCoreReqAddr;
        NextReqAddr   <= iCoreReqAddr + 32'd4;
        oDiscardPulse <= 1'b1;
      end else begin
        if (CoreHit) begin
          for (Idx = 0; Idx < P_DEPTH - 1; Idx = Idx + 1) begin
            QueueAddr[Idx] <= QueueAddr[Idx + 1];
            QueueData[Idx] <= QueueData[Idx + 1];
          end
          if (CountNext != '0) begin
            CountNext = CountNext - 1'b1;
          end
        end

        if (RspAccepted) begin
          if (CountNext < P_DEPTH) begin
            QueueAddr[CountNext] <= iMemRspAddr;
            QueueData[CountNext] <= iMemRspData;
            CountNext            = CountNext + 1'b1;
          end
          PendingValid <= 1'b0;
        end

        if (IssueReq) begin
          PendingValid <= 1'b1;
          PendingAddr  <= MemReqAddr;
          MemReqAddr   <= NextReqAddr;
          NextReqAddr  <= NextReqAddr + 32'd4;
        end

        QueueCount <= CountNext;
      end
    end
  end

endmodule
