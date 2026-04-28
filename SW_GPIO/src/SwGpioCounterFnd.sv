/*
[MODULE_INFO_START]
Name: SwGpioCounterFnd
Role: Software-GPIO controlled up-counter with FND output
Summary:
  - Accepts GPIO command bits: bit0 run, bit1 stop
  - Counts 0000 to 9999 at P_COUNT_HZ while running and displays it on FND
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SwGpioCounterFnd #(
  parameter int unsigned P_CLK_HZ   = 100_000_000,
  parameter int unsigned P_COUNT_HZ = 1
) (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic [1:0]  iGpioCtrl,

  output logic [6:0]  oSeg,
  output logic        oDp,
  output logic [3:0]  oDigitSel,
  output logic [31:0] oGpioStatus
);

  localparam int unsigned LP_CTRL_RUN_BIT   = 0;
  localparam int unsigned LP_CTRL_STOP_BIT  = 1;

  logic [1:0]  cmdPulse;
  logic        runReqPulse;
  logic        stopReqPulse;
  logic        tickCount;
  logic        tick1kHz;
  logic        tick2Hz;
  logic        runActive;
  logic        countInc;
  logic [15:0] countBcd;
  logic        rolloverPulse;

  assign runReqPulse   = cmdPulse[LP_CTRL_RUN_BIT];
  assign stopReqPulse  = cmdPulse[LP_CTRL_STOP_BIT];
  assign countInc      = runActive && tickCount;
  assign oGpioStatus   = {
    12'd0,
    stopReqPulse,
    runReqPulse,
    rolloverPulse,
    runActive,
    countBcd
  };

  GpioCommandPulse #(
    .P_WIDTH(2)
  ) uGpioCommandPulse (
    .iClk      (iClk),
    .iRstn     (iRstn),
    .iCmdLevel (iGpioCtrl),
    .oCmdPulse (cmdPulse)
  );

  TickPulseGen #(
    .P_CLK_HZ  (P_CLK_HZ),
    .P_TICK_HZ (P_COUNT_HZ)
  ) uCountTickGen (
    .iClk  (iClk),
    .iRstn (iRstn),
    .oTick (tickCount)
  );

  TickPulseGen #(
    .P_CLK_HZ  (P_CLK_HZ),
    .P_TICK_HZ (1000)
  ) uFndScanTickGen (
    .iClk  (iClk),
    .iRstn (iRstn),
    .oTick (tick1kHz)
  );

  TickPulseGen #(
    .P_CLK_HZ  (P_CLK_HZ),
    .P_TICK_HZ (2)
  ) uFndBlinkTickGen (
    .iClk  (iClk),
    .iRstn (iRstn),
    .oTick (tick2Hz)
  );

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      runActive <= 1'b0;
    end else if (stopReqPulse) begin
      runActive <= 1'b0;
    end else if (runReqPulse) begin
      runActive <= 1'b1;
    end
  end

  BcdUpCounter4 uBcdUpCounter4 (
    .iClk           (iClk),
    .iRstn          (iRstn),
    .iClear         (1'b0),
    .iInc           (countInc),
    .oDigitsBcd     (countBcd),
    .oRolloverPulse (rolloverPulse)
  );

  FndController uFndController (
    .iClk       (iClk),
    .iRstn      (iRstn),
    .iTick1kHz  (tick1kHz),
    .iTick2Hz   (tick2Hz),
    .iDigitsBcd (countBcd),
    .iBlinkMask (4'h0),
    .iDpMask    (4'h0),
    .oSeg       (oSeg),
    .oDp        (oDp),
    .oDigitSel  (oDigitSel)
  );

endmodule
