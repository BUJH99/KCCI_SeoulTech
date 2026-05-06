/*
[TB_INFO_START]
Name: tb_TOP_BubbleSort
Target: TOP
Role: Self-checking bubble-sort program testbench for the RISCV_32I_5STAGE core
Scenario:
  - Loads a ROM program that seeds 3, 1, 0, 4, 2 into DMEM and runs an ascending bubble sort
  - Waits for the CPU to raise a DMEM done flag at 0x0000_0094
  - Checks the sorted result 0, 1, 2, 3, 4 and the final self-loop PC
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_TOP_BubbleSort;

  import rv32i_pkg::*;

  localparam logic [31:0] LP_NOP_INSTR         = 32'h0000_0013;
  localparam int unsigned LP_ROM_DEPTH         = 256;
  localparam int unsigned LP_RAM_DEPTH         = 256;
  localparam int unsigned LP_SIM_CLK_HZ        = 153_600;
  localparam int unsigned LP_UART_BAUD         = 9_600;
  localparam int unsigned LP_GPIO_WIDTH        = 8;
  localparam logic [31:0] LP_ARRAY_BASE_ADDR   = 32'h0000_0080;
  localparam logic [31:0] LP_DONE_FLAG_ADDR    = 32'h0000_0094;
  localparam int unsigned LP_ARRAY_BASE_WORD   = int'(LP_ARRAY_BASE_ADDR[31:2]);
  localparam int unsigned LP_DONE_FLAG_WORD    = int'(LP_DONE_FLAG_ADDR[31:2]);
  localparam int unsigned LP_SORTED_LEN        = 5;
  localparam logic [31:0] LP_DONE_LOOP_PC      = 32'd116;
  localparam int unsigned LP_DONE_BUDGET_CYCLES = 800;

  logic iClk;
  logic iRstn;
  logic iUartRx;
  logic [LP_GPIO_WIDTH-1:0] iGpioIn;
  logic iI2cSdaIn;
  logic iSpiMiso;
  logic oUartTx;
  logic [LP_GPIO_WIDTH-1:0] oGpioOut;
  logic [LP_GPIO_WIDTH-1:0] oGpioOe;
  logic oI2cScl;
  logic oI2cSdaOut;
  logic oI2cSdaOe;
  logic oSpiSclk;
  logic oSpiMosi;
  logic oSpiCsN;
  logic [6:0] oSeg;
  logic oDp;
  logic [3:0] oDigitSel;
  logic oTimingProbe;

  TOP #(
    .P_CLK_HZ     (LP_SIM_CLK_HZ),
    .P_UART_BAUD  (LP_UART_BAUD),
    .P_GPIO_WIDTH (LP_GPIO_WIDTH)
  ) dut (
    .iClk         (iClk),
    .iRstn        (iRstn),
    .iUartRx      (iUartRx),
    .iGpioIn      (iGpioIn),
    .iI2cSdaIn    (iI2cSdaIn),
    .iSpiMiso     (iSpiMiso),
    .oUartTx      (oUartTx),
    .oGpioOut     (oGpioOut),
    .oGpioOe      (oGpioOe),
    .oI2cScl      (oI2cScl),
    .oI2cSdaOut   (oI2cSdaOut),
    .oI2cSdaOe    (oI2cSdaOe),
    .oSpiSclk     (oSpiSclk),
    .oSpiMosi     (oSpiMosi),
    .oSpiCsN      (oSpiCsN),
    .oSeg         (oSeg),
    .oDp          (oDp),
    .oDigitSel    (oDigitSel),
    .oTimingProbe (oTimingProbe)
  );

  always #5 iClk = ~iClk;

  initial begin
    iClk        = 1'b0;
    iRstn       = 1'b0;
    iUartRx     = 1'b1;
    iGpioIn     = '0;
    iI2cSdaIn   = 1'b1;
    iSpiMiso    = 1'b0;
  end

  task automatic CheckEq32(
    input logic [31:0] iActual,
    input logic [31:0] iExpected,
    input string       iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected 0x%08x, got 0x%08x", iContext, iExpected, iActual);
      end
    end
  endtask

  function automatic logic [31:0] GetDmemWord(input int unsigned iIdx);
    GetDmemWord = dut.uDataRam.MemRam[iIdx];
  endfunction

  task automatic ClearInstrRom;
    integer Idx;
    begin
      for (Idx = 0; Idx < LP_ROM_DEPTH; Idx = Idx + 1) begin
        dut.uInstrRom.MemRom[Idx] = LP_NOP_INSTR;
      end
    end
  endtask

  task automatic ClearDataRam;
    integer Idx;
    begin
      for (Idx = 0; Idx < LP_RAM_DEPTH; Idx = Idx + 1) begin
        dut.uDataRam.MemRam[Idx] = '0;
      end
    end
  endtask

  task automatic LoadRomWord(
    input int unsigned iPc,
    input logic [31:0] iInstr
  );
    begin
      dut.uInstrRom.MemRom[iPc[9:2]] = iInstr;
    end
  endtask

  task automatic WaitCycles(input int unsigned iCycles);
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iCycles; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
      end
    end
  endtask

  task automatic LoadBubbleSortProgram;
    begin
      ClearInstrRom();
      ClearDataRam();

      // 32-bit machine words with matching assembly comments for quick ROM review.
      LoadRomWord(32'd0,   32'h0800_0093); // addi x1,  x0, 128
      LoadRomWord(32'd4,   32'h0940_0113); // addi x2,  x0, 148
      LoadRomWord(32'd8,   32'h0030_0193); // addi x3,  x0, 3
      LoadRomWord(32'd12,  32'h0030_a023); // sw   x3,  0(x1)
      LoadRomWord(32'd16,  32'h0010_0193); // addi x3,  x0, 1
      LoadRomWord(32'd20,  32'h0030_a223); // sw   x3,  4(x1)
      LoadRomWord(32'd24,  32'h0000_0193); // addi x3,  x0, 0
      LoadRomWord(32'd28,  32'h0030_a423); // sw   x3,  8(x1)
      LoadRomWord(32'd32,  32'h0040_0193); // addi x3,  x0, 4
      LoadRomWord(32'd36,  32'h0030_a623); // sw   x3,  12(x1)
      LoadRomWord(32'd40,  32'h0020_0193); // addi x3,  x0, 2
      LoadRomWord(32'd44,  32'h0030_a823); // sw   x3,  16(x1)
      LoadRomWord(32'd48,  32'h0001_2023); // sw   x0,  0(x2)

      LoadRomWord(32'd52,  32'h0000_0413); // addi x8,  x0, 0
      LoadRomWord(32'd56,  32'h0040_0493); // addi x9,  x0, 4
      LoadRomWord(32'd60,  32'h0040_0513); // addi x10, x0, 4
      LoadRomWord(32'd64,  32'h4085_0533); // sub  x10, x10, x8
      LoadRomWord(32'd68,  32'h0000_0593); // addi x11, x0, 0
      LoadRomWord(32'd72,  32'h0000_8613); // addi x12, x1, 0

      LoadRomWord(32'd76,  32'h0006_2683); // lw   x13, 0(x12)
      LoadRomWord(32'd80,  32'h0046_2703); // lw   x14, 4(x12)
      LoadRomWord(32'd84,  32'h02d7_4263); // blt  x14, x13, swap
      LoadRomWord(32'd88,  32'h0046_0613); // addi x12, x12, 4
      LoadRomWord(32'd92,  32'h0015_8593); // addi x11, x11, 1
      LoadRomWord(32'd96,  32'hfea5_c6e3); // blt  x11, x10, inner_loop
      LoadRomWord(32'd100, 32'h0014_0413); // addi x8,  x8, 1
      LoadRomWord(32'd104, 32'hfc94_4ae3); // blt  x8,  x9, outer_loop
      LoadRomWord(32'd108, 32'h0010_0793); // addi x15, x0, 1
      LoadRomWord(32'd112, 32'h00f1_2023); // sw   x15, 0(x2)
      LoadRomWord(32'd116, 32'h0000_006f); // jal  x0,  done_loop

      LoadRomWord(32'd120, 32'h00e6_2023); // sw   x14, 0(x12)
      LoadRomWord(32'd124, 32'h00d6_2223); // sw   x13, 4(x12)
      LoadRomWord(32'd128, 32'h0046_0613); // addi x12, x12, 4
      LoadRomWord(32'd132, 32'h0015_8593); // addi x11, x11, 1
      LoadRomWord(32'd136, 32'hfca5_c2e3); // blt  x11, x10, inner_loop
      LoadRomWord(32'd140, 32'h0014_0413); // addi x8,  x8, 1
      LoadRomWord(32'd144, 32'hfa94_46e3); // blt  x8,  x9, outer_loop
      LoadRomWord(32'd148, 32'h0010_0793); // addi x15, x0, 1
      LoadRomWord(32'd152, 32'h00f1_2023); // sw   x15, 0(x2)
      LoadRomWord(32'd156, 32'h0000_006f); // jal  x0,  done_loop
    end
  endtask

  task automatic WaitForDoneFlag(
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.uRv32iCore.TrapEnterValid) begin
          $fatal(
            1,
            "[FAIL] %s: unexpected trap (pc=0x%08x, mcause=0x%08x)",
            iContext,
            dut.uRv32iCore.Pc,
            dut.uRv32iCore.uCsrFile.Mcause
          );
        end
        if (GetDmemWord(LP_DONE_FLAG_WORD) == 32'd1) begin
          return;
        end
      end

      $fatal(
        1,
        "[FAIL] %s: done flag not observed within %0d cycles (pc=0x%08x, done=0x%08x)",
        iContext,
        iBudgetCycles,
        dut.uRv32iCore.Pc,
        GetDmemWord(LP_DONE_FLAG_WORD)
      );
    end
  endtask

  task automatic WaitForPc(
    input logic [31:0] iExpectedPc,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.uRv32iCore.Pc == iExpectedPc) begin
          return;
        end
      end

      $fatal(
        1,
        "[FAIL] %s: PC 0x%08x not observed within %0d cycles (current pc=0x%08x)",
        iContext,
        iExpectedPc,
        iBudgetCycles,
        dut.uRv32iCore.Pc
      );
    end
  endtask

  task automatic CheckSortedArray;
    integer Idx;
    logic [31:0] ExpectedWord;
    begin
      CheckEq32(GetDmemWord(LP_DONE_FLAG_WORD), 32'd1, "bubble sort done flag");
      for (Idx = 0; Idx < LP_SORTED_LEN; Idx = Idx + 1) begin
        ExpectedWord = Idx;
        CheckEq32(
          GetDmemWord(LP_ARRAY_BASE_WORD + Idx),
          ExpectedWord,
          $sformatf("bubble sort array[%0d]", Idx)
        );
      end
    end
  endtask

  initial begin : run_test
    LoadBubbleSortProgram();
    WaitCycles(4);
    iRstn = 1'b1;

    WaitForDoneFlag(LP_DONE_BUDGET_CYCLES, "bubble sort done flag");
    WaitForPc(LP_DONE_LOOP_PC, 20, "bubble sort done self-loop PC");
    CheckSortedArray();
    CheckEq32(dut.uRv32iCore.Pc, LP_DONE_LOOP_PC, "bubble sort done self-loop PC");

    $display(
      "[PASS] bubble sort completed: array={%0d,%0d,%0d,%0d,%0d} sim_time_ns=%0t",
      GetDmemWord(LP_ARRAY_BASE_WORD + 0),
      GetDmemWord(LP_ARRAY_BASE_WORD + 1),
      GetDmemWord(LP_ARRAY_BASE_WORD + 2),
      GetDmemWord(LP_ARRAY_BASE_WORD + 3),
      GetDmemWord(LP_ARRAY_BASE_WORD + 4),
      $time
    );
    $finish;
  end

  initial begin : watchdog
    repeat (5000) @(posedge iClk);
    $fatal(1, "[FAIL] Watchdog expired at sim_time_ns=%0t", $time);
  end

endmodule
