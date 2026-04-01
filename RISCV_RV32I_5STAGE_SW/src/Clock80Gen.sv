/*
[MODULE_INFO_START]
Name: Clock80Gen
Role: Basys3 input-clock converter for the RV32I core
Summary:
  - Converts the Basys3 100MHz oscillator to a buffered 50MHz fabric clock
  - Exposes MMCM lock status so the board wrapper can hold reset until the clock is stable
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module Clock80Gen (
  input  logic iClk100Mhz,
  output logic oClk80Mhz,
  output logic oLocked
);

  logic ClkFb;
  logic ClkFbBuf;
  logic Clk80Unbuf;

  MMCME2_BASE #(
    .BANDWIDTH        ("OPTIMIZED"),
    .CLKIN1_PERIOD    (10.000),
    .CLKFBOUT_MULT_F  (8.000),
    .CLKFBOUT_PHASE   (0.000),
    .CLKOUT0_DIVIDE_F (16.000),
    .CLKOUT0_DUTY_CYCLE(0.500),
    .CLKOUT0_PHASE    (0.000),
    .CLKOUT1_DIVIDE   (1),
    .CLKOUT2_DIVIDE   (1),
    .CLKOUT3_DIVIDE   (1),
    .CLKOUT4_DIVIDE   (1),
    .CLKOUT5_DIVIDE   (1),
    .CLKOUT6_DIVIDE   (1),
    .DIVCLK_DIVIDE    (1),
    .REF_JITTER1      (0.010),
    .STARTUP_WAIT     ("FALSE")
  ) uMmcm (
    .CLKIN1   (iClk100Mhz),
    .CLKFBIN  (ClkFbBuf),
    .RST      (1'b0),
    .PWRDWN   (1'b0),
    .CLKFBOUT (ClkFb),
    .CLKFBOUTB(),
    .CLKOUT0  (Clk80Unbuf),
    .CLKOUT0B (),
    .CLKOUT1  (),
    .CLKOUT1B (),
    .CLKOUT2  (),
    .CLKOUT2B (),
    .CLKOUT3  (),
    .CLKOUT3B (),
    .CLKOUT4  (),
    .CLKOUT5  (),
    .CLKOUT6  (),
    .LOCKED   (oLocked)
  );

  BUFG uClkFbBufg (
    .I(ClkFb),
    .O(ClkFbBuf)
  );

  BUFG uClkOutBufg (
    .I(Clk80Unbuf),
    .O(oClk80Mhz)
  );

endmodule
