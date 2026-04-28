/*
[MODULE_INFO_START]
Name: I2cMasterClockDivider
Role: Generates half-period ticks for the I2C master engine
Summary:
  - Divides the 100MHz system clock down to the requested 100kHz-equivalent SCL period
  - Emits one-cycle pulses for every low/high half-cycle transition while enabled
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterClockDivider #(
  parameter int unsigned P_DIV = 1000
) (
  input  logic iClk,
  input  logic iRst,
  input  logic iEnable,
  output logic oTick
);

  localparam int unsigned LP_HALF_DIV   = (P_DIV > 1) ? (P_DIV / 2) : 1;
  localparam int unsigned LP_COUNTER_W  = (LP_HALF_DIV > 1) ? $clog2(LP_HALF_DIV) : 1;

  logic [LP_COUNTER_W-1:0] Count;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      Count <= '0;
      oTick <= 1'b0;
    end else if (!iEnable) begin
      Count <= '0;
      oTick <= 1'b0;
    end else if (Count == LP_COUNTER_W'(LP_HALF_DIV - 1)) begin
      Count <= '0;
      oTick <= 1'b1;
    end else begin
      Count <= Count + 1'b1;
      oTick <= 1'b0;
    end
  end

endmodule
