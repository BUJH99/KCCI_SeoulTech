/*
[MODULE_INFO_START]
Name: DataBusMaster
Role: Master-side native data-bus control wrapper for RAM and APB targets
Summary:
  - Owns top-level routing and final response muxing for the MEM-stage native request
  - Exposes decoded RAM/APB control signals so TOP can wire the native data bus and APB bridge separately
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module DataBusMaster (
  input  rv32i_pkg::DataBusReq_t  iReq,
  input  logic [31:0]             iRamRdata,
  input  logic [31:0]             iApbRdata,
  input  logic                    iApbReady,
  input  logic                    iApbErr,

  output logic                    oRamSel,
  output logic                    oRamWrEn,
  output logic                    oApbSel,
  output logic                    oApbWrite,
  output logic [31:0]             oAddr,
  output logic [3:0]              oByteEn,
  output logic [31:0]             oWdata,
  output rv32i_pkg::DataBusRsp_t  oRsp
);

  logic DecodeErr;

  assign oRamWrEn  = oRamSel && iReq.ReqWrite;
  assign oApbWrite = iReq.ReqWrite;
  assign oAddr     = iReq.ReqAddr;
  assign oByteEn   = iReq.ReqByteEn;
  assign oWdata    = iReq.ReqWdata;

  DataBusRouter uDataBusRouter (
    .iReq      (iReq),
    .oRamSel   (oRamSel),
    .oApbSel   (oApbSel),
    .oDecodeErr(DecodeErr)
  );

  DataBusRspMux uDataBusRspMux (
    .iRamSel   (oRamSel),
    .iApbSel   (oApbSel),
    .iDecodeErr(DecodeErr),
    .iRamRdata (iRamRdata),
    .iApbRdata (iApbRdata),
    .iApbReady (iApbReady),
    .iApbErr   (iApbErr),
    .oRsp      (oRsp)
  );

endmodule
