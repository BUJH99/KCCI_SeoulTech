/*
[MODULE_INFO_START]
Name: APB_I2C
Role: APB I2C master peripheral with event and error interrupt outputs
Summary:
  - Delegates register decode and sticky IRQ cause tracking to I2cRegs
  - Delegates compact transaction timing and external pin drive to I2cCore
  - Separates event and error IRQ outputs for independent PLIC-lite source IDs
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APB_I2C (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iPsel,
  input  logic        iPenable,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic        iSdaIn,

  output logic [31:0] oPrdata,
  output logic        oPready,
  output logic        oPslverr,
  output logic        oScl,
  output logic        oSdaOut,
  output logic        oSdaOe,
  output logic        oEventIrq,
  output logic        oErrorIrq
);

  logic        AccessEn;
  logic        CtrlEnable;
  logic        CtrlStartPulse;
  logic        CtrlStop;
  logic        CtrlAck;
  logic [7:0]  TxData;
  logic [15:0] ClkDiv;
  logic [7:0]  Addr;
  logic        CoreBusy;
  logic        CoreDonePulse;
  logic        CoreRxValidPulse;
  logic        CoreTxReady;
  logic [7:0]  CoreRxData;
  logic        CoreNackPulse;
  logic        CoreArbLostPulse;
  logic        CoreBusErrorPulse;

  assign oPready  = 1'b1;
  assign AccessEn = iPsel && iPenable && oPready;

  I2cRegs uI2cRegs (
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
    .iNackPulse         (CoreNackPulse),
    .iArbLostPulse      (CoreArbLostPulse),
    .iBusErrorPulse     (CoreBusErrorPulse),
    .oPrdata            (oPrdata),
    .oPslverr           (oPslverr),
    .oCtrlEnable        (CtrlEnable),
    .oCtrlStartPulse    (CtrlStartPulse),
    .oCtrlStop          (CtrlStop),
    .oCtrlAck           (CtrlAck),
    .oTxData            (TxData),
    .oClkDiv            (ClkDiv),
    .oAddr              (Addr),
    .oEventIrq          (oEventIrq),
    .oErrorIrq          (oErrorIrq)
  );

  I2cCore uI2cCore (
    .iClk           (iClk),
    .iRstn          (iRstn),
    .iEnable        (CtrlEnable),
    .iStartPulse    (CtrlStartPulse),
    .iStop          (CtrlStop),
    .iAck           (CtrlAck),
    .iTxData        (TxData),
    .iClkDiv        (ClkDiv),
    .iAddr          (Addr),
    .iSdaIn         (iSdaIn),
    .oBusy          (CoreBusy),
    .oDonePulse     (CoreDonePulse),
    .oRxValidPulse  (CoreRxValidPulse),
    .oTxReady       (CoreTxReady),
    .oRxData        (CoreRxData),
    .oNackPulse     (CoreNackPulse),
    .oArbLostPulse  (CoreArbLostPulse),
    .oBusErrorPulse (CoreBusErrorPulse),
    .oScl           (oScl),
    .oSdaOut        (oSdaOut),
    .oSdaOe         (oSdaOe)
  );

endmodule
