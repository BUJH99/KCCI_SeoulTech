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
  input  logic        iRst,
  input  logic        iApbSel,
  input  logic        iPwrite,
  input  logic [31:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic [31:0] iUartPrdata,
  input  logic [31:0] iGpioPrdata,
  input  logic [31:0] iI2cPrdata,
  input  logic [31:0] iIntcPrdata,
  input  logic [31:0] iSpiPrdata,
  input  logic [31:0] iFndPrdata,
  input  logic [31:0] iTimerPrdata,
  input  logic [31:0] iInstDmaPrdata,
  input  logic        iUartPready,
  input  logic        iGpioPready,
  input  logic        iI2cPready,
  input  logic        iIntcPready,
  input  logic        iSpiPready,
  input  logic        iFndPready,
  input  logic        iTimerPready,
  input  logic        iInstDmaPready,
  input  logic        iUartPslverr,
  input  logic        iGpioPslverr,
  input  logic        iI2cPslverr,
  input  logic        iIntcPslverr,
  input  logic        iSpiPslverr,
  input  logic        iFndPslverr,
  input  logic        iTimerPslverr,
  input  logic        iInstDmaPslverr,

  output logic        oPwrite,
  output logic [11:0] oPaddr,
  output logic [3:0]  oPstrb,
  output logic [31:0] oPwdata,
  output logic        oPenable,
  output logic        oUartPsel,
  output logic        oGpioPsel,
  output logic        oI2cPsel,
  output logic        oIntcPsel,
  output logic        oSpiPsel,
  output logic        oFndPsel,
  output logic        oTimerPsel,
  output logic        oInstDmaPsel,
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
    .iRst(iRst),
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
    .iI2cPrdata(iI2cPrdata),
    .iIntcPrdata(iIntcPrdata),
    .iSpiPrdata(iSpiPrdata),
    .iFndPrdata(iFndPrdata),
    .iTimerPrdata(iTimerPrdata),
    .iInstDmaPrdata(iInstDmaPrdata),
    .iUartPready(iUartPready),
    .iGpioPready(iGpioPready),
    .iI2cPready(iI2cPready),
    .iIntcPready(iIntcPready),
    .iSpiPready(iSpiPready),
    .iFndPready(iFndPready),
    .iTimerPready(iTimerPready),
    .iInstDmaPready(iInstDmaPready),
    .iUartPslverr(iUartPslverr),
    .iGpioPslverr(iGpioPslverr),
    .iI2cPslverr(iI2cPslverr),
    .iIntcPslverr(iIntcPslverr),
    .iSpiPslverr(iSpiPslverr),
    .iFndPslverr(iFndPslverr),
    .iTimerPslverr(iTimerPslverr),
    .iInstDmaPslverr(iInstDmaPslverr),
    .oUartPsel(oUartPsel),
    .oGpioPsel(oGpioPsel),
    .oI2cPsel(oI2cPsel),
    .oIntcPsel(oIntcPsel),
    .oSpiPsel(oSpiPsel),
    .oFndPsel(oFndPsel),
    .oTimerPsel(oTimerPsel),
    .oInstDmaPsel(oInstDmaPsel),
    .oAccessComplete(AccessComplete),
    .oCompletionPrdata(CompletionPrdata),
    .oCompletionPslverr(CompletionPslverr)
  );

endmodule
