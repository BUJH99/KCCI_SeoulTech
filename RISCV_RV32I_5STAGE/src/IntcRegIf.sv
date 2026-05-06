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
  input  logic                         iRstn,
  input  logic                         iPsel,
  input  logic                         iPenable,
  input  logic                         iPwrite,
  input  logic [11:0]                  iPaddr,
  input  logic [3:0]                   iPstrb,
  input  logic [31:0]                  iPwdata,
  input  logic [P_NUM_SOURCES-1:0]     iPendingVec,
  input  logic [31:0]                  iClaimId,

  output logic [P_NUM_SOURCES-1:0]     oEnableVec,
  output logic                         oClaimReadEn,
  output logic                         oCompleteWriteEn,
  output logic [31:0]                  oCompleteId,
  output logic                         oVectorEnable,
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

  logic [P_NUM_SOURCES-1:0] EnableVec_d;
  logic                     VectorEnable_d;
  logic [((P_NUM_SOURCES + 1) * P_PRIORITY_WIDTH)-1:0] PriorityEntryFlat_d;
  logic [P_PRIORITY_WIDTH-1:0] Threshold_d;
  logic [(LP_NUM_VECTOR_ENTRIES*32)-1:0] VectorEntryFlat_d;
  logic [31:0]              PendingWord;
  logic [31:0]              EnableWord;
  logic [31:0]              CtrlWord;
  logic [31:0]              ThresholdWord;
  logic [31:0]              InfoWord;
  logic [31:0]              EnableWriteWord;
  logic [31:0]              CompleteWriteWord;
  logic [31:0]              CtrlWriteWord;
  logic [31:0]              ThresholdWriteWord;
  logic [31:0]              PriorityEntryWord;
  logic [31:0]              PriorityEntryWriteWord;
  logic [31:0]              VectorEntryWord;
  logic [31:0]              VectorEntryWriteWord;
  logic                     PriorityEntryAccess;
  logic                     VectorEntryAccess;
  logic [11:0]              EntryAddr;
  logic                     AccessEn;
  int unsigned              PriorityEntryIdx;
  int unsigned              VectorEntryIdx;
  int unsigned              EntryIdx;

  assign oPready                = 1'b1;
  assign AccessEn               = iPsel && iPenable && oPready;
  assign oClaimReadEn           = AccessEn && !iPwrite && (iPaddr == LP_REG_CLAIM);
  assign oCompleteWriteEn       = AccessEn && iPwrite && (iPaddr == LP_REG_COMPLETE);
  assign oCompleteId            = CompleteWriteWord;
  assign EnableWriteWord        = ByteWriteMerge(EnableWord, iPwdata, iPstrb);
  assign CompleteWriteWord      = ByteWriteMerge(32'd0, iPwdata, iPstrb);
  assign CtrlWriteWord          = ByteWriteMerge(CtrlWord, iPwdata, iPstrb);
  assign ThresholdWriteWord     = ByteWriteMerge(ThresholdWord, iPwdata, iPstrb);
  assign PriorityEntryWriteWord = ByteWriteMerge(PriorityEntryWord, iPwdata, iPstrb);
  assign VectorEntryWriteWord   = ByteWriteMerge(VectorEntryWord, iPwdata, iPstrb);

  always_comb begin
    PendingWord   = '0;
    EnableWord    = '0;
    CtrlWord      = '0;
    ThresholdWord = '0;
    InfoWord      = '0;

    PendingWord[P_NUM_SOURCES-1:0] = iPendingVec;
    EnableWord[P_NUM_SOURCES-1:0]  = oEnableVec;
    CtrlWord[0]                    = oVectorEnable;
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
    EnableVec_d         = oEnableVec;
    VectorEnable_d      = oVectorEnable;
    PriorityEntryFlat_d = oPriorityEntryFlat;
    Threshold_d         = oThreshold;
    VectorEntryFlat_d   = oVectorEntryFlat;

    if (AccessEn && iPwrite && (iPaddr == LP_REG_ENABLE)) begin
      EnableVec_d = EnableWriteWord[P_NUM_SOURCES-1:0];
    end

    if (AccessEn && iPwrite && (iPaddr == LP_REG_CTRL)) begin
      VectorEnable_d = CtrlWriteWord[0];
    end

    if (AccessEn && iPwrite && (iPaddr == LP_REG_THRESHOLD)) begin
      Threshold_d = ThresholdWriteWord[P_PRIORITY_WIDTH-1:0];
    end

    if (AccessEn && iPwrite && PriorityEntryAccess && (PriorityEntryIdx != 0)) begin
      PriorityEntryFlat_d[(PriorityEntryIdx * P_PRIORITY_WIDTH) +: P_PRIORITY_WIDTH] =
          PriorityEntryWriteWord[P_PRIORITY_WIDTH-1:0];
    end

    if (AccessEn && iPwrite && VectorEntryAccess && (VectorEntryIdx != 0)) begin
      VectorEntryFlat_d[(VectorEntryIdx * 32) +: 32] = {VectorEntryWriteWord[31:2], 2'b00};
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
            oPrdata = EnableWord;
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

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oEnableVec         <= '0;
      oVectorEnable      <= 1'b0;
      oPriorityEntryFlat <= '0;
      oThreshold         <= '0;
      oVectorEntryFlat   <= '0;
    end else begin
      oEnableVec         <= EnableVec_d;
      oVectorEnable      <= VectorEnable_d;
      oPriorityEntryFlat <= PriorityEntryFlat_d;
      oThreshold         <= Threshold_d;
      oVectorEntryFlat   <= VectorEntryFlat_d;
    end
  end

endmodule
