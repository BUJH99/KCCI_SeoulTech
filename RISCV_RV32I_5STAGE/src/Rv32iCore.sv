/*
[MODULE_INFO_START]
Name: Rv32iCore
Role: RV32I 5-stage CPU core with external instruction and data bus interfaces
Summary:
  - Integrates Fetch/Decode/Execute/Memory/WriteBack with CSR, trap, forwarding, and pipeline-flow control
  - Exposes instruction and data bus requests so the enclosing SoC wrapper owns ROM, RAM, APB, and peripherals
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module Rv32iCore (
  input  logic                       iClk,
  input  logic                       iRst,
  input  rv32i_pkg::InstrBusRsp_t    iInstrBusRsp,
  input  rv32i_pkg::DataBusRsp_t     iDataBusRsp,
  input  logic                       iExtIrqPending,
  input  logic                       iTimerIrqPending,
  input  logic                       iIntcVectorValid,
  input  logic [31:0]                iIntcVectorPc,

  output rv32i_pkg::InstrBusReq_t    oInstrBusReq,
  output rv32i_pkg::DataBusReq_t     oDataBusReq,
  output logic                       oTimingProbe
);

  import rv32i_pkg::*;

  InstrBusReq_t InstrBusReq;
  InstrBusRsp_t InstrBusRsp;
  DataBusReq_t  DataBusReq;
  DataBusRsp_t  DataBusRsp;

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
  logic        FetchReqValid;
  logic        InstrFetchStall;
  logic        RetireValid;
  logic [31:0] RetirePc;
  logic [4:0]  RetireRdAddr;
  logic [31:0] RetireWrData;
  logic        RetireRegWr;
  logic        PipelineEmpty;
  logic        WbWrEn;
  logic [31:0] WbWrData;
  logic        ExWbWrEn;
  logic [4:0]  ExWbRdAddr;
  logic [31:0] ExWbWrData;
  logic        ExWbFwdEn;
  logic [4:0]  ExWbFwdRdAddr;
  logic [31:0] ExWbFwdWrData;

  logic        MemApbStall;

  logic [31:0] CsrRdata;
  logic [31:0] Mtvec;
  logic [31:0] Mepc;
  logic        MstatusMie;
  logic        MstatusMpie;
  logic        MieMeie;
  logic        MieMtie;
  logic        MipMeip;
  logic        MipMtip;
  logic        ExCsrWrEn;
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
  logic        TrapFromIrq;
  logic        IrqAccepted;
  logic        IrqAcceptedCore;

  (* DONT_TOUCH = "TRUE", KEEP = "TRUE" *) logic TimingSinkReg;

  assign InstrBusRsp  = iInstrBusRsp;
  assign DataBusRsp   = iDataBusRsp;
  assign oInstrBusReq = InstrBusReq;
  assign oDataBusReq  = DataBusReq;

  FetchStage uFetchStage (
    .iClk               (iClk),
    .iRst              (iRst),
    .iPcWe              (PcWe),
    .iFetchReqValid     (FetchReqValid),
    .iFetchValid        (FetchValid),
    .iTrapRedirectValid (TrapRedirectValid),
    .iTrapRedirectPc    (TrapRedirectPc),
    .iIdRedirectValid   (IdRedirectValidCtrl),
    .iIdRedirectPc      (IdRedirectPc),
    .iExRedirectValid   (ExRedirectValidCtrl),
    .iExRedirectPc      (ExRedirectPc),
    .iInstrBusRsp       (InstrBusRsp),
    .oInstrBusReq       (InstrBusReq),
    .oPc                (Pc),
    .oIFIDData          (IFIDNext)
  );

  IfIdReg uIfIdReg (
    .iClk   (iClk),
    .iRst  (iRst),
    .iFlush (IFIDFlush),
    .iHold  (IFIDHold),
    .iData  (IFIDNext),
    .oData  (IFID)
  );

  DecodeStage uDecodeStage (
    .iClk          (iClk),
    .iRst         (iRst),
    .iIFID         (IFID),
    .iIDEX         (IDEX),
    .iWbWrEn    (WbWrEn),
    .iWbRdAddr     (MEMWB.RdAddr),
    .iWbWrData  (WbWrData),
    .oLoadUseStall (LoadUseStall),
    .oRedirectValid(IdRedirectValid),
    .oRedirectPc   (IdRedirectPc),
    .oTrapValid    (IdTrapValid),
    .oTrapCause    (IdTrapCause),
    .oIDEXData     (IDEXNext)
  );

  IdExReg uIdExReg (
    .iClk   (iClk),
    .iRst  (iRst),
    .iFlush (IDEXFlush),
    .iHold  (IDEXHold),
    .iData  (IDEXNext),
    .oData  (IDEX)
  );

  ExecuteStage uExecuteStage (
    .iIDEX        (IDEX),
    .iEXMEM       (EXMEM),
    .iWbWrEn   (ExWbFwdEn),
    .iWbRdAddr    (ExWbFwdRdAddr),
    .iWbWrData (ExWbFwdWrData),
    .iCsrRdata    (CsrRdata),
    .iMepc        (Mepc),
    .oRedirectValid(ExRedirectValid),
    .oRedirectPc  (ExRedirectPc),
    .oTrapValid   (ExTrapValid),
    .oTrapCause   (ExTrapCause),
    .oCsrWrEn  (ExCsrWrEn),
    .oCsrAddr     (ExCsrAddr),
    .oCsrWdata    (ExCsrWdata),
    .oMretValid   (ExMretValid),
    .oEXMEMData   (EXMEMNext)
  );

  ExMemReg uExMemReg (
    .iClk   (iClk),
    .iRst  (iRst),
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
    .iRst (iRst),
    .iData (MEMWBNext),
    .oData (MEMWB)
  );

  WriteBackStage uWriteBackStage (
    .iMEMWB          (MEMWB),
    .oWbWrData    (WbWrData),
    .oWbWrEn      (WbWrEn),
    .oRetireValid    (RetireValid),
    .oRetirePc       (RetirePc),
    .oRetireRdAddr   (RetireRdAddr),
    .oRetireWrData   (RetireWrData),
    .oRetireRegWr (RetireRegWr)
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
    .iMieMtie           (MieMtie),
    .iMipMtip           (MipMtip),
    .iMtvec             (Mtvec),
    .iIntcVectorValid   (iIntcVectorValid),
    .iIntcVectorPc      (iIntcVectorPc),
    .oTrapCaptureValid  (TrapEnterValidCore),
    .oTrapEnterEpc      (TrapEnterEpc),
    .oTrapEnterCause    (TrapEnterCause),
    .oTrapFromEx        (TrapFromEx),
    .oTrapFromMem       (TrapFromMem),
    .oTrapFromIrq (TrapFromIrq),
    .oTrapRedirectValid (TrapRedirectValidCore),
    .oTrapRedirectPc    (TrapRedirectPc),
    .oIrqAccepted (IrqAcceptedCore)
  );

  PipeFlowCtrl uPipeFlowCtrl (
    .iLoadUseStall     (LoadUseStall),
    .iTrapCaptureValid (TrapEnterValid),
    .iTrapFromEx       (TrapFromEx),
    .iTrapFromMem      (TrapFromMem),
    .iTrapFromIrq(TrapFromIrq),
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

  assign MemApbStall         = DataBusReq.ReqValid && !DataBusRsp.RspReady;
  assign FetchReqValid       = FetchValidCore && !MemApbStall;
  assign InstrFetchStall     = FetchReqValid && !InstrBusRsp.RspReady;
  assign TrapEnterValid      = TrapEnterValidCore && !MemApbStall;
  assign TrapRedirectValid   = TrapRedirectValidCore && !MemApbStall;
  assign IrqAccepted   = IrqAcceptedCore && !MemApbStall;
  assign IdTrapValidCtrl     = IdTrapValid && !MemApbStall;
  assign ExTrapValidCtrl     = ExTrapValid && !MemApbStall;
  assign IdRedirectValidCtrl = IdRedirectValid && !MemApbStall;
  assign ExRedirectValidCtrl = ExRedirectValid && !MemApbStall;
  assign PcWe                = PcWeCore && !MemApbStall && !InstrFetchStall;
  assign IFIDHold            = IFIDHoldCore || MemApbStall;
  assign IFIDFlush           = IFIDFlushCore && !MemApbStall;
  assign IDEXHold            = MemApbStall;
  assign IDEXFlush           = IDEXFlushCore && !MemApbStall;
  assign EXMEMHold           = MemApbStall;
  assign EXMEMFlush          = EXMEMFlushCore && !MemApbStall;
  assign FetchValid          = FetchReqValid && !InstrFetchStall;
  assign ExMretValidCtrl     = ExMretValid && !MemApbStall;
  assign ExWbFwdEn           = WbWrEn || ExWbWrEn;
  assign ExWbFwdRdAddr       = WbWrEn ? MEMWB.RdAddr : ExWbRdAddr;
  assign ExWbFwdWrData    = WbWrEn ? WbWrData : ExWbWrData;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      ExWbWrEn   <= 1'b0;
      ExWbRdAddr    <= '0;
      ExWbWrData <= '0;
    end else if (WbWrEn) begin
      ExWbWrEn   <= 1'b1;
      ExWbRdAddr    <= MEMWB.RdAddr;
      ExWbWrData <= WbWrData;
    end
  end

  CsrFile uCsrFile (
    .iClk           (iClk),
    .iRst          (iRst),
    .iCsrAddr       (IDEX.CsrAddr),
    .iCsrWrEn    (ExCsrWrEn && !MemTrapValid && !MemApbStall),
    .iCsrWrAddr  (ExCsrAddr),
    .iCsrWrData  (ExCsrWdata),
    .iMretValid     (ExMretValidCtrl && !MemTrapValid),
    .iTrapEnterValid(TrapEnterValid),
    .iTrapEnterEpc  (TrapEnterEpc),
    .iTrapEnterCause(TrapEnterCause),
    .iExtIrqPending (iExtIrqPending),
    .iTimerIrqPending(iTimerIrqPending),
    .oCsrRdata      (CsrRdata),
    .oMtvec         (Mtvec),
    .oMepc          (Mepc),
    .oMstatusMie    (MstatusMie),
    .oMstatusMpie   (MstatusMpie),
    .oMieMeie       (MieMeie),
    .oMieMtie       (MieMtie),
    .oMipMeip       (MipMeip),
    .oMipMtip       (MipMtip)
  );

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      TimingSinkReg <= 1'b0;
    end else begin
      TimingSinkReg <= ^{RetireValid, RetireRegWr, RetireRdAddr, RetireWrData, RetirePc};
    end
  end

  assign oTimingProbe = TimingSinkReg;

endmodule
