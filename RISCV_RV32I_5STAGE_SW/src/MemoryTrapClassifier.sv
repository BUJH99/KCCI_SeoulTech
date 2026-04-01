/*
[MODULE_INFO_START]
Name: MemoryTrapClassifier
Role: Memory-stage trap classification helper for the RV32I 5-stage pipeline CPU
Summary:
  - Resolves inherited EX/MEM trap state, alignment faults, and data-bus access faults into one MEM-stage trap cause
  - Preserves the existing MEM-stage priority order and exposes both cause and valid/active qualifiers
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module MemoryTrapClassifier (
  input  logic                   iValid,
  input  logic                   iKill,
  input  rv32i_pkg::TrapCauseE   iIncomingTrapCause,
  input  logic                   iMemReadEn,
  input  logic                   iMemWriteEn,
  input  logic                   iBusReqValid,
  input  logic                   iBusRspErr,
  input  logic                   iLoadMisalign,
  input  logic                   iStoreMisalign,

  output logic                   oTrapValid,
  output logic                   oTrapActive,
  output rv32i_pkg::TrapCauseE   oTrapCause
);

  import rv32i_pkg::*;

  always_comb begin
    oTrapCause = TRAP_NONE;

    if (iIncomingTrapCause != TRAP_NONE) begin
      oTrapCause = iIncomingTrapCause;
    end else if (iLoadMisalign) begin
      oTrapCause = TRAP_LOAD_MISALIGNED;
    end else if (iStoreMisalign) begin
      oTrapCause = TRAP_STORE_MISALIGNED;
    end else if (iBusReqValid && iBusRspErr) begin
      if (iMemReadEn) begin
        oTrapCause = TRAP_LOAD_ACCESS;
      end else if (iMemWriteEn) begin
        oTrapCause = TRAP_STORE_ACCESS;
      end
    end
  end

  assign oTrapValid  = iValid && !iKill && (oTrapCause != TRAP_NONE);
  assign oTrapActive = (oTrapCause != TRAP_NONE);

endmodule
