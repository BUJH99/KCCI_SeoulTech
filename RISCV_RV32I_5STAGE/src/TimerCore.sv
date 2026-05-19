/*
[MODULE_INFO_START]
Name: TimerCore
Role: Timer datapath and event pulse generator
Summary:
  - Owns the prescaler, periodic interval counter, and running timer count
  - Applies APB count writes and clear-count requests before advancing timer state
  - Emits one-cycle match and overflow event pulses for the APB register block
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TimerCore (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iEn,
  input  logic        iPeriodic,
  input  logic        iClearCntPulse,
  input  logic        iCntWrPulse,
  input  logic [31:0] iCntWrData,
  input  logic [31:0] iPrescale,
  input  logic [31:0] iPeriod,
  input  logic [31:0] iCompare,

  output logic [31:0] oCnt,
  output logic        oMatchPulse,
  output logic        oOverflowPulse
);

  logic [31:0] Cnt_d;
  logic [31:0] PrescaleCnt;
  logic [31:0] PrescaleCnt_d;
  logic [31:0] PeriodCnt;
  logic [31:0] PeriodCnt_d;
  logic        TimerTick;

  always_comb begin
    Cnt_d         = oCnt;
    PrescaleCnt_d = PrescaleCnt;
    PeriodCnt_d   = PeriodCnt;
    TimerTick       = 1'b0;
    oMatchPulse     = 1'b0;
    oOverflowPulse  = 1'b0;

    if (iCntWrPulse) begin
      Cnt_d = iCntWrData;
    end

    if (iClearCntPulse) begin
      Cnt_d         = '0;
      PeriodCnt_d   = '0;
      PrescaleCnt_d = '0;
    end

    if (iEn) begin
      if (PrescaleCnt_d >= iPrescale) begin
        PrescaleCnt_d = '0;
        TimerTick       = 1'b1;
      end else begin
        PrescaleCnt_d = PrescaleCnt_d + 32'd1;
      end
    end else begin
      PrescaleCnt_d = '0;
    end

    if (TimerTick) begin
      Cnt_d = Cnt_d + 32'd1;

      if (Cnt_d == 32'd0) begin
        oOverflowPulse = 1'b1;
      end

      if (iPeriodic) begin
        if (PeriodCnt_d >= iPeriod) begin
          PeriodCnt_d = '0;
          oMatchPulse   = 1'b1;
        end else begin
          PeriodCnt_d = PeriodCnt_d + 32'd1;
        end
      end else begin
        PeriodCnt_d = '0;
        if (Cnt_d == iCompare) begin
          oMatchPulse = 1'b1;
        end
      end
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      oCnt        <= '0;
      PrescaleCnt <= '0;
      PeriodCnt   <= '0;
    end else begin
      oCnt        <= Cnt_d;
      PrescaleCnt <= PrescaleCnt_d;
      PeriodCnt   <= PeriodCnt_d;
    end
  end

endmodule
