/*
[MODULE_INFO_START]
Name: I2cSlaveRegPointer
Role: Byte register pointer for the I2C SLAVE register target
Summary:
  - Loads the register pointer from the register-address write byte
  - Auto-increments after register reads and writes
  - Preserves the pointer across repeated-start reads
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveRegPointer (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iLoadPulse,
  input  logic [7:0] iLoadAddr,
  input  logic       iIncrementPulse,

  output logic [7:0] oRegPtr
);

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      oRegPtr <= '0;
    end else begin
      if (iLoadPulse) begin
        oRegPtr <= iLoadAddr;
      end else if (iIncrementPulse) begin
        oRegPtr <= oRegPtr + 1'b1;
      end
    end
  end

endmodule
