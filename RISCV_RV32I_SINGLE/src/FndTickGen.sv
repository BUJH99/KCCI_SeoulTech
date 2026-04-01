/*
[MODULE_INFO_START]
Name: FndTickGen
Role: Local scan and blink tick generator for the FND peripheral
Summary:
  - Generates a 1kHz scan pulse for digit multiplexing
  - Generates a 2Hz blink pulse for the leaf FND blink effect logic
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module FndTickGen #(
  parameter int unsigned P_CLK_HZ = 100_000_000
) (
  input  logic iClk,
  input  logic iRstn,

  output logic oTick1kHz,
  output logic oTick2Hz
);

  localparam int unsigned LP_TICK_1KHZ_DIV   = ((P_CLK_HZ / 1000) > 0) ? (P_CLK_HZ / 1000) : 1;
  localparam int unsigned LP_TICK_2HZ_DIV    = ((P_CLK_HZ / 2) > 0) ? (P_CLK_HZ / 2) : 1;
  localparam int unsigned LP_TICK_1KHZ_CNT_W = (LP_TICK_1KHZ_DIV > 1) ? $clog2(LP_TICK_1KHZ_DIV) : 1;
  localparam int unsigned LP_TICK_2HZ_CNT_W  = (LP_TICK_2HZ_DIV > 1) ? $clog2(LP_TICK_2HZ_DIV) : 1;

  logic [LP_TICK_1KHZ_CNT_W-1:0] Tick1kHzCnt;
  logic [LP_TICK_2HZ_CNT_W-1:0]  Tick2HzCnt;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      Tick1kHzCnt <= '0;
      Tick2HzCnt  <= '0;
      oTick1kHz   <= 1'b0;
      oTick2Hz    <= 1'b0;
    end else begin
      oTick1kHz <= 1'b0;
      oTick2Hz  <= 1'b0;

      if ({{(32-LP_TICK_1KHZ_CNT_W){1'b0}}, Tick1kHzCnt} == (LP_TICK_1KHZ_DIV - 1)) begin
        Tick1kHzCnt <= '0;
        oTick1kHz   <= 1'b1;
      end else begin
        Tick1kHzCnt <= Tick1kHzCnt + 1'b1;
      end

      if ({{(32-LP_TICK_2HZ_CNT_W){1'b0}}, Tick2HzCnt} == (LP_TICK_2HZ_DIV - 1)) begin
        Tick2HzCnt <= '0;
        oTick2Hz   <= 1'b1;
      end else begin
        Tick2HzCnt <= Tick2HzCnt + 1'b1;
      end
    end
  end

endmodule
