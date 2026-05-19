/*
[MODULE_INFO_START]
Name: I2cSlaveByteShift
Role: Byte shifter and bit counter for the I2C SLAVE target
Summary:
  - Builds incoming address/register/write bytes from synchronized SDA samples
  - Tracks the current bit position for read data drive and master ACK sampling
  - Keeps byte shifting separate from address match and register-map side effects
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveByteShift (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic       iSdaSample,
  input  logic       iByteResetPulse,
  input  logic       iShiftInPulse,
  input  logic       iReadBitAdvancePulse,

  output logic [7:0] oShiftNext,
  output logic [2:0] oBitCnt,
  output logic       oByteComplete
);

  logic [7:0] shiftReg;

  assign oShiftNext    = {shiftReg[6:0], iSdaSample};
  assign oByteComplete = (oBitCnt == 3'd0);

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      shiftReg <= '0;
      oBitCnt  <= '0;
    end else begin
      if (iByteResetPulse) begin
        shiftReg <= '0;
        oBitCnt  <= 3'd7;
      end else if (iShiftInPulse) begin
        shiftReg <= oShiftNext;
        if (!oByteComplete) begin
          oBitCnt <= oBitCnt - 1'b1;
        end
      end else if (iReadBitAdvancePulse) begin
        if (!oByteComplete) begin
          oBitCnt <= oBitCnt - 1'b1;
        end
      end
    end
  end

endmodule
