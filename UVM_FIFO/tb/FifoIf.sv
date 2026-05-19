`timescale 1ns / 1ps

interface FifoIf #(
    parameter int Width = 4
) (
    input logic iClk,
    input logic iRstn
);

    logic [Width-1:0] iData;
    logic             Wr_En;
    logic             Rd_En;
    logic [Width-1:0] oData;
    logic             Full;
    logic             Empty;

    clocking drv_cb @(posedge iClk);
        default input #1step output #0;
        output iData;
        output Wr_En;
        output Rd_En;
        input  iRstn;
        input  oData;
        input  Full;
        input  Empty;
    endclocking

    clocking mon_cb @(posedge iClk);
        default input #0 output #0;
        input iData;
        input Wr_En;
        input Rd_En;
        input iRstn;
        input oData;
        input Full;
        input Empty;
    endclocking

    modport dut (
        input  iClk,
        input  iRstn,
        input  iData,
        input  Wr_En,
        input  Rd_En,
        output oData,
        output Full,
        output Empty
    );

endinterface
