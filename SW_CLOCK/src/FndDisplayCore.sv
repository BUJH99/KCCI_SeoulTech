/*
[MODULE_INFO_START]
Name: FndDisplayCore
Role: Hardware FND scan engine
Summary:
  - Receives a software display frame through AXI GPIO
  - Scans four active-low Basys3 FND digits at P_SCAN_HZ
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module FndDisplayCore #(
  parameter int unsigned P_CLK_HZ  = 100_000_000,
  parameter int unsigned P_SCAN_HZ = 1000
) (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic [31:0] iDisplayWord,

  output logic [6:0]  oSeg,
  output logic        oDp,
  output logic [3:0]  oDigitSel
);

  logic        tickScan;
  logic [1:0]  scanIdx;
  logic [15:0] digitsBcd;
  logic [3:0]  dpMask;
  logic [3:0]  blankMask;
  logic [3:0]  curDigit;
  logic        curDp;
  logic        curBlank;

  assign digitsBcd = iDisplayWord[15:0];
  assign dpMask    = iDisplayWord[19:16];
  assign blankMask = iDisplayWord[23:20];

  TickPulseGen #(
    .P_CLK_HZ  (P_CLK_HZ),
    .P_TICK_HZ (P_SCAN_HZ)
  ) uScanTickGen (
    .iClk  (iClk),
    .iRstn (iRstn),
    .oTick (tickScan)
  );

  function automatic logic [6:0] DecodeDigit(input logic [3:0] iDigit);
    begin
      unique case (iDigit)
        4'h0:    DecodeDigit = 7'b100_0000;
        4'h1:    DecodeDigit = 7'b111_1001;
        4'h2:    DecodeDigit = 7'b010_0100;
        4'h3:    DecodeDigit = 7'b011_0000;
        4'h4:    DecodeDigit = 7'b001_1001;
        4'h5:    DecodeDigit = 7'b001_0010;
        4'h6:    DecodeDigit = 7'b000_0010;
        4'h7:    DecodeDigit = 7'b101_1000;
        4'h8:    DecodeDigit = 7'b000_0000;
        4'h9:    DecodeDigit = 7'b001_0000;
        4'hA:    DecodeDigit = 7'b000_1000;
        4'hB:    DecodeDigit = 7'b000_0011;
        4'hC:    DecodeDigit = 7'b100_0110;
        4'hD:    DecodeDigit = 7'b010_0001;
        4'hE:    DecodeDigit = 7'b000_0110;
        4'hF:    DecodeDigit = 7'b000_1110;
        default: DecodeDigit = 7'b111_1111;
      endcase
    end
  endfunction

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      scanIdx <= 2'd0;
    end else if (tickScan) begin
      scanIdx <= scanIdx + 2'd1;
    end
  end

  always_comb begin
    oDigitSel = 4'b1111;
    curDigit  = 4'd0;
    curDp     = 1'b0;
    curBlank  = 1'b0;

    unique case (scanIdx)
      2'd0: begin
        oDigitSel = 4'b1110;
        curDigit  = digitsBcd[3:0];
        curDp     = dpMask[0];
        curBlank  = blankMask[0];
      end
      2'd1: begin
        oDigitSel = 4'b1101;
        curDigit  = digitsBcd[7:4];
        curDp     = dpMask[1];
        curBlank  = blankMask[1];
      end
      2'd2: begin
        oDigitSel = 4'b1011;
        curDigit  = digitsBcd[11:8];
        curDp     = dpMask[2];
        curBlank  = blankMask[2];
      end
      default: begin
        oDigitSel = 4'b0111;
        curDigit  = digitsBcd[15:12];
        curDp     = dpMask[3];
        curBlank  = blankMask[3];
      end
    endcase

    oSeg = curBlank ? 7'b111_1111 : DecodeDigit(curDigit);
    oDp  = curBlank ? 1'b1 : ~curDp;
  end

endmodule
