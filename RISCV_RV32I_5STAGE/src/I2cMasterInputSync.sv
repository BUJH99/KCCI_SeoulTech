/*
[MODULE_INFO_START]
Name: I2cMasterInputSync
Role: SDA input synchronizer for the I2C master core
Summary:
  - Captures SDA through two flip-flops in the system clock domain
  - Provides the synchronized sample to ACK, arbitration, and RX logic
  - Keeps CDC handling separate from protocol sequencing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterInputSync (
  input  logic iClk,
  input  logic iRst,
  input  logic iSdaIn,

  output logic oSdaInSync
);

  logic SdaIn_d1;
  logic SdaIn_d2;

  assign oSdaInSync = SdaIn_d2;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      SdaIn_d1 <= 1'b1;
      SdaIn_d2 <= 1'b1;
    end else begin
      SdaIn_d1 <= iSdaIn;
      SdaIn_d2 <= SdaIn_d1;
    end
  end

endmodule
