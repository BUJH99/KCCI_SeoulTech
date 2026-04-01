/*
[MODULE_INFO_START]
Name: CoreTrapGate
Role: Top-level trap and side-effect gating glue
Summary:
  - Combines decode, PC, and data-memory fault conditions into pre-trap and core-trap signals
  - Gates PC write and register write while preserving the current memory request policy
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module CoreTrapGate (
  input  logic iIllegal,
  input  logic iTrapReq,
  input  logic iInstrAddrMisaligned,
  input  logic iDataMisaligned,
  input  logic iRegWriteReq,
  input  logic iMemReadReq,
  input  logic iMemWriteReq,
  output logic oPreTrap,
  output logic oCoreTrap,
  output logic oPcWe,
  output logic oRegWrite,
  output logic oMemRead,
  output logic oMemWrite
);

  assign oPreTrap  = iIllegal || iTrapReq || iInstrAddrMisaligned;
  assign oCoreTrap = oPreTrap || iDataMisaligned;
  assign oPcWe     = !oCoreTrap;
  assign oRegWrite = iRegWriteReq && !oCoreTrap;
  assign oMemRead  = iMemReadReq;
  assign oMemWrite = iMemWriteReq;

endmodule
