`timescale 1ns / 1ps

module tb_UartTxRouter;
  import rv32i_pkg::*;

  logic       oCpuTxReady;
  logic       oDmaTxReady;
  logic       oTxFifoPush;
  logic [7:0] oTxFifoData;

  UartTxRouter dut (
    .iMode(UART_MODE_DMA),
    .iTxFifoFull(1'b0),
    .iCpuTxValid(1'b1),
    .iCpuTxData(8'h11),
    .iDmaTxValid(1'b1),
    .iDmaTxData(8'h22),
    .oCpuTxReady(oCpuTxReady),
    .oDmaTxReady(oDmaTxReady),
    .oTxFifoPush(oTxFifoPush),
    .oTxFifoData(oTxFifoData)
  );

  initial begin
    #1;
    if (oCpuTxReady !== 1'b0 || oDmaTxReady !== 1'b1 || oTxFifoPush !== 1'b1 || oTxFifoData !== 8'h22) begin
      $fatal(1, "[FAIL] DMA TX route mismatch");
    end
    $display("[PASS] tb_UartTxRouter");
    $finish;
  end
endmodule
