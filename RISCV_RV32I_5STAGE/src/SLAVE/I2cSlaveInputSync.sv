/*
[MODULE_INFO_START]
Name: I2cSlaveInputSync
Role: I2C SLAVE SCL/SDA synchronizer and edge detector
Summary:
  - Synchronizes SCL and SDA into the system clock domain
  - Generates SCL rise/fall and START/STOP events
  - Provides the synchronized SDA sample used by protocol and byte-shift logic
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveInputSync (
  input  logic iClk,
  input  logic iRst,
  input  logic iScl,
  input  logic iSdaIn,

  output logic oSclRise,
  output logic oSclFall,
  output logic oStartSeen,
  output logic oStopSeen,
  output logic oSdaSample
);

  logic Scl_d1;
  logic Scl_d2;
  logic Sda_d1;
  logic Sda_d2;

  assign oSclRise   = Scl_d1 && !Scl_d2;
  assign oSclFall   = !Scl_d1 && Scl_d2;
  assign oStartSeen = Scl_d1 && Sda_d2 && !Sda_d1;
  assign oStopSeen  = Scl_d1 && !Sda_d2 && Sda_d1;
  assign oSdaSample = Sda_d1;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      Scl_d1 <= 1'b1;
      Scl_d2 <= 1'b1;
      Sda_d1 <= 1'b1;
      Sda_d2 <= 1'b1;
    end else begin
      Scl_d1 <= iScl;
      Scl_d2 <= Scl_d1;
      Sda_d1 <= iSdaIn;
      Sda_d2 <= Sda_d1;
    end
  end

endmodule
