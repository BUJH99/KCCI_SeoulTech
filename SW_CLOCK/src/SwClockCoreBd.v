/*
[MODULE_INFO_START]
Name: SwClockCoreBd
Role: Vivado block-design module-reference shim for the SystemVerilog SW_CLOCK core
Summary:
  - Provides a plain-Verilog wrapper for BD module reference support
  - Delegates button debounce and FND scan behavior to the SystemVerilog TOP module
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SwClockCoreBd #(
    parameter integer P_CLK_HZ      = 100_000_000,
    parameter integer P_SCAN_HZ     = 1000,
    parameter integer P_DEBOUNCE_MS = 20
) (
    input  wire        iClk,
    input  wire        iRstn,
    input  wire [31:0] iDisplayWord,
    input  wire [3:0]  iBtnRaw,

    output wire [7:0]  oButtonStatus,
    output wire [6:0]  oSeg,
    output wire        oDp,
    output wire [3:0]  oDigitSel
);

    TOP #(
        .P_CLK_HZ     (P_CLK_HZ),
        .P_SCAN_HZ    (P_SCAN_HZ),
        .P_DEBOUNCE_MS(P_DEBOUNCE_MS)
    ) uTOP (
        .iClk         (iClk),
        .iRstn        (iRstn),
        .iDisplayWord (iDisplayWord),
        .iBtnRaw      (iBtnRaw),
        .oButtonStatus(oButtonStatus),
        .oSeg         (oSeg),
        .oDp          (oDp),
        .oDigitSel    (oDigitSel)
    );

endmodule
