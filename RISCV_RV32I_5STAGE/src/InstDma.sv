/*
[MODULE_INFO_START]
Name: InstDma
Role: Transport-independent instruction image loader DMA
Summary:
  - Bridges the UART byte stream to ProgramRam writes through control and data submodules
  - Exposes loader status, ACK/ERR TX bytes, and packet metadata to InstDmaRegs
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstDma (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iRxValid,
  input  logic [7:0]  iRxData,
  input  logic        iTxReady,
  input  logic        iCtrlArm,
  input  logic        iCtrlClearErr,

  output logic        oRxReady,
  output logic        oTxValid,
  output logic [7:0]  oTxData,
  output logic        oStatusBusy,
  output logic        oStatusDone,
  output logic        oStatusErr,
  output logic        oStatusAppValid,
  output logic [7:0]  oErrCode,
  output logic [31:0] oLoadAddr,
  output logic [31:0] oByteCnt,
  output logic [31:0] oEntryAddr,
  output logic [31:0] oExpectedChecksum,
  output logic [31:0] oActualChecksum,
  output logic [31:0] oWordsWritten,
  output logic        oPramWrEn,
  output logic [31:0] oPramAddr,
  output logic [31:0] oPramWdata,
  output logic [3:0]  oPramWstrb
);

  logic        DataStart;
  logic [31:0] DataLoadAddr;
  logic [31:0] DataByteCnt;
  logic        DataPayloadValid;
  logic [7:0]  DataPayloadByte;
  logic        DataPayloadLast;
  logic        DataPayloadReady;
  logic        DataWrDone;
  logic        DataBytesDone;
  logic [31:0] DataActualChecksum;
  logic [31:0] DataWordsWritten;

  InstDmaCtrl uInstDmaCtrl (
    .iClk(iClk),
    .iRst(iRst),
    .iCtrlArm(iCtrlArm),
    .iCtrlClearErr(iCtrlClearErr),
    .iRxValid(iRxValid),
    .iRxData(iRxData),
    .iTxReady(iTxReady),
    .iDataPayloadReady(DataPayloadReady),
    .iDataActualChecksum(DataActualChecksum),
    .iDataWordsWritten(DataWordsWritten),
    .oRxReady(oRxReady),
    .oTxValid(oTxValid),
    .oTxData(oTxData),
    .oDataStart(DataStart),
    .oDataLoadAddr(DataLoadAddr),
    .oDataByteCnt(DataByteCnt),
    .oDataPayloadValid(DataPayloadValid),
    .oDataPayloadByte(DataPayloadByte),
    .oDataPayloadLast(DataPayloadLast),
    .oBusy(oStatusBusy),
    .oDone(oStatusDone),
    .oErr(oStatusErr),
    .oAppValid(oStatusAppValid),
    .oErrCode(oErrCode),
    .oLoadAddr(oLoadAddr),
    .oByteCnt(oByteCnt),
    .oEntryAddr(oEntryAddr),
    .oExpectedChecksum(oExpectedChecksum),
    .oActualChecksum(oActualChecksum),
    .oWordsWritten(oWordsWritten)
  );

  InstDmaData uInstDmaData (
    .iClk(iClk),
    .iRst(iRst),
    .iStart(DataStart),
    .iLoadAddr(DataLoadAddr),
    .iByteCnt(DataByteCnt),
    .iPayloadValid(DataPayloadValid),
    .iPayloadByte(DataPayloadByte),
    .iPayloadLast(DataPayloadLast),
    .oPayloadReady(DataPayloadReady),
    .oWrDone(DataWrDone),
    .oBytesDone(DataBytesDone),
    .oActualChecksum(DataActualChecksum),
    .oWordsWritten(DataWordsWritten),
    .oPramWrEn(oPramWrEn),
    .oPramAddr(oPramAddr),
    .oPramWdata(oPramWdata),
    .oPramWstrb(oPramWstrb)
  );

endmodule
