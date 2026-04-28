/*
[MODULE_INFO_START]
Name: SwGpioCoreBd
Role: Vivado block-design module-reference shim for the SystemVerilog SW_GPIO core
Summary:
  - Provides a plain-Verilog top file for Vivado BD module reference support
  - Delegates all counter and FND behavior to the SystemVerilog Top module
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SwGpioCoreBd #(
    parameter integer P_CLK_HZ   = 100_000_000,
    parameter integer P_COUNT_HZ = 1
) (
    input  wire        iClk,
    input  wire        iRstn,
    input  wire [1:0]  iGpioCtrl,

    output wire [6:0]  oSeg,
    output wire        oDp,
    output wire [3:0]  oDigitSel,
    output wire [31:0] oGpioStatus
);

    Top #(
        .P_CLK_HZ  (P_CLK_HZ),
        .P_COUNT_HZ(P_COUNT_HZ)
    ) uTop (
        .iClk       (iClk),
        .iRstn      (iRstn),
        .iGpioCtrl  (iGpioCtrl),
        .oSeg       (oSeg),
        .oDp        (oDp),
        .oDigitSel  (oDigitSel),
        .oGpioStatus(oGpioStatus)
    );

endmodule
