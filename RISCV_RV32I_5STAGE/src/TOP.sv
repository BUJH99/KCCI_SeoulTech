/*
[MODULE_INFO_START]
Name: TOP
Role: Top-level SoC wrapper for the RV32I 5-stage CPU
Summary:
  - Instantiates Rv32iCore and owns the instruction ROM, data RAM, APB bridge, UART, GPIO, and interrupt controller
  - Keeps memory/peripheral wiring outside the CPU core so additional SoC targets can attach without changing the pipeline
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TOP #(
  parameter int unsigned P_CLK_HZ           = 100_000_000,
  parameter int unsigned P_SYS_CLK_DIVIDE   = 4,
  parameter int unsigned P_UART_BAUD        = 115_200,
  parameter int unsigned P_GPIO_WIDTH       = 8,
  parameter int unsigned P_INSTR_ADDR_WIDTH = 10,
  parameter string       P_INSTR_INIT_FILE  = "C:/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_5STAGE/src/timing_programs/uart_bootrom.mem",
  parameter int unsigned P_BOOT_ADDR_WIDTH    = P_INSTR_ADDR_WIDTH,
  parameter int unsigned P_BOOT_DEPTH_WORDS   = (1 << P_BOOT_ADDR_WIDTH),
  parameter string       P_BOOT_INIT_FILE     = P_INSTR_INIT_FILE,
  parameter int unsigned P_PROGRAM_ADDR_WIDTH = 14,
  parameter int unsigned P_PROGRAM_DEPTH_WORDS = (1 << P_PROGRAM_ADDR_WIDTH),
  parameter string       P_PROGRAM_INIT_FILE  = "",
  parameter int unsigned P_PROGRAM_READ_ONLY_INIT = 0,
  parameter int unsigned P_INSTR_MEM_IMPL     = 0,
  parameter int unsigned P_INSTR_MEM_LATENCY  = 0,
  parameter int unsigned P_PREFETCH_DEPTH     = 0,
  parameter bit          P_UART_RESET_CPU_MODE = 1'b0,
  parameter int unsigned P_DATA_ADDR_WIDTH  = 8
) (
  input  logic                    iClk,
  input  logic                    iRst,
  input  logic                    iUartRx,
  input  logic [P_GPIO_WIDTH-1:0] iGpioIn,
  input  logic                    iSpiMiso,
  inout  wire                     ioI2cScl,
  inout  wire                     ioI2cSda,

  output logic                    oUartTx,
  output logic [P_GPIO_WIDTH-1:0] oGpioOut,
  output logic [P_GPIO_WIDTH-1:0] oGpioOe,
  output logic                    oSpiSclk,
  output logic                    oSpiMosi,
  output logic                    oSpiCsN,
  output logic [6:0]              oSeg,
  output logic                    oDp,
  output logic [3:0]              oDigitSel,
  output logic                    oTimingProbe
);

  import rv32i_pkg::*;

  localparam int unsigned LP_SYS_CLK_HZ = P_CLK_HZ / P_SYS_CLK_DIVIDE;

  InstrBusReq_t InstrBusReq;
  InstrBusRsp_t InstrBusRsp;
  DataBusReq_t  DataBusReq;
  DataBusRsp_t  DataBusRsp;

  logic        SysClk;
  logic        SysClkLocked;
  logic        SysRstAssert;
  logic        SysRstMeta;
  logic        SysRst;
  logic        RamSel;
  logic        RamWrEn;
  logic        ApbSel;
  logic        ApbWr;
  logic        ApbPwrite;
  logic        ApbPenable;
  logic [31:0] BusAddr;
  logic [3:0]  BusByteEn;
  logic [31:0] BusWdata;
  logic [31:0] RamRdWord;
  logic [31:0] ProgramInstDmaRdWord;
  logic        ProgramInstDmaWrEn;
  logic [31:0] ProgramInstDmaAddr;
  logic [31:0] ProgramInstDmaWdata;
  logic [3:0]  ProgramInstDmaWstrb;
  logic        InstrPrefetchHitPulse;
  logic        InstrPrefetchEmptyPulse;
  logic        InstrPrefetchDiscardPulse;
  logic [31:0] ApbPrdata;
  logic        ApbRspReady;
  logic        ApbPslverr;
  logic [31:0] AxiAwaddr;
  logic [2:0]  AxiAwprot;
  logic        AxiAwvalid;
  logic        AxiAwready;
  logic [31:0] AxiWdata;
  logic [3:0]  AxiWstrb;
  logic        AxiWvalid;
  logic        AxiWready;
  logic        AxiBvalid;
  logic        AxiBready;
  logic [1:0]  AxiBresp;
  logic [31:0] AxiAraddr;
  logic [2:0]  AxiArprot;
  logic        AxiArvalid;
  logic        AxiArready;
  logic        AxiRvalid;
  logic        AxiRready;
  logic [31:0] AxiRdata;
  logic [1:0]  AxiRresp;
  logic [11:0] ApbPaddr;
  logic [3:0]  ApbPstrb;
  logic [31:0] ApbPwdata;
  logic        UartPsel;
  logic        GpioPsel;
  logic        I2cPsel;
  logic        IntcPsel;
  logic        SpiPsel;
  logic        FndPsel;
  logic        TimerPsel;
  logic        InstDmaRegsPsel;
  logic [31:0] UartPrdata;
  logic [31:0] GpioPrdata;
  logic [31:0] I2cPrdata;
  logic [31:0] IntcPrdata;
  logic [31:0] SpiPrdata;
  logic [31:0] FndPrdata;
  logic [31:0] TimerPrdata;
  logic [31:0] InstDmaRegsPrdata;
  logic        UartPready;
  logic        GpioPready;
  logic        I2cPready;
  logic        IntcPready;
  logic        SpiPready;
  logic        FndPready;
  logic        TimerPready;
  logic        InstDmaRegsPready;
  logic        UartPslverr;
  logic        GpioPslverr;
  logic        I2cPslverr;
  logic        IntcPslverr;
  logic        SpiPslverr;
  logic        FndPslverr;
  logic        TimerPslverr;
  logic        InstDmaRegsPslverr;

  logic        UartIrq;
  UartModeE    UartMode;
  logic        UartRxFlushReq;
  logic        UartCpuRxEn;
  logic        UartCpuTxEn;
  logic        UartCpuPop;
  logic        UartCpuRxValid;
  logic [7:0]  UartCpuRxData;
  logic        UartCpuTxValid;
  logic [7:0]  UartCpuTxData;
  logic        UartCpuTxReady;
  logic        UartTxBusy;
  logic        UartTxIdle;
  logic        UartRxOverflowSet;
  logic        InstDmaRxValid;
  logic [7:0]  InstDmaRxData;
  logic        InstDmaRxReady;
  logic        InstDmaTxValid;
  logic [7:0]  InstDmaTxData;
  logic        InstDmaTxReady;
  logic        InstDmaCtrlArm;
  logic        InstDmaCtrlClearErr;
  logic        InstDmaBusy;
  logic        InstDmaDone;
  logic        InstDmaErr;
  logic        InstDmaAppValid;
  logic [7:0]  InstDmaErrCode;
  logic [31:0] InstDmaLoadAddr;
  logic [31:0] InstDmaByteCnt;
  logic [31:0] InstDmaEntryAddr;
  logic [31:0] InstDmaExpectedChecksum;
  logic [31:0] InstDmaActualChecksum;
  logic [31:0] InstDmaWordsWritten;
  logic        GpioIrq;
  logic        I2cEventIrq;
  logic        I2cErrIrq;
  logic        SpiEventIrq;
  logic        SpiErrIrq;
  logic [LP_INTC_NUM_SOURCES-1:0] IntcIrqVec;
  logic        ExtIrqPending;
  logic        TimerIrqPending;
  logic        IntcVectorValid;
  logic [31:0] IntcVectorPc;
  logic [31:0] IntcSelSrcId;
  logic        I2cSclOut;
  logic        I2cSclOe;
  logic        I2cSdaIn;
  logic        I2cSdaOut;
  logic        I2cSdaOe;

  assign ioI2cScl = I2cSclOe ? 1'b0 : 1'bz;
  assign ioI2cSda = I2cSdaOe ? 1'b0 : 1'bz;
  assign I2cSdaIn = ioI2cSda;
  assign SysRstAssert = iRst || !SysClkLocked;

  SysClockDivider #(
    .P_DIVIDE(P_SYS_CLK_DIVIDE)
  ) uSysClockDivider (
    .iClk    (iClk),
    .iRst   (iRst),
    .oClk    (SysClk),
    .oLocked (SysClkLocked)
  );

  always_ff @(posedge SysClk or posedge SysRstAssert) begin
    if (SysRstAssert) begin
      SysRstMeta <= 1'b1;
      SysRst     <= 1'b1;
    end else begin
      SysRstMeta <= 1'b0;
      SysRst     <= SysRstMeta;
    end
  end

  Rv32iCore uRv32iCore (
    .iClk          (SysClk),
    .iRst         (SysRst),
    .iInstrBusRsp  (InstrBusRsp),
    .iDataBusRsp   (DataBusRsp),
    .iExtIrqPending(ExtIrqPending),
    .iTimerIrqPending(TimerIrqPending),
    .iIntcVectorValid(IntcVectorValid),
    .iIntcVectorPc (IntcVectorPc),
    .oInstrBusReq  (InstrBusReq),
    .oDataBusReq   (DataBusReq),
    .oTimingProbe  (oTimingProbe)
  );

  InstrFetchMemory #(
    .P_BOOT_ADDR_WIDTH    (P_BOOT_ADDR_WIDTH),
    .P_BOOT_DEPTH_WORDS   (P_BOOT_DEPTH_WORDS),
    .P_BOOT_INIT_FILE     (P_BOOT_INIT_FILE),
    .P_PROGRAM_ADDR_WIDTH (P_PROGRAM_ADDR_WIDTH),
    .P_PROGRAM_DEPTH_WORDS(P_PROGRAM_DEPTH_WORDS),
    .P_PROGRAM_INIT_FILE  (P_PROGRAM_INIT_FILE),
    .P_PROGRAM_READ_ONLY_INIT(P_PROGRAM_READ_ONLY_INIT),
    .P_INSTR_MEM_IMPL     (P_INSTR_MEM_IMPL),
    .P_INSTR_MEM_LATENCY  (P_INSTR_MEM_LATENCY),
    .P_PREFETCH_DEPTH     (P_PREFETCH_DEPTH)
  ) uInstrFetchMemory (
    .iClk                (SysClk),
    .iRst                (SysRst),
    .iInstrBusReq        (InstrBusReq),
    .iInstDmaWrEn        (ProgramInstDmaWrEn),
    .iInstDmaAddr        (ProgramInstDmaAddr),
    .iInstDmaWdata       (ProgramInstDmaWdata),
    .iInstDmaWstrb       (ProgramInstDmaWstrb),
    .oInstrBusRsp        (InstrBusRsp),
    .oInstDmaRdData      (ProgramInstDmaRdWord),
    .oPrefetchHitPulse   (InstrPrefetchHitPulse),
    .oPrefetchEmptyPulse (InstrPrefetchEmptyPulse),
    .oDiscardPulse       (InstrPrefetchDiscardPulse)
  );

  DataBusInterconnect uDataBusInterconnect (
    .iReq     (DataBusReq),
    .iRamRdata(RamRdWord),
    .iApbRdata(ApbPrdata),
    .iApbReady(ApbRspReady),
    .iApbErr  (ApbPslverr),
    .oRamSel  (RamSel),
    .oRamWrEn (RamWrEn),
    .oApbSel  (ApbSel),
    .oApbWr(ApbWr),
    .oAddr    (BusAddr),
    .oByteEn  (BusByteEn),
    .oWdata   (BusWdata),
    .oRsp     (DataBusRsp)
  );

  DataRam #(
    .P_ADDR_WIDTH (P_DATA_ADDR_WIDTH)
  ) uDataRam (
    .iClk    (SysClk),
    .iWrEn   (RamWrEn),
    .iByteEn (BusByteEn),
    .iAddr   (BusAddr),
    .iWrData (BusWdata),
    .oRdWord (RamRdWord)
  );

  DataBusAxiLiteMaster uDataBusAxiLiteMaster (
    .iClk        (SysClk),
    .iRst       (SysRst),
    .iReqValid   (ApbSel),
    .iReqWr   (ApbWr),
    .iReqAddr    (BusAddr),
    .iReqByteEn  (BusByteEn),
    .iReqWdata   (BusWdata),
    .iAxiAwready (AxiAwready),
    .iAxiWready  (AxiWready),
    .iAxiBvalid  (AxiBvalid),
    .iAxiBresp   (AxiBresp),
    .iAxiArready (AxiArready),
    .iAxiRvalid  (AxiRvalid),
    .iAxiRdata   (AxiRdata),
    .iAxiRresp   (AxiRresp),
    .oRspReady   (ApbRspReady),
    .oRspRdata   (ApbPrdata),
    .oRspErr     (ApbPslverr),
    .oAxiAwaddr  (AxiAwaddr),
    .oAxiAwprot  (AxiAwprot),
    .oAxiAwvalid (AxiAwvalid),
    .oAxiWdata   (AxiWdata),
    .oAxiWstrb   (AxiWstrb),
    .oAxiWvalid  (AxiWvalid),
    .oAxiBready  (AxiBready),
    .oAxiAraddr  (AxiAraddr),
    .oAxiArprot  (AxiArprot),
    .oAxiArvalid (AxiArvalid),
    .oAxiRready  (AxiRready)
  );

  AxiLiteToApbBridge uAxiLiteToApbBridge (
    .iClk         (SysClk),
    .iRst        (SysRst),
    .iAxiAwaddr   (AxiAwaddr),
    .iAxiAwprot   (AxiAwprot),
    .iAxiAwvalid  (AxiAwvalid),
    .iAxiWdata    (AxiWdata),
    .iAxiWstrb    (AxiWstrb),
    .iAxiWvalid   (AxiWvalid),
    .iAxiBready   (AxiBready),
    .iAxiAraddr   (AxiAraddr),
    .iAxiArprot   (AxiArprot),
    .iAxiArvalid  (AxiArvalid),
    .iAxiRready   (AxiRready),
    .iUartPrdata  (UartPrdata),
    .iGpioPrdata  (GpioPrdata),
    .iI2cPrdata   (I2cPrdata),
    .iIntcPrdata  (IntcPrdata),
    .iSpiPrdata   (SpiPrdata),
    .iFndPrdata   (FndPrdata),
    .iTimerPrdata (TimerPrdata),
    .iInstDmaPrdata(InstDmaRegsPrdata),
    .iUartPready  (UartPready),
    .iGpioPready  (GpioPready),
    .iI2cPready   (I2cPready),
    .iIntcPready  (IntcPready),
    .iSpiPready   (SpiPready),
    .iFndPready   (FndPready),
    .iTimerPready (TimerPready),
    .iInstDmaPready(InstDmaRegsPready),
    .iUartPslverr (UartPslverr),
    .iGpioPslverr (GpioPslverr),
    .iI2cPslverr  (I2cPslverr),
    .iIntcPslverr (IntcPslverr),
    .iSpiPslverr  (SpiPslverr),
    .iFndPslverr  (FndPslverr),
    .iTimerPslverr(TimerPslverr),
    .iInstDmaPslverr(InstDmaRegsPslverr),
    .oAxiAwready  (AxiAwready),
    .oAxiWready   (AxiWready),
    .oAxiBvalid   (AxiBvalid),
    .oAxiBresp    (AxiBresp),
    .oAxiArready  (AxiArready),
    .oAxiRvalid   (AxiRvalid),
    .oAxiRdata    (AxiRdata),
    .oAxiRresp    (AxiRresp),
    .oPwrite      (ApbPwrite),
    .oPaddr       (ApbPaddr),
    .oPstrb       (ApbPstrb),
    .oPwdata      (ApbPwdata),
    .oPenable     (ApbPenable),
    .oUartPsel    (UartPsel),
    .oGpioPsel    (GpioPsel),
    .oI2cPsel     (I2cPsel),
    .oIntcPsel    (IntcPsel),
    .oSpiPsel     (SpiPsel),
    .oFndPsel     (FndPsel),
    .oTimerPsel   (TimerPsel),
    .oInstDmaPsel (InstDmaRegsPsel)
  );

  UartSubsystem #(
    .P_CLK_HZ(LP_SYS_CLK_HZ),
    .P_BAUD(P_UART_BAUD)
  ) uUartSubsystem (
    .iClk(SysClk),
    .iRst(SysRst),
    .iUartRx(iUartRx),
    .iMode(UartMode),
    .iRxFlushReq(UartRxFlushReq),
    .iCpuRxEn(UartCpuRxEn),
    .iCpuTxEn(UartCpuTxEn),
    .iCpuPop(UartCpuPop),
    .iCpuTxValid(UartCpuTxValid),
    .iCpuTxData(UartCpuTxData),
    .iDmaReady(InstDmaRxReady),
    .iDmaTxValid(InstDmaTxValid),
    .iDmaTxData(InstDmaTxData),
    .oUartTx(oUartTx),
    .oCpuValid(UartCpuRxValid),
    .oCpuData(UartCpuRxData),
    .oCpuTxReady(UartCpuTxReady),
    .oDmaValid(InstDmaRxValid),
    .oDmaData(InstDmaRxData),
    .oDmaTxReady(InstDmaTxReady),
    .oTxBusy(UartTxBusy),
    .oTxIdle(UartTxIdle),
    .oRxOverflowSet(UartRxOverflowSet)
  );

  InstDma uInstDma (
    .iClk(SysClk),
    .iRst(SysRst),
    .iRxValid(InstDmaRxValid),
    .iRxData(InstDmaRxData),
    .iTxReady(InstDmaTxReady),
    .iCtrlArm(InstDmaCtrlArm),
    .iCtrlClearErr(InstDmaCtrlClearErr),
    .oRxReady(InstDmaRxReady),
    .oTxValid(InstDmaTxValid),
    .oTxData(InstDmaTxData),
    .oStatusBusy(InstDmaBusy),
    .oStatusDone(InstDmaDone),
    .oStatusErr(InstDmaErr),
    .oStatusAppValid(InstDmaAppValid),
    .oErrCode(InstDmaErrCode),
    .oLoadAddr(InstDmaLoadAddr),
    .oByteCnt(InstDmaByteCnt),
    .oEntryAddr(InstDmaEntryAddr),
    .oExpectedChecksum(InstDmaExpectedChecksum),
    .oActualChecksum(InstDmaActualChecksum),
    .oWordsWritten(InstDmaWordsWritten),
    .oPramWrEn(ProgramInstDmaWrEn),
    .oPramAddr(ProgramInstDmaAddr),
    .oPramWdata(ProgramInstDmaWdata),
    .oPramWstrb(ProgramInstDmaWstrb)
  );

  InstDmaRegs #(
    .P_UART_RESET_CPU_MODE(P_UART_RESET_CPU_MODE)
  ) uInstDmaRegs (
    .iClk(SysClk),
    .iRst(SysRst),
    .iPsel(InstDmaRegsPsel),
    .iPenable(ApbPenable),
    .iPwrite(ApbPwrite),
    .iPaddr(ApbPaddr),
    .iPstrb(ApbPstrb),
    .iPwdata(ApbPwdata),
    .iStatusBusy(InstDmaBusy),
    .iStatusDone(InstDmaDone),
    .iStatusErr(InstDmaErr),
    .iStatusAppValid(InstDmaAppValid),
    .iErrCode(InstDmaErrCode),
    .iLoadAddr(InstDmaLoadAddr),
    .iByteCnt(InstDmaByteCnt),
    .iEntryAddr(InstDmaEntryAddr),
    .iExpectedChecksum(InstDmaExpectedChecksum),
    .iActualChecksum(InstDmaActualChecksum),
    .iWordsWritten(InstDmaWordsWritten),
    .iUartTxIdle(UartTxIdle),
    .oPrdata(InstDmaRegsPrdata),
    .oPready(InstDmaRegsPready),
    .oPslverr(InstDmaRegsPslverr),
    .oCtrlArm(InstDmaCtrlArm),
    .oCtrlClearErr(InstDmaCtrlClearErr),
    .oUartMode(UartMode),
    .oUartRxFlushReq(UartRxFlushReq)
  );

  APB_UART #(
    .P_CLK_HZ(LP_SYS_CLK_HZ),
    .P_BAUD(P_UART_BAUD)
  ) uAPB_UART (
    .iClk(SysClk),
    .iRst(SysRst),
    .iPsel(UartPsel),
    .iPenable(ApbPenable),
    .iPwrite(ApbPwrite),
    .iPaddr(ApbPaddr),
    .iPstrb(ApbPstrb),
    .iPwdata(ApbPwdata),
    .iCpuRxValid(UartCpuRxValid),
    .iCpuRxData(UartCpuRxData),
    .iCpuTxReady(UartCpuTxReady),
    .iUartTxBusy(UartTxBusy),
    .iRxOverflowSet(UartRxOverflowSet),
    .oPrdata(UartPrdata),
    .oPready(UartPready),
    .oPslverr(UartPslverr),
    .oCpuPop(UartCpuPop),
    .oCpuTxValid(UartCpuTxValid),
    .oCpuTxData(UartCpuTxData),
    .oRxEn(UartCpuRxEn),
    .oTxEn(UartCpuTxEn),
    .oIrq(UartIrq)
  );

  APB_GPIO #(
    .P_GPIO_WIDTH (P_GPIO_WIDTH)
  ) uAPB_GPIO (
    .iClk    (SysClk),
    .iRst   (SysRst),
    .iPsel   (GpioPsel),
    .iPenable(ApbPenable),
    .iPwrite (ApbPwrite),
    .iPaddr  (ApbPaddr),
    .iPstrb  (ApbPstrb),
    .iPwdata (ApbPwdata),
    .iGpioIn (iGpioIn),
    .oPrdata (GpioPrdata),
    .oPready (GpioPready),
    .oPslverr(GpioPslverr),
    .oGpioOut(oGpioOut),
    .oGpioOe (oGpioOe),
    .oIrq    (GpioIrq)
  );

  APB_I2C uAPB_I2C (
    .iClk     (SysClk),
    .iRst    (SysRst),
    .iPsel    (I2cPsel),
    .iPenable (ApbPenable),
    .iPwrite  (ApbPwrite),
    .iPaddr   (ApbPaddr),
    .iPstrb   (ApbPstrb),
    .iPwdata  (ApbPwdata),
    .iSdaIn   (I2cSdaIn),
    .oPrdata  (I2cPrdata),
    .oPready  (I2cPready),
    .oPslverr (I2cPslverr),
    .oScl     (I2cSclOut),
    .oSclOe   (I2cSclOe),
    .oSdaOut  (I2cSdaOut),
    .oSdaOe   (I2cSdaOe),
    .oEventIrq(I2cEventIrq),
    .oErrIrq(I2cErrIrq)
  );

  APB_SPI uAPB_SPI (
    .iClk     (SysClk),
    .iRst    (SysRst),
    .iPsel    (SpiPsel),
    .iPenable (ApbPenable),
    .iPwrite  (ApbPwrite),
    .iPaddr   (ApbPaddr),
    .iPstrb   (ApbPstrb),
    .iPwdata  (ApbPwdata),
    .iMiso    (iSpiMiso),
    .oPrdata  (SpiPrdata),
    .oPready  (SpiPready),
    .oPslverr (SpiPslverr),
    .oSclk    (oSpiSclk),
    .oMosi    (oSpiMosi),
    .oCsN     (oSpiCsN),
    .oEventIrq(SpiEventIrq),
    .oErrIrq(SpiErrIrq)
  );

  APB_FND #(
    .P_CLK_HZ (LP_SYS_CLK_HZ)
  ) uAPB_FND (
    .iClk     (SysClk),
    .iRst    (SysRst),
    .iPsel    (FndPsel),
    .iPenable (ApbPenable),
    .iPwrite  (ApbPwrite),
    .iPaddr   (ApbPaddr),
    .iPstrb   (ApbPstrb),
    .iPwdata  (ApbPwdata),
    .oPrdata  (FndPrdata),
    .oPready  (FndPready),
    .oPslverr (FndPslverr),
    .oSeg     (oSeg),
    .oDp      (oDp),
    .oDigitSel(oDigitSel)
  );

  APB_Timer #(
    .P_CLK_HZ (LP_SYS_CLK_HZ)
  ) uAPB_Timer (
    .iClk              (SysClk),
    .iRst             (SysRst),
    .iPsel             (TimerPsel),
    .iPenable          (ApbPenable),
    .iPwrite           (ApbPwrite),
    .iPaddr            (ApbPaddr),
    .iPstrb            (ApbPstrb),
    .iPwdata           (ApbPwdata),
    .oPrdata           (TimerPrdata),
    .oPready           (TimerPready),
    .oPslverr          (TimerPslverr),
    .oTimerIrqPending  (TimerIrqPending)
  );

  always_comb begin
    IntcIrqVec = '0;
    IntcIrqVec[LP_INTC_SRC_GPIO-1]      = GpioIrq;
    IntcIrqVec[LP_INTC_SRC_UART_RX-1]   = UartIrq;
    IntcIrqVec[LP_INTC_SRC_I2C_EVENT-1] = I2cEventIrq;
    IntcIrqVec[LP_INTC_SRC_I2C_ERROR-1] = I2cErrIrq;
    IntcIrqVec[LP_INTC_SRC_SPI_EVENT-1] = SpiEventIrq;
    IntcIrqVec[LP_INTC_SRC_SPI_ERROR-1] = SpiErrIrq;
  end

  InterruptController #(
    .P_NUM_SOURCES    (LP_INTC_NUM_SOURCES),
    .P_PRIORITY_WIDTH (LP_INTC_PRIORITY_WIDTH)
  ) uInterruptController (
    .iClk          (SysClk),
    .iRst         (SysRst),
    .iPsel         (IntcPsel),
    .iPenable      (ApbPenable),
    .iPwrite       (ApbPwrite),
    .iPaddr        (ApbPaddr),
    .iPstrb        (ApbPstrb),
    .iPwdata       (ApbPwdata),
    .iIrqVec       (IntcIrqVec),
    .oPrdata       (IntcPrdata),
    .oPready       (IntcPready),
    .oPslverr      (IntcPslverr),
    .oVectorValid  (IntcVectorValid),
    .oVectorPc     (IntcVectorPc),
    .oSelSrcId(IntcSelSrcId),
    .oMachineExtIrq(ExtIrqPending)
  );

endmodule
