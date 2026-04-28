/*
[MODULE_INFO_START]
Name: I2cSlaveSubsystem
Role: Complete I2C slave engine for the Serial Slave project
Summary:
  - Synchronizes bus inputs, detects START/STOP conditions, and decodes single-byte register accesses with repeated-start reads
  - Drives ACK/readback timing via an open-drain SDA low-enable output and emits completed write transactions to the manager layer
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveSubsystem (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iEnable,
  input  logic       iJbScl,
  input  logic       iSdaIn,
  input  logic [7:0] iTxnReadData,
  output logic       oSdaDriveLow,
  output logic       oTxnValid,
  output logic       oTxnWrite,
  output logic [7:0] oTxnAddr,
  output logic [7:0] oTxnWdata
);

  logic I2cSclIn;
  logic I2cSdaIn;
  logic wI2cSlaveInputSync2I2cSlaveEdgeDetect_SclSync;
  logic wI2cSlaveInputSync2I2cSlaveEdgeDetect_SdaSync;
  logic wI2cSlaveEdgeDetect2I2cSlaveCtrl_SclRise;
  logic wI2cSlaveEdgeDetect2I2cSlaveCtrl_SclFall;
  logic wI2cSlaveEdgeDetect2I2cSlaveCtrl_StartPulse;
  logic wI2cSlaveEdgeDetect2I2cSlaveCtrl_StopPulse;
  logic wI2cSlaveCtrl2I2cSlaveDatapath_StartFrame;
  logic wI2cSlaveCtrl2I2cSlaveDatapath_LoadTxByte;
  logic [7:0] wI2cSlaveCtrl2I2cSlaveDatapath_TxByte;
  logic wI2cSlaveCtrl2I2cSlaveDatapath_ClearBitCnt;
  logic wI2cSlaveCtrl2I2cSlaveDatapath_SampleRxBit;
  logic wI2cSlaveCtrl2I2cSlaveDatapath_AdvanceTxBit;
  logic wI2cSlaveCtrl2I2cSlaveIo_SdaDriveLow;
  logic [7:0] wI2cSlaveDatapath2I2cSlaveCtrl_RxByte;
  logic wI2cSlaveDatapath2I2cSlaveCtrl_TxBit;
  logic wI2cSlaveDatapath2I2cSlaveCtrl_LastBit;

  assign I2cSclIn = iEnable ? iJbScl : 1'b1;
  assign I2cSdaIn = iEnable ? iSdaIn : 1'b1;

  I2cSlaveInputSync uI2cSlaveInputSync (
    .iClk    (iClk),
    .iRst    (iRst),
    .iScl    (I2cSclIn),
    .iSda    (I2cSdaIn),
    .oSclSync(wI2cSlaveInputSync2I2cSlaveEdgeDetect_SclSync),
    .oSdaSync(wI2cSlaveInputSync2I2cSlaveEdgeDetect_SdaSync)
  );

  I2cSlaveEdgeDetect uI2cSlaveEdgeDetect (
    .iClk      (iClk),
    .iRst      (iRst),
    .iSclSync  (wI2cSlaveInputSync2I2cSlaveEdgeDetect_SclSync),
    .iSdaSync  (wI2cSlaveInputSync2I2cSlaveEdgeDetect_SdaSync),
    .oSclRise  (wI2cSlaveEdgeDetect2I2cSlaveCtrl_SclRise),
    .oSclFall  (wI2cSlaveEdgeDetect2I2cSlaveCtrl_SclFall),
    .oStartPulse(wI2cSlaveEdgeDetect2I2cSlaveCtrl_StartPulse),
    .oStopPulse(wI2cSlaveEdgeDetect2I2cSlaveCtrl_StopPulse)
  );

  I2cSlaveDatapath uI2cSlaveDatapath (
    .iClk      (iClk),
    .iRst      (iRst),
    .iStartFrame(wI2cSlaveCtrl2I2cSlaveDatapath_StartFrame),
    .iLoadTxByte(wI2cSlaveCtrl2I2cSlaveDatapath_LoadTxByte),
    .iTxByte   (wI2cSlaveCtrl2I2cSlaveDatapath_TxByte),
    .iClearBitCnt(wI2cSlaveCtrl2I2cSlaveDatapath_ClearBitCnt),
    .iSampleRxBit(wI2cSlaveCtrl2I2cSlaveDatapath_SampleRxBit),
    .iAdvanceTxBit(wI2cSlaveCtrl2I2cSlaveDatapath_AdvanceTxBit),
    .iSdaSync  (wI2cSlaveInputSync2I2cSlaveEdgeDetect_SdaSync),
    .oRxByte   (wI2cSlaveDatapath2I2cSlaveCtrl_RxByte),
    .oTxBit    (wI2cSlaveDatapath2I2cSlaveCtrl_TxBit),
    .oLastBit  (wI2cSlaveDatapath2I2cSlaveCtrl_LastBit)
  );

  I2cSlaveCtrl uI2cSlaveCtrl (
    .iClk      (iClk),
    .iRst      (iRst),
    .iStartPulse(wI2cSlaveEdgeDetect2I2cSlaveCtrl_StartPulse),
    .iStopPulse(wI2cSlaveEdgeDetect2I2cSlaveCtrl_StopPulse),
    .iSclRise  (wI2cSlaveEdgeDetect2I2cSlaveCtrl_SclRise),
    .iSclFall  (wI2cSlaveEdgeDetect2I2cSlaveCtrl_SclFall),
    .iRxByte   (wI2cSlaveDatapath2I2cSlaveCtrl_RxByte),
    .iTxBit    (wI2cSlaveDatapath2I2cSlaveCtrl_TxBit),
    .iLastBit  (wI2cSlaveDatapath2I2cSlaveCtrl_LastBit),
    .iTxnReadData(iTxnReadData),
    .oStartFrame(wI2cSlaveCtrl2I2cSlaveDatapath_StartFrame),
    .oLoadTxByte(wI2cSlaveCtrl2I2cSlaveDatapath_LoadTxByte),
    .oTxByte   (wI2cSlaveCtrl2I2cSlaveDatapath_TxByte),
    .oClearBitCnt(wI2cSlaveCtrl2I2cSlaveDatapath_ClearBitCnt),
    .oSampleRxBit(wI2cSlaveCtrl2I2cSlaveDatapath_SampleRxBit),
    .oAdvanceTxBit(wI2cSlaveCtrl2I2cSlaveDatapath_AdvanceTxBit),
    .oSdaDriveLow(wI2cSlaveCtrl2I2cSlaveIo_SdaDriveLow),
    .oTxnValid (oTxnValid),
    .oTxnWrite (oTxnWrite),
    .oTxnAddr  (oTxnAddr),
    .oTxnWdata (oTxnWdata)
  );

  I2cSlaveIo uI2cSlaveIo (
    .iEnable     (iEnable),
    .iSdaDriveLow(wI2cSlaveCtrl2I2cSlaveIo_SdaDriveLow),
    .oSdaDriveLow(oSdaDriveLow)
  );

endmodule
