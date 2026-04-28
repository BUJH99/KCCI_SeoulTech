/*
[MODULE_INFO_START]
Name: Timer10ms
Role: Sticky poll timer for the MasterSequencer
Summary:
  - Counts fabric clock cycles until the programmed polling interval expires
  - Holds oExpired high until the sequencer explicitly clears it
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module Timer10ms #(
  parameter int unsigned P_CYCLES = 1_000_000
) (
  input  logic iClk,
  input  logic iRst,
  input  logic iClr,
  output logic oExpired
);

  localparam int unsigned LP_COUNTER_W = (P_CYCLES > 1) ? $clog2(P_CYCLES) : 1;

  logic [LP_COUNTER_W-1:0] Count;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      Count    <= '0;
      oExpired <= 1'b0;
    end else if (iClr) begin
      Count    <= '0;
      oExpired <= 1'b0;
    end else if (!oExpired) begin
      if (Count == LP_COUNTER_W'(P_CYCLES - 1)) begin
        Count    <= Count;
        oExpired <= 1'b1;
      end else begin
        Count    <= Count + 1'b1;
        oExpired <= 1'b0;
      end
    end
  end

endmodule
