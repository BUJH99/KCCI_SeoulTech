/*
[MODULE_INFO_START]
Name: MaxTrack
Role: Frame maximum tracker
Summary:
  - Tracks the maximum signed Q7.8 sample within a frame
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module MaxTrack(
    input  wire               iClk,
    input  wire               iRstn,
    input  wire               iSampleValid,
    input  wire               iStartFirst,
    input  wire signed [15:0] iData,
    output reg  signed [15:0] oMaxData
);
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            oMaxData <= 16'sd0;
        end else if (iSampleValid) begin
            if (iStartFirst || ($signed(iData) > $signed(oMaxData)))
                oMaxData <= iData;
        end
    end
endmodule
