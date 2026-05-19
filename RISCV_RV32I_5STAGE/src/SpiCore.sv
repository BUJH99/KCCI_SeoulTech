/*
[MODULE_INFO_START]
Name: SpiCore
Role: Wrapper for the SPI mode0 frame engine used by the APB SPI trace master
Summary:
  - Preserves the APB_SPI-facing SPI core port contract
  - Wires command latch, frame control, byte datapath, input sync, and output driver blocks
  - Keeps APB register/FIFO policy outside the SPI timing core
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiCore (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iEn,
  input  logic        iStartPulse,
  input  logic        iCpol,
  input  logic        iCpha,
  input  logic        iLsbFirst,
  input  logic [7:0]  iFrameLen,
  input  logic [15:0] iClkDiv,
  input  logic [7:0]  iCsCtrl,
  input  logic [7:0]  iTxFifoData,
  input  logic        iTxFifoValid,
  input  logic        iMiso,

  output logic        oBusy,
  output logic        oDonePulse,
  output logic        oTxFifoPopPulse,
  output logic [7:0]  oRxFifoPushData,
  output logic        oRxFifoPushPulse,
  output logic        oTxUnderflowPulse,
  output logic        oModeErrPulse,
  output logic        oFrameDroppedPulse,
  output logic        oSclk,
  output logic        oMosi,
  output logic        oCsN
);

  logic MisoSync;
  logic StartAttemptPulse;
  logic StartAcceptedPulse;
  logic [7:0] FrameLenLatch;
  logic [15:0] ClkDivLatch;
  logic [7:0] CsCtrlLatch;
  logic StartIdleWindow;
  logic StartDropWindow;
  logic CsActive;
  logic CsDriveActive;
  logic AssertCsActive;
  logic LoadActive;
  logic TransferActive;
  logic DeassertCsActive;
  logic HalfPeriodDone;
  logic SclkLevel;
  logic ByteDonePulse;
  logic MosiBit;

  SpiMasterInputSync uSpiMasterInputSync (
    .iClk      (iClk),
    .iRst     (iRst),
    .iMiso     (iMiso),
    .oMisoSync (MisoSync)
  );

  assign CsDriveActive = CsActive && CsCtrlLatch[0];

  SpiMasterCommandLatch uSpiMasterCommandLatch (
    .iClk                (iClk),
    .iRst                (iRst),
    .iEn             (iEn),
    .iStartPulse         (iStartPulse),
    .iCpol               (iCpol),
    .iCpha               (iCpha),
    .iLsbFirst           (iLsbFirst),
    .iFrameLen           (iFrameLen),
    .iClkDiv             (iClkDiv),
    .iCsCtrl             (iCsCtrl),
    .iStartIdleWindow    (StartIdleWindow),
    .iStartDropWindow    (StartDropWindow),
    .oStartAttemptPulse  (StartAttemptPulse),
    .oStartAcceptedPulse (StartAcceptedPulse),
    .oFrameLenLatch      (FrameLenLatch),
    .oClkDivLatch        (ClkDivLatch),
    .oCsCtrlLatch        (CsCtrlLatch),
    .oModeErrPulse     (oModeErrPulse),
    .oFrameDroppedPulse  (oFrameDroppedPulse)
  );

  SpiMasterCtrl uSpiMasterCtrl (
    .iClk                (iClk),
    .iRst                (iRst),
    .iStartAttemptPulse  (StartAttemptPulse),
    .iStartAcceptedPulse (StartAcceptedPulse),
    .iFrameLenLatch      (FrameLenLatch),
    .iClkDivLatch        (ClkDivLatch),
    .iTxFifoValid        (iTxFifoValid),
    .iByteDonePulse      (ByteDonePulse),
    .oBusy               (oBusy),
    .oDonePulse          (oDonePulse),
    .oTxFifoPopPulse     (oTxFifoPopPulse),
    .oTxUnderflowPulse   (oTxUnderflowPulse),
    .oCsActive           (CsActive),
    .oAssertCsActive     (AssertCsActive),
    .oLoadActive         (LoadActive),
    .oTransferActive     (TransferActive),
    .oDeassertCsActive   (DeassertCsActive),
    .oStartIdleWindow    (StartIdleWindow),
    .oStartDropWindow    (StartDropWindow),
    .oHalfPeriodDone     (HalfPeriodDone),
    .oSclkLevel          (SclkLevel)
  );

  SpiMasterDatapath uSpiMasterDatapath (
    .iClk              (iClk),
    .iRst             (iRst),
    .iAssertCsActive   (AssertCsActive),
    .iLoadActive       (LoadActive),
    .iTransferActive   (TransferActive),
    .iHalfPeriodDone   (HalfPeriodDone),
    .iSclkLevel        (SclkLevel),
    .iTxFifoData       (iTxFifoData),
    .iTxFifoValid      (iTxFifoValid),
    .iMisoSync         (MisoSync),
    .oMosiBit          (MosiBit),
    .oRxFifoPushData   (oRxFifoPushData),
    .oRxFifoPushPulse  (oRxFifoPushPulse),
    .oByteDonePulse    (ByteDonePulse)
  );

  SpiMasterDriver uSpiMasterDriver (
    .iCsActive  (CsDriveActive),
    .iSclkLevel (SclkLevel),
    .iMosiBit   (MosiBit),
    .oSclk      (oSclk),
    .oMosi      (oMosi),
    .oCsN       (oCsN)
  );

endmodule
