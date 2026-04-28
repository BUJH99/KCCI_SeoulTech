/*
[MODULE_INFO_START]
Name: I2cMasterIo
Role: Pin-level adapter for the I2C master subsystem
Summary:
  - Converts the controller's desired SCL level into an open-drain low-drive enable
  - Keeps SCL/SDA open-drain tri-state policy outside the I2C control FSM
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterIo (
  input  logic iSclLevel,
  input  logic iSdaDriveLow,
  output logic oSclDriveLow,
  output logic oSdaDriveLow
);

  assign oSclDriveLow = !iSclLevel;
  assign oSdaDriveLow = iSdaDriveLow;

endmodule
