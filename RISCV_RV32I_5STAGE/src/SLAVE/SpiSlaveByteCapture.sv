/*
[MODULE_INFO_START]
Name: SpiSlaveByteCapture
Role: SPI SLAVE mode0 byte capture block
Summary:
  - Samples synchronized MOSI on SCLK rising edges while CS is active
  - Builds MSB-first bytes and emits a one-cycle valid pulse
  - Leaves frame length policy to the frame tracker
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiSlaveByteCapture (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iFrameStartPulse,
  input  logic       iFrameActive,
  input  logic       iSclkRise,
  input  logic       iMosiSync,

  output logic [7:0] oByteData,
  output logic       oByteValidPulse,
  output logic       oByteValidNow,
  output logic [2:0] oBitCnt
);

  logic [7:0] ShiftReg;

  assign oByteValidNow = iFrameActive && iSclkRise && (oBitCnt == 3'd7);

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      ShiftReg        <= '0;
      oBitCnt         <= '0;
      oByteData       <= '0;
      oByteValidPulse <= 1'b0;
    end else begin
      oByteValidPulse <= 1'b0;

      if (iFrameStartPulse) begin
        ShiftReg <= '0;
        oBitCnt  <= '0;
      end else if (iFrameActive && iSclkRise) begin
        ShiftReg <= {ShiftReg[6:0], iMosiSync};

        if (oBitCnt == 3'd7) begin
          oByteData       <= {ShiftReg[6:0], iMosiSync};
          oByteValidPulse <= 1'b1;
          oBitCnt         <= '0;
        end else begin
          oBitCnt <= oBitCnt + 1'b1;
        end
      end
    end
  end

endmodule
