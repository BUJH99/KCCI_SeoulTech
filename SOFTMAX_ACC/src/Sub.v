/*
[MODULE_INFO_START]
Name: Sub
Role: Frame normalization stage
Summary:
  - Stores one downscaled frame and waits for the scalar term
  - Replays the frame and subtracts the normalization scalar
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module Sub #(
    parameter integer P_C_MAX  = 1024,
    parameter integer P_ADDR_W = 10
)(
    input  wire                iClk,
    input  wire                iRstn,
    input  wire [15:0]         iVectorData,
    input  wire                iVectorValid,
    input  wire                iVectorLast,
    output wire                oVectorReady,
    input  wire [15:0]         iScalarData,
    input  wire                iScalarValid,
    output wire                oScalarReady,
    output reg  [15:0]         oData,
    output reg                 oDataValid,
    input  wire                iDataReady,
    output reg                 oDataLast
);
    localparam integer LP_COUNT_W = $clog2(P_C_MAX + 1);

    function [P_ADDR_W-1:0] fnIncAddr;
        input [P_ADDR_W-1:0] iAddr;
    begin
        if (iAddr == (P_C_MAX - 1))
            fnIncAddr = {P_ADDR_W{1'b0}};
        else
            fnIncAddr = iAddr + 1'b1;
    end
    endfunction

    reg [P_ADDR_W-1:0]  ptrWr;
    reg [P_ADDR_W-1:0]  ptrRd;
    reg [LP_COUNT_W-1:0] cntWr;
    reg [LP_COUNT_W-1:0] cntRd;
    reg [LP_COUNT_W-1:0] frameLen;
    reg [15:0]          scalarData;
    reg                 frameStored;
    reg                 busy;
    reg                 readPending;
    reg                 pendingLast;

    wire                vectorHandshake;
    wire                scalarHandshake;
    wire                readReq;
    wire                bufferValid;
    wire [15:0]         bufferData;
    wire [15:0]         subtractData;
    wire                outputHandshake;

    assign oVectorReady = !frameStored && !busy && (cntWr < P_C_MAX);
    assign oScalarReady = frameStored && !busy;
    assign vectorHandshake  = iVectorValid && oVectorReady;
    assign scalarHandshake  = iScalarValid && oScalarReady;
    assign readReq     = busy && !readPending && !oDataValid && (cntRd < frameLen);
    assign outputHandshake  = oDataValid && iDataReady;

    FrameBuf #(
        .P_DATA_WIDTH(16),
        .P_ADDR_W    (P_ADDR_W)
    ) uFrameBuf (
        .iClk   (iClk),
        .iRstn  (iRstn),
        .iWrData(iVectorData),
        .iWrEn  (vectorHandshake),
        .iWrAddr(ptrWr),
        .iRdEn  (readReq),
        .iRdAddr(ptrRd),
        .oRdValid(bufferValid),
        .oRdData (bufferData)
    );

    Q78SubSat uQ78SubSat (
        .iDataA(bufferData),
        .iDataB(scalarData),
        .oData (subtractData)
    );

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            ptrWr      <= {P_ADDR_W{1'b0}};
            ptrRd      <= {P_ADDR_W{1'b0}};
            cntWr     <= {LP_COUNT_W{1'b0}};
            cntRd     <= {LP_COUNT_W{1'b0}};
            frameLen    <= {LP_COUNT_W{1'b0}};
            scalarData  <= 16'd0;
            frameStored <= 1'b0;
            busy        <= 1'b0;
            readPending <= 1'b0;
            pendingLast <= 1'b0;
            oData        <= 16'd0;
            oDataValid   <= 1'b0;
            oDataLast    <= 1'b0;
        end else begin
            if (vectorHandshake) begin
                ptrWr  <= fnIncAddr(ptrWr);
                cntWr <= cntWr + 1'b1;
                if (iVectorLast || (cntWr == (P_C_MAX - 1))) begin
                    frameLen    <= cntWr + 1'b1;
                    frameStored <= 1'b1;
                end
            end

            if (scalarHandshake) begin
                scalarData  <= iScalarData;
                busy        <= 1'b1;
                ptrRd      <= {P_ADDR_W{1'b0}};
                cntRd     <= {LP_COUNT_W{1'b0}};
                readPending <= 1'b0;
                pendingLast <= 1'b0;
            end

            if (readReq) begin
                readPending <= 1'b1;
                pendingLast <= (cntRd == (frameLen - 1'b1));
                ptrRd      <= fnIncAddr(ptrRd);
                cntRd     <= cntRd + 1'b1;
            end

            if (bufferValid) begin
                oData      <= subtractData;
                oDataValid <= 1'b1;
                oDataLast  <= pendingLast;
                readPending <= 1'b0;
            end

            if (outputHandshake) begin
                oDataValid <= 1'b0;
                if (oDataLast) begin
                    oDataLast    <= 1'b0;
                    ptrWr      <= {P_ADDR_W{1'b0}};
                    ptrRd      <= {P_ADDR_W{1'b0}};
                    cntWr     <= {LP_COUNT_W{1'b0}};
                    cntRd     <= {LP_COUNT_W{1'b0}};
                    frameLen    <= {LP_COUNT_W{1'b0}};
                    frameStored <= 1'b0;
                    busy        <= 1'b0;
                    readPending <= 1'b0;
                    pendingLast <= 1'b0;
                end
            end
        end
    end
endmodule
