/*
[MODULE_INFO_START]
Name: TOP
Role: Top-level wrapper for the RV32I 5-stage pipeline CPU
Summary:
  - Integrates Fetch/Decode/Execute/Memory/WriteBack with a native data bus, separate APB bridge, and machine-mode CSR block
  - Routes synchronous traps and machine external interrupts through TrapController and PipeFlowCtrl without the legacy halt wrapper
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TOP #(
  parameter int unsigned P_CLK_HZ     = 100_000_000,
  parameter int unsigned P_UART_BAUD  = 115_200,
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

  import rv32i_pkg::*;

  logic [31:0] Pc;
  logic        PcWe;
  logic        PcWeCore;
  logic        TrapRedirectValid;
  logic        TrapRedirectValidCore;
  logic [31:0] TrapRedirectPc;

  IFID_t IFID;
  IFID_t IFIDNext;
  logic  IFIDFlush;
  logic  IFIDFlushCore;
  logic  IFIDHold;
  logic  IFIDHoldCore;

  IDEX_t IDEX;
  IDEX_t IDEXNext;
  logic  IDEXHold;
  logic  IDEXFlush;
  logic  IDEXFlushCore;

  EXMEM_t EXMEM;
  EXMEM_t EXMEMNext;
  logic   EXMEMHold;
  logic   EXMEMFlush;
  logic   EXMEMFlushCore;

  MEMWB_t MEMWB;
  MEMWB_t MEMWBNext;

  logic        IdTrapValid;
  logic        IdTrapValidCtrl;
  logic        LoadUseStall;
  logic        IdRedirectValid;
  logic        IdRedirectValidCtrl;
  logic [31:0] IdRedirectPc;
  TrapCauseE   IdTrapCause;

  logic [31:0] ExRedirectPc;
  logic        ExRedirectValid;
  logic        ExRedirectValidCtrl;
  TrapCauseE   ExTrapCause;
  logic        ExTrapValid;
  logic        ExTrapValidCtrl;

  TrapCauseE   MemTrapCause;
  logic        MemTrapValid;

  logic        FetchValid;
  logic        FetchValidCore;
  logic        RetireValid;
  logic [31:0] RetirePc;
  logic [4:0]  RetireRdAddr;
  logic [31:0] RetireWrData;
  logic        RetireRegWrite;
  logic        PipelineEmpty;
  logic        WbWriteEn;
  logic [31:0] WbWriteData;
  logic        ExWbWriteEn;
  logic [4:0]  ExWbRdAddr;
  logic [31:0] ExWbWriteData;
  logic        ExWbFwdEn;
  logic [4:0]  ExWbFwdRdAddr;
  logic [31:0] ExWbFwdWriteData;

  DataBusReq_t DataBusReq;
  DataBusRsp_t DataBusRsp;
  logic        RamSel;
  logic        RamWrEn;
  logic        ApbSel;
  logic        ApbWrite;
  logic        ApbPwrite;
  logic        ApbPenable;
  logic [31:0] BusAddr;
  logic [3:0]  BusByteEn;
  logic [31:0] BusWdata;
  logic [31:0] RamRdWord;
  logic [31:0] ApbPrdata;
  logic        ApbRspReady;
  logic        ApbPslverr;
  logic [11:0] ApbPaddr;
  logic [3:0]  ApbPstrb;
  logic [31:0] ApbPwdata;
  logic        UartPsel;
  logic        GpioPsel;
  logic        FndPsel;
  logic        IntcPsel;
  logic [31:0] UartPrdata;
  logic [31:0] GpioPrdata;
  logic [31:0] FndPrdata;
  logic [31:0] IntcPrdata;
  logic        UartPready;
  logic        GpioPready;
  logic        FndPready;
  logic        IntcPready;
  logic        UartPslverr;
  logic        GpioPslverr;
  logic        FndPslverr;
  logic        IntcPslverr;
  logic        MemApbStall;

  logic [31:0] CsrRdata;
  logic [31:0] Mtvec;
  logic [31:0] Mepc;
  logic        MstatusMie;
  logic        MstatusMpie;
  logic        MieMeie;
  logic        MipMeip;
  logic        ExCsrWriteEn;
  logic [11:0] ExCsrAddr;
  logic [31:0] ExCsrWdata;
  logic        ExMretValid;
  logic        ExMretValidCtrl;
  logic        TrapEnterValid;
  logic        TrapEnterValidCore;
  logic [31:0] TrapEnterEpc;
  logic [31:0] TrapEnterCause;
  logic        TrapFromEx;
  logic        TrapFromMem;
  logic        InterruptAccepted;
  logic        InterruptAcceptedCore;
  logic        ExtIrqPending;

  logic        UartIrq;
  logic        GpioIrq;

  (* DONT_TOUCH = "TRUE", KEEP = "TRUE" *) logic TimingSinkReg;

  FetchStage uFetchStage (
    .iClk               (iClk),
    .iRstn              (iRstn),
    .iPcWe              (PcWe),
    .iFetchValid        (FetchValid),
    .iTrapRedirectValid (TrapRedirectValid),
    .iTrapRedirectPc    (TrapRedirectPc),
    .iIdRedirectValid   (IdRedirectValidCtrl),
    .iIdRedirectPc      (IdRedirectPc),
    .iExRedirectValid   (ExRedirectValidCtrl),
    .iExRedirectPc      (ExRedirectPc),
    .oPc                (Pc),
    .oIFIDData          (IFIDNext)
  );

  IfIdReg uIfIdReg (
    .iClk   (iClk),
    .iRstn  (iRstn),
    .iFlush (IFIDFlush),
    .iHold  (IFIDHold),
    .iData  (IFIDNext),
    .oData  (IFID)
  );

  DecodeStage uDecodeStage (
    .iClk          (iClk),
    .iRstn         (iRstn),
    .iIFID         (IFID),
    .iIDEX         (IDEX),
    .iWbWriteEn    (WbWriteEn),
    .iWbRdAddr     (MEMWB.RdAddr),
    .iWbWriteData  (WbWriteData),
    .oLoadUseStall (LoadUseStall),
    .oRedirectValid(IdRedirectValid),
    .oRedirectPc   (IdRedirectPc),
    .oTrapValid    (IdTrapValid),
    .oTrapCause    (IdTrapCause),
    .oIDEXData     (IDEXNext)
  );

  IdExReg uIdExReg (
    .iClk   (iClk),
    .iRstn  (iRstn),
    .iFlush (IDEXFlush),
    .iHold  (IDEXHold),
    .iData  (IDEXNext),
    .oData  (IDEX)
  );

  ExecuteStage uExecuteStage (
    .iIDEX        (IDEX),
    .iEXMEM       (EXMEM),
    .iWbWriteEn   (ExWbFwdEn),
    .iWbRdAddr    (ExWbFwdRdAddr),
    .iWbWriteData (ExWbFwdWriteData),
    .iCsrRdata    (CsrRdata),
    .iMepc        (Mepc),
    .oRedirectValid(ExRedirectValid),
    .oRedirectPc  (ExRedirectPc),
    .oTrapValid   (ExTrapValid),
    .oTrapCause   (ExTrapCause),
    .oCsrWriteEn  (ExCsrWriteEn),
    .oCsrAddr     (ExCsrAddr),
    .oCsrWdata    (ExCsrWdata),
    .oMretValid   (ExMretValid),
    .oEXMEMData   (EXMEMNext)
  );

  ExMemReg uExMemReg (
    .iClk   (iClk),
    .iRstn  (iRstn),
    .iFlush (EXMEMFlush),
    .iHold  (EXMEMHold),
    .iData  (EXMEMNext),
    .oData  (EXMEM)
  );

  MemoryStage uMemoryStage (
    .iEXMEM     (EXMEM),
    .iDataBusRsp(DataBusRsp),
    .oDataBusReq(DataBusReq),
    .oTrapValid (MemTrapValid),
    .oTrapCause (MemTrapCause),
    .oMEMWBData (MEMWBNext)
  );

  MemWbReg uMemWbReg (
    .iClk  (iClk),
    .iRstn (iRstn),
    .iData (MEMWBNext),
    .oData (MEMWB)
  );

  WriteBackStage uWriteBackStage (
    .iMEMWB          (MEMWB),
    .oWbWriteData    (WbWriteData),
    .oWbWriteEn      (WbWriteEn),
    .oRetireValid    (RetireValid),
    .oRetirePc       (RetirePc),
    .oRetireRdAddr   (RetireRdAddr),
    .oRetireWrData   (RetireWrData),
    .oRetireRegWrite (RetireRegWrite)
  );

  TrapController uTrapController (
    .iIFID              (IFID),
    .iIDEX              (IDEX),
    .iEXMEM             (EXMEM),
    .iExRedirectValid   (ExRedirectValidCtrl),
    .iIdTrapValid       (IdTrapValidCtrl),
    .iIdTrapCause       (IdTrapCause),
    .iExTrapValid       (ExTrapValidCtrl),
    .iExTrapCause       (ExTrapCause),
    .iMemTrapValid      (MemTrapValid),
    .iMemTrapCause      (MemTrapCause),
    .iMstatusMie        (MstatusMie),
    .iMieMeie           (MieMeie),
    .iMipMeip           (MipMeip),
    .iMtvec             (Mtvec),
    .oTrapCaptureValid  (TrapEnterValidCore),
    .oTrapEnterEpc      (TrapEnterEpc),
    .oTrapEnterCause    (TrapEnterCause),
    .oTrapFromEx        (TrapFromEx),
    .oTrapFromMem       (TrapFromMem),
    .oTrapRedirectValid (TrapRedirectValidCore),
    .oTrapRedirectPc    (TrapRedirectPc),
    .oInterruptAccepted (InterruptAcceptedCore)
  );

  PipeFlowCtrl uPipeFlowCtrl (
    .iLoadUseStall     (LoadUseStall),
    .iTrapCaptureValid (TrapEnterValid),
    .iTrapFromEx       (TrapFromEx),
    .iTrapFromMem      (TrapFromMem),
    .iIdRedirectValid  (IdRedirectValidCtrl),
    .iExRedirectValid  (ExRedirectValidCtrl),
    .iIFIDValid        (IFID.Valid),
    .iIDEXValid        (IDEX.Valid),
    .iEXMEMValid       (EXMEM.Valid),
    .iMEMWBValid       (MEMWB.Valid),
    .oPcAdvance        (),
    .oFrontFlush       (),
    .oIdexFlushReq     (),
    .oPcWe             (PcWeCore),
    .oIFIDHold         (IFIDHoldCore),
    .oIFIDFlush        (IFIDFlushCore),
    .oIDEXFlush        (IDEXFlushCore),
    .oEXMEMFlush       (EXMEMFlushCore),
    .oFetchValid       (FetchValidCore),
    .oPipelineEmpty    (PipelineEmpty)
  );

  assign MemApbStall       = DataBusReq.ReqValid && !DataBusRsp.RspReady;
  assign TrapEnterValid    = TrapEnterValidCore && !MemApbStall;
  assign TrapRedirectValid = TrapRedirectValidCore && !MemApbStall;
  assign InterruptAccepted = InterruptAcceptedCore && !MemApbStall;
  assign IdTrapValidCtrl   = IdTrapValid && !MemApbStall;
  assign ExTrapValidCtrl   = ExTrapValid && !MemApbStall;
  assign IdRedirectValidCtrl = IdRedirectValid && !MemApbStall;
  assign ExRedirectValidCtrl = ExRedirectValid && !MemApbStall;
  assign PcWe             = PcWeCore && !MemApbStall;
  assign IFIDHold         = IFIDHoldCore || MemApbStall;
  assign IFIDFlush        = IFIDFlushCore && !MemApbStall;
  assign IDEXHold         = MemApbStall;
  assign IDEXFlush        = IDEXFlushCore && !MemApbStall;
  assign EXMEMHold        = MemApbStall;
  assign EXMEMFlush       = EXMEMFlushCore && !MemApbStall;
  assign FetchValid       = FetchValidCore && !MemApbStall;
  assign ExMretValidCtrl  = ExMretValid && !MemApbStall;
  assign ExWbFwdEn        = WbWriteEn || ExWbWriteEn;
  assign ExWbFwdRdAddr    = WbWriteEn ? MEMWB.RdAddr : ExWbRdAddr;
  assign ExWbFwdWriteData = WbWriteEn ? WbWriteData : ExWbWriteData;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      ExWbWriteEn   <= 1'b0;
      ExWbRdAddr    <= '0;
      ExWbWriteData <= '0;
    end else if (WbWriteEn) begin
      ExWbWriteEn   <= 1'b1;
      ExWbRdAddr    <= MEMWB.RdAddr;
      ExWbWriteData <= WbWriteData;
    end
  end

  CsrFile uCsrFile (
    .iClk           (iClk),
    .iRstn          (iRstn),
    .iCsrAddr       (IDEX.CsrAddr),
    .iCsrWriteEn    (ExCsrWriteEn && !MemTrapValid && !MemApbStall),
    .iCsrWriteAddr  (ExCsrAddr),
    .iCsrWriteData  (ExCsrWdata),
    .iMretValid     (ExMretValidCtrl && !MemTrapValid),
    .iTrapEnterValid(TrapEnterValid),
    .iTrapEnterEpc  (TrapEnterEpc),
    .iTrapEnterCause(TrapEnterCause),
    .iExtIrqPending (ExtIrqPending),
    .oCsrRdata      (CsrRdata),
    .oMtvec         (Mtvec),
    .oMepc          (Mepc),
    .oMstatusMie    (MstatusMie),
    .oMstatusMpie   (MstatusMpie),
    .oMieMeie       (MieMeie),
    .oMipMeip       (MipMeip)
  );

  DataBusMaster uDataBusMaster (
    .iReq     (DataBusReq),
    .iRamRdata(RamRdWord),
    .iApbRdata(ApbPrdata),
    .iApbReady(ApbRspReady),
    .iApbErr  (ApbPslverr),
    .oRamSel  (RamSel),
    .oRamWrEn (RamWrEn),
    .oApbSel  (ApbSel),
    .oApbWrite(ApbWrite),
    .oAddr    (BusAddr),
    .oByteEn  (BusByteEn),
    .oWdata   (BusWdata),
    .oRsp     (DataBusRsp)
  );

  DataRam uDataRam (
    .iClk    (iClk),
    .iWrEn   (RamWrEn),
    .iByteEn (BusByteEn),
    .iAddr   (BusAddr),
    .iWrData (BusWdata),
    .oRdWord (RamRdWord)
  );

  APBMASTER uAPBMASTER (
    .iClk         (iClk),
    .iRstn        (iRstn),
    .iApbSel      (ApbSel),
    .iPwrite      (ApbWrite),
    .iPaddr       (BusAddr),
    .iPstrb       (BusByteEn),
    .iPwdata      (BusWdata),
    .iUartPrdata  (UartPrdata),
    .iGpioPrdata  (GpioPrdata),
    .iFndPrdata   (FndPrdata),
    .iIntcPrdata  (IntcPrdata),
    .iUartPready  (UartPready),
    .iGpioPready  (GpioPready),
    .iFndPready   (FndPready),
    .iIntcPready  (IntcPready),
    .iUartPslverr (UartPslverr),
    .iGpioPslverr (GpioPslverr),
    .iFndPslverr  (FndPslverr),
    .iIntcPslverr (IntcPslverr),
    .oPwrite      (ApbPwrite),
    .oPaddr       (ApbPaddr),
    .oPstrb       (ApbPstrb),
    .oPwdata      (ApbPwdata),
    .oPenable     (ApbPenable),
    .oUartPsel    (UartPsel),
    .oGpioPsel    (GpioPsel),
    .oFndPsel     (FndPsel),
    .oIntcPsel    (IntcPsel),
    .oRspReady    (ApbRspReady),
    .oPrdata      (ApbPrdata),
    .oPslverr     (ApbPslverr)
  );

  APB_UART #(
    .P_CLK_HZ (P_CLK_HZ),
    .P_BAUD   (P_UART_BAUD)
  ) uAPB_UART (
    .iClk    (iClk),
    .iRstn   (iRstn),
    .iPsel   (UartPsel),
    .iPenable(ApbPenable),
    .iPwrite (ApbPwrite),
    .iPaddr  (ApbPaddr),
    .iPstrb  (ApbPstrb),
    .iPwdata (ApbPwdata),
    .iUartRx (iUartRx),
    .oPrdata (UartPrdata),
    .oPready (UartPready),
    .oPslverr(UartPslverr),
    .oUartTx (oUartTx),
    .oIrq    (UartIrq)
  );

  APB_GPIO #(
    .P_GPIO_WIDTH (P_GPIO_WIDTH)
  ) uAPB_GPIO (
    .iClk    (iClk),
    .iRstn   (iRstn),
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

  APB_FND #(
    .P_CLK_HZ (P_CLK_HZ)
  ) uAPB_FND (
    .iClk     (iClk),
    .iRstn    (iRstn),
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

  InterruptController uInterruptController (
    .iClk          (iClk),
    .iRstn         (iRstn),
    .iPsel         (IntcPsel),
    .iPenable      (ApbPenable),
    .iPwrite       (ApbPwrite),
    .iPaddr        (ApbPaddr),
    .iPstrb        (ApbPstrb),
    .iPwdata       (ApbPwdata),
    .iUartIrq      (UartIrq),
    .iGpioIrq      (GpioIrq),
    .oPrdata       (IntcPrdata),
    .oPready       (IntcPready),
    .oPslverr      (IntcPslverr),
    .oMachineExtIrq(ExtIrqPending)
  );

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      TimingSinkReg <= 1'b0;
    end else begin
      TimingSinkReg <= ^{RetireValid, RetireRegWrite, RetireRdAddr, RetireWrData, RetirePc};
    end
  end

  assign oTimingProbe = TimingSinkReg;

endmodule
