/*
[MODULE_INFO_START]
Name: Fp32ToQ78
Role: FP32 to Q7.8 converter
Summary:
  - Converts one IEEE-754 single-precision value to signed Q7.8
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module Fp32ToQ78(
    input  wire [31:0]        iFp32,
    output reg  signed [15:0] oQ78
);
    localparam integer LP_FP32_EXP_W    = 8;
    localparam integer LP_FP32_MANT_W   = 23;
    localparam integer LP_Q78_FRAC_W    = 8;
    localparam integer LP_SHIFT_BIAS    = 127 + LP_FP32_MANT_W - LP_Q78_FRAC_W;
    localparam integer LP_WIDE_W        = 32;
    localparam integer LP_SHIFT_MAX     = LP_WIDE_W - 1;
    localparam [LP_FP32_EXP_W-1:0] LP_EXP_ZERO = 8'h00;
    localparam [LP_FP32_EXP_W-1:0] LP_EXP_INF  = 8'hFF;
    localparam signed [15:0] LP_Q78_MAX = 16'sd32767;
    localparam signed [15:0] LP_Q78_MIN = -16'sd32768;
    localparam signed [LP_WIDE_W-1:0] LP_Q78_MAX_WIDE = 32'sd32767;
    localparam signed [LP_WIDE_W-1:0] LP_Q78_MIN_WIDE = -32'sd32768;
    localparam signed [LP_WIDE_W-1:0] LP_SCALED_SAT   = 32'sh7FFF_FFFF;

    wire                     isNegative     = iFp32[31];
    wire [LP_FP32_EXP_W-1:0] exponent       = iFp32[30:23];
    wire [LP_FP32_MANT_W-1:0] mantissa      = iFp32[22:0];
    wire [LP_FP32_MANT_W:0]   mantWithHidden = {1'b1, mantissa};
    wire                     isZeroExp      = (exponent == LP_EXP_ZERO);
    wire                     isSpecialExp   = (exponent == LP_EXP_INF);

    integer shift;
    integer rightShift;
    reg signed [LP_WIDE_W-1:0] scaledAbs;
    reg signed [LP_WIDE_W-1:0] scaledValue;

    always @* begin
        shift       = 0;
        rightShift  = 0;
        scaledAbs   = {LP_WIDE_W{1'b0}};
        scaledValue = {LP_WIDE_W{1'b0}};
        oQ78        = 16'sd0;

        if (isSpecialExp) begin
            oQ78 = isNegative ? LP_Q78_MIN : LP_Q78_MAX;
        end else if (isZeroExp) begin
            oQ78 = 16'sd0;
        end else begin
            // Convert the FP32 exponent into the shift needed for Q7.8.
            shift = $signed({1'b0, exponent}) - LP_SHIFT_BIAS;

            if (shift >= 0) begin
                if (shift > LP_SHIFT_MAX)
                    scaledAbs = LP_SCALED_SAT;
                else
                    scaledAbs = $signed({1'b0, mantWithHidden}) << shift;
            end else begin
                rightShift = -shift;
                if (rightShift >= LP_WIDE_W)
                    scaledAbs = {LP_WIDE_W{1'b0}};
                else if (rightShift == 0)
                    scaledAbs = $signed({1'b0, mantWithHidden});
                else
                    scaledAbs = ($signed({1'b0, mantWithHidden}) + (32'sd1 << (rightShift - 1))) >>> rightShift;
            end

            if (isNegative)
                scaledValue = -scaledAbs;
            else
                scaledValue = scaledAbs;

            if (scaledValue > LP_Q78_MAX_WIDE)
                oQ78 = LP_Q78_MAX;
            else if (scaledValue < LP_Q78_MIN_WIDE)
                oQ78 = LP_Q78_MIN;
            else
                oQ78 = scaledValue[15:0];
        end
    end
endmodule
