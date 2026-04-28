/*
[MODULE_INFO_START]
Name: SpiMasterSubsystem
Role: Complete SPI master transaction engine for the Master project
Summary:
  - Integrates the SPI divider, input synchronizer, datapath, controller, and pin adapter
  - Exposes an abstract register transaction interface to the top-level sequencer
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiMasterSubsystem #(
  parameter int unsigned P_DIV = 100
) (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iTxnStart,
  input  logic       iTxnRw,
  input  logic [7:0] iTxnRegAddr,
  input  logic [7:0] iTxnWrData,
  input  logic       iJaMiso,
  output logic       oTxnBusy,
  output logic       oTxnDone,
  output logic [7:0] oTxnRdData,
  output logic       oJaCs,
  output logic       oJaMosi,
  output logic       oJaSclk
);

  logic wSpiClockDivider2SpiMasterCtrl_Tick;
  logic wSpiMasterInputSync2SpiMasterDatapath_MisoSync;
  logic wSpiMasterCtrl2SpiMasterClockDivider_DivEnable;
  logic wSpiMasterCtrl2SpiMasterDatapath_LoadFrame;
  logic wSpiMasterCtrl2SpiMasterDatapath_SampleRx;
  logic wSpiMasterCtrl2SpiMasterDatapath_ShiftTx;
  logic wSpiMasterCtrl2SpiMasterDatapath_CaptureFrame;
  logic wSpiMasterDatapath2SpiMasterCtrl_BitsDone;
  logic wSpiMasterDatapath2SpiMasterIo_MosiBit;
  logic wSpiMasterCtrl2SpiMasterIo_CsActive;
  logic wSpiMasterCtrl2SpiMasterIo_SclkLevel;

  SpiMasterClockDivider #(
    .P_DIV(P_DIV)
  ) uSpiMasterClockDivider (
    .iClk   (iClk),
    .iRst   (iRst),
    .iEnable(wSpiMasterCtrl2SpiMasterClockDivider_DivEnable),
    .oTick  (wSpiClockDivider2SpiMasterCtrl_Tick)
  );

  SpiMasterInputSync uSpiMasterInputSync (
    .iClk    (iClk),
    .iRst    (iRst),
    .iMiso   (iJaMiso),
    .oMisoSync(wSpiMasterInputSync2SpiMasterDatapath_MisoSync)
  );

  SpiMasterDatapath uSpiMasterDatapath (
    .iClk        (iClk),
    .iRst        (iRst),
    .iLoadFrame  (wSpiMasterCtrl2SpiMasterDatapath_LoadFrame),
    .iSampleRx   (wSpiMasterCtrl2SpiMasterDatapath_SampleRx),
    .iShiftTx    (wSpiMasterCtrl2SpiMasterDatapath_ShiftTx),
    .iCaptureFrame(wSpiMasterCtrl2SpiMasterDatapath_CaptureFrame),
    .iMisoSync   (wSpiMasterInputSync2SpiMasterDatapath_MisoSync),
    .iTxnRw      (iTxnRw),
    .iTxnRegAddr (iTxnRegAddr),
    .iTxnWrData  (iTxnWrData),
    .oMosiBit    (wSpiMasterDatapath2SpiMasterIo_MosiBit),
    .oBitsDone   (wSpiMasterDatapath2SpiMasterCtrl_BitsDone),
    .oRxData     (oTxnRdData)
  );

  SpiMasterCtrl uSpiMasterCtrl (
    .iClk        (iClk),
    .iRst        (iRst),
    .iTxnStart   (iTxnStart),
    .iTick       (wSpiClockDivider2SpiMasterCtrl_Tick),
    .iBitsDone   (wSpiMasterDatapath2SpiMasterCtrl_BitsDone),
    .oDivEnable  (wSpiMasterCtrl2SpiMasterClockDivider_DivEnable),
    .oCsActive   (wSpiMasterCtrl2SpiMasterIo_CsActive),
    .oSclkLevel  (wSpiMasterCtrl2SpiMasterIo_SclkLevel),
    .oLoadFrame  (wSpiMasterCtrl2SpiMasterDatapath_LoadFrame),
    .oSampleRx   (wSpiMasterCtrl2SpiMasterDatapath_SampleRx),
    .oShiftTx    (wSpiMasterCtrl2SpiMasterDatapath_ShiftTx),
    .oCaptureFrame(wSpiMasterCtrl2SpiMasterDatapath_CaptureFrame),
    .oBusy       (oTxnBusy),
    .oDone       (oTxnDone)
  );

  SpiMasterIo uSpiMasterIo (
    .iCsActive (wSpiMasterCtrl2SpiMasterIo_CsActive),
    .iSclkLevel(wSpiMasterCtrl2SpiMasterIo_SclkLevel),
    .iMosiBit  (wSpiMasterDatapath2SpiMasterIo_MosiBit),
    .oJaCs     (oJaCs),
    .oJaMosi   (oJaMosi),
    .oJaSclk   (oJaSclk)
  );

endmodule
