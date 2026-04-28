/*
[MODULE_INFO_START]
Name: I2cMasterSubsystem
Role: Complete I2C master transaction engine for the Master project
Summary:
  - Integrates divider, synchronizer, datapath, control FSM, and board-facing IO adapter
  - Presents a single-byte register transaction interface to the top-level sequencer
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterSubsystem #(
  parameter int unsigned P_DIV = 1000
) (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iTxnStart,
  input  logic       iTxnRw,
  input  logic [7:0] iTxnRegAddr,
  input  logic [7:0] iTxnWrData,
  input  logic       iSclIn,
  input  logic       iSdaIn,
  output logic       oTxnBusy,
  output logic       oTxnDone,
  output logic [7:0] oTxnRdData,
  output logic       oSclDriveLow,
  output logic       oSdaDriveLow
);

  logic wI2cMasterClockDivider2I2cMasterCtrl_Tick;
  logic wI2cMasterInputSync2I2cMasterCtrl_SclSync;
  logic wI2cMasterInputSync2I2cMasterDatapath_SdaSync;
  logic wI2cMasterCtrl2I2cMasterClockDivider_DivEnable;
  logic wI2cMasterCtrl2I2cMasterDatapath_LoadTxByte;
  logic [7:0] wI2cMasterCtrl2I2cMasterDatapath_TxByte;
  logic wI2cMasterCtrl2I2cMasterDatapath_ClearBitCnt;
  logic wI2cMasterCtrl2I2cMasterDatapath_TxAdvance;
  logic wI2cMasterCtrl2I2cMasterDatapath_RxSample;
  logic wI2cMasterCtrl2I2cMasterDatapath_CaptureAck;
  logic wI2cMasterDatapath2I2cMasterCtrl_TxBit;
  logic wI2cMasterDatapath2I2cMasterCtrl_LastBit;
  logic wI2cMasterDatapath2I2cMasterCtrl_AckBit;
  logic wI2cMasterCtrl2I2cMasterIo_SclLevel;
  logic wI2cMasterCtrl2I2cMasterIo_SclDriveLow;
  logic wI2cMasterCtrl2I2cMasterIo_SdaDriveLow;

  I2cMasterClockDivider #(
    .P_DIV(P_DIV)
  ) uI2cMasterClockDivider (
    .iClk   (iClk),
    .iRst   (iRst),
    .iEnable(wI2cMasterCtrl2I2cMasterClockDivider_DivEnable),
    .oTick  (wI2cMasterClockDivider2I2cMasterCtrl_Tick)
  );

  I2cMasterInputSync uI2cMasterInputSync (
    .iClk   (iClk),
    .iRst   (iRst),
    .iScl   (iSclIn),
    .iSda   (iSdaIn),
    .oSclSync(wI2cMasterInputSync2I2cMasterCtrl_SclSync),
    .oSdaSync(wI2cMasterInputSync2I2cMasterDatapath_SdaSync)
  );

  I2cMasterDatapath uI2cMasterDatapath (
    .iClk       (iClk),
    .iRst       (iRst),
    .iLoadTxByte(wI2cMasterCtrl2I2cMasterDatapath_LoadTxByte),
    .iTxByte    (wI2cMasterCtrl2I2cMasterDatapath_TxByte),
    .iClearBitCnt(wI2cMasterCtrl2I2cMasterDatapath_ClearBitCnt),
    .iTxAdvance (wI2cMasterCtrl2I2cMasterDatapath_TxAdvance),
    .iRxSample  (wI2cMasterCtrl2I2cMasterDatapath_RxSample),
    .iCaptureAck(wI2cMasterCtrl2I2cMasterDatapath_CaptureAck),
    .iSdaSync   (wI2cMasterInputSync2I2cMasterDatapath_SdaSync),
    .oTxBit     (wI2cMasterDatapath2I2cMasterCtrl_TxBit),
    .oLastBit   (wI2cMasterDatapath2I2cMasterCtrl_LastBit),
    .oAckBit    (wI2cMasterDatapath2I2cMasterCtrl_AckBit),
    .oRxByte    (oTxnRdData)
  );

  I2cMasterCtrl uI2cMasterCtrl (
    .iClk       (iClk),
    .iRst       (iRst),
    .iTxnStart  (iTxnStart),
    .iTxnRw     (iTxnRw),
    .iTxnRegAddr(iTxnRegAddr),
    .iTxnWrData (iTxnWrData),
    .iTick      (wI2cMasterClockDivider2I2cMasterCtrl_Tick),
    .iSclSync   (wI2cMasterInputSync2I2cMasterCtrl_SclSync),
    .iSdaSync   (wI2cMasterInputSync2I2cMasterDatapath_SdaSync),
    .iTxBit     (wI2cMasterDatapath2I2cMasterCtrl_TxBit),
    .iLastBit   (wI2cMasterDatapath2I2cMasterCtrl_LastBit),
    .iAckBit    (wI2cMasterDatapath2I2cMasterCtrl_AckBit),
    .oDivEnable (wI2cMasterCtrl2I2cMasterClockDivider_DivEnable),
    .oBusy      (oTxnBusy),
    .oDone      (oTxnDone),
    .oSclLevel  (wI2cMasterCtrl2I2cMasterIo_SclLevel),
    .oSdaDriveLow(wI2cMasterCtrl2I2cMasterIo_SdaDriveLow),
    .oLoadTxByte(wI2cMasterCtrl2I2cMasterDatapath_LoadTxByte),
    .oTxByte    (wI2cMasterCtrl2I2cMasterDatapath_TxByte),
    .oClearBitCnt(wI2cMasterCtrl2I2cMasterDatapath_ClearBitCnt),
    .oTxAdvance (wI2cMasterCtrl2I2cMasterDatapath_TxAdvance),
    .oRxSample  (wI2cMasterCtrl2I2cMasterDatapath_RxSample),
    .oCaptureAck(wI2cMasterCtrl2I2cMasterDatapath_CaptureAck)
  );

  I2cMasterIo uI2cMasterIo (
    .iSclLevel   (wI2cMasterCtrl2I2cMasterIo_SclLevel),
    .iSdaDriveLow(wI2cMasterCtrl2I2cMasterIo_SdaDriveLow),
    .oSclDriveLow(wI2cMasterCtrl2I2cMasterIo_SclDriveLow),
    .oSdaDriveLow(oSdaDriveLow)
  );

  assign oSclDriveLow = wI2cMasterCtrl2I2cMasterIo_SclDriveLow;

endmodule
