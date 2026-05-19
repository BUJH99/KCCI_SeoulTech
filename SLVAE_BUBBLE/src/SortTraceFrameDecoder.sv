/*
[MODULE_INFO_START]
Name: SortTraceFrameDecoder
Role: Decoder for v1 24-byte Bubble Sort trace frames received over SPI
Summary:
  - Validates magic, version, fixed length, and XOR checksum for each trace frame
  - Extracts 8-bit phase/flags/index fields and 16-bit frame/counter fields
  - Emits dedicated pulses for accepted, checksum-error, format-error, and short-frame outcomes
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SortTraceFrameDecoder (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic [7:0] iByteData,
  input  logic       iByteValidPulse,
  input  logic       iFrameStartPulse,
  input  logic       iFrameEndPulse,
  input  logic       iShortFramePulse,

  output logic        oFrameValidPulse,
  output logic        oChecksumErrorPulse,
  output logic        oFormatErrorPulse,
  output logic        oShortFramePulse,
  output logic [15:0] oFrameId,
  output logic [7:0]  oFrameType,
  output logic [7:0]  oPhase,
  output logic [7:0]  oFlags,
  output logic [7:0]  oArrayLen,
  output logic [7:0]  oPassIdx,
  output logic [7:0]  oCompareIdx,
  output logic [7:0]  oLeftIdx,
  output logic [7:0]  oRightIdx,
  output logic [7:0]  oLeftValue,
  output logic [7:0]  oRightValue,
  output logic [7:0]  oChangedIdx,
  output logic [15:0] oCompareCount,
  output logic [15:0] oSwapCount,
  output logic [15:0] oTotalCount,
  output logic [7:0]  oStatusCode
);

  localparam int unsigned LP_FRAME_BYTES = 24;
  localparam logic [5:0]  LP_FRAME_BYTES_CNT = 6'd24;
  localparam logic [7:0]  LP_MAGIC0      = 8'hA5;
  localparam logic [7:0]  LP_MAGIC1      = 8'h5A;
  localparam logic [7:0]  LP_VERSION     = 8'h01;

  logic [7:0] memFrame [0:LP_FRAME_BYTES-1];
  logic [5:0] byteIdx;
  logic [7:0] checksum;
  logic       checksumOk;
  logic       formatOk;

  assign checksumOk = (checksum == iByteData);
  assign formatOk   = (memFrame[0] == LP_MAGIC0) && (memFrame[1] == LP_MAGIC1) && (memFrame[2] == LP_VERSION);

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      byteIdx             <= '0;
      checksum            <= '0;
      oFrameValidPulse    <= 1'b0;
      oChecksumErrorPulse <= 1'b0;
      oFormatErrorPulse   <= 1'b0;
      oShortFramePulse    <= 1'b0;
      oFrameId            <= '0;
      oFrameType          <= '0;
      oPhase              <= '0;
      oFlags              <= '0;
      oArrayLen           <= '0;
      oPassIdx            <= '0;
      oCompareIdx         <= '0;
      oLeftIdx            <= '0;
      oRightIdx           <= '0;
      oLeftValue          <= '0;
      oRightValue         <= '0;
      oChangedIdx         <= '0;
      oCompareCount       <= '0;
      oSwapCount          <= '0;
      oTotalCount         <= '0;
      oStatusCode         <= '0;
    end else begin
      oFrameValidPulse    <= 1'b0;
      oChecksumErrorPulse <= 1'b0;
      oFormatErrorPulse   <= 1'b0;
      oShortFramePulse    <= 1'b0;

      if (iFrameStartPulse) begin
        byteIdx  <= '0;
        checksum <= '0;
      end

      if (iByteValidPulse && (byteIdx < LP_FRAME_BYTES_CNT)) begin
        memFrame[byteIdx[4:0]] <= iByteData;

        if (byteIdx < 6'd23) begin
          checksum <= checksum ^ iByteData;
          byteIdx  <= byteIdx + 1'b1;
        end else begin
          if (checksumOk && formatOk) begin
            oFrameValidPulse <= 1'b1;
            oFrameId         <= {memFrame[5], memFrame[4]};
            oFrameType       <= memFrame[3];
            oPhase           <= memFrame[6];
            oFlags           <= memFrame[7];
            oArrayLen        <= memFrame[8];
            oPassIdx         <= memFrame[9];
            oCompareIdx      <= memFrame[10];
            oLeftIdx         <= memFrame[11];
            oRightIdx        <= memFrame[12];
            oLeftValue       <= memFrame[13];
            oRightValue      <= memFrame[14];
            oChangedIdx      <= memFrame[15];
            oCompareCount    <= {memFrame[17], memFrame[16]};
            oSwapCount       <= {memFrame[19], memFrame[18]};
            oTotalCount      <= {memFrame[21], memFrame[20]};
            oStatusCode      <= memFrame[22];
          end else if (!checksumOk) begin
            oChecksumErrorPulse <= 1'b1;
          end else begin
            oFormatErrorPulse <= 1'b1;
          end
          byteIdx <= LP_FRAME_BYTES_CNT;
        end
      end

      if (iShortFramePulse || (iFrameEndPulse && (byteIdx != LP_FRAME_BYTES_CNT))) begin
        oShortFramePulse <= 1'b1;
      end
    end
  end

endmodule
