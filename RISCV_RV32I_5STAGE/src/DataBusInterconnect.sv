/*
[MODULE_INFO_START]
Name: DataBusInterconnect
Role: Native data-bus interconnect for RAM and AXI/MMIO targets
Summary:
  - Owns top-level native data-bus decode and final response selection
  - Keeps DataRam and AXI master as external targets wired by TOP
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module DataBusInterconnect (
  input  rv32i_pkg::DataBusReq_t  iReq,
  input  logic [31:0]             iRamRdata,
  input  logic [31:0]             iApbRdata,
  input  logic                    iApbReady,
  input  logic                    iApbErr,

  output logic                    oRamSel,
  output logic                    oRamWrEn,
  output logic                    oApbSel,
  output logic                    oApbWr,
  output logic [31:0]             oAddr,
  output logic [3:0]              oByteEn,
  output logic [31:0]             oWdata,
  output rv32i_pkg::DataBusRsp_t  oRsp
);

  logic DecodeErr;

  assign oRamWrEn  = oRamSel && iReq.ReqWr;
  assign oApbWr = iReq.ReqWr;
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
