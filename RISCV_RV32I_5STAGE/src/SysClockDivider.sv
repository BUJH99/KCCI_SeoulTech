/*
[MODULE_INFO_START]
Name: SysClockDivider
Role: Global clock divider for the RV32I SoC build target
Summary:
  - Uses a Xilinx 7-series MMCM to derive a slower system clock from the board clock
  - Keeps the divided clock on a global clock network so the CPU and APB peripherals can close timing reliably
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SysClockDivider #(
  parameter int unsigned P_DIVIDE = 4
) (
  input  logic iClk,
  input  logic iRst,

  output logic oClk,
  output logic oLocked
);

  logic ClkFb;
  logic ClkFbBufg;
  logic ClkOut;

  MMCME2_BASE #(
    .BANDWIDTH          ("OPTIMIZED"),
    .CLKFBOUT_MULT_F   (8.000),
    .CLKFBOUT_PHASE    (0.000),
    .CLKIN1_PERIOD     (10.000),
    .CLKOUT0_DIVIDE_F  (8.000 * P_DIVIDE),
    .CLKOUT0_DUTY_CYCLE(0.500),
    .CLKOUT0_PHASE     (0.000),
    .DIVCLK_DIVIDE     (1),
    .STARTUP_WAIT      ("FALSE")
  ) uSysClkMmcm (
    .CLKIN1  (iClk),
    .CLKFBIN (ClkFbBufg),
    .RST     (iRst),
    .PWRDWN  (1'b0),
    .CLKFBOUT(ClkFb),
    .CLKOUT0 (ClkOut),
    .LOCKED  (oLocked),
    .CLKFBOUTB(),
    .CLKOUT0B(),
    .CLKOUT1 (),
    .CLKOUT1B(),
    .CLKOUT2 (),
    .CLKOUT2B(),
    .CLKOUT3 (),
    .CLKOUT3B(),
    .CLKOUT4 (),
    .CLKOUT5 (),
    .CLKOUT6 ()
  );

  BUFG uSysClkFeedbackBufg (
    .I(ClkFb),
    .O(ClkFbBufg)
  );

  BUFG uSysClkBufg (
    .I(ClkOut),
    .O(oClk)
  );

endmodule
