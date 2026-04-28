/*
[MODULE_INFO_START]
Name: SpiSlaveSubsystem
Role: Complete SPI slave engine for the Serial Slave project
Summary:
  - Synchronizes incoming SPI signals, detects protocol edges, and decodes 16-bit Mode-0 register transactions
  - Returns register read data on MISO and emits completed write/read transactions to the manager layer
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiSlaveSubsystem (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iEnable,
  input  logic       iJaCs,
  input  logic       iJaMosi,
  input  logic       iJaSclk,
  input  logic [7:0] iTxnReadData,
  output logic       oJaMiso,
  output logic       oTxnValid,
  output logic       oTxnWrite,
  output logic [7:0] oTxnAddr,
  output logic [7:0] oTxnWdata
);

  logic SpiCsIn;
  logic SpiSclkIn;
  logic SpiMosiIn;
  logic wSpiSlaveInputSync2SpiSlaveEdgeDetect_CsSync;
  logic wSpiSlaveInputSync2SpiSlaveEdgeDetect_SclkSync;
  logic wSpiSlaveInputSync2SpiSlaveDatapath_MosiSync;
  logic wSpiSlaveEdgeDetect2SpiSlaveCtrl_CsRise;
  logic wSpiSlaveEdgeDetect2SpiSlaveCtrl_CsFall;
  logic wSpiSlaveEdgeDetect2SpiSlaveCtrl_SclkRise;
  logic wSpiSlaveEdgeDetect2SpiSlaveCtrl_SclkFall;
  logic wSpiSlaveCtrl2SpiSlaveDatapath_StartFrame;
  logic wSpiSlaveCtrl2SpiSlaveDatapath_SampleMosi;
  logic wSpiSlaveCtrl2SpiSlaveDatapath_ShiftMiso;
  logic wSpiSlaveDatapath2SpiSlaveCtrl_FrameDone;
  logic wSpiSlaveDatapath2SpiSlaveIo_MisoBit;

  assign SpiCsIn   = iEnable ? iJaCs   : 1'b1;
  assign SpiSclkIn = iEnable ? iJaSclk : 1'b0;
  assign SpiMosiIn = iEnable ? iJaMosi : 1'b0;

  SpiSlaveInputSync uSpiSlaveInputSync (
    .iClk    (iClk),
    .iRst    (iRst),
    .iCs     (SpiCsIn),
    .iSclk   (SpiSclkIn),
    .iMosi   (SpiMosiIn),
    .oCsSync (wSpiSlaveInputSync2SpiSlaveEdgeDetect_CsSync),
    .oSclkSync(wSpiSlaveInputSync2SpiSlaveEdgeDetect_SclkSync),
    .oMosiSync(wSpiSlaveInputSync2SpiSlaveDatapath_MosiSync)
  );

  SpiSlaveEdgeDetect uSpiSlaveEdgeDetect (
    .iClk     (iClk),
    .iRst     (iRst),
    .iCsSync  (wSpiSlaveInputSync2SpiSlaveEdgeDetect_CsSync),
    .iSclkSync(wSpiSlaveInputSync2SpiSlaveEdgeDetect_SclkSync),
    .oCsRise  (wSpiSlaveEdgeDetect2SpiSlaveCtrl_CsRise),
    .oCsFall  (wSpiSlaveEdgeDetect2SpiSlaveCtrl_CsFall),
    .oSclkRise(wSpiSlaveEdgeDetect2SpiSlaveCtrl_SclkRise),
    .oSclkFall(wSpiSlaveEdgeDetect2SpiSlaveCtrl_SclkFall)
  );

  SpiSlaveDatapath uSpiSlaveDatapath (
    .iClk      (iClk),
    .iRst      (iRst),
    .iStartFrame(wSpiSlaveCtrl2SpiSlaveDatapath_StartFrame),
    .iSampleMosi(wSpiSlaveCtrl2SpiSlaveDatapath_SampleMosi),
    .iShiftMiso(wSpiSlaveCtrl2SpiSlaveDatapath_ShiftMiso),
    .iMosiSync (wSpiSlaveInputSync2SpiSlaveDatapath_MosiSync),
    .iReadData (iTxnReadData),
    .oMisoBit  (wSpiSlaveDatapath2SpiSlaveIo_MisoBit),
    .oHeaderReady(),
    .oTxnWrite (oTxnWrite),
    .oTxnAddr  (oTxnAddr),
    .oTxnWdata (oTxnWdata),
    .oFrameDone(wSpiSlaveDatapath2SpiSlaveCtrl_FrameDone)
  );

  SpiSlaveCtrl uSpiSlaveCtrl (
    .iClk      (iClk),
    .iRst      (iRst),
    .iCsFall   (wSpiSlaveEdgeDetect2SpiSlaveCtrl_CsFall),
    .iCsRise   (wSpiSlaveEdgeDetect2SpiSlaveCtrl_CsRise),
    .iSclkRise (wSpiSlaveEdgeDetect2SpiSlaveCtrl_SclkRise),
    .iSclkFall (wSpiSlaveEdgeDetect2SpiSlaveCtrl_SclkFall),
    .iFrameDone(wSpiSlaveDatapath2SpiSlaveCtrl_FrameDone),
    .oStartFrame(wSpiSlaveCtrl2SpiSlaveDatapath_StartFrame),
    .oSampleMosi(wSpiSlaveCtrl2SpiSlaveDatapath_SampleMosi),
    .oShiftMiso(wSpiSlaveCtrl2SpiSlaveDatapath_ShiftMiso),
    .oTxnValid (oTxnValid),
    .oBusy     ()
  );

  SpiSlaveIo uSpiSlaveIo (
    .iEnable (iEnable),
    .iMisoBit(wSpiSlaveDatapath2SpiSlaveIo_MisoBit),
    .oJaMiso (oJaMiso)
  );

endmodule
