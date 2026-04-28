/*
[MODULE_INFO_START]
Name: FndBcdDecoder
Role: BCD to seven-segment decoder
Summary:
  - Converts one BCD/hex nibble into active-low seven-segment pins
  - Blanks the digit when iBlanking is asserted
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module FndBcdDecoder (
  input  logic [3:0] iCurBcd,
  input  logic       iBlanking,

  output logic [6:0] oSeg
);

  always_comb begin
    oSeg = 7'b111_1111;

    if (!iBlanking) begin
      unique case (iCurBcd)
        4'h0:    oSeg = 7'b100_0000;
        4'h1:    oSeg = 7'b111_1001;
        4'h2:    oSeg = 7'b010_0100;
        4'h3:    oSeg = 7'b011_0000;
        4'h4:    oSeg = 7'b001_1001;
        4'h5:    oSeg = 7'b001_0010;
        4'h6:    oSeg = 7'b000_0010;
        4'h7:    oSeg = 7'b101_1000;
        4'h8:    oSeg = 7'b000_0000;
        4'h9:    oSeg = 7'b001_0000;
        4'hA:    oSeg = 7'b000_1000;
        4'hB:    oSeg = 7'b000_0011;
        4'hC:    oSeg = 7'b100_0110;
        4'hD:    oSeg = 7'b010_0001;
        4'hE:    oSeg = 7'b000_0110;
        4'hF:    oSeg = 7'b000_1110;
        default: oSeg = 7'b111_1111;
      endcase
    end
  end

endmodule
