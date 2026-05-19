/*
[MODULE_INFO_START]
Name: SpiMasterDatapath
Role: SPI master byte datapath for TX/RX shifting and RX push generation
Summary:
  - Loads one TX FIFO byte for each controller LOAD phase
  - Shifts MOSI MSB-first and samples synchronized MISO on mode0 rising edges
  - Emits RX byte data, RX FIFO push pulse, and byte-done pulse at the byte boundary
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiMasterDatapath (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iAssertCsActive,
  input  logic       iLoadActive,
  input  logic       iTransferActive,
  input  logic       iHalfPeriodDone,
  input  logic       iSclkLevel,
  input  logic [7:0] iTxFifoData,
  input  logic       iTxFifoValid,
  input  logic       iMisoSync,

  output logic       oMosiBit,
  output logic [7:0] oRxFifoPushData,
  output logic       oRxFifoPushPulse,
  output logic       oByteDonePulse
);

  logic [7:0] ShiftTx;
  logic [7:0] ShiftRx;
  logic [7:0] RxByteLatched;
  logic [2:0] BitCnt;
  logic       ByteDonePending;

  assign oMosiBit       = ShiftTx[7];
  assign oByteDonePulse = iTransferActive && iHalfPeriodDone && iSclkLevel && ByteDonePending;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      ShiftTx          <= '0;
      ShiftRx          <= '0;
      RxByteLatched    <= '0;
      BitCnt           <= '0;
      ByteDonePending  <= 1'b0;
      oRxFifoPushData  <= '0;
      oRxFifoPushPulse <= 1'b0;
    end else begin
      oRxFifoPushPulse <= 1'b0;

      if (iAssertCsActive) begin
        ShiftTx         <= '0;
        ShiftRx         <= '0;
        RxByteLatched   <= '0;
        BitCnt          <= '0;
        ByteDonePending <= 1'b0;
      end else if (iLoadActive) begin
        ShiftRx         <= '0;
        BitCnt          <= '0;
        ByteDonePending <= 1'b0;
        if (iTxFifoValid) begin
          ShiftTx <= iTxFifoData;
        end
      end else if (iTransferActive) begin
        if (iHalfPeriodDone) begin
          if (!iSclkLevel) begin
            ShiftRx <= {ShiftRx[6:0], iMisoSync};
            if (BitCnt == 3'd7) begin
              RxByteLatched   <= {ShiftRx[6:0], iMisoSync};
              ByteDonePending <= 1'b1;
            end else begin
              BitCnt <= BitCnt + 1'b1;
            end
          end else begin
            if (ByteDonePending) begin
              oRxFifoPushData  <= RxByteLatched;
              oRxFifoPushPulse <= 1'b1;
              ByteDonePending  <= 1'b0;
            end else begin
              ShiftTx <= {ShiftTx[6:0], 1'b0};
            end
          end
        end
      end
    end
  end

endmodule
