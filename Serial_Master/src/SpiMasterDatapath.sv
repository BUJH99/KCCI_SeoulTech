/*
[MODULE_INFO_START]
Name: SpiMasterDatapath
Role: Shift-register datapath for the SPI master transfer engine
Summary:
  - Loads the 16-bit SPI frame, shifts MOSI on falling edges, and samples MISO on rising edges
  - Captures the returned low byte for read transactions once the frame completes
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiMasterDatapath (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iLoadFrame,
  input  logic       iSampleRx,
  input  logic       iShiftTx,
  input  logic       iCaptureFrame,
  input  logic       iMisoSync,
  input  logic       iTxnRw,
  input  logic [7:0] iTxnRegAddr,
  input  logic [7:0] iTxnWrData,
  output logic       oMosiBit,
  output logic       oBitsDone,
  output logic [7:0] oRxData
);

  logic [15:0] FrameShift;
  logic [15:0] RxShift;
  logic [4:0]  BitCnt;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      FrameShift <= '0;
      RxShift    <= '0;
      BitCnt     <= '0;
    end else begin
      if (iLoadFrame) begin
        FrameShift <= {iTxnRw, iTxnRegAddr[6:0], iTxnWrData};
        RxShift    <= '0;
        BitCnt     <= '0;
      end

      if (iSampleRx) begin
        RxShift <= {RxShift[14:0], iMisoSync};
        BitCnt  <= BitCnt + 1'b1;
      end

      if (iShiftTx) begin
        FrameShift <= {FrameShift[14:0], 1'b0};
      end
    end
  end

  assign oMosiBit  = FrameShift[15];
  assign oBitsDone = (BitCnt == 5'd16);
  assign oRxData   = RxShift[7:0];

endmodule
