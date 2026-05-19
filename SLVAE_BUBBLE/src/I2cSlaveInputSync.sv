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
  input  logic iRstn,
  input  logic iScl,
  input  logic iSdaIn,

  output logic oSclRise,
  output logic oSclFall,
  output logic oStartSeen,
  output logic oStopSeen,
  output logic oSdaSample
);

  logic scl_d1;
  logic scl_d2;
  logic sda_d1;
  logic sda_d2;

  assign oSclRise   = scl_d1 && !scl_d2;
  assign oSclFall   = !scl_d1 && scl_d2;
  assign oStartSeen = scl_d1 && sda_d2 && !sda_d1;
  assign oStopSeen  = scl_d1 && !sda_d2 && sda_d1;
  assign oSdaSample = sda_d1;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      scl_d1 <= 1'b1;
      scl_d2 <= 1'b1;
      sda_d1 <= 1'b1;
      sda_d2 <= 1'b1;
    end else begin
      scl_d1 <= iScl;
      scl_d2 <= scl_d1;
      sda_d1 <= iSdaIn;
      sda_d2 <= sda_d1;
    end
  end

endmodule
