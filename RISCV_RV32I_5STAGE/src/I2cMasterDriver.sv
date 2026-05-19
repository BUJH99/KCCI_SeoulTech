/*
[MODULE_INFO_START]
Name: I2cMasterDriver
Role: I2C master open-drain output driver adapter
Summary:
  - Converts internal SCL/SDA drive-low requests into output-enable style pins
  - Never drives logic 1 on SCL or SDA
  - Keeps board-facing open-drain policy separate from transaction sequencing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterDriver (
  input  logic iSclDriveLow,
  input  logic iSdaDriveLow,

  output logic oScl,
  output logic oSclOe,
  output logic oSdaOut,
  output logic oSdaOe
);

  assign oScl    = !iSclDriveLow;
  assign oSclOe  = iSclDriveLow;
  assign oSdaOut = 1'b0;
  assign oSdaOe  = iSdaDriveLow;

endmodule
