/*
[MODULE_INFO_START]
Name: SortSlaveRegs
Role: SLAVE display/status register bank for the Bubble Sort demo
Summary:
  - Stores the I2C-visible v1 SLAVE_ID, display mode, status, frame, error, and brightness registers
  - Updates 16-bit pass/compare/swap/total counters from valid SPI trace frames
  - Provides pass, swap, or total count for the local SLAVE FND controller
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SortSlaveRegs (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iSpiActive,
  input  logic        iFrameValidPulse,
  input  logic        iChecksumErrPulse,
  input  logic        iFormatErrPulse,
  input  logic        iShortFramePulse,
  input  logic [15:0] iFrameId,
  input  logic [7:0]  iPhase,
  input  logic [7:0]  iPassIdx,
  input  logic [15:0] iCompareCnt,
  input  logic [15:0] iSwapCnt,
  input  logic [15:0] iTotalCnt,
  input  logic        iDisplayModeWrEn,
  input  logic [7:0]  iDisplayModeWrData,
  input  logic        iBrightnessWrEn,
  input  logic [7:0]  iBrightnessWrData,
  input  logic [15:0] iErrClearMask,
  input  logic        iInvalidRegPulse,

  output logic [31:0] oSlaveId,
  output logic [7:0]  oDisplayMode,
  output logic [31:0] oStatus,
  output logic [15:0] oLastFrameId,
  output logic [15:0] oErrCode,
  output logic [7:0]  oBrightness,
  output logic [15:0] oPassCnt,
  output logic [15:0] oCompareCnt,
  output logic [15:0] oSwapCnt,
  output logic [15:0] oTotalCnt,
  output logic [15:0] oSelCnt
);

  localparam logic [7:0] LP_DISPLAY_PASS     = 8'd0;
  localparam logic [7:0] LP_DISPLAY_COMPARE  = 8'd1;
  localparam logic [7:0] LP_DISPLAY_SWAP     = 8'd2;
  localparam logic [7:0] LP_DISPLAY_TOTAL    = 8'd3;
  localparam logic [7:0] LP_DISPLAY_FRAME_ID = 8'd4;
  localparam logic [7:0] LP_DISPLAY_STATUS   = 8'd5;

  logic [7:0] LatestPhase;
  logic       FrameValidSeen;
  logic [15:0] StatusDisplayWord;

  assign oSlaveId = 32'h534C_5631;
  assign oStatus  = {24'd0, LatestPhase[3:0], (oErrCode != 16'd0), FrameValidSeen, iSpiActive, 1'b1};
  assign StatusDisplayWord = (oErrCode != 16'd0) ? oErrCode : oStatus[15:0];

  always_comb begin
    unique case (oDisplayMode)
      LP_DISPLAY_PASS:     oSelCnt = oPassCnt;
      LP_DISPLAY_COMPARE:  oSelCnt = oCompareCnt;
      LP_DISPLAY_SWAP:     oSelCnt = oSwapCnt;
      LP_DISPLAY_TOTAL:    oSelCnt = oTotalCnt;
      LP_DISPLAY_FRAME_ID: oSelCnt = oLastFrameId;
      LP_DISPLAY_STATUS:   oSelCnt = StatusDisplayWord;
      default:             oSelCnt = oTotalCnt;
    endcase
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      oDisplayMode  <= LP_DISPLAY_PASS;
      oLastFrameId  <= '0;
      oErrCode    <= '0;
      oBrightness   <= 8'h0F;
      oPassCnt    <= '0;
      oCompareCnt <= '0;
      oSwapCnt    <= '0;
      oTotalCnt   <= '0;
      LatestPhase   <= '0;
      FrameValidSeen <= 1'b0;
    end else begin
      oErrCode <= oErrCode & ~iErrClearMask;

      if (iChecksumErrPulse) begin
        oErrCode[0] <= 1'b1;
      end

      if (iFormatErrPulse) begin
        oErrCode[1] <= 1'b1;
      end

      if (iShortFramePulse) begin
        oErrCode[2] <= 1'b1;
      end

      if (iInvalidRegPulse) begin
        oErrCode[3] <= 1'b1;
      end

      if (iFrameValidPulse) begin
        oLastFrameId   <= iFrameId;
        oPassCnt     <= {8'd0, iPassIdx};
        oCompareCnt  <= iCompareCnt;
        oSwapCnt     <= iSwapCnt;
        oTotalCnt    <= iTotalCnt;
        LatestPhase    <= iPhase;
        FrameValidSeen <= 1'b1;
      end

      if (iDisplayModeWrEn) begin
        if (iDisplayModeWrData <= LP_DISPLAY_STATUS) begin
          oDisplayMode <= iDisplayModeWrData;
        end else begin
          oErrCode[4] <= 1'b1;
        end
      end

      if (iBrightnessWrEn) begin
        oBrightness <= iBrightnessWrData;
      end
    end
  end

endmodule
