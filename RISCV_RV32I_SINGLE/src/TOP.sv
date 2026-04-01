/*
[MODULE_INFO_START]
Name: TOP
Role: Top-level wrapper for the RV32I single-cycle CPU with CSR, trap, and APB-based SoC peripherals
Summary:
  - Wires together PC, instruction ROM, control, datapath, bus fabric, external memory, APB peripherals, and machine-mode CSR state
  - Routes synchronous traps and machine external interrupts into mtvec and supports MRET return via mepc
  - Retains one writeback-derived timing sink so post-synthesis timing stays observable
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TOP #(
  parameter int unsigned P_CLK_HZ     = 100_000_000,
  parameter int unsigned P_UART_BAUD  = 9_600,
  parameter int unsigned P_GPIO_WIDTH = 8
) (
  input  logic                    iClk,
  input  logic                    iRstn,
  input  logic                    iUartRx,
  input  logic [P_GPIO_WIDTH-1:0] iGpioIn,
  output logic                    oUartTx,
  output logic [P_GPIO_WIDTH-1:0] oGpioOut,
  output logic [P_GPIO_WIDTH-1:0] oGpioOe,
  output logic [6:0]              oSeg,
  output logic                    oDp,
  output logic [3:0]              oDigitSel,
  output logic                    oTimingProbe
);

  logic [31:0] pc;
  logic [31:0] instr;
  logic [31:0] nextPcCore;
  logic [31:0] nextPc;
  logic [31:0] pcTarget;
  logic [31:0] jalrTarget;
  logic        regWriteReq;
  logic        memReadReq;
  logic        memWriteReq;
  logic        regWrite;
  logic        pcWe;
  logic        loadUnsigned;
  logic        illegal;
  logic        trapReqDecoded;
  logic        branchTaken;
  logic        dataMisaligned;
  logic        instrAddrMisaligned;
  logic        csrUseImm;
  logic        csrWriteEnReq;
  logic        csrWriteEnCommit;
  logic        mretValidReq;
  logic        mretValidCommit;
  logic        interruptAccepted;
  logic        trapEnterValid;
  logic        syncTrapValid;
  logic        dataBusHold;
  logic        loadMisalign;
  logic        storeMisalign;
  logic [31:0] trapEnterCause;
  logic [31:0] busRdData;
  logic [31:0] rdWrData;
  logic [31:0] memAddr;
  logic [31:0] memWrData;
  logic [31:0] ramRdWord;
  logic [31:0] apbPrdata;
  logic        apbPready;
  logic        apbPslverr;
  logic [31:0] csrRdata;
  logic [31:0] mtvec;
  logic [31:0] mepc;
  logic [31:0] csrWdata;
  logic [3:0]  memByteEn;
  logic [11:0] csrAddr;
  logic        mstatusMie;
  logic        mstatusMpie;
  logic        mieMeie;
  logic        mipMeip;
  logic        extIrqPending;
  logic        uartIrq;
  logic        gpioIrq;
  logic        ramSel;
  logic        ramWrEn;
  logic        apbSel;
  logic        apbWrite;
  logic        apbPwrite;
  logic        apbPenable;
  logic [31:0] busAddr;
  logic [31:0] busWdata;
  logic [3:0]  busByteEn;
  logic [11:0] apbPaddr;
  logic [3:0]  apbPstrb;
  logic [31:0] apbPwdata;
  logic        uartPsel;
  logic        gpioPsel;
  logic        fndPsel;
  logic        intcPsel;
  logic [31:0] uartPrdata;
  logic [31:0] gpioPrdata;
  logic [31:0] fndPrdata;
  logic [31:0] intcPrdata;
  logic        uartPready;
  logic        gpioPready;
  logic        fndPready;
  logic        intcPready;
  logic        uartPslverr;
  logic        gpioPslverr;
  logic        fndPslverr;
  logic        intcPslverr;
  logic        preBusTrapValid;
  (* DONT_TOUCH = "TRUE", KEEP = "TRUE" *) logic timingRetainMetric;
  rv32i_pkg::bus_cmd_e     busCmdReq;
  rv32i_pkg::mem_size_e    memSize;
  rv32i_pkg::alu_a_sel_e   aluASel;
  rv32i_pkg::alu_b_sel_e   aluBSel;
  rv32i_pkg::imm_sel_e     immSel;
  rv32i_pkg::branch_e      branchOp;
  rv32i_pkg::pc_sel_e      pcSel;
  rv32i_pkg::wb_sel_e      wbSel;
  rv32i_pkg::alu_op_e      aluOp;
  rv32i_pkg::csr_cmd_e     csrCmd;
  rv32i_pkg::sys_op_e      sysOp;
  rv32i_pkg::trap_cause_e  decodeTrapCause;
  rv32i_pkg::trap_cause_e  trapCause;
  rv32i_pkg::DataBusReq_t  dataBusReq;
  rv32i_pkg::DataBusRsp_t  dataBusRsp;

  Pc uPc (
    .iClk(iClk),
    .iRstn(iRstn),
    .iPcWe(pcWe),
    .iNextPc(nextPc),
    .oPc(pc)
  );

  InstrRom uInstrRom (
    .iAddr(pc),
    .oInstr(instr)
  );

  ControlUnit uControlUnit (
    .iInstr(instr),
    .oRegWrite(regWriteReq),
    .oMemRead(memReadReq),
    .oMemWrite(memWriteReq),
    .oBusCmd(busCmdReq),
    .oLoadUnsigned(loadUnsigned),
    .oMemSize(memSize),
    .oAluASel(aluASel),
    .oAluBSel(aluBSel),
    .oImmSel(immSel),
    .oBranchOp(branchOp),
    .oPcSel(pcSel),
    .oWbSel(wbSel),
    .oAluOp(aluOp),
    .oCsrUseImm(csrUseImm),
    .oCsrCmd(csrCmd),
    .oSysOp(sysOp),
    .oTrapReq(trapReqDecoded),
    .oIllegal(illegal)
  );

  Datapath uDatapath (
    .iClk(iClk),
    .iRstn(iRstn),
    .iPc(pc),
    .iInstr(instr),
    .iRegWrite(regWrite),
    .iLoadUnsigned(loadUnsigned),
    .iBusCmd(busCmdReq),
    .iMemSize(memSize),
    .iAluASel(aluASel),
    .iAluBSel(aluBSel),
    .iImmSel(immSel),
    .iBranchOp(branchOp),
    .iWbSel(wbSel),
    .iAluOp(aluOp),
    .iCsrUseImm(csrUseImm),
    .iCsrCmd(csrCmd),
    .iSysOp(sysOp),
    .iCsrRdata(csrRdata),
    .iMemRdDataRaw(busRdData),
    .oAluResult(),
    .oPcTarget(pcTarget),
    .oJalrTarget(jalrTarget),
    .oBranchTaken(branchTaken),
    .oDataMisaligned(dataMisaligned),
    .oMemAddr(memAddr),
    .oMemWrData(memWrData),
    .oMemByteEn(memByteEn),
    .oMemRdData(),
    .oMemRdDataQualified(),
    .oRs2Data(),
    .oCsrAddr(csrAddr),
    .oCsrWriteEn(csrWriteEnReq),
    .oCsrWdata(csrWdata),
    .oMretValid(mretValidReq),
    .oRdWrData(rdWrData),
    .oTimingProbe()
  );

  always_comb begin
    decodeTrapCause = rv32i_pkg::TRAP_NONE;

    if (illegal) begin
      decodeTrapCause = rv32i_pkg::TRAP_ILLEGAL;
    end else if (trapReqDecoded) begin
      unique case (sysOp)
        rv32i_pkg::SYS_ECALL:  decodeTrapCause = rv32i_pkg::TRAP_ECALL;
        rv32i_pkg::SYS_EBREAK: decodeTrapCause = rv32i_pkg::TRAP_EBREAK;
        default:               decodeTrapCause = rv32i_pkg::TRAP_ILLEGAL;
      endcase
    end else if (instrAddrMisaligned) begin
      decodeTrapCause = rv32i_pkg::TRAP_INSTR_MISALIGNED;
    end
  end

  assign loadMisalign   = (busCmdReq == rv32i_pkg::BUS_CMD_READ) && dataMisaligned;
  assign storeMisalign  = (busCmdReq == rv32i_pkg::BUS_CMD_WRITE) && dataMisaligned;
  assign preBusTrapValid = (decodeTrapCause != rv32i_pkg::TRAP_NONE) || loadMisalign || storeMisalign;

  assign interruptAccepted = extIrqPending
                          && mstatusMie
                          && mieMeie
                          && !preBusTrapValid
                          && !mretValidReq
                          && (busCmdReq == rv32i_pkg::BUS_CMD_IDLE);

  assign dataBusReq.ReqValid  = (busCmdReq != rv32i_pkg::BUS_CMD_IDLE)
                             && !loadMisalign
                             && !storeMisalign
                             && (decodeTrapCause == rv32i_pkg::TRAP_NONE)
                             && !interruptAccepted;
  assign dataBusReq.ReqWrite  = (busCmdReq == rv32i_pkg::BUS_CMD_WRITE);
  assign dataBusReq.ReqAddr   = memAddr;
  assign dataBusReq.ReqByteEn = memByteEn;
  assign dataBusReq.ReqWdata  = memWrData;

  DataBusMaster uDataBusMaster (
    .iReq(dataBusReq),
    .iRamRdata(ramRdWord),
    .iApbRdata(apbPrdata),
    .iApbReady(apbPready),
    .iApbErr(apbPslverr),
    .oRamSel(ramSel),
    .oRamWrEn(ramWrEn),
    .oApbSel(apbSel),
    .oApbWrite(apbWrite),
    .oAddr(busAddr),
    .oByteEn(busByteEn),
    .oWdata(busWdata),
    .oRsp(dataBusRsp)
  );

  ExternalMemory uExternalMemory (
    .iClk(iClk),
    .iReadEn(ramSel && !dataBusReq.ReqWrite),
    .iWriteEn(ramWrEn),
    .iAddr(busAddr),
    .iWrData(busWdata),
    .iByteEn(busByteEn),
    .oRdData(ramRdWord)
  );

  APBMASTER uAPBMASTER (
    .iClk(iClk),
    .iRstn(iRstn),
    .iApbSel(apbSel),
    .iPwrite(apbWrite),
    .iPaddr(busAddr),
    .iPstrb(busByteEn),
    .iPwdata(busWdata),
    .iUartPrdata(uartPrdata),
    .iGpioPrdata(gpioPrdata),
    .iFndPrdata(fndPrdata),
    .iIntcPrdata(intcPrdata),
    .iUartPready(uartPready),
    .iGpioPready(gpioPready),
    .iFndPready(fndPready),
    .iIntcPready(intcPready),
    .iUartPslverr(uartPslverr),
    .iGpioPslverr(gpioPslverr),
    .iFndPslverr(fndPslverr),
    .iIntcPslverr(intcPslverr),
    .oPwrite(apbPwrite),
    .oPaddr(apbPaddr),
    .oPstrb(apbPstrb),
    .oPwdata(apbPwdata),
    .oPenable(apbPenable),
    .oUartPsel(uartPsel),
    .oGpioPsel(gpioPsel),
    .oFndPsel(fndPsel),
    .oIntcPsel(intcPsel),
    .oRspReady(apbPready),
    .oPrdata(apbPrdata),
    .oPslverr(apbPslverr)
  );

  APB_UART #(
    .P_CLK_HZ(P_CLK_HZ),
    .P_BAUD(P_UART_BAUD)
  ) uAPB_UART (
    .iClk(iClk),
    .iRstn(iRstn),
    .iPsel(uartPsel),
    .iPenable(apbPenable),
    .iPwrite(apbPwrite),
    .iPaddr(apbPaddr),
    .iPstrb(apbPstrb),
    .iPwdata(apbPwdata),
    .iUartRx(iUartRx),
    .oPrdata(uartPrdata),
    .oPready(uartPready),
    .oPslverr(uartPslverr),
    .oUartTx(oUartTx),
    .oIrq(uartIrq)
  );

  APB_GPIO #(
    .P_GPIO_WIDTH(P_GPIO_WIDTH)
  ) uAPB_GPIO (
    .iClk(iClk),
    .iRstn(iRstn),
    .iPsel(gpioPsel),
    .iPenable(apbPenable),
    .iPwrite(apbPwrite),
    .iPaddr(apbPaddr),
    .iPstrb(apbPstrb),
    .iPwdata(apbPwdata),
    .iGpioIn(iGpioIn),
    .oPrdata(gpioPrdata),
    .oPready(gpioPready),
    .oPslverr(gpioPslverr),
    .oGpioOut(oGpioOut),
    .oGpioOe(oGpioOe),
    .oIrq(gpioIrq)
  );

  APB_FND #(
    .P_CLK_HZ(P_CLK_HZ)
  ) uAPB_FND (
    .iClk(iClk),
    .iRstn(iRstn),
    .iPsel(fndPsel),
    .iPenable(apbPenable),
    .iPwrite(apbPwrite),
    .iPaddr(apbPaddr),
    .iPstrb(apbPstrb),
    .iPwdata(apbPwdata),
    .oPrdata(fndPrdata),
    .oPready(fndPready),
    .oPslverr(fndPslverr),
    .oSeg(oSeg),
    .oDp(oDp),
    .oDigitSel(oDigitSel)
  );

  InterruptController uInterruptController (
    .iClk(iClk),
    .iRstn(iRstn),
    .iPsel(intcPsel),
    .iPenable(apbPenable),
    .iPwrite(apbPwrite),
    .iPaddr(apbPaddr),
    .iPstrb(apbPstrb),
    .iPwdata(apbPwdata),
    .iUartIrq(uartIrq),
    .iGpioIrq(gpioIrq),
    .oPrdata(intcPrdata),
    .oPready(intcPready),
    .oPslverr(intcPslverr),
    .oMachineExtIrq(extIrqPending)
  );

  CsrFile uCsrFile (
    .iClk(iClk),
    .iRstn(iRstn),
    .iCsrAddr(csrAddr),
    .iCsrWriteEn(csrWriteEnCommit),
    .iCsrWriteAddr(csrAddr),
    .iCsrWriteData(csrWdata),
    .iMretValid(mretValidCommit),
    .iTrapEnterValid(trapEnterValid),
    .iTrapEnterEpc(pc),
    .iTrapEnterCause(trapEnterCause),
    .iExtIrqPending(extIrqPending),
    .oCsrRdata(csrRdata),
    .oMtvec(mtvec),
    .oMepc(mepc),
    .oMstatusMie(mstatusMie),
    .oMstatusMpie(mstatusMpie),
    .oMieMeie(mieMeie),
    .oMipMeip(mipMeip)
  );

  MemoryTrapClassifier uMemoryTrapClassifier (
    .iValid(1'b1),
    .iKill(1'b0),
    .iIncomingTrapCause(decodeTrapCause),
    .iMemReadEn(busCmdReq == rv32i_pkg::BUS_CMD_READ),
    .iMemWriteEn(busCmdReq == rv32i_pkg::BUS_CMD_WRITE),
    .iBusReqValid(dataBusReq.ReqValid),
    .iBusRspErr(dataBusReq.ReqValid && dataBusRsp.RspReady && dataBusRsp.RspErr),
    .iLoadMisalign(loadMisalign),
    .iStoreMisalign(storeMisalign),
    .oTrapValid(syncTrapValid),
    .oTrapActive(),
    .oTrapCause(trapCause)
  );

  assign trapEnterValid  = syncTrapValid || interruptAccepted;
  assign trapEnterCause  = interruptAccepted
                         ? rv32i_pkg::LP_MCAUSE_MACHINE_EXT_INT
                         : rv32i_pkg::TrapCauseToMcause(trapCause);
  assign mretValidCommit = mretValidReq && !trapEnterValid && !interruptAccepted && !dataBusHold;
  assign csrWriteEnCommit = csrWriteEnReq && !trapEnterValid && !interruptAccepted && !dataBusHold;
  assign regWrite        = regWriteReq && !trapEnterValid && !interruptAccepted && !dataBusHold;
  assign dataBusHold     = dataBusReq.ReqValid && !dataBusRsp.RspReady;
  assign busRdData       = dataBusRsp.RspRdata;

  NextPcGen uNextPcGen (
    .iPc(pc),
    .iPcSel(pcSel),
    .iBranchTaken(branchTaken),
    .iPcTarget(pcTarget),
    .iJalrTarget(jalrTarget),
    .oNextPc(nextPcCore),
    .oInstrAddrMisaligned(instrAddrMisaligned)
  );

  assign nextPc = trapEnterValid    ? mtvec
                : mretValidCommit   ? mepc
                : nextPcCore;
  assign pcWe   = !dataBusHold;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      timingRetainMetric <= 1'b0;
    end else begin
      timingRetainMetric <= ^rdWrData;
    end
  end

  assign oTimingProbe = timingRetainMetric;

endmodule
