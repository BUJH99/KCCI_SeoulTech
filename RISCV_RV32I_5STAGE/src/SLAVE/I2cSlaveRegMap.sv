/*
[MODULE_INFO_START]
Name: I2cSlaveRegMap
Role: Register map decoder for the SLAVE I2C target
Summary:
  - Owns readable/writable byte-address legality and read data muxing
  - Emits DISPLAY_MODE, BRIGHTNESS, and ERROR_CODE W1C write pulses
  - Flags invalid register accesses without owning I2C bus timing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveRegMap (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iAddrMatched,
  input  logic [7:0]  iRegPtr,
  input  logic        iWrBytePulse,
  input  logic [7:0]  iWrByteData,
  input  logic        iRdByteStartPulse,
  input  logic [31:0] iSlaveId,
  input  logic [7:0]  iDisplayMode,
  input  logic [31:0] iStatus,
  input  logic [15:0] iLastFrameId,
  input  logic [15:0] iErrCode,
  input  logic [7:0]  iBrightness,
  input  logic [15:0] iCompareCnt,
  input  logic [15:0] iSwapCnt,
  input  logic [15:0] iTotalCnt,

  output logic [7:0]  oRdByteData,
  output logic        oDisplayModeWrEn,
  output logic [7:0]  oDisplayModeWrData,
  output logic        oBrightnessWrEn,
  output logic [7:0]  oBrightnessWrData,
  output logic [15:0] oErrClearMask,
  output logic        oInvalidRegPulse
);

  logic RdAddrValid;
  logic WrAddrValid;

  function automatic logic IsReadableAddr(input logic [7:0] iRegAddr);
    begin
      unique case (iRegAddr)
        8'h00, 8'h01, 8'h02, 8'h03,
        8'h04,
        8'h08, 8'h09, 8'h0A, 8'h0B,
        8'h0C, 8'h0D,
        8'h10, 8'h11,
        8'h14,
        8'h18, 8'h19,
        8'h1C, 8'h1D,
        8'h20, 8'h21: IsReadableAddr = 1'b1;
        default:       IsReadableAddr = 1'b0;
      endcase
    end
  endfunction

  function automatic logic IsWritableAddr(input logic [7:0] iRegAddr);
    begin
      unique case (iRegAddr)
        8'h04,
        8'h10, 8'h11,
        8'h14:  IsWritableAddr = 1'b1;
        default: IsWritableAddr = 1'b0;
      endcase
    end
  endfunction

  assign RdAddrValid  = IsReadableAddr(iRegPtr);
  assign WrAddrValid = IsWritableAddr(iRegPtr);

  always_comb begin
    unique case (iRegPtr)
      8'h00:   oRdByteData = iSlaveId[7:0];
      8'h01:   oRdByteData = iSlaveId[15:8];
      8'h02:   oRdByteData = iSlaveId[23:16];
      8'h03:   oRdByteData = iSlaveId[31:24];
      8'h04:   oRdByteData = iDisplayMode;
      8'h08:   oRdByteData = iStatus[7:0];
      8'h09:   oRdByteData = iStatus[15:8];
      8'h0A:   oRdByteData = iStatus[23:16];
      8'h0B:   oRdByteData = iStatus[31:24];
      8'h0C:   oRdByteData = iLastFrameId[7:0];
      8'h0D:   oRdByteData = iLastFrameId[15:8];
      8'h10:   oRdByteData = iErrCode[7:0];
      8'h11:   oRdByteData = iErrCode[15:8];
      8'h14:   oRdByteData = iBrightness;
      8'h18:   oRdByteData = iCompareCnt[7:0];
      8'h19:   oRdByteData = iCompareCnt[15:8];
      8'h1C:   oRdByteData = iSwapCnt[7:0];
      8'h1D:   oRdByteData = iSwapCnt[15:8];
      8'h20:   oRdByteData = iTotalCnt[7:0];
      8'h21:   oRdByteData = iTotalCnt[15:8];
      default: oRdByteData = 8'd0;
    endcase
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      oDisplayModeWrEn   <= 1'b0;
      oDisplayModeWrData <= '0;
      oBrightnessWrEn    <= 1'b0;
      oBrightnessWrData  <= '0;
      oErrClearMask       <= '0;
      oInvalidRegPulse      <= 1'b0;
    end else begin
      oDisplayModeWrEn <= 1'b0;
      oBrightnessWrEn  <= 1'b0;
      oErrClearMask     <= '0;
      oInvalidRegPulse    <= 1'b0;

      if (iRdByteStartPulse && !RdAddrValid) begin
        oInvalidRegPulse <= iAddrMatched;
      end

      if (iWrBytePulse) begin
        if (WrAddrValid) begin
          unique case (iRegPtr)
            8'h04: begin
              oDisplayModeWrEn   <= iAddrMatched;
              oDisplayModeWrData <= iWrByteData;
            end

            8'h10: begin
              oErrClearMask[7:0] <= iAddrMatched ? iWrByteData : 8'd0;
            end

            8'h11: begin
              oErrClearMask[15:8] <= iAddrMatched ? iWrByteData : 8'd0;
            end

            8'h14: begin
              oBrightnessWrEn   <= iAddrMatched;
              oBrightnessWrData <= iWrByteData;
            end

            default: begin
            end
          endcase
        end else begin
          oInvalidRegPulse <= iAddrMatched;
        end
      end
    end
  end

endmodule
