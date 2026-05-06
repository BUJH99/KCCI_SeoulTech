/*
[MODULE_INFO_START]
Name: SpiTraceSlave
Role: SPI byte receiver for the SLAVE Bubble Sort trace display target
Summary:
  - Samples MOSI on SPI clock rising edges while chip select is active
  - Emits one byte-valid pulse after every received 8-bit trace byte
  - Keeps the receiver independent from the MASTER SoC build boundary
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiTraceSlave (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic       iSpiSclk,
  input  logic       iSpiMosi,
  input  logic       iSpiCsN,

  output logic [7:0] oByteData,
  output logic       oByteValidPulse
);

  logic       Sclk_d1;
  logic       Sclk_d2;
  logic       CsN_d1;
  logic       CsN_d2;
  logic [7:0] ShiftReg;
  logic [2:0] BitCnt;
  logic       SclkRise;
  logic       CsActive;

  assign SclkRise = Sclk_d1 && !Sclk_d2;
  assign CsActive = !CsN_d2;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      Sclk_d1         <= 1'b0;
      Sclk_d2         <= 1'b0;
      CsN_d1          <= 1'b1;
      CsN_d2          <= 1'b1;
      ShiftReg        <= '0;
      BitCnt          <= '0;
      oByteData       <= '0;
      oByteValidPulse <= 1'b0;
    end else begin
      Sclk_d1         <= iSpiSclk;
      Sclk_d2         <= Sclk_d1;
      CsN_d1          <= iSpiCsN;
      CsN_d2          <= CsN_d1;
      oByteValidPulse <= 1'b0;

      if (!CsActive) begin
        ShiftReg <= '0;
        BitCnt   <= '0;
      end else if (SclkRise) begin
        ShiftReg <= {ShiftReg[6:0], iSpiMosi};

        if (BitCnt == 3'd7) begin
          oByteData       <= {ShiftReg[6:0], iSpiMosi};
          oByteValidPulse <= 1'b1;
          BitCnt          <= '0;
        end else begin
          BitCnt <= BitCnt + 1'b1;
        end
      end
    end
  end

endmodule
