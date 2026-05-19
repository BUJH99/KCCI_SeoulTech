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
  input  logic        iRstn,
  input  logic        iSpiActive,
  input  logic        iFrameValidPulse,
  input  logic        iChecksumErrorPulse,
  input  logic        iFormatErrorPulse,
  input  logic        iShortFramePulse,
  input  logic [15:0] iFrameId,
  input  logic [7:0]  iPhase,
  input  logic [7:0]  iPassIdx,
  input  logic [15:0] iCompareCount,
  input  logic [15:0] iSwapCount,
  input  logic [15:0] iTotalCount,
  input  logic        iDisplayModeWriteEn,
  input  logic [7:0]  iDisplayModeWriteData,
  input  logic        iBrightnessWriteEn,
  input  logic [7:0]  iBrightnessWriteData,
  input  logic [15:0] iErrorClearMask,
  input  logic        iInvalidRegPulse,

  output logic [31:0] oSlaveId,
  output logic [7:0]  oDisplayMode,
  output logic [31:0] oStatus,
  output logic [15:0] oLastFrameId,
  output logic [15:0] oErrorCode,
  output logic [7:0]  oBrightness,
  output logic [15:0] oPassCount,
  output logic [15:0] oCompareCount,
  output logic [15:0] oSwapCount,
  output logic [15:0] oTotalCount,
  output logic [15:0] oSelectedCount
);

  localparam logic [7:0] LP_DISPLAY_PASS     = 8'd0;
  localparam logic [7:0] LP_DISPLAY_SWAP     = 8'd1;
  localparam logic [7:0] LP_DISPLAY_TOTAL    = 8'd2;

  logic [7:0] latestPhase;
  logic       frameValidSeen;

  assign oSlaveId = 32'h534C_5631;
  assign oStatus  = {24'd0, latestPhase[3:0], (oErrorCode != 16'd0), frameValidSeen, iSpiActive, 1'b1};

  always_comb begin
    unique case (oDisplayMode)
      LP_DISPLAY_PASS:     oSelectedCount = oPassCount;
      LP_DISPLAY_SWAP:     oSelectedCount = oSwapCount;
      LP_DISPLAY_TOTAL:    oSelectedCount = oTotalCount;
      default:             oSelectedCount = oTotalCount;
    endcase
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oDisplayMode  <= LP_DISPLAY_PASS;
      oLastFrameId  <= '0;
      oErrorCode    <= '0;
      oBrightness   <= 8'h0F;
      oPassCount    <= '0;
      oCompareCount <= '0;
      oSwapCount    <= '0;
      oTotalCount   <= '0;
      latestPhase   <= '0;
      frameValidSeen <= 1'b0;
    end else begin
      oErrorCode <= oErrorCode & ~iErrorClearMask;

      if (iChecksumErrorPulse) begin
        oErrorCode[0] <= 1'b1;
      end

      if (iFormatErrorPulse) begin
        oErrorCode[1] <= 1'b1;
      end

      if (iShortFramePulse) begin
        oErrorCode[2] <= 1'b1;
      end

      if (iInvalidRegPulse) begin
        oErrorCode[3] <= 1'b1;
      end

      if (iFrameValidPulse) begin
        oLastFrameId   <= iFrameId;
        oPassCount     <= {8'd0, iPassIdx};
        oCompareCount  <= iCompareCount;
        oSwapCount     <= iSwapCount;
        oTotalCount    <= iTotalCount;
        latestPhase    <= iPhase;
        frameValidSeen <= 1'b1;
      end

      if (iDisplayModeWriteEn) begin
        if (iDisplayModeWriteData <= LP_DISPLAY_TOTAL) begin
          oDisplayMode <= iDisplayModeWriteData;
        end else begin
          oErrorCode[4] <= 1'b1;
        end
      end

      if (iBrightnessWriteEn) begin
        oBrightness <= iBrightnessWriteData;
      end
    end
  end

endmodule
