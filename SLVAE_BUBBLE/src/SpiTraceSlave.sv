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
  input  logic       iRstn,
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

  logic sclkRise;
  logic csRise;
  logic csFall;
  logic mosiSync;
  logic [2:0] bitCnt;
  logic byteValidNow;

  SpiSlaveInputSync uSpiSlaveInputSync (
    .iClk          (iClk),
    .iRstn         (iRstn),
    .iSpiSclk      (iSpiSclk),
    .iSpiMosi      (iSpiMosi),
    .iSpiCsN       (iSpiCsN),
    .oSclkRise     (sclkRise),
    .oCsRise       (csRise),
    .oCsFall       (csFall),
    .oMosiSync     (mosiSync),
    .oFrameActive  (oFrameActive)
  );

  SpiSlaveByteCapture uSpiSlaveByteCapture (
    .iClk             (iClk),
    .iRstn            (iRstn),
    .iFrameStartPulse (csFall),
    .iFrameActive     (oFrameActive),
    .iSclkRise        (sclkRise),
    .iMosiSync        (mosiSync),
    .oByteData        (oByteData),
    .oByteValidPulse  (oByteValidPulse),
    .oByteValidNow    (byteValidNow),
    .oBitCnt          (bitCnt)
  );

  SpiSlaveFrameTracker #(
    .P_FRAME_BYTES (P_FRAME_BYTES)
  ) uSpiSlaveFrameTracker (
    .iClk              (iClk),
    .iRstn             (iRstn),
    .iCsRise           (csRise),
    .iCsFall           (csFall),
    .iByteValidPulse   (byteValidNow),
    .iBitCnt           (bitCnt),
    .oFrameStartPulse  (oFrameStartPulse),
    .oFrameEndPulse    (oFrameEndPulse),
    .oShortFramePulse  (oShortFramePulse)
  );

endmodule
