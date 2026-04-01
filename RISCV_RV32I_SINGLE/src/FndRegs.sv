/*
[MODULE_INFO_START]
Name: FndRegs
Role: APB-facing register block for the FND peripheral control state
Summary:
  - Stores the digit BCD payload, blink mask, decimal-point mask, and display enable bit
  - Implements APB readback and byte-write decoding for the local FND register map
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module FndRegs (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iAccessEn,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,

  output logic [31:0] oPrdata,
  output logic        oPslverr,
  output logic [15:0] oDigitsBcd,
  output logic [3:0]  oBlinkMask,
  output logic [3:0]  oDpMask,
  output logic        oDisplayEn
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_REG_DIGITS_BCD = 12'h000;
  localparam logic [11:0] LP_REG_BLINK_MASK = 12'h004;
  localparam logic [11:0] LP_REG_DP_MASK    = 12'h008;
  localparam logic [11:0] LP_REG_CTRL       = 12'h00C;

  logic [31:0] DigitsWord;
  logic [31:0] BlinkWord;
  logic [31:0] DpWord;
  logic [31:0] CtrlWord;
  logic [31:0] DigitsWriteWord;
  logic [31:0] BlinkWriteWord;
  logic [31:0] DpWriteWord;
  logic [31:0] CtrlWriteWord;

  assign DigitsWord      = {16'd0, oDigitsBcd};
  assign BlinkWord       = {28'd0, oBlinkMask};
  assign DpWord          = {28'd0, oDpMask};
  assign CtrlWord        = {31'd0, oDisplayEn};
  assign DigitsWriteWord = ByteWriteMerge(DigitsWord, iPwdata, iPstrb);
  assign BlinkWriteWord  = ByteWriteMerge(BlinkWord, iPwdata, iPstrb);
  assign DpWriteWord     = ByteWriteMerge(DpWord, iPwdata, iPstrb);
  assign CtrlWriteWord   = ByteWriteMerge(CtrlWord, iPwdata, iPstrb);

  always_comb begin
    oPrdata  = '0;
    oPslverr = 1'b0;

    if (iAccessEn) begin
      unique case (iPaddr)
        LP_REG_DIGITS_BCD: begin
          if (!iPwrite) begin
            oPrdata = DigitsWord;
          end
        end

        LP_REG_BLINK_MASK: begin
          if (!iPwrite) begin
            oPrdata = BlinkWord;
          end
        end

        LP_REG_DP_MASK: begin
          if (!iPwrite) begin
            oPrdata = DpWord;
          end
        end

        LP_REG_CTRL: begin
          if (!iPwrite) begin
            oPrdata = CtrlWord;
          end
        end

        default: begin
          oPslverr = 1'b1;
        end
      endcase
    end
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oDigitsBcd <= '0;
      oBlinkMask <= '0;
      oDpMask    <= '0;
      oDisplayEn <= 1'b1;
    end else begin
      if (iAccessEn && iPwrite && (iPaddr == LP_REG_DIGITS_BCD)) begin
        oDigitsBcd <= DigitsWriteWord[15:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_BLINK_MASK)) begin
        oBlinkMask <= BlinkWriteWord[3:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_DP_MASK)) begin
        oDpMask <= DpWriteWord[3:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL)) begin
        oDisplayEn <= CtrlWriteWord[0];
      end
    end
  end

endmodule
