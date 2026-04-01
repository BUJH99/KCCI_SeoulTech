/*
[MODULE_INFO_START]
Name: U16ToFp32
Role: U0.16 to FP32 stream converter
Summary:
  - Converts U0.16 stream samples to IEEE-754 single precision
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module U16ToFp32(
    input  wire        iClk,
    input  wire        iRstn,
    input  wire        iSValid,
    output wire        oSReady,
    input  wire [15:0] iSData,
    input  wire        iSLast,
    output wire        oMValid,
    input  wire        iMReady,
    output wire [31:0] oMData,
    output wire        oMLast
);
    localparam integer LP_U16_W          = 16;
    localparam integer LP_FP32_W         = 32;
    localparam integer LP_FP32_EXP_W     = 8;
    localparam integer LP_FP32_FRAC_W    = 23;
    localparam integer LP_INPUT_MSB      = LP_U16_W - 1;
    localparam [LP_FP32_EXP_W-1:0] LP_FP32_EXP_BIAS = 8'd127;
    localparam integer LP_U16_FRAC_W     = 16;
    localparam [LP_FP32_EXP_W-1:0] LP_EXP_OFFSET    = LP_FP32_EXP_BIAS - LP_U16_FRAC_W;
    localparam integer LP_FRAC_ZERO_W    = LP_FP32_FRAC_W - (LP_U16_W - 1);
    localparam [LP_FP32_W-1:0] LP_FP32_ZERO = {LP_FP32_W{1'b0}};

    function [31:0] fnU16ToFp32;
        input [LP_U16_W-1:0] iValue;
        integer idxBit;
        integer msbIdx;
        reg     msbFound;
        reg [LP_FP32_EXP_W-1:0]  exponent;
        reg [LP_FP32_FRAC_W-1:0] fraction;
        reg [LP_U16_W-1:0] normShiftData;
    begin
        if (iValue == {LP_U16_W{1'b0}}) begin
            fnU16ToFp32 = LP_FP32_ZERO;
        end else begin
            msbFound = 1'b0;
            msbIdx   = 0;
            for (idxBit = LP_INPUT_MSB; idxBit >= 0; idxBit = idxBit - 1) begin
                if (!msbFound && iValue[idxBit]) begin
                    msbIdx   = idxBit;
                    msbFound = 1'b1;
                end
            end

            exponent      = msbIdx[LP_FP32_EXP_W-1:0] + LP_EXP_OFFSET;
            normShiftData = iValue << (LP_INPUT_MSB - msbIdx[4:0]);
            fraction      = {normShiftData[LP_INPUT_MSB-1:0], {LP_FRAC_ZERO_W{1'b0}}};
            fnU16ToFp32 = {1'b0, exponent, fraction};
        end
    end
    endfunction

    // Handshake signals pass through unchanged. This block only converts the
    // stream data format from U0.16 into IEEE-754 single precision.
    assign oSReady = iMReady;
    assign oMValid = iSValid;
    assign oMLast  = iSLast;
    assign oMData  = fnU16ToFp32(iSData);
endmodule
