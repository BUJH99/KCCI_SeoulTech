`timescale 1ns / 1ps

module tb_InstDmaCtrl;
  logic        iClk;
  logic        iRst;
  logic        iCtrlArm;
  logic        iCtrlClearErr;
  logic        iRxValid;
  logic [7:0]  iRxData;
  logic        iTxReady;
  logic        iDataPayloadReady;
  logic [31:0] iDataActualChecksum;
  logic [31:0] iDataWordsWritten;
  logic        oRxReady;
  logic        oTxValid;
  logic [7:0]  oTxData;
  logic        oDataStart;
  logic [31:0] oDataLoadAddr;
  logic [31:0] oDataByteCnt;
  logic        oDataPayloadValid;
  logic [7:0]  oDataPayloadByte;
  logic        oDataPayloadLast;
  logic        oDone;
  logic        oErr;

  InstDmaCtrl dut (
    .iClk(iClk),
    .iRst(iRst),
    .iCtrlArm(iCtrlArm),
    .iCtrlClearErr(iCtrlClearErr),
    .iRxValid(iRxValid),
    .iRxData(iRxData),
    .iTxReady(iTxReady),
    .iDataPayloadReady(iDataPayloadReady),
    .iDataActualChecksum(iDataActualChecksum),
    .iDataWordsWritten(iDataWordsWritten),
    .oRxReady(oRxReady),
    .oTxValid(oTxValid),
    .oTxData(oTxData),
    .oDataStart(oDataStart),
    .oDataLoadAddr(oDataLoadAddr),
    .oDataByteCnt(oDataByteCnt),
    .oDataPayloadValid(oDataPayloadValid),
    .oDataPayloadByte(oDataPayloadByte),
    .oDataPayloadLast(oDataPayloadLast),
    .oBusy(),
    .oDone(oDone),
    .oErr(oErr),
    .oAppValid(),
    .oErrCode(),
    .oLoadAddr(),
    .oByteCnt(),
    .oEntryAddr(),
    .oExpectedChecksum(),
    .oActualChecksum(),
    .oWordsWritten()
  );

  always #5 iClk = ~iClk;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      iDataActualChecksum <= '0;
    end else if (oDataPayloadValid) begin
      iDataActualChecksum <= iDataActualChecksum + {24'd0, oDataPayloadByte};
    end
  end

  task automatic SendByte(input logic [7:0] data);
    begin
      do begin
        @(posedge iClk);
      end while (!oRxReady);
      iRxValid <= 1'b1;
      iRxData  <= data;
      @(posedge iClk);
      iRxValid <= 1'b0;
    end
  endtask

  task automatic SendU32(input logic [31:0] data);
    begin
      SendByte(data[7:0]);
      SendByte(data[15:8]);
      SendByte(data[23:16]);
      SendByte(data[31:24]);
    end
  endtask

  initial begin
    iClk               = 1'b0;
    iRst              = 1'b1;
    iCtrlArm           = 1'b0;
    iCtrlClearErr      = 1'b0;
    iRxValid           = 1'b0;
    iRxData            = '0;
    iTxReady           = 1'b1;
    iDataPayloadReady  = 1'b1;
    iDataWordsWritten  = 32'd1;

    repeat (2) @(posedge iClk);
    iRst    <= 1'b0;
    iCtrlArm <= 1'b1;

    SendByte("R");
    SendByte("A");
    SendByte("X");
    SendByte("I");
    SendU32(32'h0000_1000);
    SendU32(32'd4);
    SendU32(32'h0000_1000);
    SendU32(32'h0000_006F);
    SendByte(8'h6F);
    SendByte(8'h00);
    SendByte(8'h00);
    SendByte(8'h00);

    do begin
      @(posedge iClk);
    end while (!oTxValid);
    if (oTxData !== 8'h06) begin
      $fatal(1, "[FAIL] InstDmaCtrl did not ACK a valid packet");
    end
    @(posedge iClk);
    if (oDone !== 1'b1) begin
      $fatal(1, "[FAIL] InstDmaCtrl did not latch DONE");
    end

    iCtrlClearErr <= 1'b1;
    @(posedge iClk);
    iCtrlClearErr <= 1'b0;
    iDataActualChecksum <= '0;

    SendByte("B");
    do begin
      @(posedge iClk);
    end while (!oTxValid);
    if (oTxData !== 8'h15) begin
      $fatal(1, "[FAIL] InstDmaCtrl did not ERR bad magic");
    end
    @(posedge iClk);
    if (oErr !== 1'b1) begin
      $fatal(1, "[FAIL] InstDmaCtrl did not latch ERROR");
    end

    $display("[PASS] tb_InstDmaCtrl");
    $finish;
  end
endmodule
