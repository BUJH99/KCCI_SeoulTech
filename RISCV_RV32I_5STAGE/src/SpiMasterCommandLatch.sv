/*
[MODULE_INFO_START]
Name: SpiMasterCommandLatch
Role: START validator and command/config latch for the SPI master core
Summary:
  - Accepts only the mode0, MSB-first, 24-byte, CS0-enabled trace frame contract
  - Latches frame length, clock divider, and chip-select config at each idle START attempt
  - Emits APB-visible mode-error and dropped-frame pulses without owning frame sequencing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiMasterCommandLatch (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iEn,
  input  logic        iStartPulse,
  input  logic        iCpol,
  input  logic        iCpha,
  input  logic        iLsbFirst,
  input  logic [7:0]  iFrameLen,
  input  logic [15:0] iClkDiv,
  input  logic [7:0]  iCsCtrl,
  input  logic        iStartIdleWindow,
  input  logic        iStartDropWindow,

  output logic        oStartAttemptPulse,
  output logic        oStartAcceptedPulse,
  output logic [7:0]  oFrameLenLatch,
  output logic [15:0] oClkDivLatch,
  output logic [7:0]  oCsCtrlLatch,
  output logic        oModeErrPulse,
  output logic        oFrameDroppedPulse
);

  localparam logic [7:0] LP_SORT_FRAME_LEN = 8'd24;

  logic CmdValid;

  assign CmdValid        = iEn && !iCpol && !iCpha && !iLsbFirst
                             && (iFrameLen == LP_SORT_FRAME_LEN) && iCsCtrl[0];
  assign oStartAttemptPulse  = iStartPulse && iStartIdleWindow;
  assign oStartAcceptedPulse = oStartAttemptPulse && CmdValid;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      oFrameLenLatch      <= LP_SORT_FRAME_LEN;
      oClkDivLatch        <= '0;
      oCsCtrlLatch        <= 8'h01;
      oModeErrPulse     <= 1'b0;
      oFrameDroppedPulse  <= 1'b0;
    end else begin
      oModeErrPulse    <= iStartPulse && iStartIdleWindow && !CmdValid;
      oFrameDroppedPulse <= iStartPulse && iStartDropWindow;

      if (oStartAttemptPulse) begin
        oFrameLenLatch <= iFrameLen;
        oClkDivLatch   <= iClkDiv;
        oCsCtrlLatch   <= iCsCtrl;
      end
    end
  end

endmodule
