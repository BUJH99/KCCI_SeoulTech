/*
[MODULE_INFO_START]
Name: SortTraceFrameDecoder
Role: Decoder for compact Bubble Sort trace frames received over SPI
Summary:
  - Freezes the v1 frame as 12 bytes ending in an XOR checksum
  - Extracts frame ID, phase, pass/compare indices, values, swap flag, and counters
  - Emits a frame-valid pulse or checksum-error pulse at frame boundary
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SortTraceFrameDecoder (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic [7:0] iByteData,
  input  logic       iByteValidPulse,

  output logic       oFrameValidPulse,
  output logic       oChecksumErrorPulse,
  output logic [7:0] oFrameId,
  output logic [2:0] oPhase,
  output logic [7:0] oPassIdx,
  output logic [7:0] oCompareIdx,
  output logic [7:0] oLeftValue,
  output logic [7:0] oRightValue,
  output logic       oSwapFlag,
  output logic [7:0] oChangedIndex,
  output logic [7:0] oCompareCount,
  output logic [7:0] oSwapCount,
  output logic [7:0] oTotalCount
);

  localparam int unsigned LP_FRAME_BYTES = 12;

  logic [3:0] ByteIdx;
  logic [7:0] Checksum;
  logic [7:0] FrameId_d;
  logic [2:0] Phase_d;
  logic [7:0] PassIdx_d;
  logic [7:0] CompareIdx_d;
  logic [7:0] LeftValue_d;
  logic [7:0] RightValue_d;
  logic       SwapFlag_d;
  logic [7:0] ChangedIndex_d;
  logic [7:0] CompareCount_d;
  logic [7:0] SwapCount_d;
  logic [7:0] TotalCount_d;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      ByteIdx             <= '0;
      Checksum            <= '0;
      FrameId_d           <= '0;
      Phase_d             <= '0;
      PassIdx_d           <= '0;
      CompareIdx_d        <= '0;
      LeftValue_d         <= '0;
      RightValue_d        <= '0;
      SwapFlag_d          <= 1'b0;
      ChangedIndex_d      <= '0;
      CompareCount_d      <= '0;
      SwapCount_d         <= '0;
      TotalCount_d        <= '0;
      oFrameValidPulse    <= 1'b0;
      oChecksumErrorPulse <= 1'b0;
      oFrameId            <= '0;
      oPhase              <= '0;
      oPassIdx            <= '0;
      oCompareIdx         <= '0;
      oLeftValue          <= '0;
      oRightValue         <= '0;
      oSwapFlag           <= 1'b0;
      oChangedIndex       <= '0;
      oCompareCount       <= '0;
      oSwapCount          <= '0;
      oTotalCount         <= '0;
    end else begin
      oFrameValidPulse    <= 1'b0;
      oChecksumErrorPulse <= 1'b0;

      if (iByteValidPulse) begin
        unique case (ByteIdx)
          4'd0:  FrameId_d      <= iByteData;
          4'd1:  Phase_d        <= iByteData[2:0];
          4'd2:  PassIdx_d      <= iByteData;
          4'd3:  CompareIdx_d   <= iByteData;
          4'd4:  LeftValue_d    <= iByteData;
          4'd5:  RightValue_d   <= iByteData;
          4'd6:  SwapFlag_d     <= iByteData[0];
          4'd7:  ChangedIndex_d <= iByteData;
          4'd8:  CompareCount_d <= iByteData;
          4'd9:  SwapCount_d    <= iByteData;
          4'd10: TotalCount_d   <= iByteData;
          default: begin
          end
        endcase

        if (ByteIdx == 4'(LP_FRAME_BYTES - 1)) begin
          if (Checksum == iByteData) begin
            oFrameValidPulse <= 1'b1;
            oFrameId         <= FrameId_d;
            oPhase           <= Phase_d;
            oPassIdx         <= PassIdx_d;
            oCompareIdx      <= CompareIdx_d;
            oLeftValue       <= LeftValue_d;
            oRightValue      <= RightValue_d;
            oSwapFlag        <= SwapFlag_d;
            oChangedIndex    <= ChangedIndex_d;
            oCompareCount    <= CompareCount_d;
            oSwapCount       <= SwapCount_d;
            oTotalCount      <= TotalCount_d;
          end else begin
            oChecksumErrorPulse <= 1'b1;
          end

          ByteIdx  <= '0;
          Checksum <= '0;
        end else begin
          Checksum <= Checksum ^ iByteData;
          ByteIdx  <= ByteIdx + 1'b1;
        end
      end
    end
  end

endmodule
