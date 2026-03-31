/*
[MODULE_INFO_START]
Name: MemoryStage
Role: Memory-stage wrapper for the RV32I 5-stage pipeline CPU
Summary:
  - Owns data-memory access orchestration for the MEM stage
  - Delegates trap classification while keeping MEM/WB bundle assembly inside the stage
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module MemoryStage (
  input  rv32i_pkg::EXMEM_t     iEXMEM,
  input  rv32i_pkg::DataBusRsp_t iDataBusRsp,
  
  output rv32i_pkg::DataBusReq_t oDataBusReq,
  output logic                  oTrapValid,
  output rv32i_pkg::TrapCauseE  oTrapCause,
  output rv32i_pkg::MEMWB_t     oMEMWBData
);

  import rv32i_pkg::*;

  // ==== 1. Memory Access Signals ====
  
  logic [31:0] MemAddr;
  logic        MemReadEn;
  logic        MemWriteEn;
  logic        BusReqValid;
  logic [3:0]  ByteEn;
  logic [31:0] WrData;
  logic [31:0] MemLoadData;
  logic [31:0] MemRdData;
  logic        MemAddrMisalign;
  logic        LoadMisalign;
  logic        StoreMisalign;
  logic        MemTrapValid;
  logic        TrapActive;
  logic        BusRspReady;
  logic        BusRspErr;
  logic        MemCommitReady;
  TrapCauseE   MemTrapCause;

  // Verify memory accesses are only triggered by non-killed valid instructions
  assign MemReadEn          = iEXMEM.Valid && !iEXMEM.Kill && iEXMEM.MemRead;
  assign MemWriteEn         = iEXMEM.Valid && !iEXMEM.Kill && iEXMEM.MemWrite;
  assign MemAddr            = iEXMEM.AluResult;
  assign MemRdData          = MemLoadData;
  assign BusRspReady        = iDataBusRsp.RspReady;
  assign BusRspErr          = BusReqValid && BusRspReady && iDataBusRsp.RspErr;

  assign MemAddrMisalign    = ((iEXMEM.MemSize == MEM_HALF) &&  MemAddr[0])
                           || ((iEXMEM.MemSize == MEM_WORD) && (MemAddr[1:0] != 2'b00));
  assign LoadMisalign       = MemReadEn  && MemAddrMisalign;
  assign StoreMisalign      = MemWriteEn && MemAddrMisalign;

  // ==== 2. Store Data Formatting ====

  StoreFormatter uStoreFormatter (
    .iMemWrite   (MemWriteEn),
    .iMemSize    (iEXMEM.MemSize),
    .iAddr       (MemAddr),
    .iStoreData  (iEXMEM.StoreData),

    .oByteEn     (ByteEn),
    .oWrData     (WrData)
  );

  // ==== 3. Fabric Request ====

  assign BusReqValid           = (MemReadEn || MemWriteEn)
                              && !LoadMisalign
                              && !StoreMisalign
                              && (iEXMEM.TrapCause == TRAP_NONE);

  assign oDataBusReq.ReqValid  = BusReqValid;
  assign oDataBusReq.ReqWrite  = MemWriteEn;
  assign oDataBusReq.ReqAddr   = MemAddr;
  assign oDataBusReq.ReqByteEn = ByteEn;
  assign oDataBusReq.ReqWdata  = WrData;
  assign MemCommitReady        = !BusReqValid || BusRspReady;

  // ==== 4. Load Data Formatting ====

  LoadFormatter uLoadFormatter (
    .iMemRead      (MemReadEn),
    .iMemSize      (iEXMEM.MemSize),
    .iLoadUnsigned (iEXMEM.LoadUnsigned),
    .iAddr         (MemAddr),
    .iRdData       (iDataBusRsp.RspRdata),

    .oLoadData     (MemLoadData)
  );

  // ==== 5. Trap Classification ====

  MemoryTrapClassifier uMemoryTrapClassifier (
    .iValid            (iEXMEM.Valid),
    .iKill             (iEXMEM.Kill),
    .iIncomingTrapCause(iEXMEM.TrapCause),
    .iMemReadEn        (MemReadEn),
    .iMemWriteEn       (MemWriteEn),
    .iBusReqValid      (BusReqValid),
    .iBusRspErr        (BusRspErr),
    .iLoadMisalign     (LoadMisalign),
    .iStoreMisalign    (StoreMisalign),
    .oTrapValid        (MemTrapValid),
    .oTrapActive       (TrapActive),
    .oTrapCause        (MemTrapCause)
  );

  // ==== 6. Pipeline Payload Builder ====

  always_comb begin
    oMEMWBData                    = '0;
    if (MemCommitReady) begin
      oMEMWBData.Valid     = iEXMEM.Valid;
      oMEMWBData.Kill      = iEXMEM.Kill || TrapActive;
      oMEMWBData.RdValid   = iEXMEM.RdValid;
      oMEMWBData.Pc        = iEXMEM.Pc;
      oMEMWBData.RdAddr    = iEXMEM.RdAddr;
      oMEMWBData.AluResult = iEXMEM.AluResult;
      oMEMWBData.MemRdData = MemRdData;
      oMEMWBData.PcPlus4   = iEXMEM.PcPlus4;
      oMEMWBData.WbSel     = iEXMEM.WbSel;
      oMEMWBData.RegWrite  = iEXMEM.RegWrite && !TrapActive;
      oMEMWBData.TrapCause = MemTrapCause;
    end
  end

  assign oTrapValid = MemCommitReady && MemTrapValid;
  assign oTrapCause = MemCommitReady ? MemTrapCause : TRAP_NONE;

endmodule
