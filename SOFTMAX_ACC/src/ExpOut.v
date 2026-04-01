/*
[MODULE_INFO_START]
Name: ExpOut
Role: Exponential approximation stage for output probability
Summary:
  - Approximates exp(x) for the probability output path
  - Maintains Valid/Ready/Last alignment through the pipeline
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module ExpOut(
    input  wire         iClk,
    input  wire         iRstn,
    input  wire         iValid,
    output wire         oReady,
    input  wire         iLast,
    input  wire signed [15:0] iData,
    output wire         oValid,
    input  wire         iReady,
    output wire         oLast,
    output wire [15:0]  oData
);
    localparam integer LP_DATA_W = 16;
    localparam integer LP_ABS_W  = LP_DATA_W + 1;
    localparam integer LP_MUL_W  = 32;
    localparam [LP_DATA_W-1:0] LP_Q78_MAX_MAG = 16'h7FFF;
    localparam [LP_DATA_W-1:0] LP_ZERO_DATA   = 16'h0000;

    function [15:0] fnAbsSatQ78;
        input signed [15:0] iValue;
        reg [LP_ABS_W-1:0] absValueWide;
    begin
        if (iValue[15])
            absValueWide = {1'b0, ~iValue} + {{LP_DATA_W{1'b0}}, 1'b1};
        else
            absValueWide = {1'b0, iValue};

        if (absValueWide > {1'b0, LP_Q78_MAX_MAG})
            fnAbsSatQ78 = LP_Q78_MAX_MAG;
        else
            fnAbsSatQ78 = absValueWide[LP_DATA_W-1:0];
    end
    endfunction

    reg [LP_DATA_W-1:0] lutCoeffHigh;
    reg [LP_DATA_W-1:0] lutCoeffMid;
    reg [LP_DATA_W-1:0] lutCoeffLow;

    reg [LP_DATA_W-1:0] stage1CoeffHigh;
    reg [LP_DATA_W-1:0] stage1CoeffMid;
    reg [LP_DATA_W-1:0] stage1CoeffLow;
    reg                 stage1Valid;
    reg                 stage1Last;

    reg [LP_DATA_W-1:0] stage2CoeffHigh;
    reg [LP_DATA_W-1:0] stage2ProdMidLow;
    reg                 stage2Valid;
    reg                 stage2Last;

    reg [LP_DATA_W-1:0] stage3ExpData;
    reg                 stage3Valid;
    reg                 stage3Last;

    wire [LP_DATA_W-1:0] absMagnitude  = fnAbsSatQ78(iData);
    wire                 useHighCoeff  = (absMagnitude[14:12] == 3'b000);
    wire [LP_MUL_W-1:0]  prodMidLow    = stage1CoeffMid * stage1CoeffLow;
    wire [LP_MUL_W-1:0]  prodHighScale = stage2CoeffHigh * stage2ProdMidLow;
    wire                 stage3Ready   = !stage3Valid || iReady;
    wire                 stage2Ready   = !stage2Valid || stage3Ready;
    wire                 stage1Ready   = !stage1Valid || stage2Ready;

    always @* begin
        case (absMagnitude[11:8])
            4'b1111: lutCoeffHigh = LP_ZERO_DATA;
            4'b1110: lutCoeffHigh = LP_ZERO_DATA;
            4'b1101: lutCoeffHigh = LP_ZERO_DATA;
            4'b1100: lutCoeffHigh = LP_ZERO_DATA;
            4'b1011: lutCoeffHigh = LP_ZERO_DATA;
            4'b1010: lutCoeffHigh = 16'h0002;
            4'b1001: lutCoeffHigh = 16'h0008;
            4'b1000: lutCoeffHigh = 16'h0016;
            4'b0111: lutCoeffHigh = 16'h003B;
            4'b0110: lutCoeffHigh = 16'h00A2;
            4'b0101: lutCoeffHigh = 16'h01B9;
            4'b0100: lutCoeffHigh = 16'h04B0;
            4'b0011: lutCoeffHigh = 16'h0CBE;
            4'b0010: lutCoeffHigh = 16'h22A5;
            4'b0001: lutCoeffHigh = 16'h5E2D;
            default: lutCoeffHigh = 16'hFFFF;
        endcase
    end

    always @* begin
        case (absMagnitude[7:4])
            4'b1111: lutCoeffMid = 16'h643F;
            4'b1110: lutCoeffMid = 16'h6AB7;
            4'b1101: lutCoeffMid = 16'h7199;
            4'b1100: lutCoeffMid = 16'h78ED;
            4'b1011: lutCoeffMid = 16'h80B9;
            4'b1010: lutCoeffMid = 16'h8907;
            4'b1001: lutCoeffMid = 16'h91DD;
            4'b1000: lutCoeffMid = 16'h9B46;
            4'b0111: lutCoeffMid = 16'hA547;
            4'b0110: lutCoeffMid = 16'hAFF1;
            4'b0101: lutCoeffMid = 16'hBB4A;
            4'b0100: lutCoeffMid = 16'hC75F;
            4'b0011: lutCoeffMid = 16'hD43A;
            4'b0010: lutCoeffMid = 16'hE1EB;
            4'b0001: lutCoeffMid = 16'hF07D;
            default: lutCoeffMid = 16'hFFFF;
        endcase
    end

    always @* begin
        case (absMagnitude[3:0])
            4'b1111: lutCoeffLow = 16'hF16D;
            4'b1110: lutCoeffLow = 16'hF260;
            4'b1101: lutCoeffLow = 16'hF352;
            4'b1100: lutCoeffLow = 16'hF447;
            4'b1011: lutCoeffLow = 16'hF53A;
            4'b1010: lutCoeffLow = 16'hF631;
            4'b1001: lutCoeffLow = 16'hF727;
            4'b1000: lutCoeffLow = 16'hF820;
            4'b0111: lutCoeffLow = 16'hF916;
            4'b0110: lutCoeffLow = 16'hFA11;
            4'b0101: lutCoeffLow = 16'hFB0B;
            4'b0100: lutCoeffLow = 16'hFC08;
            4'b0011: lutCoeffLow = 16'hFD03;
            4'b0010: lutCoeffLow = 16'hFE02;
            4'b0001: lutCoeffLow = 16'hFF00;
            default: lutCoeffLow = 16'hFFFF;
        endcase
    end

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            stage1CoeffHigh <= LP_ZERO_DATA;
            stage1CoeffMid  <= LP_ZERO_DATA;
            stage1CoeffLow  <= LP_ZERO_DATA;
            stage1Valid <= 1'b0;
            stage1Last  <= 1'b0;
            stage2CoeffHigh <= LP_ZERO_DATA;
            stage2ProdMidLow <= LP_ZERO_DATA;
            stage2Valid <= 1'b0;
            stage2Last  <= 1'b0;
            stage3ExpData <= LP_ZERO_DATA;
            stage3Valid <= 1'b0;
            stage3Last  <= 1'b0;
        end else begin
            if (stage3Ready) begin
                stage3Valid <= stage2Valid;
                if (stage2Valid) begin
                    stage3ExpData <= prodHighScale[31:16];
                    stage3Last <= stage2Last;
                end
            end

            if (stage2Ready) begin
                stage2Valid <= stage1Valid;
                if (stage1Valid) begin
                    stage2CoeffHigh <= stage1CoeffHigh;
                    stage2ProdMidLow <= prodMidLow[31:16];
                    stage2Last <= stage1Last;
                end
            end

            if (stage1Ready) begin
                stage1Valid <= iValid;
                if (iValid) begin
                    if (useHighCoeff)
                        stage1CoeffHigh <= lutCoeffHigh;
                    else
                        stage1CoeffHigh <= LP_ZERO_DATA;
                    stage1CoeffMid <= lutCoeffMid;
                    stage1CoeffLow <= lutCoeffLow;
                    stage1Last     <= iLast;
                end
            end
        end
    end

    assign oReady = stage1Ready;
    assign oValid = stage3Valid;
    assign oLast  = stage3Last;
    assign oData  = stage3ExpData;
endmodule
