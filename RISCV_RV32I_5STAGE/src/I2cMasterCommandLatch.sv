/*
[MODULE_INFO_START]
Name: I2cMasterCommandLatch
Role: APB command latch for the I2C master transaction core
Summary:
  - Validates START eligibility from enable, length, and busy state
  - Latches register transaction fields on each START write
  - Emits accepted/invalid START pulses while keeping command fields separate from bus sequencing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterCommandLatch (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iEn,
  input  logic        iStartPulse,
  input  logic        iBusy,
  input  logic        iStartIdleWindow,
  input  logic        iRw,
  input  logic [6:0]  iSlaveAddr,
  input  logic [7:0]  iRegAddr,
  input  logic [31:0] iWdata,
  input  logic [2:0]  iLen,
  input  logic [15:0] iClkDiv,

  output logic        oStartValid,
  output logic        oStartAttemptPulse,
  output logic        oStartAcceptedPulse,
  output logic        oInvalidCmdPulse,
  output logic        oRwLatch,
  output logic [6:0]  oSlaveAddrLatch,
  output logic [7:0]  oRegAddrLatch,
  output logic [31:0] oWdataLatch,
  output logic [2:0]  oLenLatch,
  output logic [15:0] oClkDivLatch
);

  assign oStartValid        = iEn && (iLen >= 3'd1) && (iLen <= 3'd4) && !iBusy;
  assign oStartAttemptPulse = iStartPulse && iStartIdleWindow;
  assign oStartAcceptedPulse = oStartAttemptPulse && oStartValid;
  assign oInvalidCmdPulse = oStartAttemptPulse && !oStartValid;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      oRwLatch        <= 1'b0;
      oSlaveAddrLatch <= '0;
      oRegAddrLatch   <= '0;
      oWdataLatch     <= '0;
      oLenLatch       <= 3'd1;
      oClkDivLatch    <= '0;
    end else begin
      if (oStartAttemptPulse) begin
        oRwLatch        <= iRw;
        oSlaveAddrLatch <= iSlaveAddr;
        oRegAddrLatch   <= iRegAddr;
        oWdataLatch     <= iWdata;
        oLenLatch       <= iLen;
        oClkDivLatch    <= iClkDiv;
      end
    end
  end

endmodule
