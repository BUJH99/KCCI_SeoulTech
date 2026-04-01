/*
[MODULE_INFO_START]
Name: Sum
Role: Frame accumulator stage
Summary:
  - Accumulates one frame of exponential terms
  - Emits the packed frame sum on the last sample
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module Sum(
    input  wire         iClk,
    input  wire         iRstn,
    input  wire         iValid,
    output wire         oReady,
    input  wire         iLast,
    input  wire [15:0]  iData,
    output wire         oValid,
    input  wire         iReady,
    output wire [15:0]  oData
);
    localparam integer LP_DATA_W     = 16;
    localparam integer LP_ACC_W      = 27;
    localparam integer LP_EXT_W      = LP_ACC_W - LP_DATA_W;
    localparam integer LP_SHIFT_BITS = 11;
    localparam [LP_DATA_W-1:0] LP_ZERO_DATA = {LP_DATA_W{1'b0}};
    localparam [LP_ACC_W-1:0]  LP_ZERO_ACC  = {LP_ACC_W{1'b0}};
    localparam [LP_ACC_W-1:0]  LP_ROUND_BIAS = 27'd1024;

    reg [LP_ACC_W-1:0]  sumAcc;
    reg [LP_DATA_W-1:0] outData;
    reg        outValid;

    wire                  inHandshake       = iValid && oReady;
    wire [LP_ACC_W-1:0]   dataExtAcc   = {{LP_EXT_W{1'b0}}, iData};
    wire [LP_ACC_W-1:0]   sumAcc_d     = sumAcc + dataExtAcc;
    wire [LP_ACC_W-1:0]   sumRoundAcc  = sumAcc_d + LP_ROUND_BIAS;
    wire [LP_DATA_W-1:0]  sumRoundedQ78 = sumRoundAcc[LP_ACC_W-1:LP_SHIFT_BITS];

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            sumAcc   <= LP_ZERO_ACC;
            outData  <= LP_ZERO_DATA;
            outValid <= 1'b0;
        end else begin
            if (outValid && iReady)
                outValid <= 1'b0;

            // Accumulate each accepted sample and emit the rounded frame sum
            // when the final sample of the frame arrives.
            if (inHandshake) begin
                sumAcc <= sumAcc_d;
                if (iLast) begin
                    outData  <= sumRoundedQ78;
                    outValid <= 1'b1;
                    sumAcc   <= LP_ZERO_ACC;
                end
            end
        end
    end

    assign oReady = !outValid || iReady;
    assign oValid = outValid;
    assign oData  = outData;
endmodule
