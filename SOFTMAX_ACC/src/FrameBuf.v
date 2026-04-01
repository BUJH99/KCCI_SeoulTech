/*
[MODULE_INFO_START]
Name: FrameBuf
Role: Single-clock frame buffer
Summary:
  - Buffers frame data with one-cycle registered read latency
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module FrameBuf #(
    parameter integer P_DATA_WIDTH = 16,
    parameter integer P_ADDR_W     = 8
)(
    input  wire                      iClk,
    input  wire                      iRstn,
    input  wire [P_DATA_WIDTH-1:0]   iWrData,
    input  wire                      iWrEn,
    input  wire [P_ADDR_W-1:0]       iWrAddr,
    input  wire                      iRdEn,
    input  wire [P_ADDR_W-1:0]       iRdAddr,
    output reg                       oRdValid,
    output reg  [P_DATA_WIDTH-1:0]   oRdData
);
    localparam integer LP_DEPTH = (1 << P_ADDR_W);

    reg [P_DATA_WIDTH-1:0] memBuffer [0:LP_DEPTH-1];

    always @(posedge iClk) begin
        if (iWrEn)
            memBuffer[iWrAddr] <= iWrData;
    end

    always @(posedge iClk) begin
        if (!iRstn) begin
            oRdValid <= 1'b0;
            oRdData  <= {P_DATA_WIDTH{1'b0}};
        end else begin
            oRdValid <= iRdEn;
            if (iRdEn) begin
                if (iWrEn && (iWrAddr == iRdAddr))
                    oRdData <= iWrData;
                else
                    oRdData <= memBuffer[iRdAddr];
            end
        end
    end
endmodule
