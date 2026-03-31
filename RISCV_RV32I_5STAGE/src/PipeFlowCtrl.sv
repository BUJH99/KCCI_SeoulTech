/*
[MODULE_INFO_START]
Name: PipeFlowCtrl
Role: Front-end flush, hold, and pipeline-empty control for the RV32I 5-stage pipeline CPU
Summary:
  - Preserves the existing PipelineControl qualification for PC advance, front flush, ID/EX bubble insertion, and EX/MEM trap scrubbing
  - Consumes stall, redirect, halt, trap, and pipeline-valid state without taking ownership of redirect selection
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module PipeFlowCtrl (
  input  logic iLoadUseStall,
  input  logic iTrapCaptureValid,
  input  logic iTrapFromEx,
  input  logic iTrapFromMem,
  input  logic iIdRedirectValid,
  input  logic iExRedirectValid,
  input  logic iIFIDValid,
  input  logic iIDEXValid,
  input  logic iEXMEMValid,
  input  logic iMEMWBValid,

  output logic oPcAdvance,
  output logic oFrontFlush,
  output logic oIdexFlushReq,
  output logic oPcWe,
  output logic oIFIDHold,
  output logic oIFIDFlush,
  output logic oIDEXFlush,
  output logic oEXMEMFlush,
  output logic oFetchValid,
  output logic oPipelineEmpty
);

  assign oPcAdvance    = !iLoadUseStall;
  assign oFrontFlush   = iTrapCaptureValid
                      || iIdRedirectValid
                      || iExRedirectValid;
  assign oIdexFlushReq = iTrapFromMem
                      || iTrapFromEx
                      || iExRedirectValid
                      || iLoadUseStall;

  assign oPcWe         = iTrapCaptureValid || oPcAdvance;
  assign oIFIDHold     = iLoadUseStall;
  assign oIFIDFlush    = oFrontFlush;
  assign oIDEXFlush    = oIdexFlushReq;
  assign oEXMEMFlush   = iTrapFromMem;
  assign oFetchValid   = !(oFrontFlush || iLoadUseStall);
  assign oPipelineEmpty = !(iIFIDValid || iIDEXValid || iEXMEMValid || iMEMWBValid);

endmodule
