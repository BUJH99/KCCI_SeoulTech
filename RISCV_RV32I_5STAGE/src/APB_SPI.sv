/*
[MODULE_INFO_START]
Name: APB_SPI
Role: APB SPI master peripheral with v1 frame FIFO and interrupt outputs
Summary:
  - Delegates APB register decode, TX/RX FIFOs, and sticky IRQ tracking to SpiRegs
  - Delegates SPI mode0 frame timing and external pin drive to SpiCore
  - Keeps event and error IRQ outputs separated for PLIC-lite routing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APB_SPI (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iPsel,
  input  logic        iPenable,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic        iMiso,

  output logic [31:0] oPrdata,
  output logic        oPready,
  output logic        oPslverr,
  output logic        oSclk,
  output logic        oMosi,
  output logic        oCsN,
  output logic        oEventIrq,
  output logic        oErrIrq
);

  logic        AccessEn;
  logic        CtrlEn;
  logic        CtrlStartPulse;
  logic        CtrlCpol;
  logic        CtrlCpha;
  logic        CtrlLsbFirst;
  logic [15:0] ClkDiv;
  logic [7:0]  CsCtrl;
  logic [7:0]  FrameLen;
  logic        CoreBusy;
  logic        CoreDonePulse;
  logic        CoreTxUnderflowPulse;
  logic        CoreModeErrPulse;
  logic        CoreFrameDroppedPulse;
  logic [7:0]  TxFifoData;
  logic        TxFifoValid;
  logic        TxFifoPopPulse;
  logic [7:0]  RxFifoPushData;
  logic        RxFifoPushPulse;

  assign oPready  = 1'b1;
  assign AccessEn = iPsel && iPenable && oPready;

  SpiRegs uSpiRegs (
    .iClk               (iClk),
    .iRst              (iRst),
    .iAccessEn          (AccessEn),
    .iPwrite            (iPwrite),
    .iPaddr             (iPaddr),
    .iPstrb             (iPstrb),
    .iPwdata            (iPwdata),
    .iBusy              (CoreBusy),
    .iDonePulse         (CoreDonePulse),
    .iTxUnderflowPulse  (CoreTxUnderflowPulse),
    .iModeErrPulse    (CoreModeErrPulse),
    .iFrameDroppedPulse (CoreFrameDroppedPulse),
    .iTxFifoPopPulse    (TxFifoPopPulse),
    .iRxFifoPushPulse   (RxFifoPushPulse),
    .iRxFifoPushData    (RxFifoPushData),
    .oPrdata            (oPrdata),
    .oPslverr           (oPslverr),
    .oCtrlEn        (CtrlEn),
    .oCtrlStartPulse    (CtrlStartPulse),
    .oCtrlCpol          (CtrlCpol),
    .oCtrlCpha          (CtrlCpha),
    .oCtrlLsbFirst      (CtrlLsbFirst),
    .oClkDiv            (ClkDiv),
    .oCsCtrl            (CsCtrl),
    .oFrameLen          (FrameLen),
    .oTxFifoData        (TxFifoData),
    .oTxFifoValid       (TxFifoValid),
    .oEventIrq          (oEventIrq),
    .oErrIrq          (oErrIrq)
  );

  SpiCore uSpiCore (
    .iClk               (iClk),
    .iRst              (iRst),
    .iEn            (CtrlEn),
    .iStartPulse        (CtrlStartPulse),
    .iCpol              (CtrlCpol),
    .iCpha              (CtrlCpha),
    .iLsbFirst          (CtrlLsbFirst),
    .iFrameLen          (FrameLen),
    .iClkDiv            (ClkDiv),
    .iCsCtrl            (CsCtrl),
    .iTxFifoData        (TxFifoData),
    .iTxFifoValid       (TxFifoValid),
    .iMiso              (iMiso),
    .oBusy              (CoreBusy),
    .oDonePulse         (CoreDonePulse),
    .oTxFifoPopPulse    (TxFifoPopPulse),
    .oRxFifoPushData    (RxFifoPushData),
    .oRxFifoPushPulse   (RxFifoPushPulse),
    .oTxUnderflowPulse  (CoreTxUnderflowPulse),
    .oModeErrPulse    (CoreModeErrPulse),
    .oFrameDroppedPulse (CoreFrameDroppedPulse),
    .oSclk              (oSclk),
    .oMosi              (oMosi),
    .oCsN               (oCsN)
  );

endmodule
