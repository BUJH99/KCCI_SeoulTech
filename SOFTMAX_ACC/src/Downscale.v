/*
[MODULE_INFO_START]
Name: Downscale
Role: Frame max-subtraction stage
Summary:
  - Converts FP32 input samples to Q7.8
  - Stores one frame and outputs sample-minus-max data
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module Downscale #(
    parameter integer P_C_MAX  = 1024,
    parameter integer P_ADDR_W = 10
)(
    input  wire         iClk,
    input  wire         iRstn,
    input  wire         iSValid,
    output wire         oSReady,
    input  wire [31:0]  iSData,
    input  wire         iSLast,
    output wire         oMValid,
    input  wire         iMReady,
    output wire [15:0]  oMData,
    output wire         oMLast
);
    wire signed [15:0] fp32Q78;
    wire               wrEn;
    wire [P_ADDR_W-1:0] wrAddr;
    wire               rdEn;
    wire [P_ADDR_W-1:0] rdAddr;
    wire               inHandshake;
    wire               startFirst;
    wire               memDataValid;
    wire               memDataLast;
    wire               outStageReady;
    wire signed [15:0] maxData;
    wire signed [15:0] ramData;
    wire signed [15:0] downscaleData;

    reg signed [15:0] outData;
    reg               outValid;
    reg               outLast;

    Fp32ToQ78 uFp32ToQ78 (
        .iFp32(iSData),
        .oQ78 (fp32Q78)
    );

    DownscaleFsm #(
        .P_C_MAX (P_C_MAX),
        .P_ADDR_W(P_ADDR_W)
    ) uDownscaleFsm (
        .iClk       (iClk),
        .iRstn      (iRstn),
        .iSValid    (iSValid),
        .iSLast     (iSLast),
        .iOutReady  (outStageReady),
        .oSReady    (oSReady),
        .oInHandshake    (inHandshake),
        .oStartFirst(startFirst),
        .oWrEn      (wrEn),
        .oWrAddr    (wrAddr),
        .oRdEn      (rdEn),
        .oRdAddr    (rdAddr),
        .oDataValid (memDataValid),
        .oDataLast  (memDataLast)
    );

    MaxTrack uMaxTrack (
        .iClk        (iClk),
        .iRstn       (iRstn),
        .iSampleValid(inHandshake),
        .iStartFirst (startFirst),
        .iData       (fp32Q78),
        .oMaxData    (maxData)
    );

    Q78Ram #(
        .P_DEPTH (P_C_MAX),
        .P_ADDR_W(P_ADDR_W)
    ) uQ78Ram (
        .iClk   (iClk),
        .iWrEn  (wrEn),
        .iWrAddr(wrAddr),
        .iWrData(fp32Q78),
        .iRdEn  (rdEn),
        .iRdAddr(rdAddr),
        .oRdData(ramData)
    );

    Q78SubSat uQ78SubSat (
        .iDataA(ramData),
        .iDataB(maxData),
        .oData (downscaleData)
    );

    assign outStageReady = !outValid || iMReady;

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            outData  <= 16'd0;
            outValid <= 1'b0;
            outLast  <= 1'b0;
        end else begin
            if (memDataValid) begin
                outData  <= downscaleData;
                outValid <= 1'b1;
                outLast  <= memDataLast;
            end else if (outValid && iMReady) begin
                outValid <= 1'b0;
                outLast  <= 1'b0;
            end
        end
    end

    assign oMData  = outData;
    assign oMValid = outValid;
    assign oMLast  = outLast;
endmodule
