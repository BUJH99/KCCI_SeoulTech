/*
[MODULE_INFO_START]
Name: APB_GPIO
Role: APB GPIO wrapper that composes register and IRQ-control submodules
Summary:
  - Delegates APB register decode and storage to GpioRegs
  - Delegates GPIO edge detection and sticky pending IRQ tracking to GpioIrqCtrl
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APB_GPIO #(
  parameter int unsigned P_GPIO_WIDTH = 8
) (
  input  logic                    iClk,
  input  logic                    iRstn,
  input  logic                    iPsel,
  input  logic                    iPenable,
  input  logic                    iPwrite,
  input  logic [11:0]             iPaddr,
  input  logic [3:0]              iPstrb,
  input  logic [31:0]             iPwdata,
  input  logic [P_GPIO_WIDTH-1:0] iGpioIn,

  output logic [31:0]             oPrdata,
  output logic                    oPready,
  output logic                    oPslverr,
  output logic [P_GPIO_WIDTH-1:0] oGpioOut,
  output logic [P_GPIO_WIDTH-1:0] oGpioOe,
  output logic                    oIrq
);
  logic [P_GPIO_WIDTH-1:0] DataOut;
  logic [P_GPIO_WIDTH-1:0] Dir;
  logic [P_GPIO_WIDTH-1:0] IrqRiseEn;
  logic [P_GPIO_WIDTH-1:0] IrqFallEn;
  logic [P_GPIO_WIDTH-1:0] IrqStatus;
  logic [P_GPIO_WIDTH-1:0] IrqClrMask;
  logic                    AccessEn;

  assign oPready  = 1'b1;
  assign AccessEn = iPsel && iPenable && oPready;
  assign oGpioOut  = DataOut;
  assign oGpioOe   = Dir;

  GpioRegs #(
    .P_GPIO_WIDTH(P_GPIO_WIDTH)
  ) uGpioRegs (
    .iClk(iClk),
    .iRstn(iRstn),
    .iAccessEn(AccessEn),
    .iPwrite(iPwrite),
    .iPaddr(iPaddr),
    .iPstrb(iPstrb),
    .iPwdata(iPwdata),
    .iGpioIn(iGpioIn),
    .iIrqStatus(IrqStatus),
    .oPrdata(oPrdata),
    .oPslverr(oPslverr),
    .oDataOut(DataOut),
    .oDir(Dir),
    .oIrqRiseEn(IrqRiseEn),
    .oIrqFallEn(IrqFallEn),
    .oIrqClrMask(IrqClrMask)
  );

  GpioIrqCtrl #(
    .P_GPIO_WIDTH(P_GPIO_WIDTH)
  ) uGpioIrqCtrl (
    .iClk(iClk),
    .iRstn(iRstn),
    .iGpioIn(iGpioIn),
    .iIrqRiseEn(IrqRiseEn),
    .iIrqFallEn(IrqFallEn),
    .iIrqClrMask(IrqClrMask),
    .oIrqStatus(IrqStatus),
    .oIrq(oIrq)
  );

endmodule
