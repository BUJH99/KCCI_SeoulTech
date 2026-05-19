/*
[MODULE_INFO_START]
Name: SortDisplaySlaveTop
Role: Separate SLAVE FPGA top for the Bubble Sort display target
Summary:
  - Receives fixed 24-byte Bubble Sort trace frames from MASTER over SPI
  - Exposes v1 display/status/counter registers to MASTER over I2C
  - Drives the SLAVE FND from the I2C-selected pass/compare/swap/total/status value
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module Top #(
  parameter int unsigned P_CLK_HZ = 100_000_000
) (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic       iSpiSclk,
  input  logic       iSpiMosi,
  input  logic       iSpiCsN,
  input  logic       iI2cScl,
  inout  wire        ioI2cSda,

  output logic [6:0] oSeg,
  output logic       oDp,
  output logic [3:0] oDigitSel
);

  logic        I2cSdaIn;
  logic        I2cSdaOut;
  logic        I2cSdaOe;
  logic [7:0]  TraceByteData;
  logic        TraceByteValidPulse;
  logic        TraceFrameStartPulse;
  logic        TraceFrameEndPulse;
  logic        TraceShortFramePulse;
  logic        TraceFrameActive;
  logic        FrameValidPulse;
  logic        ChecksumErrorPulse;
  logic        FormatErrorPulse;
  logic        ShortFramePulse;
  logic [15:0] FrameId;
  logic [7:0]  FrameType;
  logic [7:0]  Phase;
  logic [7:0]  Flags;
  logic [7:0]  ArrayLen;
  logic [7:0]  PassIdx;
  logic [7:0]  CompareIdx;
  logic [7:0]  LeftIdx;
  logic [7:0]  RightIdx;
  logic [7:0]  LeftValue;
  logic [7:0]  RightValue;
  logic [7:0]  ChangedIdx;
  logic [15:0] CompareCount;
  logic [15:0] SwapCount;
  logic [15:0] TotalCount;
  logic [7:0]  StatusCode;
  logic [31:0] SlaveId;
  logic [7:0]  DisplayMode;
  logic [31:0] Status;
  logic [15:0] LastFrameId;
  logic [15:0] ErrorCode;
  logic [7:0]  Brightness;
  logic [15:0] PassCountReg;
  logic [15:0] CompareCountReg;
  logic [15:0] SwapCountReg;
  logic [15:0] TotalCountReg;
  logic [15:0] SelectedCount;
  logic        DisplayModeWriteEn;
  logic [7:0]  DisplayModeWriteData;
  logic        BrightnessWriteEn;
  logic [7:0]  BrightnessWriteData;
  logic [15:0] ErrorClearMask;
  logic        InvalidRegPulse;

  assign ioI2cSda = I2cSdaOe ? 1'b0 : 1'bz;
  assign I2cSdaIn = ioI2cSda;

  SpiTraceSlave #(
    .P_FRAME_BYTES (24)
  ) uSpiTraceSlave (
    .iClk             (iClk),
    .iRstn            (iRstn),
    .iSpiSclk         (iSpiSclk),
    .iSpiMosi         (iSpiMosi),
    .iSpiCsN          (iSpiCsN),
    .oByteData        (TraceByteData),
    .oByteValidPulse  (TraceByteValidPulse),
    .oFrameStartPulse (TraceFrameStartPulse),
    .oFrameEndPulse   (TraceFrameEndPulse),
    .oShortFramePulse (TraceShortFramePulse),
    .oFrameActive     (TraceFrameActive)
  );

  SortTraceFrameDecoder uSortTraceFrameDecoder (
    .iClk                (iClk),
    .iRstn               (iRstn),
    .iByteData           (TraceByteData),
    .iByteValidPulse     (TraceByteValidPulse),
    .iFrameStartPulse    (TraceFrameStartPulse),
    .iFrameEndPulse      (TraceFrameEndPulse),
    .iShortFramePulse    (TraceShortFramePulse),
    .oFrameValidPulse    (FrameValidPulse),
    .oChecksumErrorPulse (ChecksumErrorPulse),
    .oFormatErrorPulse   (FormatErrorPulse),
    .oShortFramePulse    (ShortFramePulse),
    .oFrameId            (FrameId),
    .oFrameType          (FrameType),
    .oPhase              (Phase),
    .oFlags              (Flags),
    .oArrayLen           (ArrayLen),
    .oPassIdx            (PassIdx),
    .oCompareIdx         (CompareIdx),
    .oLeftIdx            (LeftIdx),
    .oRightIdx           (RightIdx),
    .oLeftValue          (LeftValue),
    .oRightValue         (RightValue),
    .oChangedIdx         (ChangedIdx),
    .oCompareCount       (CompareCount),
    .oSwapCount          (SwapCount),
    .oTotalCount         (TotalCount),
    .oStatusCode         (StatusCode)
  );

  SortSlaveRegs uSortSlaveRegs (
    .iClk                  (iClk),
    .iRstn                 (iRstn),
    .iSpiActive            (TraceFrameActive),
    .iFrameValidPulse      (FrameValidPulse),
    .iChecksumErrorPulse   (ChecksumErrorPulse),
    .iFormatErrorPulse     (FormatErrorPulse),
    .iShortFramePulse      (ShortFramePulse),
    .iFrameId              (FrameId),
    .iPhase                (Phase),
    .iPassIdx              (PassIdx),
    .iCompareCount         (CompareCount),
    .iSwapCount            (SwapCount),
    .iTotalCount           (TotalCount),
    .iDisplayModeWriteEn   (DisplayModeWriteEn),
    .iDisplayModeWriteData (DisplayModeWriteData),
    .iBrightnessWriteEn    (BrightnessWriteEn),
    .iBrightnessWriteData  (BrightnessWriteData),
    .iErrorClearMask       (ErrorClearMask),
    .iInvalidRegPulse      (InvalidRegPulse),
    .oSlaveId              (SlaveId),
    .oDisplayMode          (DisplayMode),
    .oStatus               (Status),
    .oLastFrameId          (LastFrameId),
    .oErrorCode            (ErrorCode),
    .oBrightness           (Brightness),
    .oPassCount            (PassCountReg),
    .oCompareCount         (CompareCountReg),
    .oSwapCount            (SwapCountReg),
    .oTotalCount           (TotalCountReg),
    .oSelectedCount        (SelectedCount)
  );

  I2cSlaveRegTarget uI2cSlaveRegTarget (
    .iClk                  (iClk),
    .iRstn                 (iRstn),
    .iScl                  (iI2cScl),
    .iSdaIn                (I2cSdaIn),
    .iSlaveId              (SlaveId),
    .iDisplayMode          (DisplayMode),
    .iStatus               (Status),
    .iLastFrameId          (LastFrameId),
    .iErrorCode            (ErrorCode),
    .iBrightness           (Brightness),
    .iCompareCount         (CompareCountReg),
    .iSwapCount            (SwapCountReg),
    .iTotalCount           (TotalCountReg),
    .oSdaOut               (I2cSdaOut),
    .oSdaOe                (I2cSdaOe),
    .oDisplayModeWriteEn   (DisplayModeWriteEn),
    .oDisplayModeWriteData (DisplayModeWriteData),
    .oBrightnessWriteEn    (BrightnessWriteEn),
    .oBrightnessWriteData  (BrightnessWriteData),
    .oErrorClearMask       (ErrorClearMask),
    .oInvalidRegPulse      (InvalidRegPulse)
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
