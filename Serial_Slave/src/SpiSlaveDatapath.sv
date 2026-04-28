/*
[MODULE_INFO_START]
Name: SpiSlaveDatapath
Role: Shift-register datapath for the SPI slave engine
Summary:
  - Samples the incoming 16-bit frame, decodes the header after the first byte, and shifts read data back on MISO
  - Exposes the captured register address and write payload to the transaction manager
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiSlaveDatapath (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iStartFrame,
  input  logic       iSampleMosi,
  input  logic       iShiftMiso,
  input  logic       iMosiSync,
  input  logic [7:0] iReadData,
  output logic       oMisoBit,
  output logic       oHeaderReady,
  output logic       oTxnWrite,
  output logic [7:0] oTxnAddr,
  output logic [7:0] oTxnWdata,
  output logic       oFrameDone
);

  logic [15:0] RxShift;
  logic [7:0]  ReadShift;
  logic [4:0]  BitCnt;
  logic        HeaderReady;
  logic        TxnWrite;
  logic [7:0]  TxnAddr;
  logic        ReadLoaded;
  logic        MisoBit;
  logic        FrameDone;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      RxShift     <= '0;
      ReadShift   <= '0;
      BitCnt      <= '0;
      HeaderReady <= 1'b0;
      TxnWrite    <= 1'b0;
      TxnAddr     <= '0;
      ReadLoaded  <= 1'b0;
      MisoBit     <= 1'b0;
      FrameDone   <= 1'b0;
    end else begin
      if (iStartFrame) begin
        RxShift     <= '0;
        ReadShift   <= '0;
        BitCnt      <= '0;
        HeaderReady <= 1'b0;
        TxnWrite    <= 1'b0;
        TxnAddr     <= '0;
        ReadLoaded  <= 1'b0;
        MisoBit     <= 1'b0;
        FrameDone   <= 1'b0;
      end

      if (iSampleMosi) begin
        RxShift <= {RxShift[14:0], iMosiSync};
        BitCnt  <= BitCnt + 1'b1;

        if (BitCnt == 5'd7) begin
          HeaderReady <= 1'b1;
          TxnWrite    <= !{RxShift[6:0], iMosiSync}[7];
          TxnAddr     <= {1'b0, {RxShift[5:0], iMosiSync}};
        end

        if (BitCnt == 5'd15) begin
          FrameDone <= 1'b1;
        end
      end

      if (iShiftMiso) begin
        if (BitCnt < 5'd8) begin
          MisoBit <= 1'b0;
        end else if (!TxnWrite) begin
          if (!ReadLoaded && (BitCnt == 5'd8)) begin
            MisoBit    <= iReadData[7];
            ReadShift  <= {iReadData[6:0], 1'b0};
            ReadLoaded <= 1'b1;
          end else begin
            MisoBit   <= ReadShift[7];
            ReadShift <= {ReadShift[6:0], 1'b0};
          end
        end else begin
          MisoBit <= 1'b0;
        end
      end
    end
  end

  assign oMisoBit    = MisoBit;
  assign oHeaderReady= HeaderReady;
  assign oTxnWrite   = TxnWrite;
  assign oTxnAddr    = TxnAddr;
  assign oTxnWdata   = RxShift[7:0];
  assign oFrameDone  = FrameDone;

endmodule
