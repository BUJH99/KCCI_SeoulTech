/*
[MODULE_INFO_START]
Name: SpiTraceSlave
Role: Wrapper for the SLAVE SPI trace byte receiver
Summary:
  - Preserves the SortDisplaySlaveTop-facing SPI trace receiver contract
  - Wires input synchronization, frame tracking, and byte capture blocks
  - Keeps byte capture independent from trace frame validation and display register storage
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiTraceSlave #(
  parameter int unsigned P_FRAME_BYTES = 24
) (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iSpiSclk,
  input  logic       iSpiMosi,
  input  logic       iSpiCsN,

  output logic [7:0] oByteData,
  output logic       oByteValidPulse,
  output logic       oFrameStartPulse,
  output logic       oFrameEndPulse,
  output logic       oShortFramePulse,
  output logic       oFrameActive
);

  logic SclkRise;
  logic CsRise;
  logic CsFall;
  logic MosiSync;
  logic [2:0] BitCnt;
  logic ByteValidNow;

  SpiSlaveInputSync uSpiSlaveInputSync (
    .iClk          (iClk),
    .iRst         (iRst),
    .iSpiSclk      (iSpiSclk),
    .iSpiMosi      (iSpiMosi),
    .iSpiCsN       (iSpiCsN),
    .oSclkRise     (SclkRise),
    .oCsRise       (CsRise),
    .oCsFall       (CsFall),
    .oMosiSync     (MosiSync),
    .oFrameActive  (oFrameActive)
  );

  SpiSlaveByteCapture uSpiSlaveByteCapture (
    .iClk             (iClk),
    .iRst            (iRst),
    .iFrameStartPulse (CsFall),
    .iFrameActive     (oFrameActive),
    .iSclkRise        (SclkRise),
    .iMosiSync        (MosiSync),
    .oByteData        (oByteData),
    .oByteValidPulse  (oByteValidPulse),
    .oByteValidNow    (ByteValidNow),
    .oBitCnt          (BitCnt)
  );

  SpiSlaveFrameTracker #(
    .P_FRAME_BYTES (P_FRAME_BYTES)
  ) uSpiSlaveFrameTracker (
    .iClk              (iClk),
    .iRst             (iRst),
    .iCsRise           (CsRise),
    .iCsFall           (CsFall),
    .iByteValidPulse   (ByteValidNow),
    .iBitCnt           (BitCnt),
    .oFrameStartPulse  (oFrameStartPulse),
    .oFrameEndPulse    (oFrameEndPulse),
    .oShortFramePulse  (oShortFramePulse)
  );

endmodule
