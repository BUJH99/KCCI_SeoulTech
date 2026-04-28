/*
[MODULE_INFO_START]
Name: BcdUpCounter4
Role: Four-digit BCD up counter
Summary:
  - Counts from 0000 to 9999 on iInc pulses
  - Rolls over to 0000 and reports a one-cycle rollover pulse
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module BcdUpCounter4 (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iClear,
  input  logic        iInc,

  output logic [15:0] oDigitsBcd,
  output logic        oRolloverPulse
);

  logic [3:0] digitOnes;
  logic [3:0] digitTens;
  logic [3:0] digitHundreds;
  logic [3:0] digitThousands;
  logic       atMax;

  assign digitOnes      = oDigitsBcd[3:0];
  assign digitTens      = oDigitsBcd[7:4];
  assign digitHundreds  = oDigitsBcd[11:8];
  assign digitThousands = oDigitsBcd[15:12];
  assign atMax          = (oDigitsBcd == 16'h9999);

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oDigitsBcd      <= '0;
      oRolloverPulse <= 1'b0;
    end else begin
      oRolloverPulse <= 1'b0;

      if (iClear) begin
        oDigitsBcd <= '0;
      end else if (iInc) begin
        oRolloverPulse <= atMax;

        if (atMax) begin
          oDigitsBcd <= '0;
        end else if (digitOnes != 4'd9) begin
          oDigitsBcd[3:0] <= digitOnes + 1'b1;
        end else if (digitTens != 4'd9) begin
          oDigitsBcd[3:0] <= 4'd0;
          oDigitsBcd[7:4] <= digitTens + 1'b1;
        end else if (digitHundreds != 4'd9) begin
          oDigitsBcd[3:0]  <= 4'd0;
          oDigitsBcd[7:4]  <= 4'd0;
          oDigitsBcd[11:8] <= digitHundreds + 1'b1;
        end else begin
          oDigitsBcd[3:0]   <= 4'd0;
          oDigitsBcd[7:4]   <= 4'd0;
          oDigitsBcd[11:8]  <= 4'd0;
          oDigitsBcd[15:12] <= digitThousands + 1'b1;
        end
      end
    end
  end

endmodule
