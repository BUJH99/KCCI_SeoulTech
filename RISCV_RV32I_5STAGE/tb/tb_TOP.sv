/*
[TB_INFO_START]
Name: tb_TOP
Target: TOP
Role: Self-checking regression testbench for the RISCV_32I_5STAGE core
Scenario:
  - Runs the shared InstructionFORTIMING benchmark and reports cycles, retires, and CPI
  - Preserves the existing forwarding, stall, and flush regressions
  - Adds MMIO, CSR, trap, MRET, and external interrupt scenarios for the APB/CSR integration
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_TOP;

  import rv32i_pkg::*;

  localparam logic [31:0] LP_NOP_INSTR     = 32'h0000_0013;
  localparam logic [31:0] LP_BENCH_DONE_PC = 32'h0000_0168;
  localparam logic [31:0] LP_TRAP_VECTOR   = 32'h0000_0040;
  localparam int unsigned LP_ROM_DEPTH     = 256;
  localparam int unsigned LP_RAM_DEPTH     = 256;
  localparam int unsigned LP_SIM_CLK_HZ    = 153_600;
  localparam int unsigned LP_UART_BAUD     = 9_600;
  localparam int unsigned LP_GPIO_WIDTH    = 8;
  localparam int unsigned LP_UART_BIT_CYCLES = (LP_SIM_CLK_HZ / LP_UART_BAUD);

  logic iClk;
  logic iRstn;
  logic iUartRx;
  logic [LP_GPIO_WIDTH-1:0] iGpioIn;
  logic oUartTx;
  logic [LP_GPIO_WIDTH-1:0] oGpioOut;
  logic [LP_GPIO_WIDTH-1:0] oGpioOe;
  logic [6:0] oSeg;
  logic oDp;
  logic [3:0] oDigitSel;
  logic oTimingProbe;

  int unsigned CycleCount;

  TOP #(
    .P_CLK_HZ     (LP_SIM_CLK_HZ),
    .P_UART_BAUD  (LP_UART_BAUD),
    .P_GPIO_WIDTH (LP_GPIO_WIDTH)
  ) dut (
    .iClk        (iClk),
    .iRstn       (iRstn),
    .iUartRx     (iUartRx),
    .iGpioIn     (iGpioIn),
    .oUartTx     (oUartTx),
    .oGpioOut    (oGpioOut),
    .oGpioOe     (oGpioOe),
    .oSeg        (oSeg),
    .oDp         (oDp),
    .oDigitSel   (oDigitSel),
    .oTimingProbe(oTimingProbe)
  );

  always #5 iClk = ~iClk;

  always @(posedge iClk) begin
    CycleCount <= CycleCount + 1;
  end

  initial begin
    iClk       = 1'b0;
    iRstn      = 1'b0;
    iUartRx    = 1'b1;
    iGpioIn    = '0;
    CycleCount = 0;
  end

  initial begin : run_test
    RunBenchmarkTest();
    RunExMemForwardTest();
    RunMemWbForwardTest();
    RunStoreForwardTest();
    RunLoadUseStallTest();
    RunJalrForwardTest();
    RunBranchFlushTest();
    RunJalFlushAndKilledStoreTest();
    RunMisalignedLoadTrapTest();
    RunMisalignedStoreTrapTest();
    RunFenceAndX0Test();
    RunGpioMmioTest();
    RunFndMmioTest();
    RunApbZeroWaitProtocolTest();
    RunApbWaitStateHoldTest();
    RunCsrOpsTest();
    RunMretRedirectTest();
    RunUartTxMmioTest();
    RunAccessFaultTest();
    RunUartInterruptTest();
    RunGpioInterruptTest();
    RunInterruptPriorityTest();
    RunInterruptCompleteGateTest();
    RunInterruptMaskTest();

    $display("[PASS] tb_TOP completed all 5-stage checks in %0d total cycles", CycleCount);
    $finish;
  end

  initial begin : watchdog
    repeat (50000) @(posedge iClk);
    $fatal(1, "[FAIL] Watchdog expired after %0d cycles", CycleCount);
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

  task automatic CheckEq1(
    input logic  iActual,
    input logic  iExpected,
    input string iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected %0b, got %0b", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEqint(
    input int unsigned iActual,
    input int unsigned iExpected,
    input string       iContext
  );
    begin
      if (iActual != iExpected) begin
        $fatal(1, "[FAIL] %s: expected %0d, got %0d", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEqFwd(
    input ForwardSelE iActual,
    input ForwardSelE iExpected,
    input string        iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected forward sel %0d, got %0d", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEqTrap(
    input TrapCauseE iActual,
    input TrapCauseE iExpected,
    input string       iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected trap cause %0d, got %0d", iContext, iExpected, iActual);
      end
    end
  endtask

  function automatic logic [31:0] EncIType(
    input logic [11:0] iImm12,
    input logic [4:0]  iRs1,
    input logic [2:0]  iFunct3,
    input logic [4:0]  iRd,
    input logic [6:0]  iOpcode
  );
    EncIType = {iImm12, iRs1, iFunct3, iRd, iOpcode};
  endfunction

  function automatic logic [31:0] EncSType(
    input logic [11:0] iImm12,
    input logic [4:0]  iRs2,
    input logic [4:0]  iRs1,
    input logic [2:0]  iFunct3
  );
    EncSType = {iImm12[11:5], iRs2, iRs1, iFunct3, iImm12[4:0], LP_OPCODE_STORE};
  endfunction

  function automatic logic [31:0] EncUType(
    input logic [19:0] iImm20,
    input logic [4:0]  iRd,
    input logic [6:0]  iOpcode
  );
    EncUType = {iImm20, iRd, iOpcode};
  endfunction

  function automatic logic [31:0] EncAddi(
    input logic [4:0] iRd,
    input logic [4:0] iRs1,
    input integer     iImm
  );
    EncAddi = EncIType(iImm[11:0], iRs1, 3'b000, iRd, LP_OPCODE_OPIMM);
  endfunction

  function automatic logic [31:0] EncLui(
    input logic [4:0]  iRd,
    input logic [19:0] iImm20
  );
    EncLui = EncUType(iImm20, iRd, LP_OPCODE_LUI);
  endfunction

  function automatic logic [31:0] EncLoad(
    input logic [4:0] iRd,
    input logic [4:0] iRs1,
    input integer     iImm,
    input logic [2:0] iFunct3
  );
    EncLoad = EncIType(iImm[11:0], iRs1, iFunct3, iRd, LP_OPCODE_LOAD);
  endfunction

  function automatic logic [31:0] EncStore(
    input logic [4:0] iRs2,
    input logic [4:0] iRs1,
    input integer     iImm,
    input logic [2:0] iFunct3
  );
    EncStore = EncSType(iImm[11:0], iRs2, iRs1, iFunct3);
  endfunction

  function automatic logic [31:0] EncBType(
    input integer     iImm,
    input logic [4:0] iRs2,
    input logic [4:0] iRs1,
    input logic [2:0] iFunct3
  );
    logic [12:0] Imm13;
    begin
      Imm13   = iImm[12:0];
      EncBType = {Imm13[12], Imm13[10:5], iRs2, iRs1, iFunct3, Imm13[4:1], Imm13[11], LP_OPCODE_BRANCH};
    end
  endfunction

  function automatic logic [31:0] EncBeq(
    input logic [4:0] iRs1,
    input logic [4:0] iRs2,
    input integer     iImm
  );
    EncBeq = EncBType(iImm, iRs2, iRs1, 3'b000);
  endfunction

  function automatic logic [31:0] EncJType(
    input integer     iImm,
    input logic [4:0] iRd
  );
    logic [20:0] Imm21;
    begin
      Imm21   = iImm[20:0];
      EncJType = {Imm21[20], Imm21[10:1], Imm21[11], Imm21[19:12], iRd, LP_OPCODE_JAL};
    end
  endfunction

  function automatic logic [31:0] EncJal(
    input logic [4:0] iRd,
    input integer     iImm
  );
    EncJal = EncJType(iImm, iRd);
  endfunction

  function automatic logic [31:0] EncCsrReg(
    input logic [4:0]  iRd,
    input logic [4:0]  iRs1,
    input logic [11:0] iCsrAddr,
    input logic [2:0]  iFunct3
  );
    EncCsrReg = {iCsrAddr, iRs1, iFunct3, iRd, LP_OPCODE_SYSTEM};
  endfunction

  function automatic logic [31:0] EncCsrImm(
    input logic [4:0]  iRd,
    input logic [4:0]  iZimm,
    input logic [11:0] iCsrAddr,
    input logic [2:0]  iFunct3
  );
    EncCsrImm = {iCsrAddr, iZimm, iFunct3, iRd, LP_OPCODE_SYSTEM};
  endfunction

  function automatic logic [31:0] EncMret;
    EncMret = {LP_SYSTEM_MRET, 5'd0, 3'b000, 5'd0, LP_OPCODE_SYSTEM};
  endfunction

  function automatic logic [31:0] GetRfWord(input int unsigned iIdx);
    GetRfWord = dut.uDecodeStage.uRegfile.MemReg[iIdx];
  endfunction

  function automatic logic [31:0] GetDmemWord(input int unsigned iIdx);
    GetDmemWord = dut.uDataRam.MemRam[iIdx];
  endfunction

  task automatic ClearInstrRom;
    integer Idx;
    begin
      for (Idx = 0; Idx < LP_ROM_DEPTH; Idx = Idx + 1) begin
        dut.uFetchStage.uInstrRom.MemRom[Idx] = LP_NOP_INSTR;
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

  task automatic HoldResetAndClear;
    begin
      iRstn = 1'b0;
      iUartRx = 1'b1;
      iGpioIn = '0;
      ClearInstrRom();
      ClearDataRam();
      repeat (4) @(posedge iClk);
    end
  endtask

  task automatic HoldResetAndClearDataOnly;
    begin
      iRstn = 1'b0;
      iUartRx = 1'b1;
      iGpioIn = '0;
      ClearDataRam();
      repeat (4) @(posedge iClk);
    end
  endtask

  task automatic ReleaseReset;
    begin
      iRstn = 1'b1;
    end
  endtask

  task automatic LoadRomWord(
    input int unsigned iPc,
    input logic [31:0] iInstr
  );
    begin
      dut.uFetchStage.uInstrRom.MemRom[iPc[9:2]] = iInstr;
    end
  endtask

  task automatic WaitForRetirePc(
    input logic [31:0] iExpectedPc,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.RetireValid && (dut.RetirePc == iExpectedPc)) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s: expected retire PC 0x%08x within %0d cycles, current retireValid=%0b retirePc=0x%08x",
        iContext,
        iExpectedPc,
        iBudgetCycles,
        dut.RetireValid,
        dut.RetirePc
      );
    end
  endtask

  task automatic WaitForExStagePc(
    input logic [31:0] iExpectedPc,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.IDEX.Valid && (dut.IDEX.Pc == iExpectedPc)) begin
          return;
        end
      end
      $fatal(1, "[FAIL] %s: EX stage never observed PC 0x%08x", iContext, iExpectedPc);
    end
  endtask

  task automatic WaitForIdStagePc(
    input logic [31:0] iExpectedPc,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.IFID.Valid && (dut.IFID.Pc == iExpectedPc)) begin
          return;
        end
      end
      $fatal(1, "[FAIL] %s: ID stage never observed PC 0x%08x", iContext, iExpectedPc);
    end
  endtask

  task automatic WaitForTrapState(
    input logic [31:0] iExpectedVectorPc,
    input logic [31:0] iExpectedEpc,
    input logic [31:0] iExpectedCause,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if ((dut.Pc == iExpectedVectorPc)
         && (dut.uCsrFile.Mepc == iExpectedEpc)
         && (dut.uCsrFile.Mcause == iExpectedCause)) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s: trap state not observed (pc=0x%08x mepc=0x%08x mcause=0x%08x)",
        iContext,
        dut.Pc,
        dut.uCsrFile.Mepc,
        dut.uCsrFile.Mcause
      );
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

  task automatic WaitForGpioApbSetup(
    input logic [11:0] iExpectedAddr,
    input logic [3:0]  iExpectedStrb,
    input logic [31:0] iExpectedWdata,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.GpioPsel && !dut.ApbPenable) begin
          CheckEq1(dut.ApbPwrite, 1'b1, $sformatf("%s setup write", iContext));
          CheckEq32({20'd0, dut.ApbPaddr}, {20'd0, iExpectedAddr}, $sformatf("%s setup addr", iContext));
          CheckEq32({28'd0, dut.ApbPstrb}, {28'd0, iExpectedStrb}, $sformatf("%s setup strb", iContext));
          CheckEq32(dut.ApbPwdata, iExpectedWdata, $sformatf("%s setup wdata", iContext));
          return;
        end
      end

      $fatal(1, "[FAIL] %s: GPIO APB setup phase not observed within %0d cycles", iContext, iBudgetCycles);
    end
  endtask

  task automatic WaitForGpioApbAccess(
    input logic [11:0] iExpectedAddr,
    input logic [3:0]  iExpectedStrb,
    input logic [31:0] iExpectedWdata,
    input logic        iExpectedReady,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.GpioPsel && dut.ApbPenable) begin
          CheckEq1(dut.ApbPwrite, 1'b1, $sformatf("%s access write", iContext));
          CheckEq32({20'd0, dut.ApbPaddr}, {20'd0, iExpectedAddr}, $sformatf("%s access addr", iContext));
          CheckEq32({28'd0, dut.ApbPstrb}, {28'd0, iExpectedStrb}, $sformatf("%s access strb", iContext));
          CheckEq32(dut.ApbPwdata, iExpectedWdata, $sformatf("%s access wdata", iContext));
          CheckEq1(dut.DataBusRsp.RspReady, iExpectedReady, $sformatf("%s access ready", iContext));
          return;
        end
      end

      $fatal(1, "[FAIL] %s: GPIO APB access phase not observed within %0d cycles", iContext, iBudgetCycles);
    end
  endtask

  task automatic SendUartByte(input logic [7:0] iByte);
    int unsigned BitIdx;
    begin
      iUartRx = 1'b1;
      WaitCycles(LP_UART_BIT_CYCLES);
      iUartRx = 1'b0;
      WaitCycles(LP_UART_BIT_CYCLES);

      for (BitIdx = 0; BitIdx < 8; BitIdx = BitIdx + 1) begin
        iUartRx = iByte[BitIdx];
        WaitCycles(LP_UART_BIT_CYCLES);
      end

      iUartRx = 1'b1;
      WaitCycles(LP_UART_BIT_CYCLES);
      WaitCycles(LP_UART_BIT_CYCLES);
    end
  endtask

  task automatic RunBenchmarkTest;
    int unsigned ExecCycles;
    int unsigned RetiredInstrs;
    int unsigned StallCount;
    int unsigned WaitIdx;
    bit          Started;
    bit          DoneSeen;
    real         Cpi;
    begin
      HoldResetAndClearDataOnly();
      ReleaseReset();

      ExecCycles   = 0;
      RetiredInstrs = 0;
      StallCount   = 0;
      Started      = 1'b0;
      DoneSeen     = 1'b0;

      for (WaitIdx = 0; WaitIdx < 2000; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (!Started && dut.FetchValid) begin
          Started = 1'b1;
        end
        if (Started) begin
          ExecCycles = ExecCycles + 1;
        end
        if (dut.RetireValid) begin
          RetiredInstrs = RetiredInstrs + 1;
        end
        if (dut.LoadUseStall) begin
          StallCount = StallCount + 1;
        end
        if (dut.RetireValid && (dut.RetirePc == LP_BENCH_DONE_PC)) begin
          DoneSeen = 1'b1;
          break;
        end
      end

      if (!DoneSeen) begin
        $fatal(1, "[FAIL] benchmark did not reach done retire");
      end

      Cpi = ExecCycles;
      Cpi = Cpi / RetiredInstrs;
      $display("[INFO] benchmark cycles=%0d retires=%0d CPI=%0.4f", ExecCycles, RetiredInstrs, Cpi);

      CheckEqint(StallCount, 1, "benchmark load-use stall count");

      CheckEq32(GetRfWord(0),  32'h0000_0000, "benchmark x0 hard-wire");
      CheckEq32(GetRfWord(1),  32'h0000_000F, "benchmark x1");
      CheckEq32(GetRfWord(2),  32'h0000_0003, "benchmark x2");
      CheckEq32(GetRfWord(3),  32'hFFFF_FFF0, "benchmark x3");
      CheckEq32(GetRfWord(4),  32'h0000_F234, "benchmark x4");
      CheckEq32(GetRfWord(5),  32'hFFFF_FF00, "benchmark x5");
      CheckEq32(GetRfWord(6),  32'h0000_E468, "benchmark x6");
      CheckEq32(GetRfWord(7),  32'h0000_0006, "benchmark x7");
      CheckEq32(GetRfWord(8),  32'h0000_0006, "benchmark x8");
      CheckEq32(GetRfWord(9),  32'h0000_0000, "benchmark x9");
      CheckEq32(GetRfWord(10), 32'h0000_0006, "benchmark x10");
      CheckEq32(GetRfWord(11), 32'h0000_0144, "benchmark x11");
      CheckEq32(GetRfWord(12), 32'h0000_0158, "benchmark x12");
      CheckEq32(GetRfWord(13), 32'h0000_0154, "benchmark x13");
      CheckEq32(GetRfWord(14), 32'h0000_0014, "benchmark x14");
      CheckEq32(GetRfWord(15), 32'h0000_0037, "benchmark x15");
      CheckEq32(GetRfWord(16), 32'h1234_500F, "benchmark x16");
      CheckEq32(GetRfWord(17), 32'h0000_1067, "benchmark x17");
      CheckEq32(GetRfWord(18), 32'h0000_000F, "benchmark x18");
      CheckEq32(GetRfWord(19), 32'h0000_0007, "benchmark x19");
      CheckEq32(GetRfWord(20), 32'h0000_0030, "benchmark x20");
      CheckEq32(GetRfWord(21), 32'h0000_0007, "benchmark x21");
      CheckEq32(GetRfWord(22), 32'hFFFF_FFFC, "benchmark x22");
      CheckEq32(GetRfWord(23), 32'h0000_0080, "benchmark x23");
      CheckEq32(GetRfWord(24), 32'h0000_0090, "benchmark x24");
      CheckEq32(GetRfWord(25), 32'h1234_5000, "benchmark x25");
      CheckEq32(GetRfWord(26), 32'h0000_1064, "benchmark x26");
      CheckEq32(GetRfWord(27), 32'h0000_0014, "benchmark x27");
      CheckEq32(GetRfWord(28), 32'h0000_0017, "benchmark x28");
      CheckEq32(GetRfWord(29), 32'hFFFF_FF80, "benchmark x29");
      CheckEq32(GetRfWord(30), 32'h0000_0080, "benchmark x30");
      CheckEq32(GetRfWord(31), 32'hFFFF_F234, "benchmark x31");
      CheckEq32(GetDmemWord(32), 32'h0000_0014, "benchmark DMEM[0x80]");
      CheckEq32(GetDmemWord(33), 32'hF234_7F80, "benchmark DMEM[0x84]");

      @(posedge iClk);
      @(posedge iClk);
      CheckEq32(dut.Pc, LP_BENCH_DONE_PC, "benchmark done self-loop PC");
    end
  endtask

  task automatic RunExMemForwardTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  32'h0050_0093); // addi x1, x0, 5
      LoadRomWord(32'd8,  32'h0010_8133); // add  x2, x1, x1
      LoadRomWord(32'd12, 32'h0000_006F); // jal  x0, 0
      ReleaseReset();

      WaitForExStagePc(32'd8, 20, "EX/MEM->EX bypass stage");
      CheckEqFwd(dut.uExecuteStage.ExRs1FwdSel, FWD_EX_MEM, "EX/MEM->EX rs1 bypass");
      CheckEqFwd(dut.uExecuteStage.ExRs2FwdSel, FWD_EX_MEM, "EX/MEM->EX rs2 bypass");

      WaitForRetirePc(32'd12, 40, "EX/MEM->EX final loop");
      CheckEq32(GetRfWord(2), 32'h0000_000A, "EX/MEM->EX result");
    end
  endtask

  task automatic RunMemWbForwardTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  32'h0050_0093); // addi x1, x0, 5
      LoadRomWord(32'd8,  32'h0000_0193); // addi x3, x0, 0
      LoadRomWord(32'd12, 32'h0000_8233); // add  x4, x1, x0
      LoadRomWord(32'd16, 32'h0000_006F); // jal  x0, 0
      ReleaseReset();

      WaitForExStagePc(32'd12, 30, "MEM/WB->EX bypass stage");
      CheckEqFwd(dut.uExecuteStage.ExRs1FwdSel, FWD_MEM_WB, "MEM/WB->EX rs1 bypass");
      WaitForRetirePc(32'd16, 50, "MEM/WB->EX final loop");
      CheckEq32(GetRfWord(4), 32'h0000_0005, "MEM/WB->EX result");
    end
  endtask

  task automatic RunStoreForwardTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4, 32'h0050_0093); // addi x1, x0, 5
      LoadRomWord(32'd8, 32'h0010_2023); // sw   x1, 0(x0)
      LoadRomWord(32'd12, 32'h0000_006F); // jal  x0, 0
      ReleaseReset();

      WaitForExStagePc(32'd8, 20, "store-data bypass stage");
      CheckEqFwd(dut.uExecuteStage.ExRs2FwdSel, FWD_EX_MEM, "OPIMM->STORE store-data bypass");
      WaitForRetirePc(32'd12, 40, "store-data bypass final loop");
      CheckEq32(GetDmemWord(0), 32'h0000_0005, "store-data bypass memory write");
    end
  endtask

  task automatic RunLoadUseStallTest;
    int unsigned StallCount;
    int unsigned WaitIdx;
    bit          SeenConsumerEx;
    begin
      HoldResetAndClear();
      dut.uDataRam.MemRam[0] = 32'h1234_5678;
      LoadRomWord(32'd4, 32'h0000_2083); // lw   x1, 0(x0)
      LoadRomWord(32'd8, 32'h0000_8133); // add  x2, x1, x0
      LoadRomWord(32'd12, 32'h0000_006F); // jal  x0, 0
      ReleaseReset();

      StallCount = 0;
      SeenConsumerEx = 1'b0;
      for (WaitIdx = 0; WaitIdx < 50; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.LoadUseStall) begin
          StallCount = StallCount + 1;
        end
        if (!SeenConsumerEx && dut.IDEX.Valid && (dut.IDEX.Pc == 32'd8)) begin
          SeenConsumerEx = 1'b1;
          CheckEqFwd(dut.uExecuteStage.ExRs1FwdSel, FWD_MEM_WB, "LOAD->use MEM/WB bypass after stall");
        end
        if (dut.RetireValid && (dut.RetirePc == 32'd12)) begin
          break;
        end
      end

      CheckEq1(SeenConsumerEx, 1'b1, "LOAD->use consumer reached EX");
      CheckEqint(StallCount, 1, "LOAD->use one-cycle stall count");
      CheckEq32(GetRfWord(1), 32'h1234_5678, "LOAD value");
      CheckEq32(GetRfWord(2), 32'h1234_5678, "LOAD->use result");
    end
  endtask

  task automatic RunJalrForwardTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  32'h0140_0093); // addi x1, x0, 20
      LoadRomWord(32'd8,  32'h0000_8167); // jalr x2, x1, 0
      LoadRomWord(32'd12, 32'h0630_0193); // addi x3, x0, 99 (killed)
      LoadRomWord(32'd16, 32'h0000_0013); // nop
      LoadRomWord(32'd20, 32'h0010_0213); // addi x4, x0, 1
      LoadRomWord(32'd24, 32'h0000_006F); // jal  x0, 0
      ReleaseReset();

      WaitForExStagePc(32'd8, 30, "JALR forwarded-base stage");
      CheckEqFwd(dut.uExecuteStage.ExRs1FwdSel, FWD_EX_MEM, "JALR rs1 bypass");
      CheckEq1(dut.ExRedirectValid, 1'b1, "JALR EX redirect");

      WaitForRetirePc(32'd24, 60, "JALR forwarded-base final loop");
      CheckEq32(GetRfWord(2), 32'h0000_000C, "JALR link register");
      CheckEq32(GetRfWord(3), 32'h0000_0000, "JALR skipped instruction");
      CheckEq32(GetRfWord(4), 32'h0000_0001, "JALR target execution");
    end
  endtask

  task automatic RunBranchFlushTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  32'h0010_0093); // addi x1, x0, 1
      LoadRomWord(32'd8,  32'h0010_8463); // beq  x1, x1, +8
      LoadRomWord(32'd12, 32'h0630_0113); // addi x2, x0, 99 (killed)
      LoadRomWord(32'd16, 32'h0010_0193); // addi x3, x0, 1
      LoadRomWord(32'd20, 32'h0000_006F); // jal  x0, 0
      ReleaseReset();

      WaitForExStagePc(32'd8, 30, "taken branch flush stage");
      CheckEq1(dut.ExRedirectValid, 1'b1, "taken branch EX redirect");
      WaitForRetirePc(32'd20, 60, "taken branch final loop");
      CheckEq32(GetRfWord(2), 32'h0000_0000, "taken branch killed addi");
      CheckEq32(GetRfWord(3), 32'h0000_0001, "taken branch target addi");
    end
  endtask

  task automatic RunJalFlushAndKilledStoreTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  32'h0050_0093); // addi x1, x0, 5
      LoadRomWord(32'd8,  32'h0080_02EF); // jal  x5, +8
      LoadRomWord(32'd12, 32'h0010_2023); // sw   x1, 0(x0) (killed)
      LoadRomWord(32'd16, 32'h0010_0313); // addi x6, x0, 1
      LoadRomWord(32'd20, 32'h0000_006F); // jal  x0, 0
      ReleaseReset();

      WaitForIdStagePc(32'd8, 30, "ID-resolved JAL stage");
      CheckEq1(dut.IdRedirectValid, 1'b1, "ID-resolved JAL redirect");

      WaitForRetirePc(32'd20, 70, "ID-resolved JAL final loop");
      CheckEq32(GetRfWord(5), 32'h0000_000C, "JAL link register");
      CheckEq32(GetRfWord(6), 32'h0000_0001, "JAL target instruction");
      CheckEq32(GetDmemWord(0), 32'h0000_0000, "killed store suppression");
    end
  endtask

  task automatic RunMisalignedLoadTrapTest;
    begin
      HoldResetAndClear();
      dut.uDataRam.MemRam[0] = 32'hA5A5_5A5A;
      LoadRomWord(32'd4,  EncAddi(5'd4, 5'd0, LP_TRAP_VECTOR));
      LoadRomWord(32'd8,  EncCsrReg(5'd0, 5'd4, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12, EncAddi(5'd1, 5'd0, 2));
      LoadRomWord(32'd16, EncLoad(5'd2, 5'd1, 0, 3'b010));
      LoadRomWord(32'd20, EncAddi(5'd3, 5'd0, 1));
      LoadRomWord(LP_TRAP_VECTOR, 32'h0000_006F);
      ReleaseReset();

      WaitForTrapState(LP_TRAP_VECTOR, 32'd16, LP_MCAUSE_LOAD_MISALIGNED, 80, "misaligned load");
      CheckEq32(GetRfWord(1), 32'h0000_0002, "misaligned load older instruction retire");
      CheckEq32(GetRfWord(2), 32'h0000_0000, "misaligned load suppresses writeback");
      CheckEq32(GetRfWord(3), 32'h0000_0000, "misaligned load kills younger instruction");
    end
  endtask

  task automatic RunMisalignedStoreTrapTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  EncAddi(5'd4, 5'd0, LP_TRAP_VECTOR));
      LoadRomWord(32'd8,  EncCsrReg(5'd0, 5'd4, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12, EncAddi(5'd1, 5'd0, 1));
      LoadRomWord(32'd16, EncAddi(5'd2, 5'd0, 170));
      LoadRomWord(32'd20, EncStore(5'd2, 5'd1, 0, 3'b001));
      LoadRomWord(32'd24, EncAddi(5'd3, 5'd0, 1));
      LoadRomWord(LP_TRAP_VECTOR, 32'h0000_006F);
      ReleaseReset();

      WaitForTrapState(LP_TRAP_VECTOR, 32'd20, LP_MCAUSE_STORE_MISALIGNED, 90, "misaligned store");
      CheckEq32(GetRfWord(1), 32'h0000_0001, "misaligned store x1");
      CheckEq32(GetRfWord(2), 32'h0000_00AA, "misaligned store x2");
      CheckEq32(GetRfWord(3), 32'h0000_0000, "misaligned store kills younger instruction");
      CheckEq32(GetDmemWord(0), 32'h0000_0000, "misaligned store suppresses memory write");
    end
  endtask

  task automatic RunFenceAndX0Test;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  32'h0070_0013); // addi x0, x0, 7
      LoadRomWord(32'd8,  32'h0000_000F); // fence
      LoadRomWord(32'd12, 32'h0020_0113); // addi x2, x0, 2
      LoadRomWord(32'd16, 32'h0000_006F); // jal  x0, 0
      ReleaseReset();

      WaitForRetirePc(32'd8, 40, "FENCE retire");
      WaitForRetirePc(32'd16, 60, "FENCE final loop");
      CheckEq32(GetRfWord(0), 32'h0000_0000, "x0 hard-wire after attempted write");
      CheckEq32(GetRfWord(2), 32'h0000_0002, "FENCE legal no-op retire");
      CheckEq32(dut.uCsrFile.Mcause, 32'd0, "FENCE should not trap");
    end
  endtask

  task automatic RunGpioMmioTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  EncLui(5'd1, 20'h40001));
      LoadRomWord(32'd8,  EncAddi(5'd2, 5'd0, 165));
      LoadRomWord(32'd12, EncStore(5'd2, 5'd1, 0, 3'b010));
      LoadRomWord(32'd16, EncAddi(5'd3, 5'd0, 90));
      LoadRomWord(32'd20, EncStore(5'd3, 5'd1, 8, 3'b010));
      LoadRomWord(32'd24, EncLoad(5'd4, 5'd1, 0, 3'b010));
      LoadRomWord(32'd28, EncLoad(5'd5, 5'd1, 8, 3'b010));
      LoadRomWord(32'd32, 32'h0000_006F);
      ReleaseReset();

      WaitForRetirePc(32'd32, 120, "GPIO MMIO final loop");
      CheckEq32(GetRfWord(4), 32'h0000_00A5, "GPIO DATA_OUT readback");
      CheckEq32(GetRfWord(5), 32'h0000_005A, "GPIO DIR readback");
      CheckEq32({24'd0, oGpioOut}, 32'h0000_00A5, "GPIO output pins");
      CheckEq32({24'd0, oGpioOe}, 32'h0000_005A, "GPIO OE pins");
    end
  endtask

  task automatic RunFndMmioTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  EncLui(5'd1, 20'h40002));
      LoadRomWord(32'd8,  EncLui(5'd2, 20'h00001));
      LoadRomWord(32'd12, EncAddi(5'd2, 5'd2, 564));
      LoadRomWord(32'd16, EncStore(5'd2, 5'd1, 0, 3'b010));
      LoadRomWord(32'd20, EncAddi(5'd3, 5'd0, 5));
      LoadRomWord(32'd24, EncStore(5'd3, 5'd1, 8, 3'b010));
      LoadRomWord(32'd28, EncLoad(5'd4, 5'd1, 0, 3'b010));
      LoadRomWord(32'd32, 32'h0000_006F);
      ReleaseReset();

      WaitForRetirePc(32'd32, 120, "FND MMIO readback");
      WaitCycles(400);
      CheckEq32(GetRfWord(4), 32'h0000_1234, "FND digits readback");
      CheckEq1(oDigitSel == 4'b1111, 1'b0, "FND active scan");

      HoldResetAndClear();
      LoadRomWord(32'd4,  EncLui(5'd1, 20'h40002));
      LoadRomWord(32'd8,  EncLui(5'd2, 20'h00001));
      LoadRomWord(32'd12, EncAddi(5'd2, 5'd2, 564));
      LoadRomWord(32'd16, EncStore(5'd2, 5'd1, 0, 3'b010));
      LoadRomWord(32'd20, EncStore(5'd0, 5'd1, 12, 3'b010));
      LoadRomWord(32'd24, 32'h0000_006F);
      ReleaseReset();

      WaitForRetirePc(32'd24, 100, "FND disable write");
      WaitCycles(50);
      CheckEq32({25'd0, oSeg}, 32'h0000_007F, "FND blank segments");
      CheckEq1(oDp, 1'b1, "FND blank dp");
      CheckEq32({28'd0, oDigitSel}, 32'h0000_000F, "FND blank digit select");
    end
  endtask

  task automatic RunApbZeroWaitProtocolTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  EncLui(5'd1, 20'h40001));
      LoadRomWord(32'd8,  EncAddi(5'd2, 5'd0, 165));
      LoadRomWord(32'd12, EncStore(5'd2, 5'd1, 0, 3'b010));
      LoadRomWord(32'd16, 32'h0000_006F);
      ReleaseReset();

      WaitForGpioApbSetup(12'h000, 4'hF, 32'h0000_00A5, 80, "GPIO zero-wait protocol");
      CheckEq32({24'd0, oGpioOut}, 32'h0000_0000, "GPIO setup defers write side effect");
      CheckEq1(dut.ApbPenable, 1'b0, "GPIO setup PENABLE low");

      @(posedge iClk);
      CheckEq1(dut.GpioPsel, 1'b1, "GPIO access selects slave");
      CheckEq1(dut.ApbPenable, 1'b1, "GPIO access PENABLE high");
      CheckEq1(dut.DataBusRsp.RspReady, 1'b1, "GPIO zero-wait access ready");
      CheckEq1(dut.MemApbStall, 1'b0, "GPIO zero-wait no stall");

      @(posedge iClk);
      CheckEq1(dut.GpioPsel, 1'b0, "GPIO post-access deasserts PSEL");
      CheckEq1(dut.ApbPenable, 1'b0, "GPIO post-access deasserts PENABLE");

      WaitForRetirePc(32'd16, 120, "GPIO zero-wait final loop");
      CheckEq32({24'd0, oGpioOut}, 32'h0000_00A5, "GPIO zero-wait writeback");
    end
  endtask

  task automatic RunApbWaitStateHoldTest;
    IFID_t        IFIDHoldRef;
    IDEX_t        IDEXHoldRef;
    EXMEM_t       EXMEMHoldRef;
    logic [31:0]  PcHoldRef;
    int unsigned  WaitIdx;
    begin
      force dut.uAPBMASTER.AccessComplete = 1'b0;
      force dut.uAPB_GPIO.AccessEn        = 1'b0;

      HoldResetAndClear();
      LoadRomWord(32'd4,  EncLui(5'd1, 20'h40001));
      LoadRomWord(32'd8,  EncAddi(5'd2, 5'd0, 165));
      LoadRomWord(32'd12, EncStore(5'd2, 5'd1, 0, 3'b010));
      LoadRomWord(32'd16, 32'h0000_006F);
      ReleaseReset();

      WaitForGpioApbSetup(12'h000, 4'hF, 32'h0000_00A5, 80, "GPIO wait-state hold");
      WaitForGpioApbAccess(12'h000, 4'hF, 32'h0000_00A5, 1'b0, 80, "GPIO wait-state hold");

      PcHoldRef    = dut.Pc;
      IFIDHoldRef  = dut.IFID;
      IDEXHoldRef  = dut.IDEX;
      EXMEMHoldRef = dut.EXMEM;

      CheckEq1(dut.MemApbStall, 1'b1, "APB wait-state stall asserted");
      CheckEq32({24'd0, oGpioOut}, 32'h0000_0000, "APB wait-state defers GPIO write");

      for (WaitIdx = 0; WaitIdx < 3; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);

        CheckEq1(dut.GpioPsel, 1'b1, $sformatf("APB wait hold cycle %0d PSEL", WaitIdx));
        CheckEq1(dut.ApbPenable, 1'b1, $sformatf("APB wait hold cycle %0d PENABLE", WaitIdx));
        CheckEq1(dut.DataBusRsp.RspReady, 1'b0, $sformatf("APB wait hold cycle %0d ready", WaitIdx));
        CheckEq1(dut.MemApbStall, 1'b1, $sformatf("APB wait hold cycle %0d stall", WaitIdx));
        CheckEq32({24'd0, oGpioOut}, 32'h0000_0000, $sformatf("APB wait hold cycle %0d GPIO side effect", WaitIdx));

        if (dut.Pc !== PcHoldRef) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: PC changed during stall", WaitIdx);
        end
        if (dut.IFID !== IFIDHoldRef) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: IF/ID changed during stall", WaitIdx);
        end
        if (dut.IDEX !== IDEXHoldRef) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: ID/EX changed during stall", WaitIdx);
        end
        if (dut.EXMEM !== EXMEMHoldRef) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: EX/MEM changed during stall", WaitIdx);
        end
        if (dut.MEMWB.Valid && (dut.MEMWB.Pc == 32'd12)) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: waiting store reached MEM/WB early", WaitIdx);
        end
        if (dut.RetireValid && (dut.RetirePc == 32'd12)) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: waiting store retired early", WaitIdx);
        end
      end

      release dut.uAPBMASTER.AccessComplete;
      release dut.uAPB_GPIO.AccessEn;
      WaitCycles(2);
    end
  endtask

  task automatic RunApbMasterLocalErrorTest;
    int unsigned WaitIdx;
    begin
      HoldResetAndClear();
      ReleaseReset();

      force dut.ApbSel   = 1'b1;
      force dut.ApbWrite = 1'b0;
      force dut.BusAddr  = 32'h4000_4000;
      force dut.BusByteEn = 4'hF;
      force dut.BusWdata = 32'd0;

      for (WaitIdx = 0; WaitIdx < 10; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (!dut.ApbPenable) begin
          break;
        end
      end
      CheckEq1(dut.UartPsel, 1'b0, "APB local error setup no UART select");
      CheckEq1(dut.GpioPsel, 1'b0, "APB local error setup no GPIO select");
      CheckEq1(dut.FndPsel, 1'b0, "APB local error setup no FND select");
      CheckEq1(dut.IntcPsel, 1'b0, "APB local error setup no INTC select");
      CheckEq1(dut.ApbPenable, 1'b0, "APB local error setup PENABLE low");

      for (WaitIdx = 0; WaitIdx < 10; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.ApbPenable) begin
          break;
        end
      end
      CheckEq1(dut.UartPsel, 1'b0, "APB local error access no UART select");
      CheckEq1(dut.GpioPsel, 1'b0, "APB local error access no GPIO select");
      CheckEq1(dut.FndPsel, 1'b0, "APB local error access no FND select");
      CheckEq1(dut.IntcPsel, 1'b0, "APB local error access no INTC select");
      CheckEq1(dut.ApbPenable, 1'b1, "APB local error access PENABLE high");
      CheckEq1(dut.uAPBMASTER.oRspReady, 1'b1, "APB local error completion ready");
      CheckEq1(dut.uAPBMASTER.oPslverr, 1'b1, "APB local error completion error");

      release dut.ApbSel;
      release dut.ApbWrite;
      release dut.BusAddr;
      release dut.BusByteEn;
      release dut.BusWdata;

      @(posedge iClk);
      CheckEq1(dut.UartPsel, 1'b0, "APB local error post-access UART deselect");
      CheckEq1(dut.GpioPsel, 1'b0, "APB local error post-access GPIO deselect");
      CheckEq1(dut.FndPsel, 1'b0, "APB local error post-access FND deselect");
      CheckEq1(dut.IntcPsel, 1'b0, "APB local error post-access INTC deselect");
    end
  endtask

  task automatic RunCsrOpsTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,   EncAddi(5'd1, 5'd0, 136));
      LoadRomWord(32'd8,   EncCsrReg(5'd2, 5'd1, LP_CSR_MSCRATCH, 3'b001));
      LoadRomWord(32'd12,  EncCsrReg(5'd3, 5'd0, LP_CSR_MSCRATCH, 3'b010));
      LoadRomWord(32'd16,  EncAddi(5'd4, 5'd0, 8));
      LoadRomWord(32'd20,  EncCsrImm(5'd5, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(32'd24,  EncCsrImm(5'd6, 5'd8, LP_CSR_MSTATUS, 3'b110));
      LoadRomWord(32'd28,  EncCsrImm(5'd7, 5'd8, LP_CSR_MSTATUS, 3'b111));
      LoadRomWord(32'd32,  EncLui(5'd8, 20'h00001));
      LoadRomWord(32'd36,  EncAddi(5'd8, 5'd8, -2048));
      LoadRomWord(32'd40,  EncCsrReg(5'd9, 5'd8, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd44,  EncCsrReg(5'd10, 5'd8, LP_CSR_MIP, 3'b001));
      LoadRomWord(32'd48,  EncCsrReg(5'd11, 5'd0, LP_CSR_MIE, 3'b010));
      LoadRomWord(32'd52,  EncCsrReg(5'd12, 5'd0, LP_CSR_MIP, 3'b010));
      LoadRomWord(32'd56,  EncAddi(5'd13, 5'd0, LP_TRAP_VECTOR));
      LoadRomWord(32'd60,  EncCsrReg(5'd0, 5'd13, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd64,  EncAddi(5'd14, 5'd0, 32));
      LoadRomWord(32'd68,  EncCsrReg(5'd0, 5'd14, LP_CSR_MEPC, 3'b001));
      LoadRomWord(32'd72,  EncAddi(5'd15, 5'd0, 5));
      LoadRomWord(32'd76,  EncCsrReg(5'd0, 5'd15, LP_CSR_MCAUSE, 3'b001));
      LoadRomWord(32'd80,  EncCsrReg(5'd16, 5'd0, LP_CSR_MTVEC, 3'b010));
      LoadRomWord(32'd84,  EncCsrReg(5'd17, 5'd0, LP_CSR_MEPC, 3'b010));
      LoadRomWord(32'd88,  EncCsrReg(5'd18, 5'd0, LP_CSR_MCAUSE, 3'b010));
      LoadRomWord(32'd92,  32'h0000_006F);
      ReleaseReset();

      WaitForRetirePc(32'd92, 250, "CSR ops final loop");
      CheckEq32(GetRfWord(2), 32'h0000_0000, "CSRRW old mscratch");
      CheckEq32(GetRfWord(3), 32'h0000_0088, "CSRRS readback mscratch");
      CheckEq32(GetRfWord(5), 32'h0000_0000, "CSRRWI old mstatus");
      CheckEq32(GetRfWord(6), 32'h0000_0008, "CSRRSI old mstatus");
      CheckEq32(GetRfWord(7), 32'h0000_0008, "CSRRCI old mstatus");
      CheckEq32(GetRfWord(9), 32'h0000_0000, "CSRRW old mie");
      CheckEq32(GetRfWord(10), 32'h0000_0000, "CSRRW old mip");
      CheckEq32(GetRfWord(11), 32'h0000_0800, "mie readback");
      CheckEq32(GetRfWord(12), 32'h0000_0800, "mip readback");
      CheckEq32(GetRfWord(16), LP_TRAP_VECTOR, "mtvec readback");
      CheckEq32(GetRfWord(17), 32'h0000_0020, "mepc readback");
      CheckEq32(GetRfWord(18), 32'h0000_0005, "mcause readback");
      CheckEq32(dut.uCsrFile.Mscratch, 32'h0000_0088, "mscratch final value");
      CheckEq32(dut.uCsrFile.Mtvec, LP_TRAP_VECTOR, "mtvec final value");
      CheckEq32(dut.uCsrFile.Mepc, 32'h0000_0020, "mepc final value");
      CheckEq32(dut.uCsrFile.Mcause, 32'h0000_0005, "mcause final value");
      CheckEq1(dut.uCsrFile.MstatusMie, 1'b0, "mstatus MIE cleared by CSRRCI");
      CheckEq1(dut.uCsrFile.MieMeie, 1'b1, "mie MEIE set");
      CheckEq1(dut.uCsrFile.MipMeipSw, 1'b1, "mip MEIP software pending");
    end
  endtask

  task automatic RunMretRedirectTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  EncAddi(5'd1, 5'd0, 32));
      LoadRomWord(32'd8,  EncCsrReg(5'd0, 5'd1, LP_CSR_MEPC, 3'b001));
      LoadRomWord(32'd12, EncMret());
      LoadRomWord(32'd16, EncAddi(5'd2, 5'd0, 99));
      LoadRomWord(32'd32, EncAddi(5'd3, 5'd0, 1));
      LoadRomWord(32'd36, 32'h0000_006F);
      ReleaseReset();

      WaitForRetirePc(32'd36, 100, "MRET final loop");
      CheckEq32(GetRfWord(2), 32'h0000_0000, "MRET skipped instruction");
      CheckEq32(GetRfWord(3), 32'h0000_0001, "MRET target execution");
      CheckEq32(dut.uCsrFile.Mepc, 32'h0000_0020, "MRET keeps programmed mepc");
    end
  endtask

  task automatic RunUartTxMmioTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  EncLui(5'd1, 20'h40000));
      LoadRomWord(32'd8,  EncAddi(5'd2, 5'd0, 85));
      LoadRomWord(32'd12, EncStore(5'd2, 5'd1, 8, 3'b010));
      LoadRomWord(32'd16, EncLoad(5'd3, 5'd1, 4, 3'b010));
      LoadRomWord(32'd20, 32'h0000_006F);
      ReleaseReset();

      WaitForRetirePc(32'd20, 100, "UART TX MMIO final loop");
      CheckEq1((GetRfWord(3) & 32'h0000_0002) != 32'd0, 1'b1, "UART tx_not_full");
      WaitCycles(10);
      CheckEq1(dut.uAPB_UART.TxBusy, 1'b1, "UART tx_busy");
    end
  endtask

  task automatic RunAccessFaultTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  EncAddi(5'd4, 5'd0, LP_TRAP_VECTOR));
      LoadRomWord(32'd8,  EncCsrReg(5'd0, 5'd4, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12, EncLui(5'd1, 20'h40004));
      LoadRomWord(32'd16, EncLoad(5'd2, 5'd1, 0, 3'b010));
      LoadRomWord(32'd20, EncAddi(5'd3, 5'd0, 1));
      LoadRomWord(LP_TRAP_VECTOR, 32'h0000_006F);
      ReleaseReset();

      WaitForTrapState(LP_TRAP_VECTOR, 32'd16, LP_MCAUSE_LOAD_ACCESS, 120, "unmapped load access fault");
      CheckEq32(GetRfWord(2), 32'h0000_0000, "load access fault suppresses writeback");
      CheckEq32(GetRfWord(3), 32'h0000_0000, "load access fault kills younger instruction");

      HoldResetAndClear();
      LoadRomWord(32'd4,  EncAddi(5'd4, 5'd0, LP_TRAP_VECTOR));
      LoadRomWord(32'd8,  EncCsrReg(5'd0, 5'd4, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12, EncLui(5'd1, 20'h40000));
      LoadRomWord(32'd16, EncLoad(5'd2, 5'd1, 12, 3'b010));
      LoadRomWord(32'd20, EncAddi(5'd3, 5'd0, 1));
      LoadRomWord(LP_TRAP_VECTOR, 32'h0000_006F);
      ReleaseReset();

      WaitForTrapState(LP_TRAP_VECTOR, 32'd16, LP_MCAUSE_LOAD_ACCESS, 120, "UART RX empty slave error");
      CheckEq32(GetRfWord(2), 32'h0000_0000, "empty RX read returns no committed data");
      CheckEq32(GetRfWord(3), 32'h0000_0000, "empty RX read kills younger instruction");
    end
  endtask

  task automatic RunUartInterruptTest;
    int unsigned WaitIdx;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,   EncAddi(5'd1, 5'd0, LP_TRAP_VECTOR));
      LoadRomWord(32'd8,   EncCsrReg(5'd0, 5'd1, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12,  EncLui(5'd3, 20'h40000));
      LoadRomWord(32'd16,  EncLui(5'd6, 20'h40001));
      LoadRomWord(32'd20,  EncLui(5'd7, LP_APB_INTC_BASE[31:12]));
      LoadRomWord(32'd24,  EncAddi(5'd4, 5'd0, 1));
      LoadRomWord(32'd28,  EncAddi(5'd8, 5'd0, 2));
      LoadRomWord(32'd32,  EncStore(5'd4, 5'd3, 16, 3'b010));
      LoadRomWord(32'd36,  EncStore(5'd8, 5'd7, 4, 3'b010));
      LoadRomWord(32'd40,  EncLui(5'd5, 20'h00001));
      LoadRomWord(32'd44,  EncAddi(5'd5, 5'd5, -2048));
      LoadRomWord(32'd48,  EncCsrReg(5'd0, 5'd5, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd52,  EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(32'd56,  32'h0000_006F);
      LoadRomWord(LP_TRAP_VECTOR,       EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b111));
      LoadRomWord(LP_TRAP_VECTOR + 4,   EncLoad(5'd12, 5'd7, 8, 3'b010));
      LoadRomWord(LP_TRAP_VECTOR + 8,   EncLoad(5'd11, 5'd3, 12, 3'b010));
      LoadRomWord(LP_TRAP_VECTOR + 12,  EncStore(5'd8, 5'd7, 12, 3'b010));
      LoadRomWord(LP_TRAP_VECTOR + 16,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_TRAP_VECTOR + 20,  EncMret());
      ReleaseReset();

      WaitCycles(20);
      SendUartByte(8'hA5);

      for (WaitIdx = 0; WaitIdx < 400; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if ((GetRfWord(10) == 32'h0000_0001) && (GetRfWord(11) == 32'h0000_00A5) && (dut.Pc == 32'd56)) begin
          break;
        end
      end

      CheckEq32(GetRfWord(10), 32'h0000_0001, "UART IRQ handler count");
      CheckEq32(GetRfWord(11), 32'h0000_00A5, "UART IRQ RXDATA pop");
      CheckEq32(GetRfWord(12), 32'h0000_0002, "UART IRQ claim id");
      CheckEq32(dut.uCsrFile.Mcause, LP_MCAUSE_MACHINE_EXT_INT, "UART IRQ mcause");
      CheckEq32(dut.uCsrFile.Mepc, 32'd56, "UART IRQ mepc");
      CheckEq1(dut.UartIrq, 1'b0, "UART IRQ cleared after RXDATA pop");
      CheckEq1(dut.ExtIrqPending, 1'b0, "UART IRQ cleared at interrupt controller");
    end
  endtask

  task automatic RunGpioInterruptTest;
    int unsigned WaitIdx;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,   EncAddi(5'd1, 5'd0, LP_TRAP_VECTOR));
      LoadRomWord(32'd8,   EncCsrReg(5'd0, 5'd1, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12,  EncLui(5'd3, 20'h40000));
      LoadRomWord(32'd16,  EncLui(5'd6, 20'h40001));
      LoadRomWord(32'd20,  EncLui(5'd7, LP_APB_INTC_BASE[31:12]));
      LoadRomWord(32'd24,  EncAddi(5'd4, 5'd0, 1));
      LoadRomWord(32'd28,  EncStore(5'd4, 5'd6, 12, 3'b010));
      LoadRomWord(32'd32,  EncStore(5'd4, 5'd7, 4, 3'b010));
      LoadRomWord(32'd36,  EncLui(5'd5, 20'h00001));
      LoadRomWord(32'd40,  EncAddi(5'd5, 5'd5, -2048));
      LoadRomWord(32'd44,  EncCsrReg(5'd0, 5'd5, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd48,  EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(32'd52,  32'h0000_006F);
      LoadRomWord(LP_TRAP_VECTOR,       EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b111));
      LoadRomWord(LP_TRAP_VECTOR + 4,   EncLoad(5'd12, 5'd7, 8, 3'b010));
      LoadRomWord(LP_TRAP_VECTOR + 8,   EncStore(5'd4, 5'd6, 20, 3'b010));
      LoadRomWord(LP_TRAP_VECTOR + 12,  EncStore(5'd4, 5'd7, 12, 3'b010));
      LoadRomWord(LP_TRAP_VECTOR + 16,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_TRAP_VECTOR + 20,  EncMret());
      ReleaseReset();

      WaitCycles(20);
      @(negedge iClk);
      iGpioIn[0] = 1'b1;
      WaitCycles(4);

      for (WaitIdx = 0; WaitIdx < 250; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if ((GetRfWord(10) == 32'h0000_0001) && (dut.Pc == 32'd52)) begin
          break;
        end
      end

      CheckEq32(GetRfWord(10), 32'h0000_0001, "GPIO IRQ handler count");
      CheckEq32(GetRfWord(12), 32'h0000_0001, "GPIO IRQ claim id");
      CheckEq32(dut.uCsrFile.Mcause, LP_MCAUSE_MACHINE_EXT_INT, "GPIO IRQ mcause");
      CheckEq32(dut.uCsrFile.Mepc, 32'd52, "GPIO IRQ mepc");
      CheckEq1(dut.GpioIrq, 1'b0, "GPIO IRQ cleared by W1C");
      CheckEq1(dut.ExtIrqPending, 1'b0, "GPIO IRQ cleared at interrupt controller");
    end
  endtask

  task automatic RunInterruptPriorityTest;
    int unsigned WaitIdx;
    localparam logic [31:0] LP_PRIORITY_TRAP_VECTOR = 32'd864;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,   EncAddi(5'd1, 5'd0, LP_PRIORITY_TRAP_VECTOR));
      LoadRomWord(32'd8,   EncCsrReg(5'd0, 5'd1, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12,  EncLui(5'd3, 20'h40000));
      LoadRomWord(32'd16,  EncLui(5'd6, 20'h40001));
      LoadRomWord(32'd20,  EncLui(5'd7, LP_APB_INTC_BASE[31:12]));
      LoadRomWord(32'd24,  EncAddi(5'd4, 5'd0, 1));
      LoadRomWord(32'd28,  EncAddi(5'd8, 5'd0, 3));
      LoadRomWord(32'd32,  EncStore(5'd4, 5'd3, 16, 3'b010));
      LoadRomWord(32'd36,  EncStore(5'd4, 5'd6, 12, 3'b010));
      LoadRomWord(32'd40,  EncStore(5'd8, 5'd7, 4, 3'b010));
      LoadRomWord(32'd44,  EncLui(5'd5, 20'h00001));
      LoadRomWord(32'd48,  EncAddi(5'd5, 5'd5, -2048));
      LoadRomWord(32'd944, EncCsrReg(5'd0, 5'd5, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd948, EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(32'd952, 32'h0000_006F);

      LoadRomWord(LP_PRIORITY_TRAP_VECTOR,       EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b111));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 4,   EncLoad(5'd12, 5'd7, 8, 3'b010));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 8,   EncBeq(5'd10, 5'd0, 8));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 12,  EncBeq(5'd0, 5'd0, 8));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 16,  EncAddi(5'd15, 5'd12, 0));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 20,  EncAddi(5'd13, 5'd0, 1));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 24,  EncBeq(5'd12, 5'd13, 16));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 28,  EncAddi(5'd13, 5'd0, 2));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 32,  EncBeq(5'd12, 5'd13, 24));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 36,  EncMret());
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 40,  EncStore(5'd4, 5'd6, 20, 3'b010));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 44,  EncStore(5'd13, 5'd7, 12, 3'b010));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 48,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 52,  EncMret());
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 56,  EncLoad(5'd11, 5'd3, 12, 3'b010));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 60,  EncStore(5'd13, 5'd7, 12, 3'b010));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 64,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 68,  EncMret());
      ReleaseReset();

      WaitCycles(20);
      SendUartByte(8'h5A);
      @(negedge iClk);
      iGpioIn[0] = 1'b1;

      for (WaitIdx = 0; WaitIdx < 500; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if ((GetRfWord(10) == 32'h0000_0002) && (GetRfWord(11) == 32'h0000_005A) && (dut.Pc == 32'd952)) begin
          break;
        end
      end

      CheckEq32(GetRfWord(10), 32'h0000_0002, "priority test handled both sources");
      CheckEq32(GetRfWord(11), 32'h0000_005A, "priority test UART data");
      CheckEq32(GetRfWord(15), 32'h0000_0001, "priority test first claim is GPIO");
      CheckEq1(dut.GpioIrq, 1'b0, "priority test GPIO cleared");
      CheckEq1(dut.UartIrq, 1'b0, "priority test UART cleared");
      CheckEq1(dut.ExtIrqPending, 1'b0, "priority test interrupt controller cleared");
    end
  endtask

  task automatic RunInterruptCompleteGateTest;
    int unsigned WaitIdx;
    localparam logic [31:0] LP_COMPLETE_TRAP_VECTOR = 32'd128;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,   EncAddi(5'd1, 5'd0, LP_COMPLETE_TRAP_VECTOR));
      LoadRomWord(32'd8,   EncCsrReg(5'd0, 5'd1, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12,  EncLui(5'd6, 20'h40001));
      LoadRomWord(32'd16,  EncLui(5'd7, LP_APB_INTC_BASE[31:12]));
      LoadRomWord(32'd20,  EncAddi(5'd4, 5'd0, 1));
      LoadRomWord(32'd24,  EncStore(5'd4, 5'd6, 12, 3'b010));
      LoadRomWord(32'd28,  EncStore(5'd4, 5'd7, 4, 3'b010));
      LoadRomWord(32'd32,  EncLui(5'd5, 20'h00001));
      LoadRomWord(32'd36,  EncAddi(5'd5, 5'd5, -2048));
      LoadRomWord(32'd40,  EncCsrReg(5'd0, 5'd5, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd44,  EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(32'd48,  EncBeq(5'd10, 5'd4, 12));
      LoadRomWord(32'd52,  EncJal(5'd0, -4));
      LoadRomWord(32'd56,  LP_NOP_INSTR);
      LoadRomWord(32'd60,  LP_NOP_INSTR);
      LoadRomWord(32'd64,  LP_NOP_INSTR);
      LoadRomWord(32'd68,  LP_NOP_INSTR);
      LoadRomWord(32'd72,  LP_NOP_INSTR);
      LoadRomWord(32'd76,  LP_NOP_INSTR);
      LoadRomWord(32'd80,  LP_NOP_INSTR);
      LoadRomWord(32'd84,  LP_NOP_INSTR);
      LoadRomWord(32'd88,  EncStore(5'd4, 5'd7, 12, 3'b010));
      LoadRomWord(32'd92,  EncJal(5'd0, -44));

      LoadRomWord(LP_COMPLETE_TRAP_VECTOR,       EncLoad(5'd12, 5'd7, 8, 3'b010));
      LoadRomWord(LP_COMPLETE_TRAP_VECTOR + 4,   EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_COMPLETE_TRAP_VECTOR + 8,   EncMret());
      ReleaseReset();

      WaitCycles(20);
      @(negedge iClk);
      iGpioIn[0] = 1'b1;
      WaitCycles(4);

      for (WaitIdx = 0; WaitIdx < 250; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (GetRfWord(10) == 32'h0000_0001) begin
          break;
        end
      end

      CheckEq32(GetRfWord(10), 32'h0000_0001, "complete gate first GPIO service");
      CheckEq32(GetRfWord(12), 32'h0000_0001, "complete gate first claim id");
      CheckEq1(dut.GpioIrq, 1'b1, "complete gate raw GPIO source still asserted");
      CheckEq1(dut.ExtIrqPending, 1'b0, "complete gate suppresses re-notify before COMPLETE");

      for (WaitIdx = 0; WaitIdx < 400; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.ExtIrqPending == 1'b1) begin
          break;
        end
      end

      CheckEq32(GetRfWord(10), 32'h0000_0001, "complete gate service count before re-notify");
      CheckEq32(GetRfWord(12), 32'h0000_0001, "complete gate retained claim id");
      CheckEq1(dut.GpioIrq, 1'b1, "complete gate source remains asserted without W1C");
      CheckEq1(dut.ExtIrqPending, 1'b1, "complete gate re-asserts controller IRQ after COMPLETE");
    end
  endtask

  task automatic RunInterruptMaskTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,   EncAddi(5'd1, 5'd0, LP_TRAP_VECTOR));
      LoadRomWord(32'd8,   EncCsrReg(5'd0, 5'd1, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12,  EncLui(5'd3, 20'h40000));
      LoadRomWord(32'd16,  EncAddi(5'd4, 5'd0, 1));
      LoadRomWord(32'd20,  EncStore(5'd4, 5'd3, 16, 3'b010));
      LoadRomWord(32'd24,  32'h0000_006F);
      LoadRomWord(LP_TRAP_VECTOR,      EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_TRAP_VECTOR + 4,  EncMret());
      ReleaseReset();

      WaitCycles(20);
      SendUartByte(8'h3C);
      WaitCycles(220);

      CheckEq32(GetRfWord(10), 32'h0000_0000, "masked interrupt ignored");
      CheckEq1(dut.UartIrq, 1'b1, "masked UART IRQ remains pending");
      CheckEq1(dut.ExtIrqPending, 1'b0, "interrupt controller mask blocks processor IRQ");
      CheckEq32(dut.uCsrFile.Mcause, 32'h0000_0000, "masked interrupt no mcause update");
      CheckEq32(dut.Pc, 32'd24, "masked interrupt stays in main loop");
    end
  endtask

endmodule
