/*
[MODULE_INFO_START]
Name: I2cMasterInputSync
Role: Synchronizes the I2C SCL/SDA inputs for the master controller
Summary:
  - Uses two-stage synchronizers for the open-drain SCL/SDA lines
  - Shields the control logic from asynchronous bus transitions arriving from the slave board
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterInputSync (
  input  logic iClk,
  input  logic iRst,
  input  logic iScl,
  input  logic iSda,
  output logic oSclSync,
  output logic oSdaSync
);

  logic       Scl_d1;
  logic       Scl_d2;
  logic       Sda_d1;
  logic       Sda_d2;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      Scl_d1 <= 1'b1;
      Scl_d2 <= 1'b1;
      Sda_d1 <= 1'b1;
      Sda_d2 <= 1'b1;
    end else begin
      Scl_d1 <= iScl;
      Scl_d2 <= Scl_d1;
      Sda_d1 <= iSda;
      Sda_d2 <= Sda_d1;
    end
  end

  assign oSclSync = Scl_d2;
  assign oSdaSync = Sda_d2;

endmodule
