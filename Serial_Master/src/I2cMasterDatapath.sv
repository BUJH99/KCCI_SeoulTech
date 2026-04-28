/*
[MODULE_INFO_START]
Name: I2cMasterDatapath
Role: Byte and bit datapath for the I2C master transaction engine
Summary:
  - Shifts transmitted bytes, samples returned bytes, and tracks the current bit index
  - Separates ACK capture and RX byte collection from the high-level I2C control FSM
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterDatapath (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iLoadTxByte,
  input  logic [7:0] iTxByte,
  input  logic       iClearBitCnt,
  input  logic       iTxAdvance,
  input  logic       iRxSample,
  input  logic       iCaptureAck,
  input  logic       iSdaSync,
  output logic       oTxBit,
  output logic       oLastBit,
  output logic       oAckBit,
  output logic [7:0] oRxByte
);

  logic [7:0] TxShift;
  logic [7:0] RxShift;
  logic [3:0] BitCnt;
  logic       AckBit;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      TxShift <= '0;
      RxShift <= '0;
      BitCnt  <= '0;
      AckBit  <= 1'b1;
    end else begin
      if (iLoadTxByte) begin
        TxShift <= iTxByte;
      end

      if (iClearBitCnt) begin
        RxShift <= '0;
        BitCnt  <= '0;
      end else if (iTxAdvance) begin
        TxShift <= {TxShift[6:0], 1'b0};
        BitCnt  <= BitCnt + 1'b1;
      end else if (iRxSample) begin
        RxShift <= {RxShift[6:0], iSdaSync};
        BitCnt  <= BitCnt + 1'b1;
      end

      if (iCaptureAck) begin
        AckBit <= iSdaSync;
      end
    end
  end

  assign oTxBit   = TxShift[7];
  assign oLastBit = (BitCnt == 4'd7);
  assign oAckBit  = AckBit;
  assign oRxByte  = RxShift;

endmodule
