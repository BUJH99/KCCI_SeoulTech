/*
[MODULE_INFO_START]
Name: SpiSlaveFrameTracker
Role: SPI SLAVE frame boundary and length tracker
Summary:
  - Emits frame-start and frame-end pulses from synchronized CS edges
  - Counts captured bytes within a CS assertion
  - Flags short or partial frames without inspecting frame payload contents
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiSlaveFrameTracker #(
  parameter int unsigned P_FRAME_BYTES = 24
) (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic       iCsRise,
  input  logic       iCsFall,
  input  logic       iByteValidPulse,
  input  logic [2:0] iBitCnt,

  output logic       oFrameStartPulse,
  output logic       oFrameEndPulse,
  output logic       oShortFramePulse
);

  localparam logic [5:0] LP_FRAME_BYTES = 6'(P_FRAME_BYTES);

  logic [5:0] byteCnt;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      byteCnt          <= '0;
      oFrameStartPulse <= 1'b0;
      oFrameEndPulse   <= 1'b0;
      oShortFramePulse <= 1'b0;
    end else begin
      oFrameStartPulse <= 1'b0;
      oFrameEndPulse   <= 1'b0;
      oShortFramePulse <= 1'b0;

      if (iCsFall) begin
        byteCnt          <= '0;
        oFrameStartPulse <= 1'b1;
      end else if (iCsRise) begin
        oFrameEndPulse <= 1'b1;
        if ((byteCnt != LP_FRAME_BYTES) || (iBitCnt != 3'd0)) begin
          oShortFramePulse <= 1'b1;
        end
      end else if (iByteValidPulse) begin
        byteCnt <= byteCnt + 1'b1;
      end
    end
  end

endmodule
