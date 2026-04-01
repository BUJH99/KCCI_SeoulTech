/*
[MODULE_INFO_START]
Name: TOP_BASYS3
Role: Basys3 board wrapper for the RV32I 5-stage core
Summary:
  - Generates a real 50MHz fabric clock from the on-board 100MHz oscillator
  - Maps Basys3 switches, LEDs, 7-seg display, pushbutton reset, UART, and a timing probe to the board-independent TOP core
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TOP_BASYS3 #(
  parameter int unsigned P_CORE_CLK_HZ = 50_000_000,
  parameter int unsigned P_UART_BAUD   = 115_200
) (
  input  logic        iClk100Mhz,
  input  logic        iBtnC,
  input  logic        iUartRx,
  input  logic [15:0] iSw,

  output logic        oUartTx,
  output logic [15:0] oLed,
  output logic [6:0]  oSeg,
  output logic        oDp,
  output logic [3:0]  oDigitSel,
  output logic        oTimingProbe
);

  localparam int unsigned LP_GPIO_WIDTH = 8;

  logic                         RstAsync;
  logic [1:0]                   RstnSync;
  logic                         wClock80Gen2TopBasys3_Clk80Mhz;
  logic                         wClock80Gen2TopBasys3_Locked;
  logic                         wTopBasys32Core_Rstn;
  logic [LP_GPIO_WIDTH-1:0]     wTopBasys32Core_GpioIn;
  logic [LP_GPIO_WIDTH-1:0]     wCore2TopBasys3_GpioOut;
  logic [LP_GPIO_WIDTH-1:0]     wCore2TopBasys3_GpioOe;

  Clock80Gen uClock80Gen (
    .iClk100Mhz(iClk100Mhz),
    .oClk80Mhz (wClock80Gen2TopBasys3_Clk80Mhz),
    .oLocked   (wClock80Gen2TopBasys3_Locked)
  );

  assign RstAsync                        = iBtnC || !wClock80Gen2TopBasys3_Locked;
  assign wTopBasys32Core_GpioIn          = iSw[LP_GPIO_WIDTH-1:0];
  assign oLed                            = {wCore2TopBasys3_GpioOe, wCore2TopBasys3_GpioOut};

  always_ff @(posedge wClock80Gen2TopBasys3_Clk80Mhz or posedge RstAsync) begin
    if (RstAsync) begin
      RstnSync <= '0;
    end else begin
      RstnSync <= {RstnSync[0], 1'b1};
    end
  end

  assign wTopBasys32Core_Rstn = RstnSync[1];

  TOP #(
    .P_CLK_HZ    (P_CORE_CLK_HZ),
    .P_UART_BAUD (P_UART_BAUD),
    .P_GPIO_WIDTH(LP_GPIO_WIDTH)
  ) uCoreTop (
    .iClk        (wClock80Gen2TopBasys3_Clk80Mhz),
    .iRstn       (wTopBasys32Core_Rstn),
    .iUartRx     (iUartRx),
    .iGpioIn     (wTopBasys32Core_GpioIn),
    .oUartTx     (oUartTx),
    .oGpioOut    (wCore2TopBasys3_GpioOut),
    .oGpioOe     (wCore2TopBasys3_GpioOe),
    .oSeg        (oSeg),
    .oDp         (oDp),
    .oDigitSel   (oDigitSel),
    .oTimingProbe(oTimingProbe)
  );

endmodule
