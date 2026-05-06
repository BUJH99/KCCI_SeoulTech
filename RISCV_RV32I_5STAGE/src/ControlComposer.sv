/*
[MODULE_INFO_START]
Name: ControlComposer
Role: Final control decode composer
Summary:
  - Selects the active control candidate from ISA-aligned sub-decoders
  - Leaves legality and side-effect guarding to the parent control unit
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ControlComposer (
  input  rv32i_pkg::OpcodeClassE iOpcodeClass,

  input  rv32i_pkg::CTRL_DEC_t     iOpimmCtrlDec,
  input  rv32i_pkg::CTRL_DEC_t     iJumpCtrlDec,
  input  rv32i_pkg::CTRL_DEC_t     iLoadCtrlDec,
  input  rv32i_pkg::CTRL_DEC_t     iBranchCtrlDec,
  input  rv32i_pkg::CTRL_DEC_t     iRtypeCtrlDec,
  input  rv32i_pkg::CTRL_DEC_t     iStoreCtrlDec,
  input  rv32i_pkg::CTRL_DEC_t     iSystemCtrlDec,
  input  rv32i_pkg::CTRL_DEC_t     iUtypeCtrlDec,

  output rv32i_pkg::CTRL_DEC_t     oCtrlDec
);

  // ==== 1. Candidate Selection ====

  // Selects the already-formed candidate bundle for the active opcode class.
  always_comb begin
    oCtrlDec = rv32i_pkg::LP_CTRL_DEC_DEFAULT;

    unique case (iOpcodeClass)
      rv32i_pkg::OPCODE_CLASS_RTYPE:     oCtrlDec = iRtypeCtrlDec;
      rv32i_pkg::OPCODE_CLASS_OPIMM:     oCtrlDec = iOpimmCtrlDec;
      rv32i_pkg::OPCODE_CLASS_LOAD:      oCtrlDec = iLoadCtrlDec;
      rv32i_pkg::OPCODE_CLASS_STORE:     oCtrlDec = iStoreCtrlDec;
      rv32i_pkg::OPCODE_CLASS_BRANCH:    oCtrlDec = iBranchCtrlDec;
      rv32i_pkg::OPCODE_CLASS_UPPER_IMM: oCtrlDec = iUtypeCtrlDec;
      rv32i_pkg::OPCODE_CLASS_JUMP:      oCtrlDec = iJumpCtrlDec;
      rv32i_pkg::OPCODE_CLASS_SYSTEM:    oCtrlDec = iSystemCtrlDec;
      default:                           oCtrlDec = rv32i_pkg::LP_CTRL_DEC_DEFAULT;
    endcase
  end

endmodule
