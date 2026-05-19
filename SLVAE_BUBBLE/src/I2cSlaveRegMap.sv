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
  input  logic        iRstn,
  input  logic        iAddrMatched,
  input  logic [7:0]  iRegPtr,
  input  logic        iWriteBytePulse,
  input  logic [7:0]  iWriteByteData,
  input  logic        iReadByteStartPulse,
  input  logic [31:0] iSlaveId,
  input  logic [7:0]  iDisplayMode,
  input  logic [31:0] iStatus,
  input  logic [15:0] iLastFrameId,
  input  logic [15:0] iErrorCode,
  input  logic [7:0]  iBrightness,
  input  logic [15:0] iCompareCount,
  input  logic [15:0] iSwapCount,
  input  logic [15:0] iTotalCount,

  output logic [7:0]  oReadByteData,
  output logic        oDisplayModeWriteEn,
  output logic [7:0]  oDisplayModeWriteData,
  output logic        oBrightnessWriteEn,
  output logic [7:0]  oBrightnessWriteData,
  output logic [15:0] oErrorClearMask,
  output logic        oInvalidRegPulse
);

  logic readAddrValid;
  logic writeAddrValid;

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

  assign readAddrValid  = IsReadableAddr(iRegPtr);
  assign writeAddrValid = IsWritableAddr(iRegPtr);

  always_comb begin
    unique case (iRegPtr)
      8'h00:   oReadByteData = iSlaveId[7:0];
      8'h01:   oReadByteData = iSlaveId[15:8];
      8'h02:   oReadByteData = iSlaveId[23:16];
      8'h03:   oReadByteData = iSlaveId[31:24];
      8'h04:   oReadByteData = iDisplayMode;
      8'h08:   oReadByteData = iStatus[7:0];
      8'h09:   oReadByteData = iStatus[15:8];
      8'h0A:   oReadByteData = iStatus[23:16];
      8'h0B:   oReadByteData = iStatus[31:24];
      8'h0C:   oReadByteData = iLastFrameId[7:0];
      8'h0D:   oReadByteData = iLastFrameId[15:8];
      8'h10:   oReadByteData = iErrorCode[7:0];
      8'h11:   oReadByteData = iErrorCode[15:8];
      8'h14:   oReadByteData = iBrightness;
      8'h18:   oReadByteData = iCompareCount[7:0];
      8'h19:   oReadByteData = iCompareCount[15:8];
      8'h1C:   oReadByteData = iSwapCount[7:0];
      8'h1D:   oReadByteData = iSwapCount[15:8];
      8'h20:   oReadByteData = iTotalCount[7:0];
      8'h21:   oReadByteData = iTotalCount[15:8];
      default: oReadByteData = 8'd0;
    endcase
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oDisplayModeWriteEn   <= 1'b0;
      oDisplayModeWriteData <= '0;
      oBrightnessWriteEn    <= 1'b0;
      oBrightnessWriteData  <= '0;
      oErrorClearMask       <= '0;
      oInvalidRegPulse      <= 1'b0;
    end else begin
      oDisplayModeWriteEn <= 1'b0;
      oBrightnessWriteEn  <= 1'b0;
      oErrorClearMask     <= '0;
      oInvalidRegPulse    <= 1'b0;

      if (iReadByteStartPulse && !readAddrValid) begin
        oInvalidRegPulse <= iAddrMatched;
      end

      if (iWriteBytePulse) begin
        if (writeAddrValid) begin
          unique case (iRegPtr)
            8'h04: begin
              oDisplayModeWriteEn   <= iAddrMatched;
              oDisplayModeWriteData <= iWriteByteData;
            end

            8'h10: begin
              oErrorClearMask[7:0] <= iAddrMatched ? iWriteByteData : 8'd0;
            end

            8'h11: begin
              oErrorClearMask[15:8] <= iAddrMatched ? iWriteByteData : 8'd0;
            end

            8'h14: begin
              oBrightnessWriteEn   <= iAddrMatched;
              oBrightnessWriteData <= iWriteByteData;
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
