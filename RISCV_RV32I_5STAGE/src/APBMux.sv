/*
[MODULE_INFO_START]
Name: APBMux
Role: APB slave-window decode and response mux for the shared peripheral bus
Summary:
  - Decodes the latched APB request address into one-hot peripheral selects during SETUP and ACCESS
  - Muxes selected slave ready/data/error back into a single completion channel and raises a local error on window miss
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APBMux (
  input  logic [31:0] iReqAddr,
  input  logic        iApbPhaseActive,
  input  logic        iPenable,
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

  output logic        oUartPsel,
  output logic        oGpioPsel,
  output logic        oI2cPsel,
  output logic        oIntcPsel,
  output logic        oSpiPsel,
  output logic        oFndPsel,
  output logic        oTimerPsel,
  output logic        oInstDmaPsel,
  output logic        oAccessComplete,
  output logic [31:0] oCompletionPrdata,
  output logic        oCompletionPslverr
);

  import rv32i_pkg::*;

  logic        SelUart;
  logic        SelGpio;
  logic        SelI2c;
  logic        SelIntc;
  logic        SelSpi;
  logic        SelFnd;
  logic        SelTimer;
  logic        SelInstDma;
  logic        LocalErrAccess;
  logic        SelPready;
  logic [31:0] SelPrdata;
  logic        SelPslverr;

  assign SelUart        = (iReqAddr[31:12] == LP_APB_UART_BASE[31:12]);
  assign SelGpio        = (iReqAddr[31:12] == LP_APB_GPIO_BASE[31:12]);
  assign SelI2c         = (iReqAddr[31:12] == LP_APB_I2C_BASE[31:12]);
  assign SelIntc        = (iReqAddr[31:12] == LP_APB_INTC_BASE[31:12]);
  assign SelSpi         = (iReqAddr[31:12] == LP_APB_SPI_BASE[31:12]);
  assign SelFnd         = (iReqAddr[31:12] == LP_APB_FND_BASE[31:12]);
  assign SelTimer       = (iReqAddr[31:12] == LP_APB_TIMER_BASE[31:12]);
  assign SelInstDma     = (iReqAddr[31:12] == LP_APB_INST_DMA_BASE[31:12]);
  assign LocalErrAccess = !(SelUart || SelGpio || SelI2c || SelIntc || SelSpi || SelFnd || SelTimer || SelInstDma);

  assign oUartPsel = iApbPhaseActive && SelUart;
  assign oGpioPsel = iApbPhaseActive && SelGpio;
  assign oI2cPsel  = iApbPhaseActive && SelI2c;
  assign oIntcPsel = iApbPhaseActive && SelIntc;
  assign oSpiPsel  = iApbPhaseActive && SelSpi;
  assign oFndPsel  = iApbPhaseActive && SelFnd;
  assign oTimerPsel = iApbPhaseActive && SelTimer;
  assign oInstDmaPsel = iApbPhaseActive && SelInstDma;

  always_comb begin
    SelPready  = 1'b0;
    SelPrdata  = '0;
    SelPslverr = 1'b0;

    if (SelUart) begin
      SelPready  = iUartPready;
      SelPrdata  = iUartPrdata;
      SelPslverr = iUartPslverr;
    end else if (SelGpio) begin
      SelPready  = iGpioPready;
      SelPrdata  = iGpioPrdata;
      SelPslverr = iGpioPslverr;
    end else if (SelI2c) begin
      SelPready  = iI2cPready;
      SelPrdata  = iI2cPrdata;
      SelPslverr = iI2cPslverr;
    end else if (SelIntc) begin
      SelPready  = iIntcPready;
      SelPrdata  = iIntcPrdata;
      SelPslverr = iIntcPslverr;
    end else if (SelSpi) begin
      SelPready  = iSpiPready;
      SelPrdata  = iSpiPrdata;
      SelPslverr = iSpiPslverr;
    end else if (SelFnd) begin
      SelPready  = iFndPready;
      SelPrdata  = iFndPrdata;
      SelPslverr = iFndPslverr;
    end else if (SelTimer) begin
      SelPready  = iTimerPready;
      SelPrdata  = iTimerPrdata;
      SelPslverr = iTimerPslverr;
    end else if (SelInstDma) begin
      SelPready  = iInstDmaPready;
      SelPrdata  = iInstDmaPrdata;
      SelPslverr = iInstDmaPslverr;
    end
  end

  assign oAccessComplete   = iPenable && (LocalErrAccess || SelPready);
  assign oCompletionPrdata = LocalErrAccess ? '0 : SelPrdata;
  assign oCompletionPslverr = LocalErrAccess ? 1'b1 : SelPslverr;

endmodule
