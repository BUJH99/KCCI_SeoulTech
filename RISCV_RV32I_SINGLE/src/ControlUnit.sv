/*
[MODULE_INFO_START]
Name: ControlUnit
Role: Instruction-level control decoder
Summary:
  - Classifies the opcode and delegates decode to ISA-aligned sub-decoders
  - Delegates final control composition to a single post-decode submodule
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ControlUnit (
  input  logic                    [31:0] iInstr,
  output logic                           oRegWrite,
  output logic                           oMemRead,
  output logic                           oMemWrite,
  output rv32i_pkg::bus_cmd_e            oBusCmd,
  output logic                           oLoadUnsigned,
  output rv32i_pkg::mem_size_e           oMemSize,
  output rv32i_pkg::alu_a_sel_e          oAluASel,
  output rv32i_pkg::alu_b_sel_e          oAluBSel,
  output rv32i_pkg::imm_sel_e            oImmSel,
  output rv32i_pkg::branch_e             oBranchOp,
  output rv32i_pkg::pc_sel_e             oPcSel,
  output rv32i_pkg::wb_sel_e             oWbSel,
  output rv32i_pkg::alu_op_e             oAluOp,
  output logic                           oCsrUseImm,
  output rv32i_pkg::csr_cmd_e            oCsrCmd,
  output rv32i_pkg::sys_op_e             oSysOp,
  output logic                           oTrapReq,
  output logic                           oIllegal
);

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] instr31To25;
  logic [11:0] instr31To20;

  rv32i_pkg::opcode_class_e opcodeClass;

  logic illegalOpcode;
  logic rtypeIllegal;
  logic itypeAluIllegal;
  logic loadIllegal;
  logic storeIllegal;
  logic branchIllegal;
  logic utypeIllegal;
  logic jumpIllegal;
  logic systemIllegal;
  logic systemRegWrite;
  logic systemCsrUseImm;
  logic loadUnsignedDecoded;
  logic trapReqDecoded;

  rv32i_pkg::alu_op_e     rtypeAluOp;
  rv32i_pkg::alu_op_e     itypeAluOp;
  rv32i_pkg::mem_size_e   loadMemSize;
  rv32i_pkg::mem_size_e   storeMemSize;
  rv32i_pkg::branch_e     branchOpDecoded;
  rv32i_pkg::alu_a_sel_e  utypeAluASel;
  rv32i_pkg::alu_a_sel_e  jumpAluASel;
  rv32i_pkg::imm_sel_e    jumpImmSel;
  rv32i_pkg::pc_sel_e     jumpPcSel;
  rv32i_pkg::csr_cmd_e    sysCsrCmd;
  rv32i_pkg::sys_op_e     sysOpDecoded;

  InstrFields uInstrFields (
    .iInstr(iInstr),
    .oOpcode(opcode),
    .oFunct3(funct3),
    .oInstr31To25(instr31To25),
    .oInstr31To20(instr31To20),
    .oRs1(),
    .oRs2(),
    .oRd()
  );

  MainDecoder uMainDecoder (
    .iOpcode(opcode),
    .oOpcodeClass(opcodeClass),
    .oIllegalOpcode(illegalOpcode)
  );

  RtypeDecoder uRtypeDecoder (
    .iFunct3(funct3),
    .iFunct7(instr31To25),
    .oAluOp(rtypeAluOp),
    .oIllegal(rtypeIllegal)
  );

  ItypeAluDecoder uItypeAluDecoder (
    .iFunct3(funct3),
    .iInstr31To25(instr31To25),
    .oAluOp(itypeAluOp),
    .oIllegal(itypeAluIllegal)
  );

  LoadDecoder uLoadDecoder (
    .iFunct3(funct3),
    .oMemSize(loadMemSize),
    .oLoadUnsigned(loadUnsignedDecoded),
    .oIllegal(loadIllegal)
  );

  StoreDecoder uStoreDecoder (
    .iFunct3(funct3),
    .oMemSize(storeMemSize),
    .oIllegal(storeIllegal)
  );

  BranchDecoder uBranchDecoder (
    .iFunct3(funct3),
    .oBranchOp(branchOpDecoded),
    .oIllegal(branchIllegal)
  );

  UtypeDecoder uUtypeDecoder (
    .iOpcode(opcode),
    .oAluASel(utypeAluASel),
    .oIllegal(utypeIllegal)
  );

  JumpDecoder uJumpDecoder (
    .iOpcode(opcode),
    .iFunct3(funct3),
    .oAluASel(jumpAluASel),
    .oImmSel(jumpImmSel),
    .oPcSel(jumpPcSel),
    .oIllegal(jumpIllegal)
  );

  SystemDecoder uSystemDecoder (
    .iOpcode(opcode),
    .iFunct3(funct3),
    .iImm12(instr31To20),
    .oRegWrite(systemRegWrite),
    .oCsrUseImm(systemCsrUseImm),
    .oCsrCmd(sysCsrCmd),
    .oSysOp(sysOpDecoded),
    .oTrapReq(trapReqDecoded),
    .oIllegal(systemIllegal)
  );

  ControlComposer uControlComposer (
    .iIllegalOpcode(illegalOpcode),
    .iOpcodeClass(opcodeClass),
    .iItypeAluOp(itypeAluOp),
    .iItypeAluIllegal(itypeAluIllegal),
    .iJumpAluASel(jumpAluASel),
    .iJumpIllegal(jumpIllegal),
    .iJumpImmSel(jumpImmSel),
    .iJumpPcSel(jumpPcSel),
    .iLoadIllegal(loadIllegal),
    .iLoadUnsigned(loadUnsignedDecoded),
    .iLoadMemSize(loadMemSize),
    .iBranchOp(branchOpDecoded),
    .iBranchIllegal(branchIllegal),
    .iRtypeAluOp(rtypeAluOp),
    .iRtypeIllegal(rtypeIllegal),
    .iStoreIllegal(storeIllegal),
    .iStoreMemSize(storeMemSize),
    .iSystemIllegal(systemIllegal),
    .iSystemRegWrite(systemRegWrite),
    .iSystemCsrUseImm(systemCsrUseImm),
    .iSystemCsrCmd(sysCsrCmd),
    .iSysOp(sysOpDecoded),
    .iTrapReq(trapReqDecoded),
    .iUtypeAluASel(utypeAluASel),
    .iUtypeIllegal(utypeIllegal),
    .oRegWrite(oRegWrite),
    .oMemRead(oMemRead),
    .oMemWrite(oMemWrite),
    .oBusCmd(oBusCmd),
    .oLoadUnsigned(oLoadUnsigned),
    .oMemSize(oMemSize),
    .oAluASel(oAluASel),
    .oAluBSel(oAluBSel),
    .oImmSel(oImmSel),
    .oBranchOp(oBranchOp),
    .oPcSel(oPcSel),
    .oWbSel(oWbSel),
    .oAluOp(oAluOp),
    .oCsrUseImm(oCsrUseImm),
    .oCsrCmd(oCsrCmd),
    .oSysOp(oSysOp),
    .oTrapReq(oTrapReq),
    .oIllegal(oIllegal)
  );

endmodule
