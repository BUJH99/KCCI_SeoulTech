/*
[MODULE_INFO_START]
Name: FndDigitSelector
Role: Current FND digit selector
Summary:
  - Selects one BCD nibble, blink bit, and DP bit from four digits
  - Generates active-low digit select lines for a four-digit FND
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module FndDigitSelector (
  input  logic [1:0]  iScanIdx,
  input  logic [15:0] iDigitsBcd,
  input  logic [3:0]  iBlinkMask,
  input  logic [3:0]  iDpMask,

  output logic [3:0]  oDigitSel,
  output logic [3:0]  oCurBcd,
  output logic        oCurBlink,
  output logic        oCurDp
);

  always_comb begin
    oDigitSel = 4'b1111;
    oCurBcd   = 4'd0;
    oCurBlink = 1'b0;
    oCurDp    = 1'b0;

    unique case (iScanIdx)
      2'd0: begin
        oDigitSel = 4'b1110;
        oCurBcd   = iDigitsBcd[3:0];
        oCurBlink = iBlinkMask[0];
        oCurDp    = iDpMask[0];
      end
      2'd1: begin
        oDigitSel = 4'b1101;
        oCurBcd   = iDigitsBcd[7:4];
        oCurBlink = iBlinkMask[1];
        oCurDp    = iDpMask[1];
      end
      2'd2: begin
        oDigitSel = 4'b1011;
        oCurBcd   = iDigitsBcd[11:8];
        oCurBlink = iBlinkMask[2];
        oCurDp    = iDpMask[2];
      end
      default: begin
        oDigitSel = 4'b0111;
        oCurBcd   = iDigitsBcd[15:12];
        oCurBlink = iBlinkMask[3];
        oCurDp    = iDpMask[3];
      end
    endcase
  end

endmodule
