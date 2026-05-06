/*
[MODULE_INFO_START]
Name: I2cCore
Role: Compact synthesizable transaction engine for the APB I2C master
Summary:
  - Models a bounded master transaction with busy, done, RX-valid, and TX-ready status
  - Drives SCL/SDA output-enable pins suitable for board-level open-drain adaptation
  - Emits simple error pulses for disabled starts and overlapping starts
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cCore (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iEnable,
  input  logic        iStartPulse,
  input  logic        iStop,
  input  logic        iAck,
  input  logic [7:0]  iTxData,
  input  logic [15:0] iClkDiv,
  input  logic [7:0]  iAddr,
  input  logic        iSdaIn,

  output logic        oBusy,
  output logic        oDonePulse,
  output logic        oRxValidPulse,
  output logic        oTxReady,
  output logic [7:0]  oRxData,
  output logic        oNackPulse,
  output logic        oArbLostPulse,
  output logic        oBusErrorPulse,
  output logic        oScl,
  output logic        oSdaOut,
  output logic        oSdaOe
);

  localparam int unsigned LP_TRANSACTION_CYCLES = 9;

  logic [3:0] CycleCnt;
  logic [7:0] ShiftData;
  logic       SclReg;

  assign oTxReady = !oBusy;
  assign oScl     = oBusy ? SclReg : 1'b1;
  assign oSdaOut  = oBusy ? ShiftData[7] : 1'b1;
  assign oSdaOe   = oBusy;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oBusy          <= 1'b0;
      oDonePulse     <= 1'b0;
      oRxValidPulse  <= 1'b0;
      oRxData        <= '0;
      oNackPulse     <= 1'b0;
      oArbLostPulse  <= 1'b0;
      oBusErrorPulse <= 1'b0;
      CycleCnt       <= '0;
      ShiftData      <= '0;
      SclReg         <= 1'b1;
    end else begin
      oDonePulse     <= 1'b0;
      oRxValidPulse  <= 1'b0;
      oNackPulse     <= 1'b0;
      oArbLostPulse  <= 1'b0;
      oBusErrorPulse <= 1'b0;

      if (iStartPulse && !iEnable) begin
        oBusErrorPulse <= 1'b1;
      end else if (iStartPulse && oBusy) begin
        oArbLostPulse <= 1'b1;
      end else if (iStartPulse) begin
        oBusy     <= 1'b1;
        CycleCnt  <= LP_TRANSACTION_CYCLES[3:0];
        ShiftData <= iTxData;
        SclReg    <= 1'b0;
      end else if (oBusy) begin
        SclReg    <= ~SclReg;
        ShiftData <= {ShiftData[6:0], iSdaIn};

        if (CycleCnt == 4'd0) begin
          oBusy         <= 1'b0;
          oDonePulse    <= 1'b1;
          oRxValidPulse <= iAddr[0];
          oRxData       <= {iAddr[7:1], iSdaIn};
          SclReg        <= 1'b1;
        end else begin
          CycleCnt <= CycleCnt - 1'b1;
        end
      end

      if (iStop && !oBusy) begin
        SclReg <= 1'b1;
      end

      if (!iAck && oBusy && (CycleCnt == 4'd1)) begin
        oNackPulse <= 1'b1;
      end
    end
  end

endmodule
