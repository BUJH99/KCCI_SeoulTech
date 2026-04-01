/*
[MODULE_INFO_START]
Name: DataBusRspMux
Role: Final response mux between direct RAM data, APB MMIO data, and decode faults
Summary:
  - Produces the zero-wait native response seen by MemoryStage
  - Keeps decode errors separate from APB slave-side register errors
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module DataBusRspMux (
  input  logic                  iRamSel,
  input  logic                  iApbSel,
  input  logic                  iDecodeErr,
  input  logic [31:0]           iRamRdata,
  input  logic [31:0]           iApbRdata,
  input  logic                  iApbReady,
  input  logic                  iApbErr,

  output rv32i_pkg::DataBusRsp_t oRsp
);

  always_comb begin
    oRsp = '0;
    oRsp.RspReady = 1'b1;

    if (iRamSel) begin
      oRsp.RspRdata = iRamRdata;
    end else if (iApbSel) begin
      oRsp.RspRdata = iApbRdata;
      oRsp.RspReady = iApbReady;
      oRsp.RspErr   = iApbReady && iApbErr;
    end else if (iDecodeErr) begin
      oRsp.RspErr = 1'b1;
    end
  end

endmodule
