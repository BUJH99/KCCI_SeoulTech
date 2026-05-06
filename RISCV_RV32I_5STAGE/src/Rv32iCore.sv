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
  input  logic                       iRstn,
  input  rv32i_pkg::InstrBusRsp_t    iInstrBusRsp,
  input  rv32i_pkg::DataBusRsp_t     iDataBusRsp,
  input  logic                       iExtIrqPending,
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
  logic        TrapFromInterrupt;
  logic        InterruptAccepted;
  logic        InterruptAcceptedCore;

  (* DONT_TOUCH = "TRUE", KEEP = "TRUE" *) logic TimingSinkReg;

  assign InstrBusRsp  = iInstrBusRsp;
  assign DataBusRsp   = iDataBusRsp;
  assign oInstrBusReq = InstrBusReq;
  assign oDataBusReq  = DataBusReq;

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
    .iInstrBusRsp       (InstrBusRsp),
    .oInstrBusReq       (InstrBusReq),
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
    .iIntcVectorValid   (iIntcVectorValid),
    .iIntcVectorPc      (iIntcVectorPc),
    .oTrapCaptureValid  (TrapEnterValidCore),
    .oTrapEnterEpc      (TrapEnterEpc),
    .oTrapEnterCause    (TrapEnterCause),
    .oTrapFromEx        (TrapFromEx),
    .oTrapFromMem       (TrapFromMem),
    .oTrapFromInterrupt (TrapFromInterrupt),
    .oTrapRedirectValid (TrapRedirectValidCore),
    .oTrapRedirectPc    (TrapRedirectPc),
    .oInterruptAccepted (InterruptAcceptedCore)
  );

  PipeFlowCtrl uPipeFlowCtrl (
    .iLoadUseStall     (LoadUseStall),
    .iTrapCaptureValid (TrapEnterValid),
    .iTrapFromEx       (TrapFromEx),
    .iTrapFromMem      (TrapFromMem),
    .iTrapFromInterrupt(TrapFromInterrupt),
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
  assign TrapEnterValid      = TrapEnterValidCore && !MemApbStall;
  assign TrapRedirectValid   = TrapRedirectValidCore && !MemApbStall;
  assign InterruptAccepted   = InterruptAcceptedCore && !MemApbStall;
  assign IdTrapValidCtrl     = IdTrapValid && !MemApbStall;
  assign ExTrapValidCtrl     = ExTrapValid && !MemApbStall;
  assign IdRedirectValidCtrl = IdRedirectValid && !MemApbStall;
  assign ExRedirectValidCtrl = ExRedirectValid && !MemApbStall;
  assign PcWe                = PcWeCore && !MemApbStall;
  assign IFIDHold            = IFIDHoldCore || MemApbStall;
  assign IFIDFlush           = IFIDFlushCore && !MemApbStall;
  assign IDEXHold            = MemApbStall;
  assign IDEXFlush           = IDEXFlushCore && !MemApbStall;
  assign EXMEMHold           = MemApbStall;
  assign EXMEMFlush          = EXMEMFlushCore && !MemApbStall;
  assign FetchValid          = FetchValidCore && !MemApbStall;
  assign ExMretValidCtrl     = ExMretValid && !MemApbStall;
  assign ExWbFwdEn           = WbWriteEn || ExWbWriteEn;
  assign ExWbFwdRdAddr       = WbWriteEn ? MEMWB.RdAddr : ExWbRdAddr;
  assign ExWbFwdWriteData    = WbWriteEn ? WbWriteData : ExWbWriteData;

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
    .iExtIrqPending (iExtIrqPending),
    .oCsrRdata      (CsrRdata),
    .oMtvec         (Mtvec),
    .oMepc          (Mepc),
    .oMstatusMie    (MstatusMie),
    .oMstatusMpie   (MstatusMpie),
    .oMieMeie       (MieMeie),
    .oMipMeip       (MipMeip)
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
