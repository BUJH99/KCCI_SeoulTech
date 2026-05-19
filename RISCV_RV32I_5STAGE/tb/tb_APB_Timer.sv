/*
[TB_INFO_START]
Name: tb_APB_Timer
Target: APB_Timer
Role: Focused APB timer register, counter, and pending-output testbench
Scenario:
  - Checks reset readback, valid APB handshakes, unknown offset errors, prescale cadence, periodic match, W1C status, pending output, and count clear
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_APB_Timer;

  localparam logic [11:0] LP_TIMER_CTRL     = 12'h000;
  localparam logic [11:0] LP_TIMER_STATUS   = 12'h004;
  localparam logic [11:0] LP_TIMER_PRESCALE = 12'h008;
  localparam logic [11:0] LP_TIMER_PERIOD   = 12'h00C;
  localparam logic [11:0] LP_TIMER_COUNT    = 12'h010;
  localparam logic [11:0] LP_TIMER_COMPARE  = 12'h014;
  localparam logic [11:0] LP_TIMER_INFO     = 12'h018;

  localparam logic [31:0] LP_TIMER_INFO_VALUE = 32'h0007_2001;

  logic        iClk;
  logic        iRst;
  logic        iPsel;
  logic        iPenable;
  logic        iPwrite;
  logic [11:0] iPaddr;
  logic [3:0]  iPstrb;
  logic [31:0] iPwdata;
  logic [31:0] oPrdata;
  logic        oPready;
  logic        oPslverr;
  logic        oTimerIrqPending;

  APB_Timer #(
    .P_CLK_HZ (10)
  ) dut (
    .iClk(iClk),
    .iRst(iRst),
    .iPsel(iPsel),
    .iPenable(iPenable),
    .iPwrite(iPwrite),
    .iPaddr(iPaddr),
    .iPstrb(iPstrb),
    .iPwdata(iPwdata),
    .oPrdata(oPrdata),
    .oPready(oPready),
    .oPslverr(oPslverr),
    .oTimerIrqPending(oTimerIrqPending)
  );

  always #5 iClk = ~iClk;

  task automatic Tick;
    begin
      @(posedge iClk);
      #1;
    end
  endtask

  task automatic CheckEq1(input logic iActual, input logic iExpected, input string iContext);
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s expected=%0b got=%0b", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEq32(input logic [31:0] iActual, input logic [31:0] iExpected, input string iContext);
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s expected=0x%08x got=0x%08x", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic ResetDut;
    begin
      iRst    = 1'b1;
      iPsel    = 1'b0;
      iPenable = 1'b0;
      iPwrite  = 1'b0;
      iPaddr   = '0;
      iPstrb   = '0;
      iPwdata  = '0;
      repeat (3) Tick();
      iRst = 1'b0;
      Tick();
    end
  endtask

  task automatic ApbWr(input logic [11:0] iAddr, input logic [31:0] iData, output logic oErr);
    begin
      iPsel    = 1'b1;
      iPenable = 1'b0;
      iPwrite  = 1'b1;
      iPaddr   = iAddr;
      iPstrb   = 4'hF;
      iPwdata  = iData;
      Tick();
      iPenable = 1'b1;
      Tick();
      oErr = oPslverr;
      iPsel    = 1'b0;
      iPenable = 1'b0;
      iPwrite  = 1'b0;
      iPaddr   = '0;
      iPstrb   = '0;
      iPwdata  = '0;
      Tick();
    end
  endtask

  task automatic ApbRead(input logic [11:0] iAddr, output logic [31:0] oData, output logic oErr);
    begin
      iPsel    = 1'b1;
      iPenable = 1'b0;
      iPwrite  = 1'b0;
      iPaddr   = iAddr;
      iPstrb   = 4'h0;
      iPwdata  = '0;
      Tick();
      iPenable = 1'b1;
      #1;
      oData = oPrdata;
      oErr  = oPslverr;
      Tick();
      iPsel    = 1'b0;
      iPenable = 1'b0;
      iPaddr   = '0;
      Tick();
    end
  endtask

  task automatic WaitForPending(input int unsigned iTimeoutCycles, input string iContext);
    int unsigned waitIdx;
    begin
      for (waitIdx = 0; waitIdx < iTimeoutCycles; waitIdx = waitIdx + 1) begin
        Tick();
        if (oTimerIrqPending) begin
          return;
        end
      end
      $fatal(1, "[FAIL] %s pending output not asserted", iContext);
    end
  endtask

  initial begin
    logic [31:0] data;
    logic        err;

    iClk = 1'b0;
    ResetDut();

    ApbRead(LP_TIMER_CTRL, data, err);
    CheckEq1(err, 1'b0, "reset CTRL read error");
    CheckEq32(data, 32'd0, "reset CTRL");
    ApbRead(LP_TIMER_STATUS, data, err);
    CheckEq32(data, 32'd0, "reset STATUS");
    ApbRead(LP_TIMER_COMPARE, data, err);
    CheckEq32(data, 32'hFFFF_FFFF, "reset COMPARE");
    ApbRead(LP_TIMER_INFO, data, err);
    CheckEq32(data, LP_TIMER_INFO_VALUE, "INFO readback");

    ApbRead(12'h0FC, data, err);
    CheckEq1(err, 1'b1, "unknown offset read PSLVERR");
    ApbWr(LP_TIMER_INFO, 32'h1, err);
    CheckEq1(err, 1'b1, "INFO write PSLVERR");

    ApbWr(LP_TIMER_PRESCALE, 32'd1, err);
    CheckEq1(err, 1'b0, "PRESCALE write");
    ApbWr(LP_TIMER_PERIOD, 32'd2, err);
    ApbWr(LP_TIMER_CTRL, 32'h0000_0007, err);
    CheckEq1(oPready, 1'b1, "single-cycle ready");
    WaitForPending(20, "periodic timer");

    ApbRead(LP_TIMER_STATUS, data, err);
    CheckEq32(data & 32'h0000_0103, 32'h0000_0103, "periodic STATUS pending/match/running");
    CheckEq1(oTimerIrqPending, 1'b1, "pending follows INT_ENABLE and STATUS");

    ApbWr(LP_TIMER_CTRL, 32'h0000_0004, err);
    ApbWr(LP_TIMER_STATUS, 32'h0000_0001, err);
    CheckEq1(oTimerIrqPending, 1'b0, "W1C IRQ_PENDING drops pending output");
    ApbRead(LP_TIMER_STATUS, data, err);
    CheckEq32(data & 32'h2, 32'h2, "W1C selected bit leaves MATCH set");
    ApbWr(LP_TIMER_STATUS, 32'h0000_0002, err);

    ApbWr(LP_TIMER_CTRL, 32'h0000_0020, err);
    ApbWr(LP_TIMER_COUNT, 32'h0000_0055, err);
    ApbWr(LP_TIMER_CTRL, 32'h0000_0008, err);
    ApbRead(LP_TIMER_COUNT, data, err);
    CheckEq32(data, 32'd0, "CLEAR_COUNT pulse resets count");

    ApbWr(LP_TIMER_PRESCALE, 32'd0, err);
    ApbWr(LP_TIMER_COUNT, 32'hFFFF_FFFF, err);
    ApbWr(LP_TIMER_STATUS, 32'hFFFF_FFFF, err);
    ApbWr(LP_TIMER_CTRL, 32'h0000_0001, err);
    Tick();
    ApbRead(LP_TIMER_STATUS, data, err);
    CheckEq32(data & 32'h0000_0005, 32'h0000_0005, "overflow sets pending and overflow");

    $display("[PASS] tb_APB_Timer completed");
    $finish;
  end

  initial begin
    repeat (1000) @(posedge iClk);
    $fatal(1, "[FAIL] tb_APB_Timer watchdog expired");
  end

endmodule
