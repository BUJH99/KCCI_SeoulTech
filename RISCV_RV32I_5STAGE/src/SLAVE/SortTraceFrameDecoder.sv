/*
[MODULE_INFO_START]
Name: SortTraceFrameDecoder
Role: Decoder for v1 24-byte Bubble Sort trace frames received over SPI
Summary:
  - Validates magic, version, fixed length, and XOR Checksum for each trace frame
  - Extracts 8-bit phase/flags/index fields and 16-bit frame/counter fields
  - Emits dedicated pulses for accepted, Checksum-error, format-error, and short-frame outcomes
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SortTraceFrameDecoder (
  input  logic       iClk,
  input  logic       iRst,
  input  logic [7:0] iByteData,
  input  logic       iByteValidPulse,
  input  logic       iFrameStartPulse,
  input  logic       iFrameEndPulse,
  input  logic       iShortFramePulse,

  output logic        oFrameValidPulse,
  output logic        oChecksumErrPulse,
  output logic        oFormatErrPulse,
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
  output logic [15:0] oCompareCnt,
  output logic [15:0] oSwapCnt,
  output logic [15:0] oTotalCnt,
  output logic [7:0]  oStatusCode
);

  localparam int unsigned LP_FRAME_BYTES = 24;
  localparam logic [5:0]  LP_FRAME_BYTES_CNT = 6'd24;
  localparam logic [7:0]  LP_MAGIC0      = 8'hA5;
  localparam logic [7:0]  LP_MAGIC1      = 8'h5A;
  localparam logic [7:0]  LP_VERSION     = 8'h01;

  logic [7:0] MemFrame [0:LP_FRAME_BYTES-1];
  logic [5:0] ByteIdx;
  logic [7:0] Checksum;
  logic       ChecksumOk;
  logic       FormatOk;

  assign ChecksumOk = (Checksum == iByteData);
  assign FormatOk   = (MemFrame[0] == LP_MAGIC0) && (MemFrame[1] == LP_MAGIC1) && (MemFrame[2] == LP_VERSION);

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      ByteIdx             <= '0;
      Checksum            <= '0;
      oFrameValidPulse    <= 1'b0;
      oChecksumErrPulse <= 1'b0;
      oFormatErrPulse   <= 1'b0;
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
      oCompareCnt       <= '0;
      oSwapCnt          <= '0;
      oTotalCnt         <= '0;
      oStatusCode         <= '0;
    end else begin
      oFrameValidPulse    <= 1'b0;
      oChecksumErrPulse <= 1'b0;
      oFormatErrPulse   <= 1'b0;
      oShortFramePulse    <= 1'b0;

      if (iFrameStartPulse) begin
        ByteIdx  <= '0;
        Checksum <= '0;
      end

      if (iByteValidPulse && (ByteIdx < LP_FRAME_BYTES_CNT)) begin
        MemFrame[ByteIdx[4:0]] <= iByteData;

        if (ByteIdx < 6'd23) begin
          Checksum <= Checksum ^ iByteData;
          ByteIdx  <= ByteIdx + 1'b1;
        end else begin
          if (ChecksumOk && FormatOk) begin
            oFrameValidPulse <= 1'b1;
            oFrameId         <= {MemFrame[5], MemFrame[4]};
            oFrameType       <= MemFrame[3];
            oPhase           <= MemFrame[6];
            oFlags           <= MemFrame[7];
            oArrayLen        <= MemFrame[8];
            oPassIdx         <= MemFrame[9];
            oCompareIdx      <= MemFrame[10];
            oLeftIdx         <= MemFrame[11];
            oRightIdx        <= MemFrame[12];
            oLeftValue       <= MemFrame[13];
            oRightValue      <= MemFrame[14];
            oChangedIdx      <= MemFrame[15];
            oCompareCnt    <= {MemFrame[17], MemFrame[16]};
            oSwapCnt       <= {MemFrame[19], MemFrame[18]};
            oTotalCnt      <= {MemFrame[21], MemFrame[20]};
            oStatusCode      <= MemFrame[22];
          end else if (!ChecksumOk) begin
            oChecksumErrPulse <= 1'b1;
          end else begin
            oFormatErrPulse <= 1'b1;
          end
          ByteIdx <= LP_FRAME_BYTES_CNT;
        end
      end

      if (iShortFramePulse || (iFrameEndPulse && (ByteIdx != LP_FRAME_BYTES_CNT))) begin
        oShortFramePulse <= 1'b1;
      end
    end
  end

endmodule
