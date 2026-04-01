/*
[MODULE_INFO_START]
Name: Counter
Role: Wrap-around counter utility
Summary:
  - Counts with clear and increment controls
  - Wraps to zero at the configured terminal value
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module Counter #(
    parameter integer P_WIDTH      = 8,
    parameter integer P_WRAP_VALUE = 255
)(
    input  wire                 iClk,
    input  wire                 iRstn,
    input  wire                 iClr,
    input  wire                 iInc,
    output reg  [P_WIDTH-1:0]   oCnt
);
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            oCnt <= {P_WIDTH{1'b0}};
        end else if (iClr) begin
            oCnt <= {P_WIDTH{1'b0}};
        end else if (iInc) begin
            if (oCnt == P_WRAP_VALUE[P_WIDTH-1:0])
                oCnt <= {P_WIDTH{1'b0}};
            else
                oCnt <= oCnt + 1'b1;
        end
    end
endmodule
