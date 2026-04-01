/*
[MODULE_INFO_START]
Name: TrapCauseGen
Role: Decode-stage trap cause classifier
Summary:
  - Converts decode-stage illegal, system-trap, and JAL-misalignment events into a trap cause
  - Qualifies the trap result with the current IF/ID validity bit
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TrapCauseGen (
  input  logic                    iValid,
  input  logic                    iIllegal,
  input  logic                    iTrapReq,
  input  rv32i_pkg::SysOpE      iSysOp,
  input  logic                    iJalRedirectMisaligned,

  output rv32i_pkg::TrapCauseE  oTrapCause,
  output logic                    oTrapValid
);

  import rv32i_pkg::*;

  // Prioritizes decode-visible trap sources before qualifying the final output.
  always_comb begin
    oTrapCause = TRAP_NONE;

    if (iIllegal) begin
      oTrapCause = TRAP_ILLEGAL;
    end else if (iTrapReq) begin
      unique case (iSysOp)
        SYS_ECALL:  oTrapCause = TRAP_ECALL;
        SYS_EBREAK: oTrapCause = TRAP_EBREAK;
        default:    oTrapCause = TRAP_ILLEGAL;
      endcase
    end else if (iJalRedirectMisaligned) begin
      oTrapCause = TRAP_INSTR_MISALIGNED;
    end
  end

  assign oTrapValid = iValid && (oTrapCause != TRAP_NONE);

endmodule
