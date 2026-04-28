/*
[MODULE_INFO_START]
Name: TOP
Role: Basys 3 top-level wrapper for the Serial Master project
Summary:
  - Polls a remote Serial_Slave board every 10ms using either SPI or I2C depending on SW[15]
  - Mirrors the remote register readback onto LED[14:8] while routing protocol pins to PMOD JA/JB
  - Drives the I2C JB bus through open-drain SCL/SDA outputs with pull-ups
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TOP #(
  parameter int unsigned P_CLK_HZ      = 100_000_000,
  parameter int unsigned P_POLL_CYCLES = 1_000_000,
  parameter int unsigned P_SPI_DIV     = 100,
  parameter int unsigned P_I2C_DIV     = 4000
) (
  input  logic        iClk100Mhz,
  input  logic        iRst,
  input  logic [15:0] iSw,
  output logic [15:0] oLed,
  output logic        oJaCs,
  output logic        oJaMosi,
  input  logic        iJaMiso,
  output logic        oJaSclk,
  inout  wire         ioJbScl,
  inout  wire         ioJbSda
);

  import CommPkg::*;

  protocol_e ProtocolSelRaw;
  protocol_e wCommandLatch2MasterSequencer_ProtocolSel;
  protocol_e wMasterSequencer2Top_TxnProtocol;

  logic       wTimer10ms2MasterSequencer_Expired;
  logic       wMasterSequencer2Timer10ms_Clr;
  logic       wMasterSequencer2CommandLatch_Load;
  logic [7:0] wCommandLatch2MasterSequencer_WriteData;
  logic       wMasterSequencer2SpiMasterSubsystem_TxnStart;
  logic       wMasterSequencer2I2cMasterSubsystem_TxnStart;
  logic       wMasterSequencer2Top_TxnStart;
  logic       wMasterSequencer2Top_TxnRw;
  logic [7:0] wMasterSequencer2Top_TxnRegAddr;
  logic [7:0] wMasterSequencer2Top_TxnWrData;
  logic [6:0] wMasterSequencer2Top_LedMirror;
  logic       wSpiMasterSubsystem2Top_TxnBusy;
  logic       wSpiMasterSubsystem2Top_TxnDone;
  logic [7:0] wSpiMasterSubsystem2Top_TxnRdData;
  logic       wI2cMasterSubsystem2Top_TxnBusy;
  logic       wI2cMasterSubsystem2Top_TxnDone;
  logic [7:0] wI2cMasterSubsystem2Top_TxnRdData;
  logic       wSpiMasterSubsystem2Top_JaCs;
  logic       wSpiMasterSubsystem2Top_JaMosi;
  logic       wSpiMasterSubsystem2Top_JaSclk;
  logic       wI2cMasterSubsystem2Top_SclDriveLow;
  logic       wI2cMasterSubsystem2Top_SdaDriveLow;
  logic       SelectedTxnDone;
  logic [7:0] SelectedTxnRdData;

  always_comb begin
    ProtocolSelRaw = iSw[15] ? PROTOCOL_I2C : PROTOCOL_SPI;
  end

  Timer10ms #(
    .P_CYCLES(P_POLL_CYCLES)
  ) uTimer10ms (
    .iClk   (iClk100Mhz),
    .iRst   (iRst),
    .iClr   (wMasterSequencer2Timer10ms_Clr),
    .oExpired(wTimer10ms2MasterSequencer_Expired)
  );

  CommandLatch uCommandLatch (
    .iClk          (iClk100Mhz),
    .iRst          (iRst),
    .iLoad         (wMasterSequencer2CommandLatch_Load),
    .iProtocolSelRaw(ProtocolSelRaw),
    .iWriteDataRaw ({1'b0, iSw[6:0]}),
    .oProtocolSel  (wCommandLatch2MasterSequencer_ProtocolSel),
    .oWriteData    (wCommandLatch2MasterSequencer_WriteData)
  );

  MasterSequencer uMasterSequencer (
    .iClk        (iClk100Mhz),
    .iRst        (iRst),
    .iTimerExpired(wTimer10ms2MasterSequencer_Expired),
    .iProtocolSel(wCommandLatch2MasterSequencer_ProtocolSel),
    .iWriteData  (wCommandLatch2MasterSequencer_WriteData),
    .iTxnDone    (SelectedTxnDone),
    .iTxnRdData  (SelectedTxnRdData),
    .oTimerClr   (wMasterSequencer2Timer10ms_Clr),
    .oCmdLoad    (wMasterSequencer2CommandLatch_Load),
    .oTxnStart   (wMasterSequencer2Top_TxnStart),
    .oTxnRw      (wMasterSequencer2Top_TxnRw),
    .oTxnRegAddr (wMasterSequencer2Top_TxnRegAddr),
    .oTxnWrData  (wMasterSequencer2Top_TxnWrData),
    .oTxnProtocol(wMasterSequencer2Top_TxnProtocol),
    .oLedMirror  (wMasterSequencer2Top_LedMirror),
    .oBusy       ()
  );

  assign wMasterSequencer2SpiMasterSubsystem_TxnStart =
    wMasterSequencer2Top_TxnStart && (wMasterSequencer2Top_TxnProtocol == PROTOCOL_SPI);
  assign wMasterSequencer2I2cMasterSubsystem_TxnStart =
    wMasterSequencer2Top_TxnStart && (wMasterSequencer2Top_TxnProtocol == PROTOCOL_I2C);

  SpiMasterSubsystem #(
    .P_DIV(P_SPI_DIV)
  ) uSpiMasterSubsystem (
    .iClk      (iClk100Mhz),
    .iRst      (iRst),
    .iTxnStart (wMasterSequencer2SpiMasterSubsystem_TxnStart),
    .iTxnRw    (wMasterSequencer2Top_TxnRw),
    .iTxnRegAddr(wMasterSequencer2Top_TxnRegAddr),
    .iTxnWrData(wMasterSequencer2Top_TxnWrData),
    .iJaMiso   (iJaMiso),
    .oTxnBusy  (wSpiMasterSubsystem2Top_TxnBusy),
    .oTxnDone  (wSpiMasterSubsystem2Top_TxnDone),
    .oTxnRdData(wSpiMasterSubsystem2Top_TxnRdData),
    .oJaCs     (wSpiMasterSubsystem2Top_JaCs),
    .oJaMosi   (wSpiMasterSubsystem2Top_JaMosi),
    .oJaSclk   (wSpiMasterSubsystem2Top_JaSclk)
  );

  I2cMasterSubsystem #(
    .P_DIV(P_I2C_DIV)
  ) uI2cMasterSubsystem (
    .iClk      (iClk100Mhz),
    .iRst      (iRst),
    .iTxnStart (wMasterSequencer2I2cMasterSubsystem_TxnStart),
    .iTxnRw    (wMasterSequencer2Top_TxnRw),
    .iTxnRegAddr(wMasterSequencer2Top_TxnRegAddr),
    .iTxnWrData(wMasterSequencer2Top_TxnWrData),
    .iSclIn    (ioJbScl),
    .iSdaIn    (ioJbSda),
    .oTxnBusy  (wI2cMasterSubsystem2Top_TxnBusy),
    .oTxnDone  (wI2cMasterSubsystem2Top_TxnDone),
    .oTxnRdData(wI2cMasterSubsystem2Top_TxnRdData),
    .oSclDriveLow(wI2cMasterSubsystem2Top_SclDriveLow),
    .oSdaDriveLow(wI2cMasterSubsystem2Top_SdaDriveLow)
  );

  always_comb begin
    if (wMasterSequencer2Top_TxnProtocol == PROTOCOL_I2C) begin
      SelectedTxnDone   = wI2cMasterSubsystem2Top_TxnDone;
      SelectedTxnRdData = wI2cMasterSubsystem2Top_TxnRdData;
    end else begin
      SelectedTxnDone   = wSpiMasterSubsystem2Top_TxnDone;
      SelectedTxnRdData = wSpiMasterSubsystem2Top_TxnRdData;
    end
  end

  assign oLed    = {1'b0, wMasterSequencer2Top_LedMirror, 8'h00};
  assign oJaCs   = (wMasterSequencer2Top_TxnProtocol == PROTOCOL_SPI) ? wSpiMasterSubsystem2Top_JaCs   : 1'b1;
  assign oJaMosi = (wMasterSequencer2Top_TxnProtocol == PROTOCOL_SPI) ? wSpiMasterSubsystem2Top_JaMosi : 1'b0;
  assign oJaSclk = (wMasterSequencer2Top_TxnProtocol == PROTOCOL_SPI) ? wSpiMasterSubsystem2Top_JaSclk : 1'b0;
  assign ioJbScl = (wMasterSequencer2Top_TxnProtocol == PROTOCOL_I2C && wI2cMasterSubsystem2Top_SclDriveLow) ? 1'b0 : 1'bz;
  assign ioJbSda = (wMasterSequencer2Top_TxnProtocol == PROTOCOL_I2C && wI2cMasterSubsystem2Top_SdaDriveLow) ? 1'b0 : 1'bz;

endmodule
