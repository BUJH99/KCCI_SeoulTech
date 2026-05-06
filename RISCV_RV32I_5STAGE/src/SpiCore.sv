/*
[MODULE_INFO_START]
Name: SpiCore
Role: Compact synthesizable frame engine for the APB SPI master
Summary:
  - Transfers one 8-bit frame per START pulse and exposes busy/done/RX-valid status
  - Drives SCLK, MOSI, and active-low chip-select pins for the trace data plane
  - Emits simple error pulses for disabled starts and overlapping starts
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiCore (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iEnable,
  input  logic        iStartPulse,
  input  logic        iCpol,
  input  logic        iCpha,
  input  logic        iLsbFirst,
  input  logic        iManualCs,
  input  logic [7:0]  iTxData,
  input  logic [15:0] iClkDiv,
  input  logic [7:0]  iCsMask,
  input  logic        iMiso,

  output logic        oBusy,
  output logic        oDonePulse,
  output logic        oRxValidPulse,
  output logic        oTxReady,
  output logic [7:0]  oRxData,
  output logic        oRxOverflowPulse,
  output logic        oTxUnderflowPulse,
  output logic        oModeErrorPulse,
  output logic        oFrameDroppedPulse,
  output logic        oSclk,
  output logic        oMosi,
  output logic        oCsN
);

  logic [7:0] ShiftTx;
  logic [7:0] ShiftRx;
  logic [2:0] BitCnt;
  logic       SclkReg;

  assign oTxReady = !oBusy;
  assign oSclk    = oBusy ? SclkReg : iCpol;
  assign oMosi    = iLsbFirst ? ShiftTx[0] : ShiftTx[7];
  assign oCsN     = ~((oBusy || iManualCs) && iCsMask[0]);

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oBusy              <= 1'b0;
      oDonePulse         <= 1'b0;
      oRxValidPulse      <= 1'b0;
      oRxData            <= '0;
      oRxOverflowPulse   <= 1'b0;
      oTxUnderflowPulse  <= 1'b0;
      oModeErrorPulse    <= 1'b0;
      oFrameDroppedPulse <= 1'b0;
      ShiftTx            <= '0;
      ShiftRx            <= '0;
      BitCnt             <= '0;
      SclkReg            <= 1'b0;
    end else begin
      oDonePulse         <= 1'b0;
      oRxValidPulse      <= 1'b0;
      oRxOverflowPulse   <= 1'b0;
      oTxUnderflowPulse  <= 1'b0;
      oModeErrorPulse    <= 1'b0;
      oFrameDroppedPulse <= 1'b0;

      if (iStartPulse && !iEnable) begin
        oModeErrorPulse <= 1'b1;
      end else if (iStartPulse && oBusy) begin
        oFrameDroppedPulse <= 1'b1;
      end else if (iStartPulse) begin
        oBusy   <= 1'b1;
        ShiftTx <= iTxData;
        ShiftRx <= '0;
        BitCnt  <= 3'd7;
        SclkReg <= iCpha ? ~iCpol : iCpol;
      end else if (oBusy) begin
        SclkReg <= ~SclkReg;

        if (iLsbFirst) begin
          ShiftRx <= {iMiso, ShiftRx[7:1]};
          ShiftTx <= {1'b0, ShiftTx[7:1]};
        end else begin
          ShiftRx <= {ShiftRx[6:0], iMiso};
          ShiftTx <= {ShiftTx[6:0], 1'b0};
        end

        if (BitCnt == 3'd0) begin
          oBusy         <= 1'b0;
          oDonePulse    <= 1'b1;
          oRxValidPulse <= 1'b1;
          oRxData       <= iLsbFirst ? {iMiso, ShiftRx[7:1]} : {ShiftRx[6:0], iMiso};
          SclkReg       <= iCpol;
        end else begin
          BitCnt <= BitCnt - 1'b1;
        end
      end

      if (iStartPulse && (iCsMask == 8'd0)) begin
        oTxUnderflowPulse <= 1'b1;
      end
    end
  end

endmodule
