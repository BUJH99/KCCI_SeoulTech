/*
[MODULE_INFO_START]
Name: SlaveTransactionManager
Role: Transaction-to-register bridge for the Serial Slave project
Summary:
  - Accepts decoded SPI/I2C register transactions from the active protocol subsystem
  - Applies write transactions to the register file and returns read data for the current address view
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SlaveTransactionManager (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iTxnValid,
  input  logic       iTxnWrite,
  input  logic [7:0] iTxnAddr,
  input  logic [7:0] iTxnWdata,
  input  logic [6:0] iSwitchData,
  output logic [7:0] oReadData,
  output logic [6:0] oLedData
);

  SlaveRegisterFile uSlaveRegisterFile (
    .iClk      (iClk),
    .iRst      (iRst),
    .iWriteEn  (iTxnValid && iTxnWrite),
    .iWriteAddr(iTxnAddr),
    .iWriteData(iTxnWdata),
    .iReadAddr (iTxnAddr),
    .iSwitchData(iSwitchData),
    .oReadData (oReadData),
    .oLedData  (oLedData)
  );

endmodule
