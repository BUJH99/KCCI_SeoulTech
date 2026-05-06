/*
[MODULE_INFO_START]
Name: PipelineControl
Role: Wrapper that preserves the external pipeline-control contract for the RV32I 5-stage pipeline CPU
Summary:
  - Keeps the original top-level interface while delegating trap capture to TrapController and flow qualification to PipeFlowCtrl
  - Preserves the existing trap priority, redirect visibility, flush/hold behavior, fetch-valid observation, pipeline-empty status, and halt-state next values
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module PipelineControl (
  input  logic                     iLoadUseStall,

  input  rv32i_pkg::IFID_t         iIFID,
  input  rv32i_pkg::IDEX_t         iIDEX,
  input  rv32i_pkg::EXMEM_t        iEXMEM,
  input  rv32i_pkg::MEMWB_t        iMEMWB,

  input  logic                     iIdTrapValid,
  input  rv32i_pkg::TrapCauseE   iIdTrapCause,
  input  logic                     iIdRedirectValid,
  input  logic                     iExTrapValid,
  input  rv32i_pkg::TrapCauseE   iExTrapCause,
  input  logic                     iExRedirectValid,
  input  logic                     iMemTrapValid,
  input  rv32i_pkg::TrapCauseE   iMemTrapCause,
  input  logic                     iMstatusMie,
  input  logic                     iMieMeie,
  input  logic                     iMipMeip,
  input  logic [31:0]              iMtvec,
  input  logic                     iIntcVectorValid,
  input  logic [31:0]              iIntcVectorPc,

  output logic                     oPcWe,
  output logic                     oIFIDHold,
  output logic                     oIFIDFlush,
  output logic                     oIDEXFlush,
  output logic                     oEXMEMFlush,
  output logic                     oFetchValid,
  output logic                     oPipelineEmpty,
  output logic                     oTrapRedirectValid,
  output logic [31:0]              oTrapRedirectPc,
  output logic                     oTrapEnterValid,
  output logic [31:0]              oTrapEnterEpc,
  output logic [31:0]              oTrapEnterCause,
  output logic                     oInterruptAccepted
);

  import rv32i_pkg::*;

  logic        TrapCaptureValid;
  logic        TrapFromEx;
  logic        TrapFromMem;
  logic        TrapFromInterrupt;

  TrapController uTrapController (
    .iIFID              (iIFID),
    .iIDEX              (iIDEX),
    .iEXMEM             (iEXMEM),
    .iExRedirectValid   (iExRedirectValid),
    .iIdTrapValid       (iIdTrapValid),
    .iIdTrapCause       (iIdTrapCause),
    .iExTrapValid       (iExTrapValid),
    .iExTrapCause       (iExTrapCause),
    .iMemTrapValid      (iMemTrapValid),
    .iMemTrapCause      (iMemTrapCause),
    .iMstatusMie        (iMstatusMie),
    .iMieMeie           (iMieMeie),
    .iMipMeip           (iMipMeip),
    .iMtvec             (iMtvec),
    .iIntcVectorValid   (iIntcVectorValid),
    .iIntcVectorPc      (iIntcVectorPc),

    .oTrapCaptureValid  (TrapCaptureValid),
    .oTrapEnterEpc      (oTrapEnterEpc),
    .oTrapEnterCause    (oTrapEnterCause),
    .oTrapFromEx        (TrapFromEx),
    .oTrapFromMem       (TrapFromMem),
    .oTrapFromInterrupt (TrapFromInterrupt),
    .oTrapRedirectValid (oTrapRedirectValid),
    .oTrapRedirectPc    (oTrapRedirectPc),
    .oInterruptAccepted (oInterruptAccepted)
  );

  PipeFlowCtrl uPipeFlowCtrl (
    .iLoadUseStall     (iLoadUseStall),
    .iTrapCaptureValid (TrapCaptureValid),
    .iTrapFromEx       (TrapFromEx),
    .iTrapFromMem      (TrapFromMem),
    .iTrapFromInterrupt(TrapFromInterrupt),
    .iIdRedirectValid  (iIdRedirectValid),
    .iExRedirectValid  (iExRedirectValid),
    .iIFIDValid        (iIFID.Valid),
    .iIDEXValid        (iIDEX.Valid),
    .iEXMEMValid       (iEXMEM.Valid),
    .iMEMWBValid       (iMEMWB.Valid),

    .oPcAdvance        (),
    .oFrontFlush       (),
    .oIdexFlushReq     (),
    .oPcWe             (oPcWe),
    .oIFIDHold         (oIFIDHold),
    .oIFIDFlush        (oIFIDFlush),
    .oIDEXFlush        (oIDEXFlush),
    .oEXMEMFlush       (oEXMEMFlush),
    .oFetchValid       (oFetchValid),
    .oPipelineEmpty    (oPipelineEmpty)
  );

  assign oTrapEnterValid = TrapCaptureValid;

endmodule
