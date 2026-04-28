/*
[MODULE_INFO_START]
Name: TOP
Role: Basys 3 top-level wrapper for the Serial Slave project
Summary:
  - Routes PMOD JA/JB pins into either the SPI or I2C slave subsystem depending on SW[15]
  - Mirrors register 0x01 writes onto LED[6:0] and returns register 0x02 read data from SW[14:8]
  - Observes the I2C JB bus through open-drain SCL/SDA lines with pull-ups
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TOP (
  input  logic        iClk100Mhz,
  input  logic        iRst,
  input  logic [15:0] iSw,
  output logic [15:0] oLed,
  input  logic        iJaCs,
  input  logic        iJaMosi,
  output logic        oJaMiso,
  input  logic        iJaSclk,
  inout  wire         ioJbScl,
  inout  wire         ioJbSda
);

  import CommPkg::*;

  protocol_e ProtocolSelRaw;
  logic       wSpiSlaveSubsystem2Top_TxnValid;
  logic       wSpiSlaveSubsystem2Top_TxnWrite;
  logic [7:0] wSpiSlaveSubsystem2Top_TxnAddr;
  logic [7:0] wSpiSlaveSubsystem2Top_TxnWdata;
  logic       wI2cSlaveSubsystem2Top_TxnValid;
  logic       wI2cSlaveSubsystem2Top_TxnWrite;
  logic [7:0] wI2cSlaveSubsystem2Top_TxnAddr;
  logic [7:0] wI2cSlaveSubsystem2Top_TxnWdata;
  logic [7:0] wSlaveTransactionManager2SpiSlaveSubsystem_ReadData;
  logic [6:0] wSlaveTransactionManager2Top_LedData;
  logic       SelectedTxnValid;
  logic       SelectedTxnWrite;
  logic [7:0] SelectedTxnAddr;
  logic [7:0] SelectedTxnWdata;
  logic       wSpiSlaveSubsystem2Top_JaMiso;
  logic       wI2cSlaveSubsystem2Top_SdaDriveLow;

  always_comb begin
    ProtocolSelRaw = iSw[15] ? PROTOCOL_I2C : PROTOCOL_SPI;

    if (ProtocolSelRaw == PROTOCOL_I2C) begin
      SelectedTxnValid = wI2cSlaveSubsystem2Top_TxnValid;
      SelectedTxnWrite = wI2cSlaveSubsystem2Top_TxnWrite;
      SelectedTxnAddr  = wI2cSlaveSubsystem2Top_TxnAddr;
      SelectedTxnWdata = wI2cSlaveSubsystem2Top_TxnWdata;
    end else begin
      SelectedTxnValid = wSpiSlaveSubsystem2Top_TxnValid;
      SelectedTxnWrite = wSpiSlaveSubsystem2Top_TxnWrite;
      SelectedTxnAddr  = wSpiSlaveSubsystem2Top_TxnAddr;
      SelectedTxnWdata = wSpiSlaveSubsystem2Top_TxnWdata;
    end
  end

  SlaveTransactionManager uSlaveTransactionManager (
    .iClk      (iClk100Mhz),
    .iRst      (iRst),
    .iTxnValid (SelectedTxnValid),
    .iTxnWrite (SelectedTxnWrite),
    .iTxnAddr  (SelectedTxnAddr),
    .iTxnWdata (SelectedTxnWdata),
    .iSwitchData(iSw[14:8]),
    .oReadData (wSlaveTransactionManager2SpiSlaveSubsystem_ReadData),
    .oLedData  (wSlaveTransactionManager2Top_LedData)
  );

  SpiSlaveSubsystem uSpiSlaveSubsystem (
    .iClk      (iClk100Mhz),
    .iRst      (iRst),
    .iEnable   (ProtocolSelRaw == PROTOCOL_SPI),
    .iJaCs     (iJaCs),
    .iJaMosi   (iJaMosi),
    .iJaSclk   (iJaSclk),
    .iTxnReadData(wSlaveTransactionManager2SpiSlaveSubsystem_ReadData),
    .oJaMiso   (wSpiSlaveSubsystem2Top_JaMiso),
    .oTxnValid (wSpiSlaveSubsystem2Top_TxnValid),
    .oTxnWrite (wSpiSlaveSubsystem2Top_TxnWrite),
    .oTxnAddr  (wSpiSlaveSubsystem2Top_TxnAddr),
    .oTxnWdata (wSpiSlaveSubsystem2Top_TxnWdata)
  );

  I2cSlaveSubsystem uI2cSlaveSubsystem (
    .iClk      (iClk100Mhz),
    .iRst      (iRst),
    .iEnable   (ProtocolSelRaw == PROTOCOL_I2C),
    .iJbScl    (ioJbScl),
    .iSdaIn    (ioJbSda),
    .iTxnReadData(wSlaveTransactionManager2SpiSlaveSubsystem_ReadData),
    .oSdaDriveLow(wI2cSlaveSubsystem2Top_SdaDriveLow),
    .oTxnValid (wI2cSlaveSubsystem2Top_TxnValid),
    .oTxnWrite (wI2cSlaveSubsystem2Top_TxnWrite),
    .oTxnAddr  (wI2cSlaveSubsystem2Top_TxnAddr),
    .oTxnWdata (wI2cSlaveSubsystem2Top_TxnWdata)
  );

  assign oLed    = {9'h000, wSlaveTransactionManager2Top_LedData};
  assign oJaMiso = (ProtocolSelRaw == PROTOCOL_SPI) ? wSpiSlaveSubsystem2Top_JaMiso : 1'b0;
  assign ioJbSda = (ProtocolSelRaw == PROTOCOL_I2C && wI2cSlaveSubsystem2Top_SdaDriveLow) ? 1'b0 : 1'bz;

endmodule
