/*
[MODULE_INFO_START]
Name: I2cSlaveInputSync
Role: Synchronizes asynchronous I2C SCL/SDA inputs into the slave fabric clock domain
Summary:
  - Applies independent two-stage synchronizers to SCL and SDA
  - Ensures all start/stop and bit-edge processing stays on the 100MHz system clock
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveInputSync (
  input  logic iClk,
  input  logic iRst,
  input  logic iScl,
  input  logic iSda,
  output logic oSclSync,
  output logic oSdaSync
);

  logic Scl_d1;
  logic Sda_d1;
  logic Scl_d2;
  logic Sda_d2;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      Scl_d1 <= 1'b1;
      Sda_d1 <= 1'b1;
      Scl_d2 <= 1'b1;
      Sda_d2 <= 1'b1;
    end else begin
      Scl_d1 <= iScl;
      Sda_d1 <= iSda;
      Scl_d2 <= Scl_d1;
      Sda_d2 <= Sda_d1;
    end
  end

  assign oSclSync = Scl_d2;
  assign oSdaSync = Sda_d2;

endmodule
