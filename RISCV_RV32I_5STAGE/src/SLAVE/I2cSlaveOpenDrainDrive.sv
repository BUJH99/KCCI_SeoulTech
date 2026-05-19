/*
[MODULE_INFO_START]
Name: I2cSlaveOpenDrainDrive
Role: Open-drain SDA output adapter for the I2C SLAVE target
Summary:
  - Converts internal SDA drive-low requests into output-enable style pins
  - Never drives logic 1 on SDA
  - Keeps board-facing drive policy separate from protocol state
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveOpenDrainDrive (
  input  logic iSdaDriveLow,

  output logic oSdaOut,
  output logic oSdaOe
);

  assign oSdaOut = 1'b0;
  assign oSdaOe  = iSdaDriveLow;

endmodule
