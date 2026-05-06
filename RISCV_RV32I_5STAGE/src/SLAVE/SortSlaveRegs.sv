/*
[MODULE_INFO_START]
Name: SortSlaveRegs
Role: SLAVE display/status register bank for the Bubble Sort demo
Summary:
  - Stores I2C-visible display mode, status, last SPI frame ID, error code, and brightness
  - Updates pass/compare/swap/total counters from decoded SPI trace frames
  - Provides the selected counter value for the local SLAVE FND controller
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SortSlaveRegs (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic       iFrameValidPulse,
  input  logic       iChecksumErrorPulse,
  input  logic [7:0] iFrameId,
  input  logic [7:0] iPassIdx,
  input  logic [7:0] iCompareCount,
  input  logic [7:0] iSwapCount,
  input  logic [7:0] iTotalCount,
  input  logic       iDisplayModeWriteEn,
  input  logic [7:0] iDisplayModeWriteData,
  input  logic       iBrightnessWriteEn,
  input  logic [7:0] iBrightnessWriteData,
  input  logic [7:0] iErrorClearMask,

  output logic [7:0]  oSlaveId,
  output logic [1:0]  oDisplayMode,
  output logic [7:0]  oStatus,
  output logic [7:0]  oLastFrameId,
  output logic [7:0]  oErrorCode,
  output logic [7:0]  oBrightness,
  output logic [15:0] oSelectedCount
);

  logic [7:0] PassCount;
  logic [7:0] CompareCount;
  logic [7:0] SwapCount;
  logic [7:0] TotalCount;

  assign oSlaveId = 8'h5D;
  assign oStatus  = {5'd0, (oErrorCode != 8'd0), 1'b0, 1'b1};

  always_comb begin
    unique case (oDisplayMode)
      2'd0:    oSelectedCount = {8'd0, PassCount};
      2'd1:    oSelectedCount = {8'd0, CompareCount};
      2'd2:    oSelectedCount = {8'd0, SwapCount};
      default: oSelectedCount = {8'd0, TotalCount};
    endcase
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oDisplayMode <= 2'd0;
      oLastFrameId <= '0;
      oErrorCode   <= '0;
      oBrightness  <= 8'h0F;
      PassCount    <= '0;
      CompareCount <= '0;
      SwapCount    <= '0;
      TotalCount   <= '0;
    end else begin
      oErrorCode <= oErrorCode & ~iErrorClearMask;

      if (iChecksumErrorPulse) begin
        oErrorCode[0] <= 1'b1;
      end

      if (iFrameValidPulse) begin
        oLastFrameId <= iFrameId;
        PassCount    <= iPassIdx;
        CompareCount <= iCompareCount;
        SwapCount    <= iSwapCount;
        TotalCount   <= iTotalCount;
      end

      if (iDisplayModeWriteEn) begin
        oDisplayMode <= iDisplayModeWriteData[1:0];
      end

      if (iBrightnessWriteEn) begin
        oBrightness <= iBrightnessWriteData;
      end
    end
  end

endmodule
