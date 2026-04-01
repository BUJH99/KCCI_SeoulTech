/*
[MODULE_INFO_START]
Name: Q78Ram
Role: Single-port Q7.8 sample RAM
Summary:
  - Stores signed Q7.8 frame data with registered read address
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module Q78Ram #(
    parameter integer P_DEPTH  = 1024,
    parameter integer P_ADDR_W = 10
)(
    input  wire                 iClk,
    input  wire                 iWrEn,
    input  wire [P_ADDR_W-1:0]  iWrAddr,
    input  wire signed [15:0]   iWrData,
    input  wire                 iRdEn,
    input  wire [P_ADDR_W-1:0]  iRdAddr,
    output reg  signed [15:0]   oRdData
);
    reg signed [15:0] memQ78 [0:P_DEPTH-1];

    always @(posedge iClk) begin
        if (iWrEn)
            memQ78[iWrAddr] <= iWrData;
    end

    always @(posedge iClk) begin
        if (iRdEn) begin
            if (iWrEn && (iWrAddr == iRdAddr))
                oRdData <= iWrData;
            else
                oRdData <= memQ78[iRdAddr];
        end
    end
endmodule
