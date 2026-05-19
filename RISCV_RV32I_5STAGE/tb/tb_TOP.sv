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
  localparam string       LP_BENCH_INIT_FILE = "C:/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_5STAGE/src/InstructionFORTIMING.mem";
  localparam int unsigned LP_ROM_DEPTH     = 256;
  localparam int unsigned LP_RAM_DEPTH     = 256;
  localparam int unsigned LP_SIM_CLK_HZ    = 153_600;
  localparam int unsigned LP_UART_BAUD     = 9_600;
  localparam int unsigned LP_GPIO_WIDTH    = 8;
  localparam int unsigned LP_UART_BIT_CYCLES = (LP_SIM_CLK_HZ / LP_UART_BAUD);
  localparam logic [31:0] LP_INTC_REG_ENABLE        = 32'h0000_0004;
  localparam logic [31:0] LP_INTC_REG_CLAIM         = 32'h0000_0008;
  localparam logic [31:0] LP_INTC_REG_COMPLETE      = 32'h0000_000C;
  localparam logic [31:0] LP_INTC_REG_CTRL          = 32'h0000_0010;
  localparam logic [31:0] LP_INTC_REG_THRESHOLD     = 32'h0000_0014;
  localparam logic [31:0] LP_INTC_REG_PRIORITY_GPIO = 32'h0000_0024;
  localparam logic [31:0] LP_INTC_REG_PRIORITY_UART = 32'h0000_0028;
  localparam logic [31:0] LP_INTC_REG_VECTOR_ENTRY0 = 32'h0000_0080;
  localparam logic [1:0]  LP_AXI_RESP_OKAY          = 2'b00;
  localparam logic [1:0]  LP_AXI_RESP_SLVERR        = 2'b10;

  logic iClk;
  logic iRst;
  logic iUartRx;
  logic [LP_GPIO_WIDTH-1:0] iGpioIn;
  logic iSpiMiso;
  tri1  ioI2cScl;
  tri1  ioI2cSda;
  logic oUartTx;
  logic [LP_GPIO_WIDTH-1:0] oGpioOut;
  logic [LP_GPIO_WIDTH-1:0] oGpioOe;
  logic oSpiSclk;
  logic oSpiMosi;
  logic oSpiCsN;
  logic [6:0] oSeg;
  logic oDp;
  logic [3:0] oDigitSel;
  logic oTimingProbe;

  int unsigned CycleCount;

  TOP #(
    .P_CLK_HZ         (LP_SIM_CLK_HZ),
    .P_SYS_CLK_DIVIDE (1),
    .P_UART_BAUD      (LP_UART_BAUD),
    .P_GPIO_WIDTH     (LP_GPIO_WIDTH),
    .P_INSTR_INIT_FILE    (LP_BENCH_INIT_FILE),
    .P_UART_RESET_CPU_MODE(1'b1)
  ) dut (
    .iClk        (iClk),
    .iRst       (iRst),
    .iUartRx     (iUartRx),
    .iGpioIn     (iGpioIn),
    .iSpiMiso    (iSpiMiso),
    .ioI2cScl    (ioI2cScl),
    .ioI2cSda    (ioI2cSda),
    .oUartTx     (oUartTx),
    .oGpioOut    (oGpioOut),
    .oGpioOe     (oGpioOe),
    .oSpiSclk    (oSpiSclk),
    .oSpiMosi    (oSpiMosi),
    .oSpiCsN     (oSpiCsN),
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
    iRst      = 1'b1;
    iUartRx    = 1'b1;
    iGpioIn    = '0;
    iSpiMiso   = 1'b0;
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
    RunApbZeroWaitProtocolTest();
    RunAxiMmioWriteIntegrationTest();
    RunAxiMmioReadIntegrationTest();
    RunApbWaitStateHoldTest();
    RunCsrOpsTest();
    RunMretRedirectTest();
    RunUartTxMmioTest();
    RunAccessFaultTest();
    RunAxiMmioLocalErrorTrapTest();
    RunUartInterruptTest();
    RunGpioInterruptTest();
    RunMtvecVectoredInterruptTest();
    RunIntcPerSourceVectorTest();
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
    GetRfWord = dut.uRv32iCore.uDecodeStage.uRegfile.MemReg[iIdx];
  endfunction

  function automatic logic [31:0] GetDmemWord(input int unsigned iIdx);
    GetDmemWord = dut.uDataRam.MemRam[iIdx];
  endfunction

  task automatic ClearInstrRom;
    integer Idx;
    begin
      for (Idx = 0; Idx < LP_ROM_DEPTH; Idx = Idx + 1) begin
        dut.uInstrFetchMemory.uInstrRom.gen_direct_rom.MemRom[Idx] = LP_NOP_INSTR;
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
      iRst = 1'b1;
      iUartRx = 1'b1;
      iGpioIn = '0;
      ClearInstrRom();
      ClearDataRam();
      repeat (4) @(posedge iClk);
    end
  endtask

  task automatic HoldResetAndClearDataOnly;
    begin
      iRst = 1'b1;
      iUartRx = 1'b1;
      iGpioIn = '0;
      ClearDataRam();
      repeat (4) @(posedge iClk);
    end
  endtask

  task automatic ReleaseReset;
    begin
      iRst = 1'b0;
      wait (dut.SysClkLocked === 1'b1);
      wait (dut.SysRst === 1'b0);
      @(posedge iClk);
    end
  endtask

  task automatic LoadRomWord(
    input int unsigned iPc,
    input logic [31:0] iInstr
  );
    begin
      dut.uInstrFetchMemory.uInstrRom.gen_direct_rom.MemRom[iPc[9:2]] = iInstr;
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
        if (dut.uRv32iCore.RetireValid && (dut.uRv32iCore.RetirePc == iExpectedPc)) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s: expected retire PC 0x%08x within %0d cycles, current retireValid=%0b retirePc=0x%08x",
        iContext,
        iExpectedPc,
        iBudgetCycles,
        dut.uRv32iCore.RetireValid,
        dut.uRv32iCore.RetirePc
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
        if (dut.uRv32iCore.IDEX.Valid && (dut.uRv32iCore.IDEX.Pc == iExpectedPc)) begin
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
        if (dut.uRv32iCore.IFID.Valid && (dut.uRv32iCore.IFID.Pc == iExpectedPc)) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s: ID stage never observed PC 0x%08x (pc=0x%08x ifidValid=%0b ifidPc=0x%08x extIrq=%0b vectorValid=%0b vectorPc=0x%08x selectedId=%0d uartIrq=%0b gpioIrq=%0b)",
        iContext,
        iExpectedPc,
        dut.uRv32iCore.Pc,
        dut.uRv32iCore.IFID.Valid,
        dut.uRv32iCore.IFID.Pc,
        dut.ExtIrqPending,
        dut.IntcVectorValid,
        dut.IntcVectorPc,
        dut.IntcSelSrcId,
        dut.UartIrq,
        dut.GpioIrq
      );
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
        if ((dut.uRv32iCore.Pc == iExpectedVectorPc)
         && (dut.uRv32iCore.uCsrFile.Mepc == iExpectedEpc)
         && (dut.uRv32iCore.uCsrFile.Mcause == iExpectedCause)) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s: trap state not observed (pc=0x%08x mepc=0x%08x mcause=0x%08x)",
        iContext,
        dut.uRv32iCore.Pc,
        dut.uRv32iCore.uCsrFile.Mepc,
        dut.uRv32iCore.uCsrFile.Mcause
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

  task automatic WaitForGpioApbReadSetup(
    input logic [11:0] iExpectedAddr,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(negedge iClk);
        if (dut.GpioPsel && !dut.ApbPenable && !dut.ApbPwrite) begin
          CheckEq32({20'd0, dut.ApbPaddr}, {20'd0, iExpectedAddr}, $sformatf("%s read setup addr", iContext));
          CheckEq32({28'd0, dut.ApbPstrb}, 32'd0, $sformatf("%s read setup strb", iContext));
          return;
        end
      end

      $fatal(1, "[FAIL] %s: GPIO APB read setup phase not observed within %0d cycles", iContext, iBudgetCycles);
    end
  endtask

  task automatic WaitForGpioApbReadAccess(
    input logic [11:0] iExpectedAddr,
    input logic        iExpectedReady,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(negedge iClk);
        if (dut.GpioPsel && dut.ApbPenable && !dut.ApbPwrite) begin
          CheckEq32({20'd0, dut.ApbPaddr}, {20'd0, iExpectedAddr}, $sformatf("%s read access addr", iContext));
          CheckEq32({28'd0, dut.ApbPstrb}, 32'd0, $sformatf("%s read access strb", iContext));
          CheckEq1(dut.DataBusRsp.RspReady, iExpectedReady, $sformatf("%s read access ready", iContext));
          return;
        end
      end

      $fatal(1, "[FAIL] %s: GPIO APB read access phase not observed within %0d cycles", iContext, iBudgetCycles);
    end
  endtask

  task automatic WaitForAxiWriteHandshake(
    input logic [31:0] iExpectedAddr,
    input logic [3:0]  iExpectedStrb,
    input logic [31:0] iExpectedWdata,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(negedge iClk);
        if (dut.AxiAwvalid && dut.AxiWvalid) begin
          CheckEq1(dut.AxiAwready, 1'b1, $sformatf("%s AWREADY", iContext));
          CheckEq1(dut.AxiWready, 1'b1, $sformatf("%s WREADY", iContext));
          CheckEq32(dut.AxiAwaddr, iExpectedAddr, $sformatf("%s AWADDR", iContext));
          CheckEq32(dut.AxiWdata, iExpectedWdata, $sformatf("%s WDATA", iContext));
          CheckEq32({28'd0, dut.AxiWstrb}, {28'd0, iExpectedStrb}, $sformatf("%s WSTRB", iContext));
          CheckEq32({29'd0, dut.AxiAwprot}, 32'd0, $sformatf("%s AWPROT", iContext));
          CheckEq1(dut.GpioPsel, 1'b0, $sformatf("%s APB not started during AXI write accept", iContext));
          CheckEq1(dut.AxiBvalid, 1'b0, $sformatf("%s no early BVALID", iContext));
          return;
        end
      end

      $fatal(1, "[FAIL] %s: AXI write handshake not observed within %0d cycles", iContext, iBudgetCycles);
    end
  endtask

  task automatic WaitForAxiWriteResponse(
    input logic [1:0]  iExpectedResp,
    input logic        iExpectedErr,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(negedge iClk);
        if (dut.AxiBvalid) begin
          CheckEq1(dut.AxiBready, 1'b1, $sformatf("%s BREADY", iContext));
          CheckEq32({30'd0, dut.AxiBresp}, {30'd0, iExpectedResp}, $sformatf("%s BRESP", iContext));
          CheckEq1(dut.DataBusRsp.RspReady, 1'b1, $sformatf("%s native ready", iContext));
          CheckEq1(dut.DataBusRsp.RspErr, iExpectedErr, $sformatf("%s native error", iContext));
          CheckEq1(dut.ApbPenable, 1'b0, $sformatf("%s APB access finished before BVALID", iContext));
          return;
        end
      end

      $fatal(1, "[FAIL] %s: AXI write response not observed within %0d cycles", iContext, iBudgetCycles);
    end
  endtask

  task automatic WaitForAxiReadHandshake(
    input logic [31:0] iExpectedAddr,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(negedge iClk);
        if (dut.AxiArvalid) begin
          CheckEq1(dut.AxiArready, 1'b1, $sformatf("%s ARREADY", iContext));
          CheckEq32(dut.AxiAraddr, iExpectedAddr, $sformatf("%s ARADDR", iContext));
          CheckEq32({29'd0, dut.AxiArprot}, 32'd0, $sformatf("%s ARPROT", iContext));
          CheckEq1(dut.GpioPsel, 1'b0, $sformatf("%s APB not started during AXI read accept", iContext));
          CheckEq1(dut.AxiRvalid, 1'b0, $sformatf("%s no early RVALID", iContext));
          return;
        end
      end

      $fatal(1, "[FAIL] %s: AXI read handshake not observed within %0d cycles", iContext, iBudgetCycles);
    end
  endtask

  task automatic WaitForAxiReadResponse(
    input logic [31:0] iExpectedRdata,
    input logic [1:0]  iExpectedResp,
    input logic        iExpectedErr,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(negedge iClk);
        if (dut.AxiRvalid) begin
          CheckEq1(dut.AxiRready, 1'b1, $sformatf("%s RREADY", iContext));
          CheckEq32(dut.AxiRdata, iExpectedRdata, $sformatf("%s RDATA", iContext));
          CheckEq32({30'd0, dut.AxiRresp}, {30'd0, iExpectedResp}, $sformatf("%s RRESP", iContext));
          CheckEq1(dut.DataBusRsp.RspReady, 1'b1, $sformatf("%s native ready", iContext));
          CheckEq32(dut.DataBusRsp.RspRdata, iExpectedRdata, $sformatf("%s native rdata", iContext));
          CheckEq1(dut.DataBusRsp.RspErr, iExpectedErr, $sformatf("%s native error", iContext));
          CheckEq1(dut.ApbPenable, 1'b0, $sformatf("%s APB access finished before RVALID", iContext));
          return;
        end
      end

      $fatal(1, "[FAIL] %s: AXI read response not observed within %0d cycles", iContext, iBudgetCycles);
    end
  endtask

  task automatic WaitForAxiLocalErrorApbSetup(
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(negedge iClk);
        if (!dut.ApbPenable
         && !dut.UartPsel
         && !dut.GpioPsel
         && !dut.I2cPsel
         && !dut.IntcPsel
         && !dut.SpiPsel
         && !dut.FndPsel
         && (dut.ApbPaddr == 12'h000)) begin
          CheckEq1(dut.ApbPwrite, 1'b0, $sformatf("%s local setup is read", iContext));
          return;
        end
      end

      $fatal(1, "[FAIL] %s: AXI/APB local-error setup not observed within %0d cycles", iContext, iBudgetCycles);
    end
  endtask

  task automatic WaitForAxiLocalErrorApbAccess(
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned WaitIdx;
    begin
      for (WaitIdx = 0; WaitIdx < iBudgetCycles; WaitIdx = WaitIdx + 1) begin
        @(negedge iClk);
        if (dut.ApbPenable
         && !dut.UartPsel
         && !dut.GpioPsel
         && !dut.I2cPsel
         && !dut.IntcPsel
         && !dut.SpiPsel
         && !dut.FndPsel
         && (dut.ApbPaddr == 12'h000)) begin
          CheckEq1(dut.ApbPwrite, 1'b0, $sformatf("%s local access is read", iContext));
          CheckEq1(dut.DataBusRsp.RspReady, 1'b0, $sformatf("%s local access waits for AXI response", iContext));
          return;
        end
      end

      $fatal(1, "[FAIL] %s: AXI/APB local-error access not observed within %0d cycles", iContext, iBudgetCycles);
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
        if (!Started && dut.uRv32iCore.FetchValid) begin
          Started = 1'b1;
        end
        if (Started) begin
          ExecCycles = ExecCycles + 1;
        end
        if (dut.uRv32iCore.RetireValid) begin
          RetiredInstrs = RetiredInstrs + 1;
        end
        if (dut.uRv32iCore.LoadUseStall) begin
          StallCount = StallCount + 1;
        end
        if (dut.uRv32iCore.RetireValid && (dut.uRv32iCore.RetirePc == LP_BENCH_DONE_PC)) begin
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
      CheckEq32(dut.uRv32iCore.Pc, LP_BENCH_DONE_PC, "benchmark done self-loop PC");
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
      CheckEqFwd(dut.uRv32iCore.uExecuteStage.ExRs1FwdSel, FWD_EX_MEM, "EX/MEM->EX rs1 bypass");
      CheckEqFwd(dut.uRv32iCore.uExecuteStage.ExRs2FwdSel, FWD_EX_MEM, "EX/MEM->EX rs2 bypass");

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
      CheckEqFwd(dut.uRv32iCore.uExecuteStage.ExRs1FwdSel, FWD_MEM_WB, "MEM/WB->EX rs1 bypass");
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
      CheckEqFwd(dut.uRv32iCore.uExecuteStage.ExRs2FwdSel, FWD_EX_MEM, "OPIMM->STORE store-data bypass");
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
        if (dut.uRv32iCore.LoadUseStall) begin
          StallCount = StallCount + 1;
        end
        if (!SeenConsumerEx && dut.uRv32iCore.IDEX.Valid && (dut.uRv32iCore.IDEX.Pc == 32'd8)) begin
          SeenConsumerEx = 1'b1;
          CheckEqFwd(dut.uRv32iCore.uExecuteStage.ExRs1FwdSel, FWD_MEM_WB, "LOAD->use MEM/WB bypass after stall");
        end
        if (dut.uRv32iCore.RetireValid && (dut.uRv32iCore.RetirePc == 32'd12)) begin
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
      CheckEqFwd(dut.uRv32iCore.uExecuteStage.ExRs1FwdSel, FWD_EX_MEM, "JALR rs1 bypass");
      CheckEq1(dut.uRv32iCore.ExRedirectValid, 1'b1, "JALR EX redirect");

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
      CheckEq1(dut.uRv32iCore.ExRedirectValid, 1'b1, "taken branch EX redirect");
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
      CheckEq1(dut.uRv32iCore.IdRedirectValid, 1'b1, "ID-resolved JAL redirect");

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
      CheckEq32(dut.uRv32iCore.uCsrFile.Mcause, 32'd0, "FENCE should not trap");
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
      CheckEq1(dut.DataBusRsp.RspReady, 1'b0, "GPIO zero-wait access waits for AXI response");
      CheckEq1(dut.uRv32iCore.MemApbStall, 1'b1, "GPIO zero-wait access stalls until AXI response");

      @(posedge iClk);
      CheckEq1(dut.GpioPsel, 1'b0, "GPIO post-access deasserts PSEL");
      CheckEq1(dut.ApbPenable, 1'b0, "GPIO post-access deasserts PENABLE");
      CheckEq1(dut.DataBusRsp.RspReady, 1'b1, "GPIO zero-wait AXI response ready");
      CheckEq1(dut.uRv32iCore.MemApbStall, 1'b0, "GPIO zero-wait AXI response releases stall");

      WaitForRetirePc(32'd16, 120, "GPIO zero-wait final loop");
      CheckEq32({24'd0, oGpioOut}, 32'h0000_00A5, "GPIO zero-wait writeback");
    end
  endtask

  task automatic RunAxiMmioWriteIntegrationTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  EncLui(5'd1, 20'h40001));
      LoadRomWord(32'd8,  EncAddi(5'd2, 5'd0, 165));
      LoadRomWord(32'd12, EncStore(5'd2, 5'd1, 0, 3'b010));
      LoadRomWord(32'd16, 32'h0000_006F);
      ReleaseReset();

      WaitForAxiWriteHandshake(32'h4000_1000, 4'hF, 32'h0000_00A5, 80, "GPIO AXI write integration");
      WaitForGpioApbSetup(12'h000, 4'hF, 32'h0000_00A5, 20, "GPIO AXI write integration");
      WaitForGpioApbAccess(12'h000, 4'hF, 32'h0000_00A5, 1'b0, 20, "GPIO AXI write integration");
      CheckEq32({24'd0, oGpioOut}, 32'h0000_0000, "GPIO AXI write side effect waits for APB completion");
      WaitForAxiWriteResponse(LP_AXI_RESP_OKAY, 1'b0, 20, "GPIO AXI write integration");
      CheckEq32({24'd0, oGpioOut}, 32'h0000_00A5, "GPIO AXI write side effect after APB completion");

      WaitForRetirePc(32'd16, 120, "GPIO AXI write final loop");
      CheckEq32({24'd0, oGpioOut}, 32'h0000_00A5, "GPIO AXI write final output");
    end
  endtask

  task automatic RunAxiMmioReadIntegrationTest;
    begin
      HoldResetAndClear();
      iGpioIn = 8'h3C;
      LoadRomWord(32'd4,  EncLui(5'd1, 20'h40001));
      LoadRomWord(32'd8,  EncLoad(5'd2, 5'd1, 4, 3'b010));
      LoadRomWord(32'd12, 32'h0000_006F);
      ReleaseReset();

      WaitForAxiReadHandshake(32'h4000_1004, 80, "GPIO AXI read integration");
      WaitForGpioApbReadSetup(12'h004, 20, "GPIO AXI read integration");
      WaitForGpioApbReadAccess(12'h004, 1'b0, 20, "GPIO AXI read integration");
      WaitForAxiReadResponse(32'h0000_003C, LP_AXI_RESP_OKAY, 1'b0, 20, "GPIO AXI read integration");

      WaitForRetirePc(32'd12, 120, "GPIO AXI read final loop");
      CheckEq32(GetRfWord(2), 32'h0000_003C, "GPIO AXI read register writeback");
      iGpioIn = '0;
    end
  endtask

  task automatic RunApbWaitStateHoldTest;
    IFID_t        IFIDHoldRef;
    IDEX_t        IDEXHoldRef;
    EXMEM_t       EXMEMHoldRef;
    logic [31:0]  PcHoldRef;
    int unsigned  WaitIdx;
    begin
      force dut.uAPB_GPIO.oPready = 1'b0;

      HoldResetAndClear();
      LoadRomWord(32'd4,  EncLui(5'd1, 20'h40001));
      LoadRomWord(32'd8,  EncAddi(5'd2, 5'd0, 165));
      LoadRomWord(32'd12, EncStore(5'd2, 5'd1, 0, 3'b010));
      LoadRomWord(32'd16, 32'h0000_006F);
      ReleaseReset();

      WaitForGpioApbSetup(12'h000, 4'hF, 32'h0000_00A5, 80, "GPIO wait-state hold");
      WaitForGpioApbAccess(12'h000, 4'hF, 32'h0000_00A5, 1'b0, 80, "GPIO wait-state hold");

      PcHoldRef    = dut.uRv32iCore.Pc;
      IFIDHoldRef  = dut.uRv32iCore.IFID;
      IDEXHoldRef  = dut.uRv32iCore.IDEX;
      EXMEMHoldRef = dut.uRv32iCore.EXMEM;

      CheckEq1(dut.uRv32iCore.MemApbStall, 1'b1, "APB wait-state stall asserted");
      CheckEq32({24'd0, oGpioOut}, 32'h0000_0000, "APB wait-state defers GPIO write");

      for (WaitIdx = 0; WaitIdx < 3; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);

        CheckEq1(dut.GpioPsel, 1'b1, $sformatf("APB wait hold cycle %0d PSEL", WaitIdx));
        CheckEq1(dut.GpioPready, 1'b0, $sformatf("APB wait hold cycle %0d PREADY", WaitIdx));
        CheckEq1(dut.ApbPenable, 1'b1, $sformatf("APB wait hold cycle %0d PENABLE", WaitIdx));
        CheckEq1(dut.uAPB_GPIO.AccessEn, 1'b0, $sformatf("APB wait hold cycle %0d GPIO access enable", WaitIdx));
        CheckEq1(dut.DataBusRsp.RspReady, 1'b0, $sformatf("APB wait hold cycle %0d ready", WaitIdx));
        CheckEq1(dut.uRv32iCore.MemApbStall, 1'b1, $sformatf("APB wait hold cycle %0d stall", WaitIdx));
        CheckEq1(dut.AxiBvalid, 1'b0, $sformatf("APB wait hold cycle %0d no AXI write response", WaitIdx));
        CheckEq1(dut.AxiRvalid, 1'b0, $sformatf("APB wait hold cycle %0d no AXI read response", WaitIdx));
        CheckEq32({24'd0, oGpioOut}, 32'h0000_0000, $sformatf("APB wait hold cycle %0d GPIO side effect", WaitIdx));

        if (dut.uRv32iCore.Pc !== PcHoldRef) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: PC changed during stall", WaitIdx);
        end
        if (dut.uRv32iCore.IFID !== IFIDHoldRef) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: IF/ID changed during stall", WaitIdx);
        end
        if (dut.uRv32iCore.IDEX !== IDEXHoldRef) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: ID/EX changed during stall", WaitIdx);
        end
        if (dut.uRv32iCore.EXMEM !== EXMEMHoldRef) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: EX/MEM changed during stall", WaitIdx);
        end
        if (dut.uRv32iCore.MEMWB.Valid && (dut.uRv32iCore.MEMWB.Pc == 32'd12)) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: waiting store reached MEM/WB early", WaitIdx);
        end
        if (dut.uRv32iCore.RetireValid && (dut.uRv32iCore.RetirePc == 32'd12)) begin
          $fatal(1, "[FAIL] APB wait hold cycle %0d: waiting store retired early", WaitIdx);
        end
      end

      @(negedge iClk);
      force dut.uAPB_GPIO.oPready = 1'b1;
      WaitForAxiWriteResponse(LP_AXI_RESP_OKAY, 1'b0, 20, "APB wait-state release");
      CheckEq32({24'd0, oGpioOut}, 32'h0000_00A5, "APB wait-state release GPIO write");
      release dut.uAPB_GPIO.oPready;
      WaitForRetirePc(32'd16, 120, "APB wait-state final loop");
    end
  endtask

  task automatic RunApbMasterLocalErrorTest;
    int unsigned WaitIdx;
    begin
      HoldResetAndClear();
      ReleaseReset();

      force dut.ApbSel   = 1'b1;
      force dut.ApbWr = 1'b0;
      force dut.BusAddr  = 32'h4000_6000;
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
      CheckEq1(dut.I2cPsel, 1'b0, "APB local error setup no I2C select");
      CheckEq1(dut.IntcPsel, 1'b0, "APB local error setup no INTC select");
      CheckEq1(dut.SpiPsel, 1'b0, "APB local error setup no SPI select");
      CheckEq1(dut.FndPsel, 1'b0, "APB local error setup no FND select");
      CheckEq1(dut.ApbPenable, 1'b0, "APB local error setup PENABLE low");

      for (WaitIdx = 0; WaitIdx < 10; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.ApbPenable) begin
          break;
        end
      end
      CheckEq1(dut.UartPsel, 1'b0, "APB local error access no UART select");
      CheckEq1(dut.GpioPsel, 1'b0, "APB local error access no GPIO select");
      CheckEq1(dut.I2cPsel, 1'b0, "APB local error access no I2C select");
      CheckEq1(dut.IntcPsel, 1'b0, "APB local error access no INTC select");
      CheckEq1(dut.SpiPsel, 1'b0, "APB local error access no SPI select");
      CheckEq1(dut.FndPsel, 1'b0, "APB local error access no FND select");
      CheckEq1(dut.ApbPenable, 1'b1, "APB local error access PENABLE high");
      for (WaitIdx = 0; WaitIdx < 10; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (dut.ApbRspReady) begin
          break;
        end
      end
      CheckEq1(dut.ApbRspReady, 1'b1, "APB local error native completion ready");
      CheckEq1(dut.ApbPslverr, 1'b1, "APB local error native completion error");

      release dut.ApbSel;
      release dut.ApbWr;
      release dut.BusAddr;
      release dut.BusByteEn;
      release dut.BusWdata;

      @(posedge iClk);
      CheckEq1(dut.UartPsel, 1'b0, "APB local error post-access UART deselect");
      CheckEq1(dut.GpioPsel, 1'b0, "APB local error post-access GPIO deselect");
      CheckEq1(dut.I2cPsel, 1'b0, "APB local error post-access I2C deselect");
      CheckEq1(dut.IntcPsel, 1'b0, "APB local error post-access INTC deselect");
      CheckEq1(dut.SpiPsel, 1'b0, "APB local error post-access SPI deselect");
      CheckEq1(dut.FndPsel, 1'b0, "APB local error post-access FND deselect");
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
      CheckEq32(dut.uRv32iCore.uCsrFile.Mscratch, 32'h0000_0088, "mscratch final value");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mtvec, LP_TRAP_VECTOR, "mtvec final value");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mepc, 32'h0000_0020, "mepc final value");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mcause, 32'h0000_0005, "mcause final value");
      CheckEq1(dut.uRv32iCore.uCsrFile.MstatusMie, 1'b0, "mstatus MIE cleared by CSRRCI");
      CheckEq1(dut.uRv32iCore.uCsrFile.MieMeie, 1'b1, "mie MEIE set");
      CheckEq1(dut.uRv32iCore.uCsrFile.MipMeipSw, 1'b1, "mip MEIP software pending");
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
      CheckEq32(dut.uRv32iCore.uCsrFile.Mepc, 32'h0000_0020, "MRET keeps programmed mepc");
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
      LoadRomWord(32'd12, EncLui(5'd1, 20'h50000));
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

  task automatic RunAxiMmioLocalErrorTrapTest;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,  EncAddi(5'd4, 5'd0, LP_TRAP_VECTOR));
      LoadRomWord(32'd8,  EncCsrReg(5'd0, 5'd4, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12, EncLui(5'd1, 20'h40008));
      LoadRomWord(32'd16, EncLoad(5'd2, 5'd1, 0, 3'b010));
      LoadRomWord(32'd20, EncAddi(5'd3, 5'd0, 1));
      LoadRomWord(LP_TRAP_VECTOR, 32'h0000_006F);
      ReleaseReset();

      WaitForAxiReadHandshake(32'h4000_8000, 80, "AXI local error trap");
      WaitForAxiLocalErrorApbSetup(20, "AXI local error trap");
      WaitForAxiLocalErrorApbAccess(20, "AXI local error trap");
      WaitForAxiReadResponse(32'h0000_0000, LP_AXI_RESP_SLVERR, 1'b1, 20, "AXI local error trap");
      WaitForTrapState(LP_TRAP_VECTOR, 32'd16, LP_MCAUSE_LOAD_ACCESS, 120, "AXI local error trap");
      CheckEq32(GetRfWord(2), 32'h0000_0000, "AXI local error suppresses writeback");
      CheckEq32(GetRfWord(3), 32'h0000_0000, "AXI local error kills younger instruction");
    end
  endtask

  task automatic RunUartInterruptTest;
    int unsigned WaitIdx;
    localparam logic [31:0] LP_UART_TRAP_VECTOR = 32'd128;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,   EncAddi(5'd1, 5'd0, LP_UART_TRAP_VECTOR));
      LoadRomWord(32'd8,   EncCsrReg(5'd0, 5'd1, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12,  EncLui(5'd3, 20'h40000));
      LoadRomWord(32'd16,  EncLui(5'd6, 20'h40001));
      LoadRomWord(32'd20,  EncLui(5'd7, LP_APB_INTC_BASE[31:12]));
      LoadRomWord(32'd24,  EncAddi(5'd4, 5'd0, 1));
      LoadRomWord(32'd28,  EncAddi(5'd8, 5'd0, 2));
      LoadRomWord(32'd32,  EncAddi(5'd9, 5'd0, 3));
      LoadRomWord(32'd36,  EncStore(5'd4, 5'd3, 16, 3'b010));
      LoadRomWord(32'd40,  EncStore(5'd9, 5'd7, LP_INTC_REG_PRIORITY_UART, 3'b010));
      LoadRomWord(32'd44,  EncStore(5'd8, 5'd7, LP_INTC_REG_ENABLE, 3'b010));
      LoadRomWord(32'd48,  EncLui(5'd5, 20'h00001));
      LoadRomWord(32'd52,  EncAddi(5'd5, 5'd5, -2048));
      LoadRomWord(32'd56,  EncCsrReg(5'd0, 5'd5, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd60,  EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(32'd64,  32'h0000_006F);
      LoadRomWord(LP_UART_TRAP_VECTOR,       EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b111));
      LoadRomWord(LP_UART_TRAP_VECTOR + 4,   EncLoad(5'd12, 5'd7, LP_INTC_REG_CLAIM, 3'b010));
      LoadRomWord(LP_UART_TRAP_VECTOR + 8,   EncLoad(5'd11, 5'd3, 12, 3'b010));
      LoadRomWord(LP_UART_TRAP_VECTOR + 12,  EncStore(5'd8, 5'd7, LP_INTC_REG_COMPLETE, 3'b010));
      LoadRomWord(LP_UART_TRAP_VECTOR + 16,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_UART_TRAP_VECTOR + 20,  EncMret());
      ReleaseReset();

      WaitForRetirePc(32'd64, 200, "UART IRQ init loop");
      SendUartByte(8'hA5);

      for (WaitIdx = 0; WaitIdx < 400; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if ((GetRfWord(10) == 32'h0000_0001) && (GetRfWord(11) == 32'h0000_00A5) && (dut.uRv32iCore.Pc == 32'd64)) begin
          break;
        end
      end

      CheckEq32(GetRfWord(10), 32'h0000_0001, "UART IRQ handler count");
      CheckEq32(GetRfWord(11), 32'h0000_00A5, "UART IRQ RXDATA pop");
      CheckEq32(GetRfWord(12), 32'h0000_0002, "UART IRQ claim id");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mcause, LP_MCAUSE_MACHINE_EXT_INT, "UART IRQ mcause");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mepc, 32'd64, "UART IRQ mepc");
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
      LoadRomWord(32'd28,  EncAddi(5'd9, 5'd0, 3));
      LoadRomWord(32'd32,  EncStore(5'd4, 5'd6, 12, 3'b010));
      LoadRomWord(32'd36,  EncStore(5'd9, 5'd7, LP_INTC_REG_PRIORITY_GPIO, 3'b010));
      LoadRomWord(32'd40,  EncStore(5'd4, 5'd7, LP_INTC_REG_ENABLE, 3'b010));
      LoadRomWord(32'd44,  EncLui(5'd5, 20'h00001));
      LoadRomWord(32'd48,  EncAddi(5'd5, 5'd5, -2048));
      LoadRomWord(32'd52,  EncCsrReg(5'd0, 5'd5, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd56,  EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(32'd60,  32'h0000_006F);
      LoadRomWord(LP_TRAP_VECTOR,       EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b111));
      LoadRomWord(LP_TRAP_VECTOR + 4,   EncLoad(5'd12, 5'd7, LP_INTC_REG_CLAIM, 3'b010));
      LoadRomWord(LP_TRAP_VECTOR + 8,   EncStore(5'd4, 5'd6, 20, 3'b010));
      LoadRomWord(LP_TRAP_VECTOR + 12,  EncStore(5'd4, 5'd7, LP_INTC_REG_COMPLETE, 3'b010));
      LoadRomWord(LP_TRAP_VECTOR + 16,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_TRAP_VECTOR + 20,  EncMret());
      ReleaseReset();

      WaitForRetirePc(32'd60, 200, "GPIO IRQ init loop");
      @(negedge iClk);
      iGpioIn[0] = 1'b1;
      WaitCycles(4);

      for (WaitIdx = 0; WaitIdx < 250; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if ((GetRfWord(10) == 32'h0000_0001) && (dut.uRv32iCore.Pc == 32'd60)) begin
          break;
        end
      end

      CheckEq32(GetRfWord(10), 32'h0000_0001, "GPIO IRQ handler count");
      CheckEq32(GetRfWord(12), 32'h0000_0001, "GPIO IRQ claim id");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mcause, LP_MCAUSE_MACHINE_EXT_INT, "GPIO IRQ mcause");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mepc, 32'd60, "GPIO IRQ mepc");
      CheckEq1(dut.GpioIrq, 1'b0, "GPIO IRQ cleared by W1C");
      CheckEq1(dut.ExtIrqPending, 1'b0, "GPIO IRQ cleared at interrupt controller");
    end
  endtask

  task automatic RunMtvecVectoredInterruptTest;
    int unsigned WaitIdx;
    localparam logic [31:0] LP_VECTORED_BASE   = 32'd128;
    localparam logic [31:0] LP_VECTORED_TARGET = LP_VECTORED_BASE + 32'd44;
    localparam logic [31:0] LP_MAIN_LOOP_PC    = 32'd56;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,   EncAddi(5'd1, 5'd0, LP_VECTORED_BASE | 32'd1));
      LoadRomWord(32'd8,   EncCsrReg(5'd0, 5'd1, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12,  EncLui(5'd6, 20'h40001));
      LoadRomWord(32'd16,  EncLui(5'd7, LP_APB_INTC_BASE[31:12]));
      LoadRomWord(32'd20,  EncAddi(5'd4, 5'd0, 1));
      LoadRomWord(32'd24,  EncAddi(5'd9, 5'd0, 3));
      LoadRomWord(32'd28,  EncStore(5'd4, 5'd6, 12, 3'b010));
      LoadRomWord(32'd32,  EncStore(5'd9, 5'd7, LP_INTC_REG_PRIORITY_GPIO, 3'b010));
      LoadRomWord(32'd36,  EncStore(5'd4, 5'd7, LP_INTC_REG_ENABLE, 3'b010));
      LoadRomWord(32'd40,  EncLui(5'd5, 20'h00001));
      LoadRomWord(32'd44,  EncAddi(5'd5, 5'd5, -2048));
      LoadRomWord(32'd48,  EncCsrReg(5'd0, 5'd5, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd52,  EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(LP_MAIN_LOOP_PC, 32'h0000_006F);

      LoadRomWord(LP_VECTORED_TARGET,       EncLoad(5'd12, 5'd7, LP_INTC_REG_CLAIM, 3'b010));
      LoadRomWord(LP_VECTORED_TARGET + 4,   EncStore(5'd4, 5'd6, 20, 3'b010));
      LoadRomWord(LP_VECTORED_TARGET + 8,   EncStore(5'd12, 5'd7, LP_INTC_REG_COMPLETE, 3'b010));
      LoadRomWord(LP_VECTORED_TARGET + 12,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_VECTORED_TARGET + 16,  EncMret());
      ReleaseReset();

      WaitForRetirePc(LP_MAIN_LOOP_PC, 200, "mtvec vectored IRQ init loop");
      @(negedge iClk);
      iGpioIn[0] = 1'b1;
      WaitForIdStagePc(LP_VECTORED_TARGET, 120, "mtvec vectored external IRQ target");

      for (WaitIdx = 0; WaitIdx < 250; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if ((GetRfWord(10) == 32'h0000_0001) && (dut.uRv32iCore.Pc == LP_MAIN_LOOP_PC)) begin
          break;
        end
      end

      CheckEq32(GetRfWord(10), 32'h0000_0001, "mtvec vectored GPIO handler count");
      CheckEq32(GetRfWord(12), 32'h0000_0001, "mtvec vectored GPIO claim id");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mtvec, LP_VECTORED_BASE | 32'd1, "mtvec vectored mode readback");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mcause, LP_MCAUSE_MACHINE_EXT_INT, "mtvec vectored IRQ mcause");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mepc, LP_MAIN_LOOP_PC, "mtvec vectored IRQ mepc");
      CheckEq1(dut.ExtIrqPending, 1'b0, "mtvec vectored IRQ cleared at interrupt controller");
    end
  endtask

  task automatic RunIntcPerSourceVectorTest;
    int unsigned WaitIdx;
    localparam logic [31:0] LP_COMMON_TRAP_VECTOR = 32'd128;
    localparam logic [31:0] LP_GPIO_VECTOR_ENTRY  = LP_INTC_REG_VECTOR_ENTRY0 + 32'h0000_0004;
    localparam logic [31:0] LP_UART_VECTOR_ENTRY  = LP_INTC_REG_VECTOR_ENTRY0 + 32'h0000_0008;
    localparam logic [31:0] LP_GPIO_HANDLER       = 32'd320;
    localparam logic [31:0] LP_UART_HANDLER       = 32'd352;
    localparam logic [31:0] LP_MAIN_LOOP_PC       = 32'd92;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,   EncAddi(5'd1, 5'd0, LP_COMMON_TRAP_VECTOR));
      LoadRomWord(32'd8,   EncCsrReg(5'd0, 5'd1, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12,  EncLui(5'd3, 20'h40000));
      LoadRomWord(32'd16,  EncLui(5'd6, 20'h40001));
      LoadRomWord(32'd20,  EncLui(5'd7, LP_APB_INTC_BASE[31:12]));
      LoadRomWord(32'd24,  EncAddi(5'd4, 5'd0, 1));
      LoadRomWord(32'd28,  EncAddi(5'd8, 5'd0, 2));
      LoadRomWord(32'd32,  EncAddi(5'd9, 5'd0, 3));
      LoadRomWord(32'd36,  EncAddi(5'd13, 5'd0, LP_GPIO_HANDLER));
      LoadRomWord(32'd40,  EncAddi(5'd14, 5'd0, LP_UART_HANDLER));
      LoadRomWord(32'd44,  EncStore(5'd4, 5'd6, 12, 3'b010));
      LoadRomWord(32'd48,  EncStore(5'd4, 5'd3, 16, 3'b010));
      LoadRomWord(32'd52,  EncStore(5'd9, 5'd7, LP_INTC_REG_PRIORITY_GPIO, 3'b010));
      LoadRomWord(32'd56,  EncStore(5'd9, 5'd7, LP_INTC_REG_PRIORITY_UART, 3'b010));
      LoadRomWord(32'd60,  EncStore(5'd13, 5'd7, LP_GPIO_VECTOR_ENTRY, 3'b010));
      LoadRomWord(32'd64,  EncStore(5'd14, 5'd7, LP_UART_VECTOR_ENTRY, 3'b010));
      LoadRomWord(32'd68,  EncStore(5'd4, 5'd7, LP_INTC_REG_CTRL, 3'b010));
      LoadRomWord(32'd72,  EncStore(5'd9, 5'd7, LP_INTC_REG_ENABLE, 3'b010));
      LoadRomWord(32'd76,  EncLui(5'd5, 20'h00001));
      LoadRomWord(32'd80,  EncAddi(5'd5, 5'd5, -2048));
      LoadRomWord(32'd84,  EncCsrReg(5'd0, 5'd5, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd88,  EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(LP_MAIN_LOOP_PC, 32'h0000_006F);

      LoadRomWord(LP_COMMON_TRAP_VECTOR,      EncAddi(5'd31, 5'd31, 1));
      LoadRomWord(LP_COMMON_TRAP_VECTOR + 4,  EncMret());

      LoadRomWord(LP_GPIO_HANDLER,       EncLoad(5'd12, 5'd7, LP_INTC_REG_CLAIM, 3'b010));
      LoadRomWord(LP_GPIO_HANDLER + 4,   EncStore(5'd4, 5'd6, 20, 3'b010));
      LoadRomWord(LP_GPIO_HANDLER + 8,   EncStore(5'd12, 5'd7, LP_INTC_REG_COMPLETE, 3'b010));
      LoadRomWord(LP_GPIO_HANDLER + 12,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_GPIO_HANDLER + 16,  EncMret());

      LoadRomWord(LP_UART_HANDLER,       EncLoad(5'd13, 5'd7, LP_INTC_REG_CLAIM, 3'b010));
      LoadRomWord(LP_UART_HANDLER + 4,   EncAddi(5'd11, 5'd13, 0));
      LoadRomWord(LP_UART_HANDLER + 8,   EncLoad(5'd15, 5'd3, 12, 3'b010));
      LoadRomWord(LP_UART_HANDLER + 12,  EncStore(5'd13, 5'd7, LP_INTC_REG_COMPLETE, 3'b010));
      LoadRomWord(LP_UART_HANDLER + 16,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_UART_HANDLER + 20,  EncMret());
      ReleaseReset();

      WaitForRetirePc(LP_MAIN_LOOP_PC, 240, "INTC table vector init loop");
      @(negedge iClk);
      iGpioIn[0] = 1'b1;
      WaitForIdStagePc(LP_GPIO_HANDLER, 140, "INTC GPIO table-entry vector handler");
      @(negedge iClk);
      iGpioIn[0] = 1'b0;

      for (WaitIdx = 0; WaitIdx < 300; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if ((GetRfWord(10) == 32'h0000_0001) && (GetRfWord(12) == 32'h0000_0001)
         && (dut.uRv32iCore.Pc == LP_MAIN_LOOP_PC)) begin
          break;
        end
      end

      CheckEq32(GetRfWord(10), 32'h0000_0001, "INTC vector GPIO handler count");
      CheckEq32(GetRfWord(12), 32'h0000_0001, "INTC vector GPIO claim id");
      CheckEq32(GetRfWord(31), 32'h0000_0000, "INTC vector bypassed common trap for GPIO");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mcause, LP_MCAUSE_MACHINE_EXT_INT, "INTC vector GPIO mcause");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mepc, LP_MAIN_LOOP_PC, "INTC vector GPIO mepc");

      fork
        SendUartByte(8'hC3);
        WaitForIdStagePc(LP_UART_HANDLER, 500, "INTC UART table-entry vector handler");
      join

      for (WaitIdx = 0; WaitIdx < 400; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if ((GetRfWord(10) == 32'h0000_0002) && (GetRfWord(11) == 32'h0000_0002)
         && (GetRfWord(13) == 32'h0000_0002) && (dut.uRv32iCore.Pc == LP_MAIN_LOOP_PC)) begin
          break;
        end
      end

      CheckEq32(GetRfWord(10), 32'h0000_0002, "INTC vector handled GPIO and UART");
      CheckEq32(GetRfWord(11), 32'h0000_0002, "INTC vector UART handler reached");
      CheckEq32(GetRfWord(13), 32'h0000_0002, "INTC vector UART claim id");
      CheckEq32(GetRfWord(15), 32'h0000_00C3, "INTC vector UART RXDATA pop");
      CheckEq32(GetRfWord(31), 32'h0000_0000, "INTC vector bypassed common trap for UART");
      CheckEq1(dut.uInterruptController.uIntcRegIf.oVectorEn, 1'b1, "INTC vector enable register");
      CheckEq32(dut.uInterruptController.uIntcRegIf.oVectorEntryFlat[31:0], 32'd0, "INTC vector entry0 remains reserved");
      CheckEq32(dut.uInterruptController.uIntcRegIf.oVectorEntryFlat[63:32], LP_GPIO_HANDLER, "INTC vector entry1 GPIO handler");
      CheckEq32(dut.uInterruptController.uIntcRegIf.oVectorEntryFlat[95:64], LP_UART_HANDLER, "INTC vector entry2 UART handler");
      WaitCycles(4);
      CheckEq1(dut.ExtIrqPending, 1'b0, "INTC vector IRQs cleared at interrupt controller");
    end
  endtask

  task automatic RunInterruptPriorityTest;
    int unsigned WaitIdx;
    localparam logic [31:0] LP_PRIORITY_TRAP_VECTOR = 32'd128;
    localparam logic [31:0] LP_PRIORITY_DELAY_START_PC = 32'd80;
    localparam logic [31:0] LP_PRIORITY_MAIN_LOOP_PC = 32'd100;
    begin
      HoldResetAndClear();
      LoadRomWord(32'd4,   EncAddi(5'd1, 5'd0, LP_PRIORITY_TRAP_VECTOR));
      LoadRomWord(32'd8,   EncCsrReg(5'd0, 5'd1, LP_CSR_MTVEC, 3'b001));
      LoadRomWord(32'd12,  EncLui(5'd3, 20'h40000));
      LoadRomWord(32'd16,  EncLui(5'd6, 20'h40001));
      LoadRomWord(32'd20,  EncLui(5'd7, LP_APB_INTC_BASE[31:12]));
      LoadRomWord(32'd24,  EncAddi(5'd4, 5'd0, 1));
      LoadRomWord(32'd28,  EncAddi(5'd8, 5'd0, 3));
      LoadRomWord(32'd32,  EncAddi(5'd9, 5'd0, 4));
      LoadRomWord(32'd36,  EncAddi(5'd17, 5'd0, 7));
      LoadRomWord(32'd40,  EncStore(5'd4, 5'd3, 16, 3'b010));
      LoadRomWord(32'd44,  EncStore(5'd4, 5'd6, 12, 3'b010));
      LoadRomWord(32'd48,  EncStore(5'd9, 5'd7, LP_INTC_REG_PRIORITY_GPIO, 3'b010));
      LoadRomWord(32'd52,  EncStore(5'd8, 5'd7, LP_INTC_REG_PRIORITY_UART, 3'b010));
      LoadRomWord(32'd56,  EncStore(5'd8, 5'd7, LP_INTC_REG_ENABLE, 3'b010));
      LoadRomWord(32'd60,  EncStore(5'd17, 5'd7, LP_INTC_REG_THRESHOLD, 3'b010));
      LoadRomWord(32'd64,  EncLui(5'd5, 20'h00001));
      LoadRomWord(32'd68,  EncAddi(5'd5, 5'd5, -2048));
      LoadRomWord(32'd72,  EncCsrReg(5'd0, 5'd5, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd76,  EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(32'd80,  EncAddi(5'd16, 5'd0, 220));
      LoadRomWord(32'd84,  EncAddi(5'd16, 5'd16, -1));
      LoadRomWord(32'd88,  EncBeq(5'd16, 5'd0, 8));
      LoadRomWord(32'd92,  EncJal(5'd0, -8));
      LoadRomWord(32'd96,  EncStore(5'd0, 5'd7, LP_INTC_REG_THRESHOLD, 3'b010));
      LoadRomWord(LP_PRIORITY_MAIN_LOOP_PC, 32'h0000_006F);

      LoadRomWord(LP_PRIORITY_TRAP_VECTOR,       EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b111));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 4,   EncLoad(5'd12, 5'd7, LP_INTC_REG_CLAIM, 3'b010));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 8,   EncBeq(5'd10, 5'd0, 8));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 12,  EncBeq(5'd0, 5'd0, 8));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 16,  EncAddi(5'd15, 5'd12, 0));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 20,  EncAddi(5'd13, 5'd0, 1));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 24,  EncBeq(5'd12, 5'd13, 16));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 28,  EncAddi(5'd13, 5'd0, 2));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 32,  EncBeq(5'd12, 5'd13, 24));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 36,  EncMret());
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 40,  EncStore(5'd4, 5'd6, 20, 3'b010));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 44,  EncStore(5'd13, 5'd7, LP_INTC_REG_COMPLETE, 3'b010));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 48,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 52,  EncMret());
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 56,  EncLoad(5'd11, 5'd3, 12, 3'b010));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 60,  EncStore(5'd13, 5'd7, LP_INTC_REG_COMPLETE, 3'b010));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 64,  EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_PRIORITY_TRAP_VECTOR + 68,  EncMret());
      ReleaseReset();

      WaitForRetirePc(LP_PRIORITY_DELAY_START_PC, 220, "priority test threshold delay start");
      fork
        SendUartByte(8'h5A);
        begin
          @(negedge iClk);
          iGpioIn[0] = 1'b1;
        end
      join

      for (WaitIdx = 0; WaitIdx < 2000; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if ((GetRfWord(10) == 32'h0000_0002) && (GetRfWord(11) == 32'h0000_005A)
         && (dut.uRv32iCore.Pc == LP_PRIORITY_MAIN_LOOP_PC)) begin
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
      LoadRomWord(32'd24,  EncAddi(5'd9, 5'd0, 3));
      LoadRomWord(32'd28,  EncStore(5'd4, 5'd6, 12, 3'b010));
      LoadRomWord(32'd32,  EncStore(5'd9, 5'd7, LP_INTC_REG_PRIORITY_GPIO, 3'b010));
      LoadRomWord(32'd36,  EncStore(5'd4, 5'd7, LP_INTC_REG_ENABLE, 3'b010));
      LoadRomWord(32'd40,  EncLui(5'd5, 20'h00001));
      LoadRomWord(32'd44,  EncAddi(5'd5, 5'd5, -2048));
      LoadRomWord(32'd48,  EncCsrReg(5'd0, 5'd5, LP_CSR_MIE, 3'b001));
      LoadRomWord(32'd52,  EncCsrImm(5'd0, 5'd8, LP_CSR_MSTATUS, 3'b101));
      LoadRomWord(32'd56,  EncBeq(5'd10, 5'd4, 12));
      LoadRomWord(32'd60,  EncJal(5'd0, -4));
      LoadRomWord(32'd64,  LP_NOP_INSTR);
      LoadRomWord(32'd68,  LP_NOP_INSTR);
      LoadRomWord(32'd72,  LP_NOP_INSTR);
      LoadRomWord(32'd76,  LP_NOP_INSTR);
      LoadRomWord(32'd80,  LP_NOP_INSTR);
      LoadRomWord(32'd84,  LP_NOP_INSTR);
      LoadRomWord(32'd88,  LP_NOP_INSTR);
      LoadRomWord(32'd92,  LP_NOP_INSTR);
      LoadRomWord(32'd96,  EncStore(5'd4, 5'd7, LP_INTC_REG_COMPLETE, 3'b010));
      LoadRomWord(32'd100, EncJal(5'd0, -44));

      LoadRomWord(LP_COMPLETE_TRAP_VECTOR,       EncLoad(5'd12, 5'd7, LP_INTC_REG_CLAIM, 3'b010));
      LoadRomWord(LP_COMPLETE_TRAP_VECTOR + 4,   EncAddi(5'd10, 5'd10, 1));
      LoadRomWord(LP_COMPLETE_TRAP_VECTOR + 8,   EncMret());
      ReleaseReset();

      WaitForRetirePc(32'd60, 220, "complete gate init loop");
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
      CheckEq1(dut.uInterruptController.uIntcPendingCtrl.oPendingVec[0],
               1'b0, "complete gate pending clear before COMPLETE");
      CheckEq1(dut.uInterruptController.uIntcPendingCtrl.oInServiceVec[0],
               1'b1, "complete gate in-service set before COMPLETE");
      CheckEq1(dut.uInterruptController.genIntcGateway[0].uIntcGateway.oBlocked,
               1'b1, "complete gate gateway blocked before COMPLETE");
      CheckEq1(dut.ExtIrqPending, 1'b0, "complete gate suppresses re-notify before COMPLETE");

      for (WaitIdx = 0; WaitIdx < 400; WaitIdx = WaitIdx + 1) begin
        @(negedge iClk);
        if (dut.IntcPsel && dut.ApbPenable && dut.ApbPwrite
         && (dut.ApbPaddr == LP_INTC_REG_COMPLETE[11:0])) begin
          CheckEq32(dut.ApbPwdata, 32'h0000_0001, "complete gate COMPLETE source id");
          CheckEq1(dut.uInterruptController.uIntcPendingCtrl.oCompleteAcceptVec[0],
                   1'b1, "complete gate COMPLETE accept before clock edge");
          CheckEq1(dut.uInterruptController.genIntcGateway[0].uIntcGateway.oPendingSetPulse,
                   1'b0, "complete gate does not reissue pending pulse before delayed Moore state");

          @(posedge iClk);
          #1;
          CheckEq1(dut.uInterruptController.uIntcPendingCtrl.oPendingVec[0],
                   1'b0, "complete gate pending waits for delayed Moore pending pulse");
          CheckEq1(dut.uInterruptController.uIntcPendingCtrl.oInServiceVec[0],
                   1'b0, "complete gate in-service clear on COMPLETE edge");
          CheckEq1(dut.uInterruptController.genIntcGateway[0].uIntcGateway.oPendingSetPulse,
                   1'b1, "complete gate emits one-clock delayed pending pulse");
          CheckEq1(dut.uInterruptController.genIntcGateway[0].uIntcGateway.oBlocked,
                   1'b0, "complete gate gateway leaves blocked state while emitting pending pulse");
          CheckEq1(dut.ExtIrqPending, 1'b0, "complete gate controller IRQ waits for delayed pending latch");

          @(posedge iClk);
          #1;
          CheckEq1(dut.uInterruptController.uIntcPendingCtrl.oPendingVec[0],
                   1'b1, "complete gate pending re-set after delayed pending pulse");
          CheckEq1(dut.uInterruptController.uIntcPendingCtrl.oInServiceVec[0],
                   1'b0, "complete gate in-service remains clear after delayed pending pulse");
          CheckEq1(dut.uInterruptController.genIntcGateway[0].uIntcGateway.oBlocked,
                   1'b1, "complete gate gateway returns blocked after delayed pending pulse");
          CheckEq1(dut.ExtIrqPending, 1'b1, "complete gate re-asserts controller IRQ after delayed pending latch");
          break;
        end

        CheckEq1(dut.ExtIrqPending, 1'b0, "complete gate suppresses re-notify until COMPLETE");
      end

      if (WaitIdx == 400) begin
        $fatal(1, "[FAIL] complete gate COMPLETE write not observed");
      end

      CheckEq32(GetRfWord(10), 32'h0000_0001, "complete gate service count before second claim");
      CheckEq32(GetRfWord(12), 32'h0000_0001, "complete gate retained claim id before second claim");
      CheckEq1(dut.GpioIrq, 1'b1, "complete gate source remains asserted without W1C");

      for (WaitIdx = 0; WaitIdx < 250; WaitIdx = WaitIdx + 1) begin
        @(posedge iClk);
        if (GetRfWord(10) == 32'h0000_0002) begin
          break;
        end
      end

      if (WaitIdx == 250) begin
        $fatal(1, "[FAIL] complete gate second GPIO claim not observed");
      end

      CheckEq32(GetRfWord(10), 32'h0000_0002, "complete gate second GPIO service");
      CheckEq32(GetRfWord(12), 32'h0000_0001, "complete gate second claim id");
      CheckEq1(dut.GpioIrq, 1'b1, "complete gate source remains asserted after second claim");
      CheckEq1(dut.uInterruptController.uIntcPendingCtrl.oPendingVec[0],
               1'b0, "complete gate pending clear after second claim");
      CheckEq1(dut.uInterruptController.uIntcPendingCtrl.oInServiceVec[0],
               1'b1, "complete gate in-service set after second claim");
      CheckEq1(dut.uInterruptController.genIntcGateway[0].uIntcGateway.oBlocked,
               1'b1, "complete gate gateway blocked after second claim");
      CheckEq1(dut.ExtIrqPending, 1'b0, "complete gate suppresses duplicate pending after second claim");
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

      WaitForRetirePc(32'd24, 120, "masked interrupt init loop");
      SendUartByte(8'h3C);
      WaitCycles(220);

      CheckEq32(GetRfWord(10), 32'h0000_0000, "masked interrupt ignored");
      CheckEq1(dut.UartIrq, 1'b1, "masked UART IRQ remains pending");
      CheckEq1(dut.ExtIrqPending, 1'b0, "interrupt controller mask blocks processor IRQ");
      CheckEq32(dut.uRv32iCore.uCsrFile.Mcause, 32'h0000_0000, "masked interrupt no mcause update");
      CheckEq32(dut.uRv32iCore.Pc, 32'd24, "masked interrupt stays in main loop");
    end
  endtask

endmodule
