/*
[MODULE_INFO_START]
Name: I2cSlaveIo
Role: Output adapter for the I2C slave SDA drive-low control
Summary:
  - Applies protocol-selection gating to the open-drain SDA low-drive request
  - Leaves the actual tri-state assignment to the top-level board wrapper
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveIo (
  input  logic iEnable,
  input  logic iSdaDriveLow,
  output logic oSdaDriveLow
);

  assign oSdaDriveLow = iEnable ? iSdaDriveLow : 1'b0;

endmodule
