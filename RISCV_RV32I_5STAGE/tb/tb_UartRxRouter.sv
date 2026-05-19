`timescale 1ns / 1ps

module tb_UartRxRouter;
  import rv32i_pkg::*;

  logic       iRxFifoEmpty;
  logic [7:0] iRxFifoData;
  logic       iCpuPop;
  logic       iDmaReady;
  logic       oRxFifoPop;
  logic       oCpuValid;
  logic       oDmaValid;

  UartRxRouter dut (
    .iMode(UART_MODE_DMA),
    .iRxFifoEmpty(iRxFifoEmpty),
    .iRxFifoData(iRxFifoData),
    .iCpuPop(iCpuPop),
    .iDmaReady(iDmaReady),
    .oRxFifoPop(oRxFifoPop),
    .oCpuValid(oCpuValid),
    .oCpuData(),
    .oDmaValid(oDmaValid),
    .oDmaData()
  );

  initial begin
    iRxFifoEmpty = 1'b0;
    iRxFifoData  = 8'hA5;
    iCpuPop      = 1'b1;
    iDmaReady    = 1'b0;
    #1;
    if (oCpuValid !== 1'b0 || oRxFifoPop !== 1'b0) begin
      $fatal(1, "[FAIL] DMA mode allowed CPU RX pop");
    end
    iDmaReady = 1'b1;
    #1;
    if (oDmaValid !== 1'b1 || oRxFifoPop !== 1'b1) begin
      $fatal(1, "[FAIL] DMA mode did not route RX byte");
    end
    $display("[PASS] tb_UartRxRouter");
    $finish;
  end
endmodule
