/*
[MODULE_INFO_START]
Name: DecodeStage
Role: Decode-stage wrapper for the RV32I 5-stage pipeline CPU
Summary:
  - Owns register-file access, hazard detection, and instruction decode orchestration
  - Keeps decode-local operand-usage, trap classification, and ID/EX bundle assembly inside the stage
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module DecodeStage (
  input  logic                    iClk,
  input  logic                    iRstn,
  
  input  rv32i_pkg::IFID_t        iIFID,
  input  rv32i_pkg::IDEX_t        iIDEX,
  
  input  logic                    iWbWriteEn,
  input  logic [4:0]              iWbRdAddr,
  input  logic [31:0]             iWbWriteData,
  
  output logic                    oLoadUseStall,
  output logic                    oRedirectValid,
  output logic [31:0]             oRedirectPc,
  output logic                    oTrapValid,
  output rv32i_pkg::TrapCauseE  oTrapCause,
  output rv32i_pkg::IDEX_t        oIDEXData
);

  import rv32i_pkg::*;

  // ==== 1. Internal Signal Declarations ====

  logic [6:0]                Opcode;
  logic [4:0]                Rs1Addr;
  logic [4:0]                Rs2Addr;
  logic [4:0]                RdAddr;
  logic [2:0]                Funct3;
  logic [6:0]                Funct7;
  logic [11:0]               Imm12;
  
  logic [31:0]               Rs1Data;
  logic [31:0]               Rs2Data;
  logic [31:0]               Imm;
  
  logic                      TrapReq;
  logic                      Illegal;
  logic                      UseRs1;
  logic                      UseRs2;
  logic                      RdValid;
  logic                      JalRedirectReq;
  logic                      JalRedirectMisaligned;
  CTRL_t                     Ctrl;

  // ==== 2. Register File Execution ====

  // Manage synchronous writes to RF during WB stage, and transparent reads in ID stage
  Regfile uRegfile (
    .iClk         (iClk),
    .iRstn        (iRstn),
    .iRs1Addr     (Rs1Addr),
    .iRs2Addr     (Rs2Addr),
    .iRdAddr      (iWbRdAddr),
    .iRdWrData    (iWbWriteData),
    .iRdWrEn      (iWbWriteEn),
    .oRs1RdData   (Rs1Data),
    .oRs2RdData   (Rs2Data),
    .oTimingProbe ()
  );

  // ==== 3. Instruction Field Deconstruction ====

  // Keep standard field naming localized to DecodeStage and pass semantic slices
  // to the downstream control decoder.
  InstrFields uInstrFields (
    .iInstr   (iIFID.Instr),
    .oOpcode  (Opcode),
    .oRd      (RdAddr),
    .oFunct3  (Funct3),
    .oRs1     (Rs1Addr),
    .oRs2     (Rs2Addr),
    .oFunct7  (Funct7),
    .oImm12   (Imm12)
  );

  // ==== 4. Control Generation ====

  // Derives all datapath execution policies from the opcode
  ControlUnit uControlUnit (
    .iOpcode      (Opcode),
    .iFunct3      (Funct3),
    .iFunct7      (Funct7),
    .iImm12       (Imm12),
    .iRs1Addr     (Rs1Addr),
    .oCtrl        (Ctrl),
    .oTrapReq     (TrapReq),
    .oIllegal     (Illegal),
    .oUseRs1      (UseRs1),
    .oUseRs2      (UseRs2)
  );

  // Sign extends immediate values based on decoding scheme
  ImmGen uImmGen (
    .iInstr       (iIFID.Instr),
    .iImmSel      (Ctrl.ImmSel),
    .oImm         (Imm)
  );

  // ==== 5. Dependency & Hazard Assessment ====

  // Unconditional JAL redirects are canonical decode-stage work because the
  // target depends only on the already-latched PC and decoded immediate.
  JalRedirect uJalRedirect (
    .iValid              (iIFID.Valid),
    .iPc                 (iIFID.Pc),
    .iImm                (Imm),
    .iPcSel              (Ctrl.PcSel),
    .oRedirectPc         (oRedirectPc),
    .oRedirectReq        (JalRedirectReq),
    .oRedirectMisaligned (JalRedirectMisaligned)
  );

  assign RdValid = Ctrl.RegWrite && (RdAddr != '0);

  // Check load-use hazard requirement against the in-flight EX pipe stage
  HazardUnit uHazardUnit (
    .iIfValid     (iIFID.Valid),
    .iIdUseRs1    (UseRs1),
    .iIdUseRs2    (UseRs2),
    .iIdRs1Addr   (Rs1Addr),
    .iIdRs2Addr   (Rs2Addr),
    .iIDEX        (iIDEX),
    .oLoadUseStall(oLoadUseStall)
  );

  // ==== 6. Decode Boundary Exception Handling ====

  TrapCauseGen uTrapCauseGen (
    .iValid                 (iIFID.Valid),
    .iIllegal               (Illegal),
    .iTrapReq               (TrapReq),
    .iSysOp                 (Ctrl.SysOp),
    .iJalRedirectMisaligned (JalRedirectMisaligned),
    .oTrapCause             (oTrapCause),
    .oTrapValid             (oTrapValid)
  );

  // ==== 7. ID/EX Payload Packaging ====

  always_comb begin
    oIDEXData = '0;

    if (iIFID.Valid) begin
      oIDEXData.Valid     = 1'b1;
      oIDEXData.Kill      = oTrapValid;
      oIDEXData.RdValid   = RdValid;
      oIDEXData.Pc        = iIFID.Pc;
      oIDEXData.Rs1Addr   = Rs1Addr;
      oIDEXData.Rs2Addr   = Rs2Addr;
      oIDEXData.RdAddr    = RdAddr;
      oIDEXData.UseRs1    = UseRs1;
      oIDEXData.UseRs2    = UseRs2;
      oIDEXData.Rs1Data   = Rs1Data;
      oIDEXData.Rs2Data   = Rs2Data;
      oIDEXData.Imm       = Imm;
      oIDEXData.CsrAddr   = Imm12;
      oIDEXData.Ctrl      = Ctrl;
      oIDEXData.TrapCause = TRAP_NONE;

      if (oTrapValid) begin
        oIDEXData.Ctrl      = LP_CTRL_DEFAULT;
        oIDEXData.TrapCause = oTrapCause;
      end
    end
  end

  assign oRedirectValid    = JalRedirectReq && !oTrapValid;

endmodule
