/*
[MODULE_INFO_START]
Name: I2cMasterDatapath
Role: I2C master byte datapath for TX/RX shifting, bit count, and ACK capture
Summary:
  - Owns the current TX byte, RX shift register, and bit counter
  - Provides TX bit, ACK sample result, RX byte data, and RX byte-complete pulse to control logic
  - Keeps byte-level datapath state separate from transaction sequencing and error policy
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterDatapath (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iCoreRstPulse,
  input  logic       iSdaInSync,
  input  logic [6:0] iSlaveAddrLatch,
  input  logic [7:0] iRegAddrLatch,
  input  logic       iLoadAddrWrPulse,
  input  logic       iLoadRegAddrPulse,
  input  logic       iLoadAddrRdPulse,
  input  logic       iLoadWrBytePulse,
  input  logic [7:0] iWrByteData,
  input  logic       iPrepareRdPulse,
  input  logic       iNextRdBytePulse,
  input  logic       iTxBitAdvancePulse,
  input  logic       iRxSamplePulse,
  input  logic       iRxBitAdvancePulse,
  input  logic       iAckCapturePulse,

  output logic       oTxBit,
  output logic [2:0] oBitCnt,
  output logic       oAckBit,
  output logic [7:0] oRxByteData,
  output logic       oRxByteCompletePulse
);

  logic [7:0] TxByte;
  logic [7:0] RxShift;
  logic       AckBit;

  assign oTxBit               = TxByte[oBitCnt];
  assign oAckBit              = iAckCapturePulse ? iSdaInSync : AckBit;
  assign oRxByteData          = {RxShift[6:0], iSdaInSync};
  assign oRxByteCompletePulse = iRxSamplePulse && (oBitCnt == 3'd0);

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      TxByte  <= '0;
      RxShift <= '0;
      oBitCnt <= '0;
      AckBit  <= 1'b1;
    end else begin
      if (iCoreRstPulse) begin
        TxByte  <= '0;
        RxShift <= '0;
        oBitCnt <= '0;
        AckBit  <= 1'b1;
      end else if (iLoadAddrWrPulse) begin
        TxByte  <= {iSlaveAddrLatch, 1'b0};
        RxShift <= '0;
        oBitCnt <= 3'd7;
      end else if (iLoadRegAddrPulse) begin
        TxByte  <= iRegAddrLatch;
        oBitCnt <= 3'd7;
      end else if (iLoadAddrRdPulse) begin
        TxByte  <= {iSlaveAddrLatch, 1'b1};
        oBitCnt <= 3'd7;
      end else if (iLoadWrBytePulse) begin
        TxByte  <= iWrByteData;
        oBitCnt <= 3'd7;
      end else if (iPrepareRdPulse || iNextRdBytePulse) begin
        RxShift <= '0;
        oBitCnt <= 3'd7;
      end else if (iRxSamplePulse) begin
        RxShift <= oRxByteData;
      end else if (iTxBitAdvancePulse || iRxBitAdvancePulse) begin
        if (oBitCnt != 3'd0) begin
          oBitCnt <= oBitCnt - 1'b1;
        end
      end

      if (iAckCapturePulse) begin
        AckBit <= iSdaInSync;
      end
    end
  end

endmodule
