/*
[MODULE_INFO_START]
Name: APB_I2C
Role: APB I2C master peripheral with v1 register-transaction support
Summary:
  - Delegates APB decode and sticky IRQ tracking to I2cRegs
  - Delegates 7-bit single-master register read/write timing to I2cCore
  - Exposes SCL/SDA output-enable style controls for open-drain board adaptation
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APB_I2C (
  input  logic        iClk,
  input  logic        iRst,
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
  output logic        oSclOe,
  output logic        oSdaOut,
  output logic        oSdaOe,
  output logic        oEventIrq,
  output logic        oErrIrq
);

  logic        AccessEn;
  logic        CtrlEn;
  logic        CtrlStartPulse;
  logic        CtrlRw;
  logic        StartRw;
  logic        CoreRstPulse;
  logic [6:0]  SlaveAddr;
  logic [7:0]  RegAddr;
  logic [31:0] Wdata;
  logic [2:0]  Len;
  logic [15:0] ClkDiv;
  logic        CoreBusy;
  logic        CoreDonePulse;
  logic        CoreRxValidPulse;
  logic        CoreTxReady;
  logic        CoreAckOk;
  logic [31:0] CoreRxData;
  logic        CoreNackPulse;
  logic        CoreArbLostPulse;
  logic        CoreBusErrPulse;
  logic        CoreTimeoutPulse;

  assign oPready  = 1'b1;
  assign AccessEn = iPsel && iPenable && oPready;

  I2cRegs uI2cRegs (
    .iClk              (iClk),
    .iRst             (iRst),
    .iAccessEn         (AccessEn),
    .iPwrite           (iPwrite),
    .iPaddr            (iPaddr),
    .iPstrb            (iPstrb),
    .iPwdata           (iPwdata),
    .iBusy             (CoreBusy),
    .iDonePulse        (CoreDonePulse),
    .iRxValidPulse     (CoreRxValidPulse),
    .iTxReady          (CoreTxReady),
    .iAckOk            (CoreAckOk),
    .iRxData           (CoreRxData),
    .iNackPulse        (CoreNackPulse),
    .iArbLostPulse     (CoreArbLostPulse),
    .iBusErrPulse    (CoreBusErrPulse),
    .iTimeoutPulse     (CoreTimeoutPulse),
    .oPrdata           (oPrdata),
    .oPslverr          (oPslverr),
    .oCtrlEn       (CtrlEn),
    .oCtrlStartPulse   (CtrlStartPulse),
    .oCtrlRw           (CtrlRw),
    .oStartRw          (StartRw),
    .oCoreRstPulse   (CoreRstPulse),
    .oSlaveAddr        (SlaveAddr),
    .oRegAddr          (RegAddr),
    .oWdata            (Wdata),
    .oLen              (Len),
    .oClkDiv           (ClkDiv),
    .oEventIrq         (oEventIrq),
    .oErrIrq         (oErrIrq)
  );

  I2cCore uI2cCore (
    .iClk           (iClk),
    .iRst          (iRst),
    .iEn        (CtrlEn),
    .iStartPulse    (CtrlStartPulse),
    .iCoreRstPulse(CoreRstPulse),
    .iRw            (StartRw),
    .iSlaveAddr     (SlaveAddr),
    .iRegAddr       (RegAddr),
    .iWdata         (Wdata),
    .iLen           (Len),
    .iClkDiv        (ClkDiv),
    .iSdaIn         (iSdaIn),
    .oBusy          (CoreBusy),
    .oDonePulse     (CoreDonePulse),
    .oRxValidPulse  (CoreRxValidPulse),
    .oTxReady       (CoreTxReady),
    .oAckOk         (CoreAckOk),
    .oRxData        (CoreRxData),
    .oNackPulse     (CoreNackPulse),
    .oArbLostPulse  (CoreArbLostPulse),
    .oBusErrPulse (CoreBusErrPulse),
    .oTimeoutPulse  (CoreTimeoutPulse),
    .oScl           (oScl),
    .oSclOe         (oSclOe),
    .oSdaOut        (oSdaOut),
    .oSdaOe         (oSdaOe)
  );

endmodule
