/*
[MODULE_INFO_START]
Name: DownscaleFsm
Role: Frame capture and replay controller
Summary:
  - Accepts one input frame into memory
  - Replays the stored frame for max subtraction
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module DownscaleFsm #(
    parameter integer P_C_MAX  = 1024,
    parameter integer P_ADDR_W = 10
)(
    input  wire                iClk,
    input  wire                iRstn,
    input  wire                iSValid,
    input  wire                iSLast,
    input  wire                iOutReady,
    output wire                oSReady,
    output wire                oInHandshake,
    output reg                 oStartFirst,
    output reg                 oWrEn,
    output reg  [P_ADDR_W-1:0] oWrAddr,
    output reg                 oRdEn,
    output reg  [P_ADDR_W-1:0] oRdAddr,
    output wire                oDataValid,
    output wire                oDataLast
);
    localparam integer LP_STATE_W = 2;
    localparam integer LP_COUNT_W = $clog2(P_C_MAX + 1);
    localparam [LP_STATE_W-1:0] IDLE         = 2'd0;
    localparam [LP_STATE_W-1:0] FILL         = 2'd1;
    localparam [LP_STATE_W-1:0] DRAIN        = 2'd2;
    localparam [P_ADDR_W-1:0]   LP_ADDR_ZERO = {P_ADDR_W{1'b0}};
    localparam [LP_COUNT_W-1:0] LP_COUNT_ZERO = {LP_COUNT_W{1'b0}};
    localparam [LP_COUNT_W-1:0] LP_COUNT_ONE  = {{(LP_COUNT_W-1){1'b0}}, 1'b1};
    localparam [LP_COUNT_W-1:0] LP_FRAME_MAX  = P_C_MAX;

    function [P_ADDR_W-1:0] fnIncAddr;
        input [P_ADDR_W-1:0] iAddr;
    begin
        if (iAddr == (P_C_MAX - 1))
            fnIncAddr = {P_ADDR_W{1'b0}};
        else
            fnIncAddr = iAddr + 1'b1;
    end
    endfunction

    reg [LP_STATE_W-1:0] state;
    reg [LP_STATE_W-1:0] state_d;
    reg [P_ADDR_W-1:0] ptrWr;
    reg [P_ADDR_W-1:0] ptrWr_d;
    reg [P_ADDR_W-1:0] ptrRd;
    reg [P_ADDR_W-1:0] ptrRd_d;
    reg [LP_COUNT_W-1:0] cntWr;
    reg [LP_COUNT_W-1:0] cntWr_d;
    reg [LP_COUNT_W-1:0] cntRd;
    reg [LP_COUNT_W-1:0] cntRd_d;
    reg [LP_COUNT_W-1:0] frameLen;
    reg [LP_COUNT_W-1:0] frameLen_d;
    reg                  dataValid_d1;
    reg                  dataLast_d1;

    wire [LP_COUNT_W-1:0] cntWrInc;
    wire [LP_COUNT_W-1:0] cntRdInc;
    wire                  captureDone;
    wire                  drainBusy;
    wire                  drainHandshake;
    wire                  drainDone;

    assign cntWrInc   = cntWr + LP_COUNT_ONE;
    assign cntRdInc   = cntRd + LP_COUNT_ONE;
    assign captureDone = oInHandshake && (iSLast || (cntWrInc == LP_FRAME_MAX));
    assign drainBusy   = (cntRd < frameLen);
    // Allow only one RAM read response to be in flight at a time. Without
    // this guard, a stalled downstream can cause the next replay beat to
    // overwrite the current beat before it is accepted.
    assign drainHandshake   = iOutReady && drainBusy && !dataValid_d1;
    assign drainDone   = !drainBusy && !dataValid_d1;

    assign oSReady    = ((state == IDLE) || (state == FILL)) && (cntWr < P_C_MAX);
    assign oInHandshake    = iSValid && oSReady;
    assign oDataValid = dataValid_d1;
    assign oDataLast  = dataLast_d1;

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            state      <= IDLE;
            ptrWr      <= LP_ADDR_ZERO;
            ptrRd      <= LP_ADDR_ZERO;
            cntWr      <= LP_COUNT_ZERO;
            cntRd      <= LP_COUNT_ZERO;
            frameLen   <= LP_COUNT_ZERO;
            dataValid_d1 <= 1'b0;
            dataLast_d1  <= 1'b0;
        end else begin
            state      <= state_d;
            ptrWr      <= ptrWr_d;
            ptrRd      <= ptrRd_d;
            cntWr      <= cntWr_d;
            cntRd      <= cntRd_d;
            frameLen   <= frameLen_d;
            dataValid_d1 <= oRdEn;
            if (oRdEn)
                dataLast_d1 <= (cntRdInc == frameLen);
            else
                dataLast_d1 <= 1'b0;
        end
    end

    always @* begin
        state_d     = state;
        ptrWr_d     = ptrWr;
        ptrRd_d     = ptrRd;
        cntWr_d     = cntWr;
        cntRd_d     = cntRd;
        frameLen_d  = frameLen;
        oStartFirst = 1'b0;
        oWrEn       = 1'b0;
        oWrAddr     = ptrWr;
        oRdEn       = 1'b0;
        oRdAddr     = ptrRd;

        case (state)
            // IDLE and FILL share the same capture path. IDLE only flags
            // the first accepted sample of a frame for the max tracker.
            IDLE, FILL: begin
                if (oInHandshake) begin
                    oStartFirst = (state == IDLE);
                    oWrEn       = 1'b1;
                    oWrAddr     = ptrWr;
                    ptrWr_d     = fnIncAddr(ptrWr);
                    cntWr_d     = cntWrInc;
                    if (captureDone) begin
                        frameLen_d = cntWrInc;
                        ptrRd_d    = LP_ADDR_ZERO;
                        cntRd_d    = LP_COUNT_ZERO;
                        state_d    = DRAIN;
                    end else if (state == IDLE) begin
                        state_d = FILL;
                    end
                end
            end

            DRAIN: begin
                if (drainHandshake) begin
                    oRdEn   = 1'b1;
                    oRdAddr = ptrRd;
                    ptrRd_d = fnIncAddr(ptrRd);
                    cntRd_d = cntRdInc;
                end else if (drainDone) begin
                    // Wait for the final RAM read response before clearing
                    // state and counters for the next input frame.
                    state_d    = IDLE;
                    ptrWr_d    = LP_ADDR_ZERO;
                    ptrRd_d    = LP_ADDR_ZERO;
                    cntWr_d    = LP_COUNT_ZERO;
                    cntRd_d    = LP_COUNT_ZERO;
                    frameLen_d = LP_COUNT_ZERO;
                end
            end

            default: begin
                state_d = IDLE;
            end
        endcase
    end


endmodule
