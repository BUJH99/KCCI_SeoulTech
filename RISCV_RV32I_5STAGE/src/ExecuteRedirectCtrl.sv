/*
[MODULE_INFO_START]
Name: ExecuteRedirectCtrl
Role: EX-stage redirect and trap controller for the RV32I 5-stage pipeline CPU
Summary:
  - Resolves branch and JALR redirects from EX-stage results
  - Prioritizes carry-in traps and classifies redirect misalignment before the EX/MEM boundary
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ExecuteRedirectCtrl (
  input  logic                    iValid,
  input  logic                    iKill,
  input  rv32i_pkg::PcSelE      iPcSel,
  input  rv32i_pkg::SysOpE      iSysOp,
  input  rv32i_pkg::TrapCauseE  iTrapCause,
  input  logic                    iBranchTaken,
  input  logic [31:0]             iPcTarget,
  input  logic [31:0]             iJalrTarget,
  input  logic [31:0]             iMretPc,
  
  output logic                    oRedirectValid,
  output logic [31:0]             oRedirectPc,
  output logic                    oTrapValid,
  output rv32i_pkg::TrapCauseE  oTrapCause
);

  import rv32i_pkg::*;

  // ==== 1. Internal Signals ====

  logic ExStageActive;             // EX-stage active instruction
  logic BranchRedirect;            // Branch redirect condition
  logic JalrRedirect;              // JALR redirect condition
  logic MretRedirect;              // MRET redirect condition
  logic Redirect;                  // Redirect request
  logic RedirectMisaligned;        // Redirect target misalignment
  logic ExTrapActive;              // Carried-in EX trap
  logic [31:0] RedirectTarget;     // Selected redirect target PC

  // ==== 2. EX Activity Qualification ====

  assign ExStageActive = iValid && !iKill;

  // ==== 3. Redirect and Trap Resolution ====

  always_comb begin
    // Redirect condition set
    BranchRedirect     = ExStageActive && iBranchTaken;
    JalrRedirect       = ExStageActive && (iPcSel == PC_JALR);
    MretRedirect       = ExStageActive && (iSysOp == SYS_MRET);
    Redirect           = BranchRedirect || JalrRedirect || MretRedirect;

    // Redirect target path
    if (MretRedirect) begin
      RedirectTarget = iMretPc;
    end else if (JalrRedirect) begin
      RedirectTarget = iJalrTarget;
    end else begin
      RedirectTarget = iPcTarget;
    end
    RedirectMisaligned = Redirect && RedirectTarget[1];

    // Trap source qualification
    ExTrapActive       = ExStageActive && (iTrapCause != TRAP_NONE);

    // Output default set
    oRedirectPc    = RedirectTarget;
    oTrapCause     = TRAP_NONE;
    oTrapValid     = ExTrapActive || RedirectMisaligned;
    oRedirectValid = Redirect && !RedirectMisaligned;

    // Trap cause priority
    if (ExTrapActive) begin
      oTrapCause = iTrapCause;
    end else if (RedirectMisaligned) begin
      oTrapCause = TRAP_INSTR_MISALIGNED;
    end
  end

endmodule
