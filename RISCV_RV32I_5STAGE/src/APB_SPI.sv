/*
[MODULE_INFO_START]
Name: APB_SPI
Role: APB SPI master peripheral with event and error interrupt outputs
Summary:
  - Delegates register decode and sticky IRQ cause tracking to SpiRegs
  - Delegates compact frame transfer timing and SPI pin drive to SpiCore
  - Separates event and error IRQ outputs for PLIC-lite routing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APB_SPI (
  input  logic        iClk,
  input  logic        iRstn,
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
  output logic        oErrorIrq
);

  logic        AccessEn;
  logic        CtrlEnable;
  logic        CtrlStartPulse;
  logic        CtrlCpol;
  logic        CtrlCpha;
  logic        CtrlLsbFirst;
  logic        CtrlManualCs;
  logic [7:0]  TxData;
  logic [15:0] ClkDiv;
  logic [7:0]  CsMask;
  logic        CoreBusy;
  logic        CoreDonePulse;
  logic        CoreRxValidPulse;
  logic        CoreTxReady;
  logic [7:0]  CoreRxData;
  logic        CoreRxOverflowPulse;
  logic        CoreTxUnderflowPulse;
  logic        CoreModeErrorPulse;
  logic        CoreFrameDroppedPulse;

  assign oPready  = 1'b1;
  assign AccessEn = iPsel && iPenable && oPready;

  SpiRegs uSpiRegs (
    .iClk               (iClk),
    .iRstn              (iRstn),
    .iAccessEn          (AccessEn),
    .iPwrite            (iPwrite),
    .iPaddr             (iPaddr),
    .iPstrb             (iPstrb),
    .iPwdata            (iPwdata),
    .iBusy              (CoreBusy),
    .iDonePulse         (CoreDonePulse),
    .iRxValidPulse      (CoreRxValidPulse),
    .iTxReady           (CoreTxReady),
    .iRxData            (CoreRxData),
    .iRxOverflowPulse   (CoreRxOverflowPulse),
    .iTxUnderflowPulse  (CoreTxUnderflowPulse),
    .iModeErrorPulse    (CoreModeErrorPulse),
    .iFrameDroppedPulse (CoreFrameDroppedPulse),
    .oPrdata            (oPrdata),
    .oPslverr           (oPslverr),
    .oCtrlEnable        (CtrlEnable),
    .oCtrlStartPulse    (CtrlStartPulse),
    .oCtrlCpol          (CtrlCpol),
    .oCtrlCpha          (CtrlCpha),
    .oCtrlLsbFirst      (CtrlLsbFirst),
    .oCtrlManualCs      (CtrlManualCs),
    .oTxData            (TxData),
    .oClkDiv            (ClkDiv),
    .oCsMask            (CsMask),
    .oEventIrq          (oEventIrq),
    .oErrorIrq          (oErrorIrq)
  );

  SpiCore uSpiCore (
    .iClk               (iClk),
    .iRstn              (iRstn),
    .iEnable            (CtrlEnable),
    .iStartPulse        (CtrlStartPulse),
    .iCpol              (CtrlCpol),
    .iCpha              (CtrlCpha),
    .iLsbFirst          (CtrlLsbFirst),
    .iManualCs          (CtrlManualCs),
    .iTxData            (TxData),
    .iClkDiv            (ClkDiv),
    .iCsMask            (CsMask),
    .iMiso              (iMiso),
    .oBusy              (CoreBusy),
    .oDonePulse         (CoreDonePulse),
    .oRxValidPulse      (CoreRxValidPulse),
    .oTxReady           (CoreTxReady),
    .oRxData            (CoreRxData),
    .oRxOverflowPulse   (CoreRxOverflowPulse),
    .oTxUnderflowPulse  (CoreTxUnderflowPulse),
    .oModeErrorPulse    (CoreModeErrorPulse),
    .oFrameDroppedPulse (CoreFrameDroppedPulse),
    .oSclk              (oSclk),
    .oMosi              (oMosi),
    .oCsN               (oCsN)
  );

endmodule
