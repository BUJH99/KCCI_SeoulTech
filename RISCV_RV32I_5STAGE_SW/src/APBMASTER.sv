/*
[MODULE_INFO_START]
Name: APBMASTER
Role: APB master wrapper that composes control and mux submodules for MMIO peripherals
Summary:
  - Delegates request latching and phase sequencing to APBCtrl
  - Delegates APB slave decode and completion muxing to APBMux while preserving the external bridge interface
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APBMASTER (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iApbSel,
  input  logic        iPwrite,
  input  logic [31:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic [31:0] iUartPrdata,
  input  logic [31:0] iGpioPrdata,
  input  logic [31:0] iFndPrdata,
  input  logic [31:0] iIntcPrdata,
  input  logic        iUartPready,
  input  logic        iGpioPready,
  input  logic        iFndPready,
  input  logic        iIntcPready,
  input  logic        iUartPslverr,
  input  logic        iGpioPslverr,
  input  logic        iFndPslverr,
  input  logic        iIntcPslverr,

  output logic        oPwrite,
  output logic [11:0] oPaddr,
  output logic [3:0]  oPstrb,
  output logic [31:0] oPwdata,
  output logic        oPenable,
  output logic        oUartPsel,
  output logic        oGpioPsel,
  output logic        oFndPsel,
  output logic        oIntcPsel,
  output logic        oRspReady,
  output logic [31:0] oPrdata,
  output logic        oPslverr
);

  logic [31:0] ReqAddr;
  logic        ApbPhaseActive;
  logic        AccessComplete;
  logic [31:0] CompletionPrdata;
  logic        CompletionPslverr;

  APBCtrl uAPBCtrl (
    .iClk(iClk),
    .iRstn(iRstn),
    .iApbSel(iApbSel),
    .iPwrite(iPwrite),
    .iPaddr(iPaddr),
    .iPstrb(iPstrb),
    .iPwdata(iPwdata),
    .iAccessComplete(AccessComplete),
    .iCompletionPrdata(CompletionPrdata),
    .iCompletionPslverr(CompletionPslverr),
    .oReqAddr(ReqAddr),
    .oApbPhaseActive(ApbPhaseActive),
    .oPwrite(oPwrite),
    .oPaddr(oPaddr),
    .oPstrb(oPstrb),
    .oPwdata(oPwdata),
    .oPenable(oPenable),
    .oRspReady(oRspReady),
    .oPrdata(oPrdata),
    .oPslverr(oPslverr)
  );

  APBMux uAPBMux (
    .iReqAddr(ReqAddr),
    .iApbPhaseActive(ApbPhaseActive),
    .iPenable(oPenable),
    .iUartPrdata(iUartPrdata),
    .iGpioPrdata(iGpioPrdata),
    .iFndPrdata(iFndPrdata),
    .iIntcPrdata(iIntcPrdata),
    .iUartPready(iUartPready),
    .iGpioPready(iGpioPready),
    .iFndPready(iFndPready),
    .iIntcPready(iIntcPready),
    .iUartPslverr(iUartPslverr),
    .iGpioPslverr(iGpioPslverr),
    .iFndPslverr(iFndPslverr),
    .iIntcPslverr(iIntcPslverr),
    .oUartPsel(oUartPsel),
    .oGpioPsel(oGpioPsel),
    .oFndPsel(oFndPsel),
    .oIntcPsel(oIntcPsel),
    .oAccessComplete(AccessComplete),
    .oCompletionPrdata(CompletionPrdata),
    .oCompletionPslverr(CompletionPslverr)
  );

endmodule
