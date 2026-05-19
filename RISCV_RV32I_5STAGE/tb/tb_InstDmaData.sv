`timescale 1ns / 1ps

module tb_InstDmaData;
  logic        iClk;
  logic        iRst;
  logic        iStart;
  logic [31:0] iLoadAddr;
  logic [31:0] iByteCnt;
  logic        iPayloadValid;
  logic [7:0]  iPayloadByte;
  logic        iPayloadLast;
  logic        oPayloadReady;
  logic        oWrDone;
  logic        oBytesDone;
  logic [31:0] oActualChecksum;
  logic [31:0] oWordsWritten;
  logic        oPramWrEn;
  logic [31:0] oPramAddr;
  logic [31:0] oPramWdata;
  logic [3:0]  oPramWstrb;

  InstDmaData dut (
    .iClk(iClk),
    .iRst(iRst),
    .iStart(iStart),
    .iLoadAddr(iLoadAddr),
    .iByteCnt(iByteCnt),
    .iPayloadValid(iPayloadValid),
    .iPayloadByte(iPayloadByte),
    .iPayloadLast(iPayloadLast),
    .oPayloadReady(oPayloadReady),
    .oWrDone(oWrDone),
    .oBytesDone(oBytesDone),
    .oActualChecksum(oActualChecksum),
    .oWordsWritten(oWordsWritten),
    .oPramWrEn(oPramWrEn),
    .oPramAddr(oPramAddr),
    .oPramWdata(oPramWdata),
    .oPramWstrb(oPramWstrb)
  );

  always #5 iClk = ~iClk;

  task automatic SendByte(input logic [7:0] data, input logic last);
    begin
      @(posedge iClk);
      iPayloadValid <= 1'b1;
      iPayloadByte  <= data;
      iPayloadLast  <= last;
      @(posedge iClk);
      iPayloadValid <= 1'b0;
      iPayloadLast  <= 1'b0;
    end
  endtask

  initial begin
    iClk          = 1'b0;
    iRst         = 1'b1;
    iStart        = 1'b0;
    iLoadAddr     = 32'h0000_1000;
    iByteCnt    = 32'd4;
    iPayloadValid = 1'b0;
    iPayloadByte  = '0;
    iPayloadLast  = 1'b0;

    repeat (2) @(posedge iClk);
    iRst <= 1'b0;
    @(posedge iClk);
    iStart <= 1'b1;
    @(posedge iClk);
    iStart <= 1'b0;

    SendByte(8'h6F, 1'b0);
    SendByte(8'h00, 1'b0);
    SendByte(8'h00, 1'b0);
    SendByte(8'h00, 1'b1);
    #1;

    if (oPramWrEn !== 1'b1 || oPramAddr !== 32'h0000_1000 || oPramWdata !== 32'h0000_006F || oPramWstrb !== 4'hF) begin
      $fatal(1, "[FAIL] InstDmaData final write mismatch");
    end
    if (oActualChecksum !== 32'h0000_006F || oWordsWritten !== 32'd1) begin
      $fatal(1, "[FAIL] InstDmaData counters mismatch");
    end

    $display("[PASS] tb_InstDmaData");
    $finish;
  end
endmodule
