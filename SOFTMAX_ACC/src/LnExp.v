/*
[MODULE_INFO_START]
Name: LnExp
Role: Exponent LUT for ln approximation
Summary:
  - Provides the ln(2) * exponent contribution for the log path
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module LnExp (
    input  wire [4:0]         iAddr,
    output reg  signed [15:0] oData
);
    // Lookup table for the exponent contribution of ln(x).

    always @* begin
        case (iAddr)
            5'd0:  oData = -16'sd21293;
            5'd1:  oData = -16'sd19874;
            5'd2:  oData = -16'sd18454;
            5'd3:  oData = -16'sd17035;
            5'd4:  oData = -16'sd15615;
            5'd5:  oData = -16'sd14196;
            5'd6:  oData = -16'sd12776;
            5'd7:  oData = -16'sd11357;
            5'd8:  oData = -16'sd9937;
            5'd9:  oData = -16'sd8517;
            5'd10: oData = -16'sd7098;
            5'd11: oData = -16'sd5678;
            5'd12: oData = -16'sd4259;
            5'd13: oData = -16'sd2839;
            5'd14: oData = -16'sd1420;
            5'd15: oData = 16'sd0;
            5'd16: oData = 16'sd1420;
            5'd17: oData = 16'sd2839;
            5'd18: oData = 16'sd4259;
            5'd19: oData = 16'sd5678;
            5'd20: oData = 16'sd7098;
            5'd21: oData = 16'sd8517;
            5'd22: oData = 16'sd9937;
            5'd23: oData = 16'sd11357;
            5'd24: oData = 16'sd12776;
            5'd25: oData = 16'sd14196;
            5'd26: oData = 16'sd15615;
            5'd27: oData = 16'sd17035;
            5'd28: oData = 16'sd18454;
            5'd29: oData = 16'sd19874;
            5'd30: oData = 16'sd21293;
            5'd31: oData = 16'sd22713;
            default: oData = 16'sd0;
        endcase
    end
endmodule
