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

  output logic        oUartPsel,
  output logic        oGpioPsel,
  output logic        oFndPsel,
  output logic        oIntcPsel,
  output logic        oAccessComplete,
  output logic [31:0] oCompletionPrdata,
  output logic        oCompletionPslverr
);

  import rv32i_pkg::*;

  logic        SelUart;
  logic        SelGpio;
  logic        SelFnd;
  logic        SelIntc;
  logic        LocalErrAccess;
  logic        SelectedPready;
  logic [31:0] SelectedPrdata;
  logic        SelectedPslverr;

  assign SelUart        = (iReqAddr[31:12] == LP_APB_UART_BASE[31:12]);
  assign SelGpio        = (iReqAddr[31:12] == LP_APB_GPIO_BASE[31:12]);
  assign SelFnd         = (iReqAddr[31:12] == LP_APB_FND_BASE[31:12]);
  assign SelIntc        = (iReqAddr[31:12] == LP_APB_INTC_BASE[31:12]);
  assign LocalErrAccess = !(SelUart || SelGpio || SelFnd || SelIntc);

  assign oUartPsel = iApbPhaseActive && SelUart;
  assign oGpioPsel = iApbPhaseActive && SelGpio;
  assign oFndPsel  = iApbPhaseActive && SelFnd;
  assign oIntcPsel = iApbPhaseActive && SelIntc;

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
    end else if (SelFnd) begin
      SelectedPready  = iFndPready;
      SelectedPrdata  = iFndPrdata;
      SelectedPslverr = iFndPslverr;
    end else if (SelIntc) begin
      SelectedPready  = iIntcPready;
      SelectedPrdata  = iIntcPrdata;
      SelectedPslverr = iIntcPslverr;
    end
  end

  assign oAccessComplete   = iPenable && (LocalErrAccess || SelectedPready);
  assign oCompletionPrdata = LocalErrAccess ? '0 : SelectedPrdata;
  assign oCompletionPslverr = LocalErrAccess ? 1'b1 : SelectedPslverr;

endmodule
