`timescale 1ns / 1ps

module tb_InstDmaRegs;
  import rv32i_pkg::*;

  logic        iClk;
  logic        iRst;
  logic        iPsel;
  logic        iPenable;
  logic        iPwrite;
  logic [11:0] iPaddr;
  logic [3:0]  iPstrb;
  logic [31:0] iPwdata;
  logic [31:0] oPrdata;
  logic        oCtrlArm;
  logic        oCtrlClearErr;
  UartModeE    oUartMode;
  logic        oUartRxFlushReq;

  InstDmaRegs dut (
    .iClk(iClk),
    .iRst(iRst),
    .iPsel(iPsel),
    .iPenable(iPenable),
    .iPwrite(iPwrite),
    .iPaddr(iPaddr),
    .iPstrb(iPstrb),
    .iPwdata(iPwdata),
    .iStatusBusy(1'b0),
    .iStatusDone(1'b0),
    .iStatusErr(1'b0),
    .iStatusAppValid(1'b0),
    .iErrCode(8'h00),
    .iLoadAddr(32'h0000_1000),
    .iByteCnt(32'd4),
    .iEntryAddr(32'h0000_1000),
    .iExpectedChecksum(32'h6F),
    .iActualChecksum(32'h6F),
    .iWordsWritten(32'd1),
    .iUartTxIdle(1'b1),
    .oPrdata(oPrdata),
    .oPready(),
    .oPslverr(),
    .oCtrlArm(oCtrlArm),
    .oCtrlClearErr(oCtrlClearErr),
    .oUartMode(oUartMode),
    .oUartRxFlushReq(oUartRxFlushReq)
  );

  always #5 iClk = ~iClk;

  task automatic ApbWr(input logic [11:0] addr, input logic [31:0] data);
    begin
      @(posedge iClk);
      iPsel    <= 1'b1;
      iPenable <= 1'b1;
      iPwrite  <= 1'b1;
      iPaddr   <= addr;
      iPwdata  <= data;
      @(posedge iClk);
      iPsel    <= 1'b0;
      iPenable <= 1'b0;
      iPwrite  <= 1'b0;
    end
  endtask

  initial begin
    iClk     = 1'b0;
    iRst    = 1'b1;
    iPsel    = 1'b0;
    iPenable = 1'b0;
    iPwrite  = 1'b0;
    iPaddr   = '0;
    iPstrb   = 4'hF;
    iPwdata  = '0;

    repeat (2) @(posedge iClk);
    iRst <= 1'b0;

    ApbWr(12'h000, 32'h0000_0001);
    if (oCtrlArm !== 1'b1 || oUartMode !== UART_MODE_DMA) begin
      $fatal(1, "[FAIL] InstDmaRegs START behavior mismatch");
    end

    ApbWr(12'h000, 32'h0000_0008);
    if (oUartMode !== UART_MODE_CPU) begin
      $fatal(1, "[FAIL] InstDmaRegs APP_MODE_REQ did not switch CPU mode");
    end

    $display("[PASS] tb_InstDmaRegs");
    $finish;
  end
endmodule
