/*
[MODULE_INFO_START]
Name: I2cCore
Role: Wrapper for the I2C single-master register transaction engine
Summary:
  - Preserves the APB_I2C-facing I2C core port contract
  - Wires command latch, transaction control, byte datapath, input sync, and open-drain driver
  - Keeps APB register policy outside the I2C bus timing core
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cCore (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iEn,
  input  logic        iStartPulse,
  input  logic        iCoreRstPulse,
  input  logic        iRw,
  input  logic [6:0]  iSlaveAddr,
  input  logic [7:0]  iRegAddr,
  input  logic [31:0] iWdata,
  input  logic [2:0]  iLen,
  input  logic [15:0] iClkDiv,
  input  logic        iSdaIn,

  output logic        oBusy,
  output logic        oDonePulse,
  output logic        oRxValidPulse,
  output logic        oTxReady,
  output logic        oAckOk,
  output logic [31:0] oRxData,
  output logic        oNackPulse,
  output logic        oArbLostPulse,
  output logic        oBusErrPulse,
  output logic        oTimeoutPulse,
  output logic        oScl,
  output logic        oSclOe,
  output logic        oSdaOut,
  output logic        oSdaOe
);

  logic        SdaInSync;
  logic        StartAttemptPulse;
  logic        StartAcceptedPulse;
  logic        InvalidCmdPulse;
  logic        StartIdleWindow;
  logic        RwLatch;
  logic [6:0]  SlaveAddrLatch;
  logic [7:0]  RegAddrLatch;
  logic [31:0] WdataLatch;
  logic [2:0]  LenLatch;
  logic [15:0] ClkDivLatch;
  logic        TxBit;
  logic [2:0]  BitCnt;
  logic        AckBit;
  logic [7:0]  RxByteData;
  logic        RxByteCompletePulse;
  logic        LoadAddrWrPulse;
  logic        LoadRegAddrPulse;
  logic        LoadAddrRdPulse;
  logic        LoadWrBytePulse;
  logic [7:0]  WrByteData;
  logic        PrepareRdPulse;
  logic        NextRdBytePulse;
  logic        TxBitAdvancePulse;
  logic        RxSamplePulse;
  logic        RxBitAdvancePulse;
  logic        AckCapturePulse;
  logic        SclDriveLow;
  logic        SdaDriveLow;

  assign oTxReady = !oBusy;

  I2cMasterInputSync uI2cMasterInputSync (
    .iClk       (iClk),
    .iRst      (iRst),
    .iSdaIn     (iSdaIn),
    .oSdaInSync (SdaInSync)
  );

  I2cMasterCommandLatch uI2cMasterCommandLatch (
    .iClk            (iClk),
    .iRst           (iRst),
    .iEn         (iEn),
    .iStartPulse     (iStartPulse),
    .iBusy           (oBusy),
    .iStartIdleWindow(StartIdleWindow),
    .iRw             (iRw),
    .iSlaveAddr      (iSlaveAddr),
    .iRegAddr        (iRegAddr),
    .iWdata          (iWdata),
    .iLen            (iLen),
    .iClkDiv         (iClkDiv),
    .oStartValid     (),
    .oStartAttemptPulse(StartAttemptPulse),
    .oStartAcceptedPulse(StartAcceptedPulse),
    .oInvalidCmdPulse(InvalidCmdPulse),
    .oRwLatch        (RwLatch),
    .oSlaveAddrLatch (SlaveAddrLatch),
    .oRegAddrLatch   (RegAddrLatch),
    .oWdataLatch     (WdataLatch),
    .oLenLatch       (LenLatch),
    .oClkDivLatch    (ClkDivLatch)
  );

  I2cMasterCtrl uI2cMasterCtrl (
    .iClk                 (iClk),
    .iRst                (iRst),
    .iCoreRstPulse      (iCoreRstPulse),
    .iStartAttemptPulse   (StartAttemptPulse),
    .iStartAcceptedPulse  (StartAcceptedPulse),
    .iInvalidCmdPulse (InvalidCmdPulse),
    .iRwLatch             (RwLatch),
    .iLenLatch            (LenLatch),
    .iClkDivLatch         (ClkDivLatch),
    .iWdataLatch          (WdataLatch),
    .iSdaInSync           (SdaInSync),
    .iTxBit               (TxBit),
    .iBitCnt              (BitCnt),
    .iAckBit              (AckBit),
    .iRxByteData          (RxByteData),
    .iRxByteCompletePulse (RxByteCompletePulse),
    .oBusy                (oBusy),
    .oStartIdleWindow     (StartIdleWindow),
    .oDonePulse           (oDonePulse),
    .oRxValidPulse        (oRxValidPulse),
    .oAckOk               (oAckOk),
    .oRxData              (oRxData),
    .oNackPulse           (oNackPulse),
    .oArbLostPulse        (oArbLostPulse),
    .oBusErrPulse       (oBusErrPulse),
    .oTimeoutPulse        (oTimeoutPulse),
    .oLoadAddrWrPulse     (LoadAddrWrPulse),
    .oLoadRegAddrPulse    (LoadRegAddrPulse),
    .oLoadAddrRdPulse     (LoadAddrRdPulse),
    .oLoadWrBytePulse  (LoadWrBytePulse),
    .oWrByteData       (WrByteData),
    .oPrepareRdPulse    (PrepareRdPulse),
    .oNextRdBytePulse   (NextRdBytePulse),
    .oTxBitAdvancePulse   (TxBitAdvancePulse),
    .oRxSamplePulse       (RxSamplePulse),
    .oRxBitAdvancePulse   (RxBitAdvancePulse),
    .oAckCapturePulse     (AckCapturePulse),
    .oSclDriveLow         (SclDriveLow),
    .oSdaDriveLow         (SdaDriveLow)
  );

  I2cMasterDatapath uI2cMasterDatapath (
    .iClk                 (iClk),
    .iRst                (iRst),
    .iCoreRstPulse      (iCoreRstPulse),
    .iSdaInSync           (SdaInSync),
    .iSlaveAddrLatch      (SlaveAddrLatch),
    .iRegAddrLatch        (RegAddrLatch),
    .iLoadAddrWrPulse     (LoadAddrWrPulse),
    .iLoadRegAddrPulse    (LoadRegAddrPulse),
    .iLoadAddrRdPulse     (LoadAddrRdPulse),
    .iLoadWrBytePulse  (LoadWrBytePulse),
    .iWrByteData       (WrByteData),
    .iPrepareRdPulse    (PrepareRdPulse),
    .iNextRdBytePulse   (NextRdBytePulse),
    .iTxBitAdvancePulse   (TxBitAdvancePulse),
    .iRxSamplePulse       (RxSamplePulse),
    .iRxBitAdvancePulse   (RxBitAdvancePulse),
    .iAckCapturePulse     (AckCapturePulse),
    .oTxBit               (TxBit),
    .oBitCnt              (BitCnt),
    .oAckBit              (AckBit),
    .oRxByteData          (RxByteData),
    .oRxByteCompletePulse (RxByteCompletePulse)
  );

  I2cMasterDriver uI2cMasterDriver (
    .iSclDriveLow (SclDriveLow),
    .iSdaDriveLow (SdaDriveLow),
    .oScl         (oScl),
    .oSclOe       (oSclOe),
    .oSdaOut      (oSdaOut),
    .oSdaOe       (oSdaOe)
  );

endmodule
