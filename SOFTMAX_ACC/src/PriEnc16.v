/*
[MODULE_INFO_START]
Name: PriEnc16
Role: Priority encoder utility
Summary:
  - Returns the MSB position of a 16-bit input value
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module PriEnc16(
    input  wire [15:0] iData,
    output reg  [3:0]  oPos,
    output reg         oZero
);
    wire hasUpperByte       = |iData[15:8];
    wire hasUpperNibble     = |iData[15:12];
    wire hasMidUpperNibble  = |iData[11:8];
    wire hasLowerByte       = |iData[7:0];
    wire hasMidLowerNibble  = |iData[7:4];

    always @* begin
        oPos  = 4'd0;
        oZero = (iData == 16'd0);

        // Search from MSB to LSB by narrowing byte -> nibble -> bit.
        if (hasUpperByte) begin
            if (hasUpperNibble) begin
                if (iData[15])
                    oPos = 4'd15;
                else if (iData[14])
                    oPos = 4'd14;
                else if (iData[13])
                    oPos = 4'd13;
                else
                    oPos = 4'd12;
            end else if (hasMidUpperNibble) begin
                if (iData[11])
                    oPos = 4'd11;
                else if (iData[10])
                    oPos = 4'd10;
                else if (iData[9])
                    oPos = 4'd9;
                else
                    oPos = 4'd8;
            end
        end else if (hasLowerByte) begin
            if (hasMidLowerNibble) begin
                if (iData[7])
                    oPos = 4'd7;
                else if (iData[6])
                    oPos = 4'd6;
                else if (iData[5])
                    oPos = 4'd5;
                else
                    oPos = 4'd4;
            end else begin
                if (iData[3])
                    oPos = 4'd3;
                else if (iData[2])
                    oPos = 4'd2;
                else if (iData[1])
                    oPos = 4'd1;
                else
                    oPos = 4'd0;
            end
        end
    end
endmodule
