/*
[MODULE_INFO_START]
Name: ExecuteStage
Role: Execute-stage wrapper for the RV32I 5-stage pipeline CPU
Summary:
  - Owns ALU, branch-compare, redirect-target, and EX/MEM payload orchestration for the EX stage
  - Presents the EX datapath as ForwardUnit, FwdMux, ALUInputMux, Alu, BranchComparator, PcTargetGen, ExecuteRedirectCtrl, and ExecuteCsrCtrl
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ExecuteStage (
  input  rv32i_pkg::IDEX_t        iIDEX,
  input  rv32i_pkg::EXMEM_t       iEXMEM,
  input  logic                    iWbWriteEn,
  input  logic [4:0]              iWbRdAddr,
  input  logic [31:0]             iWbWriteData,
  input  logic [31:0]             iCsrRdata,
  input  logic [31:0]             iMepc,
  
  output logic                    oRedirectValid,
  output logic [31:0]             oRedirectPc,
  output logic                    oTrapValid,
  output rv32i_pkg::TrapCauseE  oTrapCause,
  output logic                    oCsrWriteEn,
  output logic [11:0]             oCsrAddr,
  output logic [31:0]             oCsrWdata,
  output logic                    oMretValid,
  
  output rv32i_pkg::EXMEM_t       oEXMEMData
);

  import rv32i_pkg::*;

  logic [31:0] Rs1Data;
  logic [31:0] Rs2Data;
  logic [31:0] StoreData;
  ForwardSelE ExRs1FwdSel;
  ForwardSelE ExRs2FwdSel;

  logic [31:0] AluOperandA;
  logic [31:0] AluOperandB;
  logic [31:0] AluResult;

  logic [31:0] BranchTargetPc;
  logic [31:0] JalrTargetPc;
  logic [31:0] PcPlus4;

  logic        BranchTaken;
  logic        CsrActive;
  logic        TrapActive;

  // ==== 1. ForwardUnit ====

  ForwardUnit uForwardUnit (
    .iIDEX          (iIDEX),
    .iEXMEM         (iEXMEM),
    .iWbWriteEn     (iWbWriteEn),
    .iWbRdAddr      (iWbRdAddr),
    .oRs1FwdSel     (ExRs1FwdSel),
    .oRs2FwdSel     (ExRs2FwdSel)
  );

  // ==== 2. FwdMux ====

  FwdMux uFwdMux (
    .iRs1Data        (iIDEX.Rs1Data),
    .iRs2Data        (iIDEX.Rs2Data),
    .iExMemFwdData   (iEXMEM.ExFwdData),
    .iMemWbWriteData (iWbWriteData),
    .iRs1FwdSel      (ExRs1FwdSel),
    .iRs2FwdSel      (ExRs2FwdSel),
    .oRs1Data        (Rs1Data),
    .oRs2Data        (Rs2Data)
  );

  // ==== 3. ALUInputMux ====

  ALUInputMux uAluInputMux (
    .iRs1Data        (Rs1Data),
    .iRs2Data        (Rs2Data),
    .iPc             (iIDEX.Pc),
    .iImm            (iIDEX.Imm),
    .iAluASel        (iIDEX.Ctrl.AluASel),
    .iAluBSel        (iIDEX.Ctrl.AluBSel),
    .oAluA           (AluOperandA),
    .oAluB           (AluOperandB)
  );

  // ==== 4. StoreDataMux ====

  StoreDataMux uStoreDataMux (
    .iRs2Data        (iIDEX.Rs2Data),
    .iExMemFwdData   (iEXMEM.ExFwdData),
    .iMemWbWriteData (iWbWriteData),
    .iRs2FwdSel      (ExRs2FwdSel),
    .oStoreData      (StoreData)
  );

  // ==== 5. Alu ====

  Alu uAlu (
    .iA       (AluOperandA),
    .iB       (AluOperandB),
    .iAluOp   (iIDEX.Ctrl.AluOp),
    
    .oResult  (AluResult)
  );

  // ==== 6. BranchComparator ====

  BranchComparator uBranchComparator (
    .iRs1Data     (Rs1Data),
    .iRs2Data     (Rs2Data),
    .iBranchOp    (iIDEX.Ctrl.BranchOp),
    
    .oBranchTaken (BranchTaken)
  );

  // ==== 7. PcTargetGen ====

  PcTargetGen uPcTargetGen (
    .iPc         (iIDEX.Pc),
    .iRs1Data    (Rs1Data),
    .iImm        (iIDEX.Imm),
    
    .oPcTarget   (BranchTargetPc),
    .oJalrTarget (JalrTargetPc),
    .oPcPlus4    (PcPlus4)
  );

  // ==== 8. ExecuteRedirectCtrl ====

  ExecuteRedirectCtrl uExecuteRedirectCtrl (
    .iValid         (iIDEX.Valid),
    .iKill          (iIDEX.Kill),
    .iPcSel         (iIDEX.Ctrl.PcSel),
    .iSysOp         (iIDEX.Ctrl.SysOp),
    .iTrapCause     (iIDEX.TrapCause),
    .iBranchTaken   (BranchTaken),
    .iPcTarget      (BranchTargetPc),
    .iJalrTarget    (JalrTargetPc),
    .iMretPc        (iMepc),
    
    .oRedirectValid (oRedirectValid),
    .oRedirectPc    (oRedirectPc),
    .oTrapValid     (oTrapValid),
    .oTrapCause     (oTrapCause)
  );

  // ==== 9. CSR Execution ====

  ExecuteCsrCtrl uExecuteCsrCtrl (
    .iValid     (iIDEX.Valid),
    .iKill      (iIDEX.Kill),
    .iTrapActive(TrapActive),
    .iCsrCmd    (iIDEX.Ctrl.CsrCmd),
    .iCsrUseImm (iIDEX.Ctrl.CsrUseImm),
    .iRs1Addr   (iIDEX.Rs1Addr),
    .iRs1Data   (Rs1Data),
    .iCsrRdata  (iCsrRdata),
    .iCsrAddr   (iIDEX.CsrAddr),
    .iSysOp     (iIDEX.Ctrl.SysOp),
    .oCsrActive (CsrActive),
    .oCsrWriteEn(oCsrWriteEn),
    .oCsrAddr   (oCsrAddr),
    .oCsrWdata  (oCsrWdata),
    .oMretValid (oMretValid)
  );

  // ==== 10. Trap Qualification ====
  assign TrapActive = (oTrapCause != TRAP_NONE);

  // ==== 11. EX/MEM Payload Packaging ====

  always_comb begin
    oEXMEMData              = '0;
    oEXMEMData.Valid        = iIDEX.Valid;
    oEXMEMData.Kill         = iIDEX.Kill || TrapActive;
    oEXMEMData.RdValid      = iIDEX.RdValid;
    oEXMEMData.Pc           = iIDEX.Pc;
    oEXMEMData.RdAddr       = iIDEX.RdAddr;
    oEXMEMData.AluResult    = AluResult;
    oEXMEMData.ExFwdData    = AluResult;
    oEXMEMData.StoreData    = StoreData;
    oEXMEMData.PcPlus4      = PcPlus4;
    oEXMEMData.WbSel        = iIDEX.Ctrl.WbSel;
    oEXMEMData.LoadUnsigned = iIDEX.Ctrl.LoadUnsigned;
    oEXMEMData.MemSize      = iIDEX.Ctrl.MemSize;
    oEXMEMData.TrapCause    = oTrapCause;

    if (CsrActive) begin
      oEXMEMData.AluResult = iCsrRdata;
      oEXMEMData.ExFwdData = iCsrRdata;
    end else if (iIDEX.Ctrl.WbSel == WB_PC4) begin
      oEXMEMData.ExFwdData = PcPlus4;
    end

    if (!iIDEX.Kill && !TrapActive) begin
      oEXMEMData.RegWrite = iIDEX.Ctrl.RegWrite && iIDEX.RdValid;
      oEXMEMData.MemRead  = iIDEX.Ctrl.MemRead;
      oEXMEMData.MemWrite = iIDEX.Ctrl.MemWrite;
    end
  end

endmodule
