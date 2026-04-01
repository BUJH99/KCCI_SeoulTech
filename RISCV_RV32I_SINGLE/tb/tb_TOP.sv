/*
[TB_INFO_START]
Name: tb_TOP
Target: TOP
Role: Self-checking regression testbench for the RISCV_32I_SINGLE core with SoC peripherals
Scenario:
  - Boot the DUT with InstructionFORTIMING and checkpoint key architectural states
  - Verify load/store formatting, machine-mode CSR behavior, and APB-based bus/peripheral integration
  - Check external memory, GPIO/UART/FND register access, and interrupt controller claim/complete flow
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_TOP;

  logic        iClk;
  logic        iRstn;
  logic        iUartRx;
  logic [7:0]  iGpioIn;
  logic        oUartTx;
  logic [7:0]  oGpioOut;
  logic [7:0]  oGpioOe;
  logic [6:0]  oSeg;
  logic        oDp;
  logic [3:0]  oDigitSel;
  logic        oTimingProbe;

  rv32i_pkg::bus_cmd_e  fmtChkBusCmd;
  rv32i_pkg::mem_size_e fmtChkMemSize;
  logic                 fmtChkLoadUnsigned;
  logic [31:0]          fmtChkAddr;
  logic [31:0]          fmtChkStoreData;
  logic [31:0]          fmtChkLoadDataRaw;
  logic [3:0]           fmtChkByteEn;
  logic [31:0]          fmtChkStoreDataAligned;
  logic [31:0]          fmtChkLoadData;
  logic                 fmtChkMisaligned;

  logic        csrChkWriteEn;
  logic [11:0] csrChkAddr;
  logic [11:0] csrChkWriteAddr;
  logic [31:0] csrChkWriteData;
  logic        csrChkMretValid;
  logic        csrChkTrapEnterValid;
  logic [31:0] csrChkTrapEnterEpc;
  logic [31:0] csrChkTrapEnterCause;
  logic        csrChkExtIrqPending;
  logic [31:0] csrChkRdata;
  logic [31:0] csrChkMtvec;
  logic [31:0] csrChkMepc;
  logic        csrChkMstatusMie;
  logic        csrChkMstatusMpie;
  logic        csrChkMieMeie;
  logic        csrChkMipMeip;

  rv32i_pkg::DataBusReq_t busChkReq;
  rv32i_pkg::DataBusRsp_t busChkRsp;
  logic [31:0]            busChkRamRdata;
  logic                   busChkRamSel;
  logic                   busChkRamWrEn;
  logic                   busChkApbSel;
  logic                   busChkApbWrite;
  logic [31:0]            busChkAddr;
  logic [3:0]             busChkByteEn;
  logic [31:0]            busChkWdata;
  logic [31:0]            busChkApbRdata;
  logic                   busChkApbReady;
  logic                   busChkApbErr;
  logic [11:0]            apbChkPaddr;
  logic [3:0]             apbChkPstrb;
  logic [31:0]            apbChkPwdata;
  logic                   apbChkPwrite;
  logic                   apbChkPenable;
  logic                   apbChkUartPsel;
  logic                   apbChkGpioPsel;
  logic                   apbChkFndPsel;
  logic                   apbChkIntcPsel;
  logic [31:0]            apbChkUartPrdata;
  logic [31:0]            apbChkGpioPrdata;
  logic [31:0]            apbChkFndPrdata;
  logic [31:0]            apbChkIntcPrdata;
  logic                   apbChkUartPready;
  logic                   apbChkGpioPready;
  logic                   apbChkFndPready;
  logic                   apbChkIntcPready;
  logic                   apbChkUartPslverr;
  logic                   apbChkGpioPslverr;
  logic                   apbChkFndPslverr;
  logic                   apbChkIntcPslverr;
  logic [7:0]             gpioChkIn;
  logic [7:0]             gpioChkOut;
  logic [7:0]             gpioChkOe;
  logic                   gpioChkIrq;
  logic                   uartChkTx;
  logic                   uartChkIrq;
  logic [6:0]             fndChkSeg;
  logic                   fndChkDp;
  logic [3:0]             fndChkDigitSel;
  logic                   intcChkMachineExtIrq;

  int unsigned cycleCount;

  TOP dut (
    .iClk(iClk),
    .iRstn(iRstn),
    .iUartRx(iUartRx),
    .iGpioIn(iGpioIn),
    .oUartTx(oUartTx),
    .oGpioOut(oGpioOut),
    .oGpioOe(oGpioOe),
    .oSeg(oSeg),
    .oDp(oDp),
    .oDigitSel(oDigitSel),
    .oTimingProbe(oTimingProbe)
  );

  LoadStoreFormatter uLoadStoreFormatterCheck (
    .iBusCmd(fmtChkBusCmd),
    .iMemSize(fmtChkMemSize),
    .iLoadUnsigned(fmtChkLoadUnsigned),
    .iAddr(fmtChkAddr),
    .iStoreData(fmtChkStoreData),
    .iLoadDataRaw(fmtChkLoadDataRaw),
    .oStoreByteEn(fmtChkByteEn),
    .oStoreDataAligned(fmtChkStoreDataAligned),
    .oLoadData(fmtChkLoadData),
    .oMisaligned(fmtChkMisaligned)
  );

  CsrFile uCsrFileCheck (
    .iClk(iClk),
    .iRstn(iRstn),
    .iCsrAddr(csrChkAddr),
    .iCsrWriteEn(csrChkWriteEn),
    .iCsrWriteAddr(csrChkWriteAddr),
    .iCsrWriteData(csrChkWriteData),
    .iMretValid(csrChkMretValid),
    .iTrapEnterValid(csrChkTrapEnterValid),
    .iTrapEnterEpc(csrChkTrapEnterEpc),
    .iTrapEnterCause(csrChkTrapEnterCause),
    .iExtIrqPending(csrChkExtIrqPending),
    .oCsrRdata(csrChkRdata),
    .oMtvec(csrChkMtvec),
    .oMepc(csrChkMepc),
    .oMstatusMie(csrChkMstatusMie),
    .oMstatusMpie(csrChkMstatusMpie),
    .oMieMeie(csrChkMieMeie),
    .oMipMeip(csrChkMipMeip)
  );

  DataBusMaster uDataBusMasterCheck (
    .iReq(busChkReq),
    .iRamRdata(busChkRamRdata),
    .iApbRdata(busChkApbRdata),
    .iApbReady(busChkApbReady),
    .iApbErr(busChkApbErr),
    .oRamSel(busChkRamSel),
    .oRamWrEn(busChkRamWrEn),
    .oApbSel(busChkApbSel),
    .oApbWrite(busChkApbWrite),
    .oAddr(busChkAddr),
    .oByteEn(busChkByteEn),
    .oWdata(busChkWdata),
    .oRsp(busChkRsp)
  );

  ExternalMemory #(
    .P_ADDR_WIDTH(4),
    .P_DATA_WIDTH(32)
  ) uExternalMemoryCheck (
    .iClk(iClk),
    .iReadEn(busChkRamSel && !busChkReq.ReqWrite),
    .iWriteEn(busChkRamWrEn),
    .iAddr(busChkAddr),
    .iWrData(busChkWdata),
    .iByteEn(busChkByteEn),
    .oRdData(busChkRamRdata)
  );

  APBMASTER uAPBMASTERCheck (
    .iClk(iClk),
    .iRstn(iRstn),
    .iApbSel(busChkApbSel),
    .iPwrite(busChkApbWrite),
    .iPaddr(busChkAddr),
    .iPstrb(busChkByteEn),
    .iPwdata(busChkWdata),
    .iUartPrdata(apbChkUartPrdata),
    .iGpioPrdata(apbChkGpioPrdata),
    .iFndPrdata(apbChkFndPrdata),
    .iIntcPrdata(apbChkIntcPrdata),
    .iUartPready(apbChkUartPready),
    .iGpioPready(apbChkGpioPready),
    .iFndPready(apbChkFndPready),
    .iIntcPready(apbChkIntcPready),
    .iUartPslverr(apbChkUartPslverr),
    .iGpioPslverr(apbChkGpioPslverr),
    .iFndPslverr(apbChkFndPslverr),
    .iIntcPslverr(apbChkIntcPslverr),
    .oPwrite(apbChkPwrite),
    .oPaddr(apbChkPaddr),
    .oPstrb(apbChkPstrb),
    .oPwdata(apbChkPwdata),
    .oPenable(apbChkPenable),
    .oUartPsel(apbChkUartPsel),
    .oGpioPsel(apbChkGpioPsel),
    .oFndPsel(apbChkFndPsel),
    .oIntcPsel(apbChkIntcPsel),
    .oRspReady(busChkApbReady),
    .oPrdata(busChkApbRdata),
    .oPslverr(busChkApbErr)
  );

  APB_UART #(
    .P_CLK_HZ(100_000_000),
    .P_BAUD(9_600)
  ) uAPBUartCheck (
    .iClk(iClk),
    .iRstn(iRstn),
    .iPsel(apbChkUartPsel),
    .iPenable(apbChkPenable),
    .iPwrite(apbChkPwrite),
    .iPaddr(apbChkPaddr),
    .iPstrb(apbChkPstrb),
    .iPwdata(apbChkPwdata),
    .iUartRx(1'b1),
    .oPrdata(apbChkUartPrdata),
    .oPready(apbChkUartPready),
    .oPslverr(apbChkUartPslverr),
    .oUartTx(uartChkTx),
    .oIrq(uartChkIrq)
  );

  APB_GPIO #(
    .P_GPIO_WIDTH(8)
  ) uAPBGpioCheck (
    .iClk(iClk),
    .iRstn(iRstn),
    .iPsel(apbChkGpioPsel),
    .iPenable(apbChkPenable),
    .iPwrite(apbChkPwrite),
    .iPaddr(apbChkPaddr),
    .iPstrb(apbChkPstrb),
    .iPwdata(apbChkPwdata),
    .iGpioIn(gpioChkIn),
    .oPrdata(apbChkGpioPrdata),
    .oPready(apbChkGpioPready),
    .oPslverr(apbChkGpioPslverr),
    .oGpioOut(gpioChkOut),
    .oGpioOe(gpioChkOe),
    .oIrq(gpioChkIrq)
  );

  APB_FND #(
    .P_CLK_HZ(100_000_000)
  ) uAPBFndCheck (
    .iClk(iClk),
    .iRstn(iRstn),
    .iPsel(apbChkFndPsel),
    .iPenable(apbChkPenable),
    .iPwrite(apbChkPwrite),
    .iPaddr(apbChkPaddr),
    .iPstrb(apbChkPstrb),
    .iPwdata(apbChkPwdata),
    .oPrdata(apbChkFndPrdata),
    .oPready(apbChkFndPready),
    .oPslverr(apbChkFndPslverr),
    .oSeg(fndChkSeg),
    .oDp(fndChkDp),
    .oDigitSel(fndChkDigitSel)
  );

  InterruptController uInterruptControllerCheck (
    .iClk(iClk),
    .iRstn(iRstn),
    .iPsel(apbChkIntcPsel),
    .iPenable(apbChkPenable),
    .iPwrite(apbChkPwrite),
    .iPaddr(apbChkPaddr),
    .iPstrb(apbChkPstrb),
    .iPwdata(apbChkPwdata),
    .iUartIrq(uartChkIrq),
    .iGpioIrq(gpioChkIrq),
    .oPrdata(apbChkIntcPrdata),
    .oPready(apbChkIntcPready),
    .oPslverr(apbChkIntcPslverr),
    .oMachineExtIrq(intcChkMachineExtIrq)
  );

  always #5 iClk = ~iClk;

  always @(posedge iClk) begin
    cycleCount <= cycleCount + 1;
  end

  initial begin
    iClk        = 1'b0;
    iRstn       = 1'b0;
    iUartRx     = 1'b1;
    iGpioIn     = '0;
    cycleCount  = 0;

    fmtChkBusCmd       = rv32i_pkg::BUS_CMD_IDLE;
    fmtChkMemSize      = rv32i_pkg::MEM_WORD;
    fmtChkLoadUnsigned = 1'b0;
    fmtChkAddr         = '0;
    fmtChkStoreData    = '0;
    fmtChkLoadDataRaw  = '0;

    csrChkWriteEn        = 1'b0;
    csrChkAddr           = rv32i_pkg::LP_CSR_MSTATUS;
    csrChkWriteAddr      = rv32i_pkg::LP_CSR_MSTATUS;
    csrChkWriteData      = '0;
    csrChkMretValid      = 1'b0;
    csrChkTrapEnterValid = 1'b0;
    csrChkTrapEnterEpc   = '0;
    csrChkTrapEnterCause = '0;
    csrChkExtIrqPending  = 1'b0;

    busChkReq         = '0;
    gpioChkIn         = '0;

    repeat (4) @(posedge iClk);
    iRstn = 1'b1;
  end

  initial begin : run_test
    wait (iRstn === 1'b1);

    run_program_checks();
    run_load_store_formatter_checks();
    run_csr_file_checks();
    run_bus_fabric_checks();

    $display("[PASS] tb_TOP completed all checks in %0d cycles", cycleCount);
    $finish;
  end

  initial begin : watchdog
    repeat (1500) @(posedge iClk);
    $fatal(1, "[FAIL] Watchdog expired after %0d cycles", cycleCount);
  end

  task automatic wait_for_pc(
    input logic [31:0] iExpectedPc,
    input int unsigned iBudgetCycles,
    input string       iContext
  );
    int unsigned waitIdx;
    begin
      for (waitIdx = 0; waitIdx < iBudgetCycles; waitIdx = waitIdx + 1) begin
        @(posedge iClk);
        if (dut.pc === iExpectedPc) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s: expected PC 0x%08x within %0d cycles, current PC=0x%08x",
        iContext,
        iExpectedPc,
        iBudgetCycles,
        dut.pc
      );
    end
  endtask

  task automatic check_eq32(
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

  task automatic check_eq1(
    input logic iActual,
    input logic iExpected,
    input string iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected %0b, got %0b", iContext, iExpected, iActual);
      end
    end
  endtask

  function automatic logic [31:0] get_rf_word(input int unsigned iIdx);
    get_rf_word = dut.uDatapath.uRegfile.memReg[iIdx];
  endfunction

  function automatic logic [31:0] get_dut_dmem_word(input int unsigned iIdx);
    get_dut_dmem_word = dut.uExternalMemory.memRam[iIdx];
  endfunction

  task automatic bus_write_ok(
    input logic [31:0] iAddr,
    input logic [3:0]  iByteEn,
    input logic [31:0] iWdata,
    input string       iContext
  );
    begin
      busChkReq.ReqValid  = 1'b1;
      busChkReq.ReqWrite  = 1'b1;
      busChkReq.ReqAddr   = iAddr;
      busChkReq.ReqByteEn = iByteEn;
      busChkReq.ReqWdata  = iWdata;

      @(posedge iClk);
      #1;
      while (!busChkRsp.RspReady) begin
        @(posedge iClk);
        #1;
      end

      check_eq1(busChkRsp.RspErr, 1'b0, iContext);
      busChkReq = '0;
      @(posedge iClk);
    end
  endtask

  task automatic bus_read_expect(
    input  logic [31:0] iAddr,
    input  logic [31:0] iExpectedData,
    input  logic        iExpectedErr,
    input  string       iContext
  );
    begin
      busChkReq.ReqValid  = 1'b1;
      busChkReq.ReqWrite  = 1'b0;
      busChkReq.ReqAddr   = iAddr;
      busChkReq.ReqByteEn = 4'b0000;
      busChkReq.ReqWdata  = '0;

      #1;
      while (!busChkRsp.RspReady) begin
        @(posedge iClk);
        #1;
      end

      check_eq1(busChkRsp.RspErr, iExpectedErr, {iContext, " error"});
      check_eq32(busChkRsp.RspRdata, iExpectedData, iContext);
      busChkReq = '0;
      @(posedge iClk);
    end
  endtask

  task automatic run_program_checks;
    begin
      wait_for_pc(32'd20, 40, "bootstrap immediates");
      check_eq32(get_rf_word(1), 32'h0000_000F, "x1 after addi");
      check_eq32(get_rf_word(2), 32'h0000_0003, "x2 after addi");
      check_eq32(get_rf_word(3), 32'hFFFF_FFF0, "x3 after addi");
      check_eq32(get_rf_word(23), 32'h0000_0080, "x23 base pointer");
      check_eq32(get_rf_word(24), 32'h0000_0090, "x24 scratch base");

      wait_for_pc(32'd60, 80, "alu sweep");
      check_eq32(get_rf_word(4), 32'h0000_0012, "x4 add");
      check_eq32(get_rf_word(5), 32'h0000_000C, "x5 sub");
      check_eq32(get_rf_word(6), 32'h0000_0078, "x6 sll");
      check_eq32(get_rf_word(7), 32'h0000_0001, "x7 slt");
      check_eq32(get_rf_word(8), 32'h0000_0000, "x8 sltu");
      check_eq32(get_rf_word(9), 32'h0000_000C, "x9 xor");
      check_eq32(get_rf_word(10), 32'h0000_0001, "x10 srl");
      check_eq32(get_rf_word(11), 32'hFFFF_FFFE, "x11 sra");
      check_eq32(get_rf_word(12), 32'h0000_000F, "x12 or");
      check_eq32(get_rf_word(13), 32'h0000_0003, "x13 and");

      wait_for_pc(32'd104, 80, "immediate sweep");
      check_eq32(get_rf_word(14), 32'h0000_0014, "x14 addi");
      check_eq32(get_rf_word(15), 32'h0000_0001, "x15 slti");
      check_eq32(get_rf_word(16), 32'h0000_0000, "x16 sltiu");
      check_eq32(get_rf_word(17), 32'h0000_000C, "x17 xori");
      check_eq32(get_rf_word(18), 32'h0000_000F, "x18 ori");
      check_eq32(get_rf_word(19), 32'h0000_0007, "x19 andi");
      check_eq32(get_rf_word(20), 32'h0000_0030, "x20 slli");
      check_eq32(get_rf_word(21), 32'h0000_0007, "x21 srli");
      check_eq32(get_rf_word(22), 32'hFFFF_FFFC, "x22 srai");
      check_eq32(get_rf_word(25), 32'h1234_5000, "x25 lui");
      check_eq32(get_rf_word(26), 32'h0000_1064, "x26 auipc");

      wait_for_pc(32'd108, 20, "store word");
      check_eq32(get_dut_dmem_word(32), 32'h0000_0014, "word store at 0x80");

      wait_for_pc(32'd148, 80, "byte and half stores");
      check_eq32(get_dut_dmem_word(33), 32'hF234_7F80, "packed byte/half stores at 0x84");

      wait_for_pc(32'd168, 60, "load sign and zero extension");
      check_eq32(get_rf_word(27), 32'h0000_0014, "x27 lw");
      check_eq32(get_rf_word(28), 32'h0000_0017, "x28 load-use add");
      check_eq32(get_rf_word(29), 32'hFFFF_FF80, "x29 lb sign extension");
      check_eq32(get_rf_word(30), 32'h0000_0080, "x30 lbu zero extension");
      check_eq32(get_rf_word(31), 32'hFFFF_F234, "x31 lh sign extension");
      check_eq32(get_rf_word(4), 32'h0000_F234, "x4 lhu zero extension");
      check_eq32(get_rf_word(5), 32'hFFFF_FF00, "x5 xor after loads");

      wait_for_pc(32'd172, 20, "post-load dependent add");
      check_eq32(get_rf_word(6), 32'h0000_E468, "x6 add using load results");

      wait_for_pc(32'd300, 240, "branch block");
      check_eq32(get_rf_word(7), 32'h0000_0006, "x7 branch fall-through count");
      check_eq32(get_rf_word(8), 32'h0000_0006, "x8 taken-path count");

      wait_for_pc(32'd328, 80, "jal link");
      check_eq32(get_rf_word(11), 32'h0000_0144, "x11 jal link");

      wait_for_pc(32'd344, 40, "jalr link");
      check_eq32(get_rf_word(12), 32'h0000_0158, "x12 jalr base");
      check_eq32(get_rf_word(13), 32'h0000_0154, "x13 jalr link");

      wait_for_pc(32'd360, 80, "program completion");
      check_eq32(get_rf_word(15), 32'h0000_0037, "x15 after jalr landing");
      check_eq32(get_rf_word(16), 32'h1234_500F, "x16 final add");
      check_eq32(get_rf_word(17), 32'h0000_1067, "x17 final add");
      check_eq32(get_rf_word(0), 32'h0000_0000, "x0 remains hard-wired");

      @(posedge iClk);
      @(posedge iClk);
      check_eq32(dut.pc, 32'h0000_0168, "done self-loop PC hold");
    end
  endtask

  task automatic run_load_store_formatter_checks;
    begin
      fmtChkBusCmd       = rv32i_pkg::BUS_CMD_WRITE;
      fmtChkMemSize      = rv32i_pkg::MEM_BYTE;
      fmtChkLoadUnsigned = 1'b0;
      fmtChkAddr         = 32'h0000_0003;
      fmtChkStoreData    = 32'h0000_00AB;
      fmtChkLoadDataRaw  = 32'h89AB_CDEF;
      #1;
      check_eq32({28'd0, fmtChkByteEn}, 32'h0000_0008, "formatter byte store strobe");
      check_eq32(fmtChkStoreDataAligned, 32'hAB00_0000, "formatter byte store alignment");
      check_eq1(fmtChkMisaligned, 1'b0, "formatter byte store aligned");

      fmtChkMemSize   = rv32i_pkg::MEM_HALF;
      fmtChkAddr      = 32'h0000_0002;
      fmtChkStoreData = 32'h0000_1234;
      #1;
      check_eq32({28'd0, fmtChkByteEn}, 32'h0000_000C, "formatter half store strobe");
      check_eq32(fmtChkStoreDataAligned, 32'h1234_0000, "formatter half store alignment");

      fmtChkBusCmd  = rv32i_pkg::BUS_CMD_READ;
      fmtChkMemSize = rv32i_pkg::MEM_WORD;
      fmtChkAddr    = 32'h0000_0002;
      #1;
      check_eq1(fmtChkMisaligned, 1'b1, "formatter misaligned word load flag");

      fmtChkMemSize      = rv32i_pkg::MEM_BYTE;
      fmtChkLoadUnsigned = 1'b0;
      fmtChkAddr         = 32'h0000_0003;
      #1;
      check_eq32(fmtChkLoadData, 32'hFFFF_FF89, "formatter signed byte load");

      fmtChkLoadUnsigned = 1'b1;
      #1;
      check_eq32(fmtChkLoadData, 32'h0000_0089, "formatter unsigned byte load");

      fmtChkMemSize      = rv32i_pkg::MEM_HALF;
      fmtChkLoadUnsigned = 1'b0;
      fmtChkAddr         = 32'h0000_0002;
      #1;
      check_eq32(fmtChkLoadData, 32'hFFFF_89AB, "formatter signed half load");

      fmtChkBusCmd = rv32i_pkg::BUS_CMD_IDLE;
    end
  endtask

  task automatic run_csr_file_checks;
    begin
      csrChkAddr = rv32i_pkg::LP_CSR_MSTATUS;
      #1;
      check_eq32(csrChkRdata, 32'h0000_0000, "csr reset mstatus");

      csrChkWriteEn   = 1'b1;
      csrChkWriteAddr = rv32i_pkg::LP_CSR_MTVEC;
      csrChkWriteData = 32'h0000_0105;
      @(posedge iClk);
      #1;
      csrChkWriteEn = 1'b0;
      check_eq32(csrChkMtvec, 32'h0000_0104, "csr mtvec aligned write");

      csrChkWriteEn   = 1'b1;
      csrChkWriteAddr = rv32i_pkg::LP_CSR_MIE;
      csrChkWriteData = 32'h0000_0800;
      @(posedge iClk);
      #1;
      csrChkWriteEn = 1'b0;
      check_eq1(csrChkMieMeie, 1'b1, "csr mie.meie write");

      csrChkWriteEn   = 1'b1;
      csrChkWriteAddr = rv32i_pkg::LP_CSR_MSTATUS;
      csrChkWriteData = 32'h0000_0008;
      @(posedge iClk);
      #1;
      csrChkWriteEn = 1'b0;
      check_eq1(csrChkMstatusMie, 1'b1, "csr mstatus.mie write");

      csrChkTrapEnterValid = 1'b1;
      csrChkTrapEnterEpc   = 32'h0000_0040;
      csrChkTrapEnterCause = rv32i_pkg::LP_MCAUSE_LOAD_ACCESS;
      @(posedge iClk);
      #1;
      csrChkTrapEnterValid = 1'b0;
      check_eq32(csrChkMepc, 32'h0000_0040, "csr mepc trap capture");
      check_eq1(csrChkMstatusMie, 1'b0, "csr mie cleared on trap");
      check_eq1(csrChkMstatusMpie, 1'b1, "csr mpie saved on trap");

      csrChkMretValid = 1'b1;
      @(posedge iClk);
      #1;
      csrChkMretValid = 1'b0;
      check_eq1(csrChkMstatusMie, 1'b1, "csr mie restored on mret");
      check_eq1(csrChkMstatusMpie, 1'b1, "csr mpie set on mret");

      csrChkExtIrqPending = 1'b1;
      #1;
      check_eq1(csrChkMipMeip, 1'b1, "csr mip reflects ext irq");
      csrChkExtIrqPending = 1'b0;
    end
  endtask

  task automatic run_bus_fabric_checks;
    begin
      uExternalMemoryCheck.memRam[1] = 32'h0000_0000;
      bus_write_ok(32'h0000_0004, 4'b1111, 32'hCAFE_BABE, "bus ram write");
      bus_read_expect(32'h0000_0004, 32'hCAFE_BABE, 1'b0, "bus ram read");

      gpioChkIn = 8'hA5;
      bus_write_ok(rv32i_pkg::LP_APB_GPIO_BASE + 32'h0000_0008, 4'b1111, 32'h0000_00F0, "gpio dir write");
      bus_read_expect(rv32i_pkg::LP_APB_GPIO_BASE + 32'h0000_0008, 32'h0000_00F0, 1'b0, "gpio dir read");
      bus_write_ok(rv32i_pkg::LP_APB_GPIO_BASE + 32'h0000_0000, 4'b1111, 32'h0000_005A, "gpio data out write");
      bus_read_expect(rv32i_pkg::LP_APB_GPIO_BASE + 32'h0000_0000, 32'h0000_005A, 1'b0, "gpio data out read");
      bus_read_expect(rv32i_pkg::LP_APB_GPIO_BASE + 32'h0000_0004, 32'h0000_00A5, 1'b0, "gpio data in read");

      bus_read_expect(rv32i_pkg::LP_APB_UART_BASE + 32'h0000_0000, 32'h0000_0003, 1'b0, "uart ctrl reset");
      bus_write_ok(rv32i_pkg::LP_APB_UART_BASE + 32'h0000_0010, 4'b1111, 32'h0000_0001, "uart irq enable write");
      bus_read_expect(rv32i_pkg::LP_APB_UART_BASE + 32'h0000_0010, 32'h0000_0001, 1'b0, "uart irq enable read");

      bus_write_ok(rv32i_pkg::LP_APB_FND_BASE + 32'h0000_0000, 4'b1111, 32'h0000_1234, "fnd digits write");
      bus_read_expect(rv32i_pkg::LP_APB_FND_BASE + 32'h0000_0000, 32'h0000_1234, 1'b0, "fnd digits read");
      check_eq1(fndChkDigitSel != 4'b1111, 1'b1, "fnd active after default enable");

      gpioChkIn = 8'h00;
      bus_write_ok(rv32i_pkg::LP_APB_GPIO_BASE + 32'h0000_000C, 4'b1111, 32'h0000_0001, "gpio rise irq enable");
      @(posedge iClk);
      gpioChkIn = 8'h01;
      @(posedge iClk);

      bus_write_ok(rv32i_pkg::LP_APB_INTC_BASE + 32'h0000_0004, 4'b1111, 32'h0000_0001, "intc enable gpio irq");
      bus_read_expect(rv32i_pkg::LP_APB_INTC_BASE + 32'h0000_0000, 32'h0000_0001, 1'b0, "intc pending read");
      check_eq1(intcChkMachineExtIrq, 1'b1, "intc machine ext irq asserted");
      bus_read_expect(rv32i_pkg::LP_APB_INTC_BASE + 32'h0000_0008, 32'h0000_0001, 1'b0, "intc claim read");
      bus_write_ok(rv32i_pkg::LP_APB_INTC_BASE + 32'h0000_000C, 4'b1111, 32'h0000_0001, "intc complete write");

      bus_read_expect(rv32i_pkg::LP_APB_INTC_BASE + 32'h0000_0040, 32'h0000_0000, 1'b1, "intc invalid register");
    end
  endtask

endmodule
