/*
[MODULE_INFO_START]
Name: Ln
Role: Natural-log approximation stage
Summary:
  - Approximates ln(x) for the accumulated frame sum
  - Uses exponent and mantissa LUT stages
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module Ln(
    input  wire                iClk,
    input  wire                iRstn,
    input  wire                iValid,
    output wire                oReady,
    input  wire [15:0]         iData,
    output wire                oValid,
    input  wire                iReady,
    output wire signed [15:0]  oData
);
    localparam integer LP_DATA_W       = 16;
    localparam integer LP_EXP_ADDR_W   = 5;
    localparam integer LP_MANT_ADDR_W  = 10;
    localparam integer LP_ACC_W        = 21;
    localparam integer LP_ALIGN_SHIFT  = 5;
    localparam integer LP_OUT_FRAC_W   = 8;
    localparam integer LP_INPUT_MSB    = LP_DATA_W - 1;
    localparam integer LP_MANT_MSB     = 14;
    localparam integer LP_MANT_LSB     = 5;
    localparam integer LP_SIGN_EXT_W   = LP_DATA_W - (LP_ACC_W - LP_OUT_FRAC_W);
    localparam [LP_EXP_ADDR_W-1:0]  LP_EXP_BIAS      = 5'd10;
    localparam [LP_EXP_ADDR_W-1:0]  LP_ZERO_EXP_ADDR = {LP_EXP_ADDR_W{1'b0}};
    localparam [LP_MANT_ADDR_W-1:0] LP_ZERO_MANT_ADDR = {LP_MANT_ADDR_W{1'b0}};
    localparam signed [LP_DATA_W-1:0] LP_ZERO_DATA = {LP_DATA_W{1'b0}};

    wire stage4Ready;
    wire stage3Ready;
    wire stage2Ready;
    wire stage1Ready;

    reg                       stage1Valid;
    reg [LP_EXP_ADDR_W-1:0]   stage1ExpAddr;
    reg [LP_MANT_ADDR_W-1:0]  stage1MantAddr;

    reg                      stage2Valid;
    reg signed [LP_DATA_W-1:0] stage2ExpTerm;
    reg        [LP_DATA_W-1:0] stage2MantTerm;

    reg                      stage3Valid;
    reg signed [LP_DATA_W-1:0] stage3LnData;

    reg                      stage4Valid;
    reg signed [LP_DATA_W-1:0] stage4LnData;

    wire [3:0]                 msbIdx;
    wire                       isInputZero;
    wire [LP_EXP_ADDR_W-1:0]   expAddrCalc  = msbIdx + LP_EXP_BIAS;
    wire [LP_DATA_W-1:0]       normShiftData = iData << (LP_INPUT_MSB - msbIdx);
    wire [LP_MANT_ADDR_W-1:0]  mantAddrCalc = normShiftData[LP_MANT_MSB:LP_MANT_LSB];
    wire [LP_MANT_ADDR_W-1:0]  lnMantAddr   = stage1MantAddr;
    wire signed [LP_DATA_W-1:0] lnExpTerm;
    wire        [LP_DATA_W-1:0] lnMantTerm;
    wire signed [LP_ACC_W-1:0] expTermQ4p16 = {stage2ExpTerm, {LP_ALIGN_SHIFT{1'b0}}};
    wire signed [LP_ACC_W-1:0] mantTermQ4p16 = {{LP_ALIGN_SHIFT{1'b0}}, stage2MantTerm};
    wire signed [LP_ACC_W-1:0] lnSumQ4p16 = expTermQ4p16 + mantTermQ4p16;
    wire signed [LP_DATA_W-1:0] lnRoundQ78 =
        {{LP_SIGN_EXT_W{lnSumQ4p16[LP_ACC_W-1]}}, lnSumQ4p16[LP_ACC_W-1:LP_OUT_FRAC_W]} +
        lnSumQ4p16[LP_OUT_FRAC_W-1];

    assign stage4Ready = !stage4Valid || iReady;
    assign stage3Ready = !stage3Valid || stage4Ready;
    assign stage2Ready = !stage2Valid || stage3Ready;
    assign stage1Ready = !stage1Valid || stage2Ready;

    PriEnc16 uPriEnc16 (
        .iData(iData),
        .oPos (msbIdx),
        .oZero(isInputZero)
    );

    LnExp uLnExp (
        .iAddr(stage1ExpAddr),
        .oData(lnExpTerm)
    );

    LnMant uLnMant (
        .iAddr(lnMantAddr),
        .oData(lnMantTerm)
    );

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            stage1Valid     <= 1'b0;
            stage2Valid     <= 1'b0;
            stage3Valid     <= 1'b0;
            stage4Valid     <= 1'b0;
            stage1ExpAddr   <= LP_ZERO_EXP_ADDR;
            stage1MantAddr  <= LP_ZERO_MANT_ADDR;
            stage2ExpTerm   <= LP_ZERO_DATA;
            stage2MantTerm  <= LP_ZERO_DATA;
            stage3LnData    <= LP_ZERO_DATA;
            stage4LnData    <= LP_ZERO_DATA;
        end else begin
            // Stage 4: hold the rounded ln result for the output handshake.
            if (stage4Ready) begin
                stage4Valid <= stage3Valid;
                if (stage3Valid)
                    stage4LnData <= stage3LnData;
            end

            // Stage 3: round the accumulated Q4.16 sum into Q7.8 output data.
            if (stage3Ready) begin
                stage3Valid <= stage2Valid;
                if (stage2Valid)
                    stage3LnData <= lnRoundQ78;
            end

            // Stage 2: capture LUT results for the exponent and mantissa terms.
            if (stage2Ready) begin
                stage2Valid <= stage1Valid;
                if (stage1Valid) begin
                    stage2ExpTerm  <= lnExpTerm;
                    stage2MantTerm <= lnMantTerm;
                end
            end

            // Stage 1: build LUT addresses from the normalized input value.
            if (stage1Ready) begin
                stage1Valid <= iValid;
                if (iValid) begin
                    if (isInputZero) begin
                        stage1ExpAddr  <= LP_ZERO_EXP_ADDR;
                        stage1MantAddr <= LP_ZERO_MANT_ADDR;
                    end else begin
                        stage1ExpAddr  <= expAddrCalc;
                        stage1MantAddr <= mantAddrCalc;
                    end
                end
            end
        end
    end

    assign oReady = stage1Ready;
    assign oValid = stage4Valid;
    assign oData  = stage4LnData;
endmodule
