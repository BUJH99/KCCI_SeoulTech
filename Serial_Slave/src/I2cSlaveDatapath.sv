/*
[MODULE_INFO_START]
Name: I2cSlaveDatapath
Role: Byte-level datapath for the I2C slave subsystem
Summary:
  - Samples incoming bytes on SCL rising edges and shifts outgoing read data on SCL falling edges
  - Tracks the current bit position separately from the protocol-state decisions in the controller
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveDatapath (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iStartFrame,
  input  logic       iLoadTxByte,
  input  logic [7:0] iTxByte,
  input  logic       iClearBitCnt,
  input  logic       iSampleRxBit,
  input  logic       iAdvanceTxBit,
  input  logic       iSdaSync,
  output logic [7:0] oRxByte,
  output logic       oTxBit,
  output logic       oLastBit
);

  logic [7:0] RxShift;
  logic [7:0] TxShift;
  logic [3:0] BitCnt;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      RxShift <= '0;
      TxShift <= '0;
      BitCnt  <= '0;
    end else begin
      if (iStartFrame || iClearBitCnt) begin
        RxShift <= '0;
        BitCnt  <= '0;
      end

      if (iLoadTxByte) begin
        TxShift <= iTxByte;
      end

      if (iSampleRxBit) begin
        RxShift <= {RxShift[6:0], iSdaSync};
        BitCnt  <= BitCnt + 1'b1;
      end else if (iAdvanceTxBit) begin
        TxShift <= {TxShift[6:0], 1'b0};
        BitCnt  <= BitCnt + 1'b1;
      end
    end
  end

  assign oRxByte  = RxShift;
  assign oTxBit   = TxShift[7];
  assign oLastBit = (BitCnt == 4'd7);

endmodule
