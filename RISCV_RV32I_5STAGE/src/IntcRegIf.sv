/*
[MODULE_INFO_START]
Name: IntcRegIf
Role: APB register interface for the PLIC-lite interrupt controller
Summary:
  - Owns enable, vector mode, priority, threshold, and vector-entry MMIO state
  - Exposes pending, claim, complete, info, and compact table-entry vector registers
  - Keeps ID0 reserved while mapping source IDs 1..P_NUM_SOURCES into per-source registers
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module IntcRegIf #(
  parameter int unsigned P_NUM_SOURCES    = rv32i_pkg::LP_INTC_NUM_SOURCES,
  parameter int unsigned P_PRIORITY_WIDTH = rv32i_pkg::LP_INTC_PRIORITY_WIDTH
) (
  input  logic                         iClk,
  input  logic                         iRst,
  input  logic                         iPsel,
  input  logic                         iPenable,
  input  logic                         iPwrite,
  input  logic [11:0]                  iPaddr,
  input  logic [3:0]                   iPstrb,
  input  logic [31:0]                  iPwdata,
  input  logic [P_NUM_SOURCES-1:0]     iPendingVec,
  input  logic [31:0]                  iClaimId,

  output logic [P_NUM_SOURCES-1:0]     oEnVec,
  output logic                         oClaimRdEn,
  output logic                         oCompleteWrEn,
  output logic [31:0]                  oCompleteId,
  output logic                         oVectorEn,
  output logic [((P_NUM_SOURCES + 1) * P_PRIORITY_WIDTH)-1:0] oPriorityEntryFlat,
  output logic [P_PRIORITY_WIDTH-1:0]  oThreshold,
  output logic [((P_NUM_SOURCES + 1) * 32)-1:0] oVectorEntryFlat,
  output logic [31:0]                  oPrdata,
  output logic                         oPready,
  output logic                         oPslverr
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_REG_PENDING       = 12'h000;
  localparam logic [11:0] LP_REG_ENABLE        = 12'h004;
  localparam logic [11:0] LP_REG_CLAIM         = 12'h008;
  localparam logic [11:0] LP_REG_COMPLETE      = 12'h00C;
  localparam logic [11:0] LP_REG_CTRL          = 12'h010;
  localparam logic [11:0] LP_REG_THRESHOLD     = 12'h014;
  localparam logic [11:0] LP_REG_INFO          = 12'h018;
  localparam logic [11:0] LP_REG_PRIORITY0     = 12'h020;
  localparam logic [11:0] LP_REG_VECTOR_ENTRY0 = 12'h080;
  localparam int unsigned LP_NUM_VECTOR_ENTRIES = P_NUM_SOURCES + 1;

  logic [P_NUM_SOURCES-1:0] EnVec_d;
  logic                     VectorEn_d;
  logic [((P_NUM_SOURCES + 1) * P_PRIORITY_WIDTH)-1:0] PriorityEntryFlat_d;
  logic [P_PRIORITY_WIDTH-1:0] Threshold_d;
  logic [(LP_NUM_VECTOR_ENTRIES*32)-1:0] VectorEntryFlat_d;
  logic [31:0]              PendingWord;
  logic [31:0]              EnWord;
  logic [31:0]              CtrlWord;
  logic [31:0]              ThresholdWord;
  logic [31:0]              InfoWord;
  logic [31:0]              EnWrWord;
  logic [31:0]              CompleteWrWord;
  logic [31:0]              CtrlWrWord;
  logic [31:0]              ThresholdWrWord;
  logic [31:0]              PriorityEntryWord;
  logic [31:0]              PriorityEntryWrWord;
  logic [31:0]              VectorEntryWord;
  logic [31:0]              VectorEntryWrWord;
  logic                     PriorityEntryAccess;
  logic                     VectorEntryAccess;
  logic [11:0]              EntryAddr;
  logic                     AccessEn;
  int unsigned              PriorityEntryIdx;
  int unsigned              VectorEntryIdx;
  int unsigned              EntryIdx;

  assign oPready                = 1'b1;
  assign AccessEn               = iPsel && iPenable && oPready;
  assign oClaimRdEn           = AccessEn && !iPwrite && (iPaddr == LP_REG_CLAIM);
  assign oCompleteWrEn       = AccessEn && iPwrite && (iPaddr == LP_REG_COMPLETE);
  assign oCompleteId            = CompleteWrWord;
  assign EnWrWord        = ByteWriteMerge(EnWord, iPwdata, iPstrb);
  assign CompleteWrWord      = ByteWriteMerge(32'd0, iPwdata, iPstrb);
  assign CtrlWrWord          = ByteWriteMerge(CtrlWord, iPwdata, iPstrb);
  assign ThresholdWrWord     = ByteWriteMerge(ThresholdWord, iPwdata, iPstrb);
  assign PriorityEntryWrWord = ByteWriteMerge(PriorityEntryWord, iPwdata, iPstrb);
  assign VectorEntryWrWord   = ByteWriteMerge(VectorEntryWord, iPwdata, iPstrb);

  always_comb begin
    PendingWord   = '0;
    EnWord    = '0;
    CtrlWord      = '0;
    ThresholdWord = '0;
    InfoWord      = '0;

    PendingWord[P_NUM_SOURCES-1:0] = iPendingVec;
    EnWord[P_NUM_SOURCES-1:0]  = oEnVec;
    CtrlWord[0]                    = oVectorEn;
    ThresholdWord[P_PRIORITY_WIDTH-1:0] = oThreshold;
    InfoWord[7:0]                  = P_NUM_SOURCES[7:0];
    InfoWord[15:8]                 = P_PRIORITY_WIDTH[7:0];
    InfoWord[16]                   = 1'b1;
    InfoWord[17]                   = 1'b1;
    InfoWord[18]                   = 1'b1;
  end

  always_comb begin
    PriorityEntryAccess = 1'b0;
    PriorityEntryIdx    = 0;
    VectorEntryAccess   = 1'b0;
    VectorEntryIdx      = 0;

    for (EntryIdx = 0; EntryIdx < LP_NUM_VECTOR_ENTRIES; EntryIdx = EntryIdx + 1) begin
      EntryAddr = LP_REG_PRIORITY0 + {EntryIdx[9:0], 2'b00};
      if (iPaddr == EntryAddr) begin
        PriorityEntryAccess = 1'b1;
        PriorityEntryIdx    = EntryIdx;
      end

      EntryAddr = LP_REG_VECTOR_ENTRY0 + {EntryIdx[9:0], 2'b00};
      if (iPaddr == EntryAddr) begin
        VectorEntryAccess = 1'b1;
        VectorEntryIdx    = EntryIdx;
      end
    end
  end

  always_comb begin
    PriorityEntryWord = '0;
    VectorEntryWord   = '0;

    if (PriorityEntryAccess && (PriorityEntryIdx != 0)) begin
      PriorityEntryWord[P_PRIORITY_WIDTH-1:0] =
          oPriorityEntryFlat[(PriorityEntryIdx * P_PRIORITY_WIDTH) +: P_PRIORITY_WIDTH];
    end

    if (VectorEntryAccess) begin
      VectorEntryWord = oVectorEntryFlat[(VectorEntryIdx * 32) +: 32];
    end
  end

  always_comb begin
    EnVec_d         = oEnVec;
    VectorEn_d      = oVectorEn;
    PriorityEntryFlat_d = oPriorityEntryFlat;
    Threshold_d         = oThreshold;
    VectorEntryFlat_d   = oVectorEntryFlat;

    if (AccessEn && iPwrite && (iPaddr == LP_REG_ENABLE)) begin
      EnVec_d = EnWrWord[P_NUM_SOURCES-1:0];
    end

    if (AccessEn && iPwrite && (iPaddr == LP_REG_CTRL)) begin
      VectorEn_d = CtrlWrWord[0];
    end

    if (AccessEn && iPwrite && (iPaddr == LP_REG_THRESHOLD)) begin
      Threshold_d = ThresholdWrWord[P_PRIORITY_WIDTH-1:0];
    end

    if (AccessEn && iPwrite && PriorityEntryAccess && (PriorityEntryIdx != 0)) begin
      PriorityEntryFlat_d[(PriorityEntryIdx * P_PRIORITY_WIDTH) +: P_PRIORITY_WIDTH] =
          PriorityEntryWrWord[P_PRIORITY_WIDTH-1:0];
    end

    if (AccessEn && iPwrite && VectorEntryAccess && (VectorEntryIdx != 0)) begin
      VectorEntryFlat_d[(VectorEntryIdx * 32) +: 32] = {VectorEntryWrWord[31:2], 2'b00};
    end
  end

  always_comb begin
    oPrdata  = '0;
    oPslverr = 1'b0;

    if (AccessEn) begin
      unique case (iPaddr)
        LP_REG_PENDING: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = PendingWord;
          end
        end

        LP_REG_ENABLE: begin
          if (!iPwrite) begin
            oPrdata = EnWord;
          end
        end

        LP_REG_CLAIM: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = iClaimId;
          end
        end

        LP_REG_COMPLETE: begin
          if (!iPwrite) begin
            oPslverr = 1'b1;
          end
        end

        LP_REG_CTRL: begin
          if (!iPwrite) begin
            oPrdata = CtrlWord;
          end
        end

        LP_REG_THRESHOLD: begin
          if (!iPwrite) begin
            oPrdata = ThresholdWord;
          end
        end

        LP_REG_INFO: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = InfoWord;
          end
        end

        default: begin
          if (PriorityEntryAccess) begin
            if (!iPwrite) begin
              oPrdata = PriorityEntryWord;
            end
          end else if (VectorEntryAccess) begin
            if (!iPwrite) begin
              oPrdata = VectorEntryWord;
            end
          end else begin
            oPslverr = 1'b1;
          end
        end
      endcase
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      oEnVec         <= '0;
      oVectorEn      <= 1'b0;
      oPriorityEntryFlat <= '0;
      oThreshold         <= '0;
      oVectorEntryFlat   <= '0;
    end else begin
      oEnVec         <= EnVec_d;
      oVectorEn      <= VectorEn_d;
      oPriorityEntryFlat <= PriorityEntryFlat_d;
      oThreshold         <= Threshold_d;
      oVectorEntryFlat   <= VectorEntryFlat_d;
    end
  end

endmodule
