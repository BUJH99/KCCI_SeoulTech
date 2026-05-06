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
  input  logic        iUartPready,
  input  logic        iGpioPready,
  input  logic        iI2cPready,
  input  logic        iIntcPready,
  input  logic        iSpiPready,
  input  logic        iFndPready,
  input  logic        iUartPslverr,
  input  logic        iGpioPslverr,
  input  logic        iI2cPslverr,
  input  logic        iIntcPslverr,
  input  logic        iSpiPslverr,
  input  logic        iFndPslverr,

  output logic        oUartPsel,
  output logic        oGpioPsel,
  output logic        oI2cPsel,
  output logic        oIntcPsel,
  output logic        oSpiPsel,
  output logic        oFndPsel,
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
  logic        LocalErrAccess;
  logic        SelectedPready;
  logic [31:0] SelectedPrdata;
  logic        SelectedPslverr;

  assign SelUart        = (iReqAddr[31:12] == LP_APB_UART_BASE[31:12]);
  assign SelGpio        = (iReqAddr[31:12] == LP_APB_GPIO_BASE[31:12]);
  assign SelI2c         = (iReqAddr[31:12] == LP_APB_I2C_BASE[31:12]);
  assign SelIntc        = (iReqAddr[31:12] == LP_APB_INTC_BASE[31:12]);
  assign SelSpi         = (iReqAddr[31:12] == LP_APB_SPI_BASE[31:12]);
  assign SelFnd         = (iReqAddr[31:12] == LP_APB_FND_BASE[31:12]);
  assign LocalErrAccess = !(SelUart || SelGpio || SelI2c || SelIntc || SelSpi || SelFnd);

  assign oUartPsel = iApbPhaseActive && SelUart;
  assign oGpioPsel = iApbPhaseActive && SelGpio;
  assign oI2cPsel  = iApbPhaseActive && SelI2c;
  assign oIntcPsel = iApbPhaseActive && SelIntc;
  assign oSpiPsel  = iApbPhaseActive && SelSpi;
  assign oFndPsel  = iApbPhaseActive && SelFnd;

  always_comb begin
    SelectedPready  = 1'b0;
    SelectedPrdata  = '0;
    SelectedPslverr = 1'b0;

    if (SelUart) begin
      SelectedPready  = iUartPready;
      SelectedPrdata  = iUartPrdata;
      SelectedPslverr = iUartPslverr;
    end else if (SelGpio) begin
      SelectedPready  = iGpioPready;
      SelectedPrdata  = iGpioPrdata;
      SelectedPslverr = iGpioPslverr;
    end else if (SelI2c) begin
      SelectedPready  = iI2cPready;
      SelectedPrdata  = iI2cPrdata;
      SelectedPslverr = iI2cPslverr;
    end else if (SelIntc) begin
      SelectedPready  = iIntcPready;
      SelectedPrdata  = iIntcPrdata;
      SelectedPslverr = iIntcPslverr;
    end else if (SelSpi) begin
      SelectedPready  = iSpiPready;
      SelectedPrdata  = iSpiPrdata;
      SelectedPslverr = iSpiPslverr;
    end else if (SelFnd) begin
      SelectedPready  = iFndPready;
      SelectedPrdata  = iFndPrdata;
      SelectedPslverr = iFndPslverr;
    end
  end

  assign oAccessComplete   = iPenable && (LocalErrAccess || SelectedPready);
  assign oCompletionPrdata = LocalErrAccess ? '0 : SelectedPrdata;
  assign oCompletionPslverr = LocalErrAccess ? 1'b1 : SelectedPslverr;

endmodule
