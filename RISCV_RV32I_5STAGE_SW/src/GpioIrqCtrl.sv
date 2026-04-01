/*
[MODULE_INFO_START]
Name: GpioIrqCtrl
Role: GPIO edge detector and sticky interrupt pending controller
Summary:
  - Samples the GPIO input vector and detects rising and falling edges per bit
  - Accumulates sticky IRQ pending bits with write-to-clear support and drives the combined IRQ output
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module GpioIrqCtrl #(
  parameter int unsigned P_GPIO_WIDTH = 8
) (
  input  logic                    iClk,
  input  logic                    iRstn,
  input  logic [P_GPIO_WIDTH-1:0] iGpioIn,
  input  logic [P_GPIO_WIDTH-1:0] iIrqRiseEn,
  input  logic [P_GPIO_WIDTH-1:0] iIrqFallEn,
  input  logic [P_GPIO_WIDTH-1:0] iIrqClrMask,

  output logic [P_GPIO_WIDTH-1:0] oIrqStatus,
  output logic                    oIrq
);

  logic [P_GPIO_WIDTH-1:0] GpioInPrev;
  logic [P_GPIO_WIDTH-1:0] GpioRisePulse;
  logic [P_GPIO_WIDTH-1:0] GpioFallPulse;
  logic [P_GPIO_WIDTH-1:0] IrqSetMask;

  assign GpioRisePulse = ~GpioInPrev & iGpioIn;
  assign GpioFallPulse = GpioInPrev & ~iGpioIn;
  assign IrqSetMask    = (GpioRisePulse & iIrqRiseEn) | (GpioFallPulse & iIrqFallEn);

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      GpioInPrev <= '0;
      oIrqStatus <= '0;
    end else begin
      GpioInPrev <= iGpioIn;
      oIrqStatus <= (oIrqStatus & ~iIrqClrMask) | IrqSetMask;
    end
  end

  assign oIrq = |oIrqStatus;

endmodule
