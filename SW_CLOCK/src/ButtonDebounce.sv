/*
[MODULE_INFO_START]
Name: ButtonDebounce
Role: Button synchronizer and debounce filter
Summary:
  - Synchronizes raw board buttons into iClk
  - Updates the stable button vector only after it remains unchanged for P_DEBOUNCE_MS
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ButtonDebounce #(
  parameter int unsigned P_WIDTH       = 4,
  parameter int unsigned P_CLK_HZ      = 100_000_000,
  parameter int unsigned P_DEBOUNCE_MS = 20
) (
  input  logic               iClk,
  input  logic               iRstn,
  input  logic [P_WIDTH-1:0] iBtnRaw,

  output logic [P_WIDTH-1:0] oBtnStable,
  output logic [P_WIDTH-1:0] oBtnRawSync
);

  localparam int unsigned LP_CYCLES_PER_MS   = (P_CLK_HZ >= 1000) ? (P_CLK_HZ / 1000) : 1;
  localparam int unsigned LP_DEBOUNCE_CYCLES = (LP_CYCLES_PER_MS * P_DEBOUNCE_MS);
  localparam int unsigned LP_CNT_WIDTH       = (LP_DEBOUNCE_CYCLES > 1) ? $clog2(LP_DEBOUNCE_CYCLES) : 1;

  localparam logic [LP_CNT_WIDTH-1:0] LP_DEBOUNCE_LAST =
      LP_CNT_WIDTH'((LP_DEBOUNCE_CYCLES > 0) ? (LP_DEBOUNCE_CYCLES - 1) : 0);

  logic [P_WIDTH-1:0] btnMeta;
  logic [P_WIDTH-1:0] btnSync;
  logic [P_WIDTH-1:0] btnSample;
  logic [LP_CNT_WIDTH-1:0] debounceCnt;

  assign oBtnRawSync = btnSync;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      btnMeta     <= '0;
      btnSync     <= '0;
      btnSample   <= '0;
      debounceCnt <= '0;
      oBtnStable  <= '0;
    end else begin
      btnMeta <= iBtnRaw;
      btnSync <= btnMeta;

      if (btnSync != btnSample) begin
        btnSample   <= btnSync;
        debounceCnt <= '0;
      end else if (debounceCnt == LP_DEBOUNCE_LAST) begin
        oBtnStable <= btnSample;
      end else begin
        debounceCnt <= debounceCnt + 1'b1;
      end
    end
  end

endmodule
