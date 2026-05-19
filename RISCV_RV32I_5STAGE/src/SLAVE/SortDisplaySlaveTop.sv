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

module SortDisplaySlaveTop #(
  parameter int unsigned P_CLK_HZ = 100_000_000
) (
  input  logic       iClk,
  input  logic       iRst,
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
  logic        ChecksumErrPulse;
  logic        FormatErrPulse;
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
  logic [15:0] CompareCnt;
  logic [15:0] SwapCnt;
  logic [15:0] TotalCnt;
  logic [7:0]  StatusCode;
  logic [31:0] SlaveId;
  logic [7:0]  DisplayMode;
  logic [31:0] Status;
  logic [15:0] LastFrameId;
  logic [15:0] ErrCode;
  logic [7:0]  Brightness;
  logic [15:0] PassCntReg;
  logic [15:0] CompareCntReg;
  logic [15:0] SwapCntReg;
  logic [15:0] TotalCntReg;
  logic [15:0] SelCnt;
  logic        DisplayModeWrEn;
  logic [7:0]  DisplayModeWrData;
  logic        BrightnessWrEn;
  logic [7:0]  BrightnessWrData;
  logic [15:0] ErrClearMask;
  logic        InvalidRegPulse;

  assign ioI2cSda = I2cSdaOe ? 1'b0 : 1'bz;
  assign I2cSdaIn = ioI2cSda;

  SpiTraceSlave #(
    .P_FRAME_BYTES (24)
  ) uSpiTraceSlave (
    .iClk             (iClk),
    .iRst            (iRst),
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
    .iRst               (iRst),
    .iByteData           (TraceByteData),
    .iByteValidPulse     (TraceByteValidPulse),
    .iFrameStartPulse    (TraceFrameStartPulse),
    .iFrameEndPulse      (TraceFrameEndPulse),
    .iShortFramePulse    (TraceShortFramePulse),
    .oFrameValidPulse    (FrameValidPulse),
    .oChecksumErrPulse (ChecksumErrPulse),
    .oFormatErrPulse   (FormatErrPulse),
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
    .oCompareCnt       (CompareCnt),
    .oSwapCnt          (SwapCnt),
    .oTotalCnt         (TotalCnt),
    .oStatusCode         (StatusCode)
  );

  SortSlaveRegs uSortSlaveRegs (
    .iClk                  (iClk),
    .iRst                 (iRst),
    .iSpiActive            (TraceFrameActive),
    .iFrameValidPulse      (FrameValidPulse),
    .iChecksumErrPulse   (ChecksumErrPulse),
    .iFormatErrPulse     (FormatErrPulse),
    .iShortFramePulse      (ShortFramePulse),
    .iFrameId              (FrameId),
    .iPhase                (Phase),
    .iPassIdx              (PassIdx),
    .iCompareCnt         (CompareCnt),
    .iSwapCnt            (SwapCnt),
    .iTotalCnt           (TotalCnt),
    .iDisplayModeWrEn   (DisplayModeWrEn),
    .iDisplayModeWrData (DisplayModeWrData),
    .iBrightnessWrEn    (BrightnessWrEn),
    .iBrightnessWrData  (BrightnessWrData),
    .iErrClearMask       (ErrClearMask),
    .iInvalidRegPulse      (InvalidRegPulse),
    .oSlaveId              (SlaveId),
    .oDisplayMode          (DisplayMode),
    .oStatus               (Status),
    .oLastFrameId          (LastFrameId),
    .oErrCode            (ErrCode),
    .oBrightness           (Brightness),
    .oPassCnt            (PassCntReg),
    .oCompareCnt         (CompareCntReg),
    .oSwapCnt            (SwapCntReg),
    .oTotalCnt           (TotalCntReg),
    .oSelCnt        (SelCnt)
  );

  I2cSlaveRegTarget uI2cSlaveRegTarget (
    .iClk                  (iClk),
    .iRst                 (iRst),
    .iScl                  (iI2cScl),
    .iSdaIn                (I2cSdaIn),
    .iSlaveId              (SlaveId),
    .iDisplayMode          (DisplayMode),
    .iStatus               (Status),
    .iLastFrameId          (LastFrameId),
    .iErrCode            (ErrCode),
    .iBrightness           (Brightness),
    .iCompareCnt         (CompareCntReg),
    .iSwapCnt            (SwapCntReg),
    .iTotalCnt           (TotalCntReg),
    .oSdaOut               (I2cSdaOut),
    .oSdaOe                (I2cSdaOe),
    .oDisplayModeWrEn   (DisplayModeWrEn),
    .oDisplayModeWrData (DisplayModeWrData),
    .oBrightnessWrEn    (BrightnessWrEn),
    .oBrightnessWrData  (BrightnessWrData),
    .oErrClearMask       (ErrClearMask),
    .oInvalidRegPulse      (InvalidRegPulse)
  );

  SlaveFndController #(
    .P_CLK_HZ(P_CLK_HZ)
  ) uSlaveFndController (
    .iClk           (iClk),
    .iRst          (iRst),
    .iSelCnt (SelCnt),
    .iBrightness    (Brightness),
    .oSeg           (oSeg),
    .oDp            (oDp),
    .oDigitSel      (oDigitSel)
  );

endmodule
