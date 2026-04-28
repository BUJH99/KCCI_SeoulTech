/*
[MODULE_INFO_START]
Name: I2cSlaveEdgeDetect
Role: Fabric-clock edge detector for synchronized I2C slave inputs
Summary:
  - Generates SCL edge pulses and detects START/STOP conditions from synchronized SCL/SDA levels
  - Keeps I2C slave protocol decoding free from asynchronous event controls
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveEdgeDetect (
  input  logic iClk,
  input  logic iRst,
  input  logic iSclSync,
  input  logic iSdaSync,
  output logic oSclRise,
  output logic oSclFall,
  output logic oStartPulse,
  output logic oStopPulse
);

  logic SclPrev;
  logic SdaPrev;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      SclPrev     <= 1'b1;
      SdaPrev     <= 1'b1;
      oSclRise    <= 1'b0;
      oSclFall    <= 1'b0;
      oStartPulse <= 1'b0;
      oStopPulse  <= 1'b0;
    end else begin
      oSclRise    <= (!SclPrev && iSclSync);
      oSclFall    <= (SclPrev && !iSclSync);
      oStartPulse <= ( iSclSync &&  SdaPrev && !iSdaSync);
      oStopPulse  <= ( iSclSync && !SdaPrev &&  iSdaSync);
      SclPrev     <= iSclSync;
      SdaPrev     <= iSdaSync;
    end
  end

endmodule
