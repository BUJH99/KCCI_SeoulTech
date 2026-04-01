/*
[MODULE_INFO_START]
Name: CtrlException
Role: Final control guard for illegal and trap-producing decode results
Summary:
  - Converts selected decode results into architecturally safe final control outputs
  - Suppresses side effects when an illegal opcode or trap request is present
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module CtrlException (
  input  logic                 iIllegalOpcode,
  input  rv32i_pkg::CTRL_DEC_t iCtrlDec,

  output rv32i_pkg::CTRL_t     oCtrl,
  output logic                 oTrapReq,
  output logic                 oIllegal
);

  rv32i_pkg::CTRL_t Ctrl;
  logic             TrapReq;
  logic             Illegal;

  // Applies the final exception policy after class-specific decode selection.
  always_comb begin
    Ctrl    = iCtrlDec.Ctrl;
    TrapReq = iCtrlDec.TrapReq;
    Illegal = iIllegalOpcode || iCtrlDec.Illegal;

    if (Illegal || TrapReq) begin
      Ctrl.RegWrite     = 1'b0;
      Ctrl.MemRead      = 1'b0;
      Ctrl.MemWrite     = 1'b0;
      Ctrl.LoadUnsigned = 1'b0;
      Ctrl.CsrUseImm    = 1'b0;
      Ctrl.MemSize      = rv32i_pkg::MEM_WORD;
      Ctrl.BranchOp     = rv32i_pkg::BR_NONE;
      Ctrl.CsrCmd       = rv32i_pkg::CSR_NONE;
    end

    if (Illegal) begin
      Ctrl.AluASel = rv32i_pkg::ALUA_RS1;
      Ctrl.AluBSel = rv32i_pkg::ALUB_RS2;
      Ctrl.ImmSel  = rv32i_pkg::IMM_NONE;
      Ctrl.PcSel   = rv32i_pkg::PC_PLUS4;
      Ctrl.WbSel   = rv32i_pkg::WB_ALU;
      Ctrl.AluOp   = rv32i_pkg::ALU_ADD;
      Ctrl.SysOp   = rv32i_pkg::SYS_NONE;
      Ctrl.CsrCmd  = rv32i_pkg::CSR_NONE;
      TrapReq      = 1'b0;
    end

    oCtrl    = Ctrl;
    oTrapReq = TrapReq;
    oIllegal = Illegal;
  end

endmodule
