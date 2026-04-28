/*
[MODULE_INFO_START]
Name: TickPulseGen
Role: Periodic one-cycle tick generator
Summary:
  - Divides the input clock into a one-cycle tick at P_TICK_HZ
  - Uses an active-low reset for block-design friendly integration
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TickPulseGen #(
  parameter int unsigned P_CLK_HZ  = 100_000_000,
  parameter int unsigned P_TICK_HZ = 1
) (
  input  logic iClk,
  input  logic iRstn,

  output logic oTick
);

  localparam int unsigned LP_DIV       = (P_CLK_HZ >= P_TICK_HZ) ? (P_CLK_HZ / P_TICK_HZ) : 1;
  localparam int unsigned LP_CNT_WIDTH = (LP_DIV > 1) ? $clog2(LP_DIV) : 1;

  localparam logic [LP_CNT_WIDTH-1:0] LP_DIV_LAST = LP_CNT_WIDTH'(LP_DIV - 1);

  logic [LP_CNT_WIDTH-1:0] cnt;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      cnt   <= '0;
      oTick <= 1'b0;
    end else begin
      if (cnt == LP_DIV_LAST) begin
        cnt   <= '0;
        oTick <= 1'b1;
      end else begin
        cnt   <= cnt + 1'b1;
        oTick <= 1'b0;
      end
    end
  end

endmodule
