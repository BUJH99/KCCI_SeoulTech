/*
[MODULE_INFO_START]
Name: ReadFsm
Role: Frame read sequencer utility
Summary:
  - Generates sequential read requests across one stored frame
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module ReadFsm #(
    parameter integer P_ADDR_W  = 10,
    parameter integer P_COUNT_W = 11
)(
    input  wire                   iClk,
    input  wire                   iRstn,
    input  wire                   iStart,
    input  wire [P_COUNT_W-1:0]   iFrameLen,
    input  wire                   iStepReady,
    output reg                    oRdEn,
    output reg  [P_ADDR_W-1:0]    oRdAddr,
    output reg                    oBusy,
    output reg                    oLast
);
    reg [P_ADDR_W-1:0]  ptrRd;
    reg [P_COUNT_W-1:0] cntRd;

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            ptrRd   <= {P_ADDR_W{1'b0}};
            cntRd  <= {P_COUNT_W{1'b0}};
            oRdEn   <= 1'b0;
            oRdAddr <= {P_ADDR_W{1'b0}};
            oBusy   <= 1'b0;
            oLast   <= 1'b0;
        end else begin
            oRdEn <= 1'b0;
            oLast <= 1'b0;

            if (iStart) begin
                ptrRd  <= {P_ADDR_W{1'b0}};
                cntRd <= {P_COUNT_W{1'b0}};
                oBusy  <= (iFrameLen != {P_COUNT_W{1'b0}});
            end else if (oBusy && iStepReady) begin
                oRdEn   <= 1'b1;
                oRdAddr <= ptrRd;
                oLast   <= (cntRd == (iFrameLen - 1'b1));
                ptrRd   <= ptrRd + 1'b1;
                cntRd  <= cntRd + 1'b1;
                if (cntRd == (iFrameLen - 1'b1))
                    oBusy <= 1'b0;
            end
        end
    end
endmodule
