/*
[MODULE_INFO_START]
Name: SortDisplaySlaveTop
Role: Separate SLAVE FPGA top for the Bubble Sort display target
Summary:
  - Receives Bubble Sort trace frames from MASTER over SPI
  - Exposes display mode, status, last frame, error, and brightness registers over I2C
  - Drives the SLAVE FND from the selected pass/compare/swap/total counter
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SortDisplaySlaveTop #(
  parameter int unsigned P_CLK_HZ = 100_000_000
) (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic       iSpiSclk,
  input  logic       iSpiMosi,
  input  logic       iSpiCsN,
  input  logic       iI2cScl,
  input  logic       iI2cSdaIn,

  output logic       oI2cSdaOut,
  output logic       oI2cSdaOe,
  output logic [6:0] oSeg,
  output logic       oDp,
  output logic [3:0] oDigitSel
);

  logic [7:0]  TraceByteData;
  logic        TraceByteValidPulse;
  logic        FrameValidPulse;
  logic        ChecksumErrorPulse;
  logic [7:0]  FrameId;
  logic [2:0]  Phase;
  logic [7:0]  PassIdx;
  logic [7:0]  CompareIdx;
  logic [7:0]  LeftValue;
  logic [7:0]  RightValue;
  logic        SwapFlag;
  logic [7:0]  ChangedIndex;
  logic [7:0]  CompareCount;
  logic [7:0]  SwapCount;
  logic [7:0]  TotalCount;
  logic [7:0]  SlaveId;
  logic [1:0]  DisplayMode;
  logic [7:0]  Status;
  logic [7:0]  LastFrameId;
  logic [7:0]  ErrorCode;
  logic [7:0]  Brightness;
  logic [15:0] SelectedCount;
  logic        DisplayModeWriteEn;
  logic [7:0]  DisplayModeWriteData;
  logic        BrightnessWriteEn;
  logic [7:0]  BrightnessWriteData;
  logic [7:0]  ErrorClearMask;

  SpiTraceSlave uSpiTraceSlave (
    .iClk             (iClk),
    .iRstn            (iRstn),
    .iSpiSclk         (iSpiSclk),
    .iSpiMosi         (iSpiMosi),
    .iSpiCsN          (iSpiCsN),
    .oByteData        (TraceByteData),
    .oByteValidPulse  (TraceByteValidPulse)
  );

  SortTraceFrameDecoder uSortTraceFrameDecoder (
    .iClk                (iClk),
    .iRstn               (iRstn),
    .iByteData           (TraceByteData),
    .iByteValidPulse     (TraceByteValidPulse),
    .oFrameValidPulse    (FrameValidPulse),
    .oChecksumErrorPulse (ChecksumErrorPulse),
    .oFrameId            (FrameId),
    .oPhase              (Phase),
    .oPassIdx            (PassIdx),
    .oCompareIdx         (CompareIdx),
    .oLeftValue          (LeftValue),
    .oRightValue         (RightValue),
    .oSwapFlag           (SwapFlag),
    .oChangedIndex       (ChangedIndex),
    .oCompareCount       (CompareCount),
    .oSwapCount          (SwapCount),
    .oTotalCount         (TotalCount)
  );

  SortSlaveRegs uSortSlaveRegs (
    .iClk                  (iClk),
    .iRstn                 (iRstn),
    .iFrameValidPulse      (FrameValidPulse),
    .iChecksumErrorPulse   (ChecksumErrorPulse),
    .iFrameId              (FrameId),
    .iPassIdx              (PassIdx),
    .iCompareCount         (CompareCount),
    .iSwapCount            (SwapCount),
    .iTotalCount           (TotalCount),
    .iDisplayModeWriteEn   (DisplayModeWriteEn),
    .iDisplayModeWriteData (DisplayModeWriteData),
    .iBrightnessWriteEn    (BrightnessWriteEn),
    .iBrightnessWriteData  (BrightnessWriteData),
    .iErrorClearMask       (ErrorClearMask),
    .oSlaveId              (SlaveId),
    .oDisplayMode          (DisplayMode),
    .oStatus               (Status),
    .oLastFrameId          (LastFrameId),
    .oErrorCode            (ErrorCode),
    .oBrightness           (Brightness),
    .oSelectedCount        (SelectedCount)
  );

  I2cSlaveRegTarget uI2cSlaveRegTarget (
    .iClk                  (iClk),
    .iRstn                 (iRstn),
    .iScl                  (iI2cScl),
    .iSdaIn                (iI2cSdaIn),
    .iSlaveId              (SlaveId),
    .iDisplayMode          (DisplayMode),
    .iStatus               (Status),
    .iLastFrameId          (LastFrameId),
    .iErrorCode            (ErrorCode),
    .iBrightness           (Brightness),
    .oSdaOut               (oI2cSdaOut),
    .oSdaOe                (oI2cSdaOe),
    .oDisplayModeWriteEn   (DisplayModeWriteEn),
    .oDisplayModeWriteData (DisplayModeWriteData),
    .oBrightnessWriteEn    (BrightnessWriteEn),
    .oBrightnessWriteData  (BrightnessWriteData),
    .oErrorClearMask       (ErrorClearMask)
  );

  SlaveFndController #(
    .P_CLK_HZ(P_CLK_HZ)
  ) uSlaveFndController (
    .iClk           (iClk),
    .iRstn          (iRstn),
    .iSelectedCount (SelectedCount),
    .iBrightness    (Brightness),
    .oSeg           (oSeg),
    .oDp            (oDp),
    .oDigitSel      (oDigitSel)
  );

endmodule
