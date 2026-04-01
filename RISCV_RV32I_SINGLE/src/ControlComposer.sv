/*
[MODULE_INFO_START]
Name: ControlComposer
Role: Final control decode composer
Summary:
  - Selects class-specific control outputs from ISA-aligned sub-decoders
  - Applies illegal-instruction and trap policy before driving final control
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ControlComposer (
  input  logic                     iIllegalOpcode,
  input  rv32i_pkg::opcode_class_e iOpcodeClass,
  input  rv32i_pkg::alu_op_e       iItypeAluOp,
  input  logic                     iItypeAluIllegal,
  input  rv32i_pkg::alu_a_sel_e    iJumpAluASel,
  input  logic                     iJumpIllegal,
  input  rv32i_pkg::imm_sel_e      iJumpImmSel,
  input  rv32i_pkg::pc_sel_e       iJumpPcSel,
  input  logic                     iLoadIllegal,
  input  logic                     iLoadUnsigned,
  input  rv32i_pkg::mem_size_e     iLoadMemSize,
  input  rv32i_pkg::branch_e       iBranchOp,
  input  logic                     iBranchIllegal,
  input  rv32i_pkg::alu_op_e       iRtypeAluOp,
  input  logic                     iRtypeIllegal,
  input  logic                     iStoreIllegal,
  input  rv32i_pkg::mem_size_e     iStoreMemSize,
  input  logic                     iSystemIllegal,
  input  logic                     iSystemRegWrite,
  input  logic                     iSystemCsrUseImm,
  input  rv32i_pkg::csr_cmd_e      iSystemCsrCmd,
  input  rv32i_pkg::sys_op_e       iSysOp,
  input  logic                     iTrapReq,
  input  rv32i_pkg::alu_a_sel_e    iUtypeAluASel,
  input  logic                     iUtypeIllegal,
  output logic                     oRegWrite,
  output logic                     oMemRead,
  output logic                     oMemWrite,
  output rv32i_pkg::bus_cmd_e      oBusCmd,
  output logic                     oLoadUnsigned,
  output rv32i_pkg::mem_size_e     oMemSize,
  output rv32i_pkg::alu_a_sel_e    oAluASel,
  output rv32i_pkg::alu_b_sel_e    oAluBSel,
  output rv32i_pkg::imm_sel_e      oImmSel,
  output rv32i_pkg::branch_e       oBranchOp,
  output rv32i_pkg::pc_sel_e       oPcSel,
  output rv32i_pkg::wb_sel_e       oWbSel,
  output rv32i_pkg::alu_op_e       oAluOp,
  output logic                     oCsrUseImm,
  output rv32i_pkg::csr_cmd_e      oCsrCmd,
  output rv32i_pkg::sys_op_e       oSysOp,
  output logic                     oTrapReq,
  output logic                     oIllegal
);

  always_comb begin
    oRegWrite     = 1'b0;
    oMemRead      = 1'b0;
    oMemWrite     = 1'b0;
    oBusCmd       = rv32i_pkg::BUS_CMD_IDLE;
    oLoadUnsigned = 1'b0;
    oMemSize      = rv32i_pkg::MEM_WORD;
    oAluASel      = rv32i_pkg::ALUA_RS1;
    oAluBSel      = rv32i_pkg::ALUB_RS2;
    oImmSel       = rv32i_pkg::IMM_NONE;
    oBranchOp     = rv32i_pkg::BR_NONE;
    oPcSel        = rv32i_pkg::PC_PLUS4;
    oWbSel        = rv32i_pkg::WB_ALU;
    oAluOp        = rv32i_pkg::ALU_ADD;
    oCsrUseImm    = 1'b0;
    oCsrCmd       = rv32i_pkg::CSR_NONE;
    oSysOp        = rv32i_pkg::SYS_NONE;
    oTrapReq      = 1'b0;
    oIllegal      = iIllegalOpcode;

    unique case (iOpcodeClass)
      rv32i_pkg::OPCODE_CLASS_RTYPE: begin
        oRegWrite = 1'b1;
        oAluOp    = iRtypeAluOp;
        oIllegal  = oIllegal || iRtypeIllegal;
      end
      rv32i_pkg::OPCODE_CLASS_OPIMM: begin
        oRegWrite = 1'b1;
        oAluBSel  = rv32i_pkg::ALUB_IMM;
        oImmSel   = rv32i_pkg::IMM_I;
        oAluOp    = iItypeAluOp;
        oIllegal  = oIllegal || iItypeAluIllegal;
      end
      rv32i_pkg::OPCODE_CLASS_LOAD: begin
        oRegWrite     = 1'b1;
        oMemRead      = 1'b1;
        oBusCmd       = rv32i_pkg::BUS_CMD_READ;
        oLoadUnsigned = iLoadUnsigned;
        oMemSize      = iLoadMemSize;
        oAluBSel      = rv32i_pkg::ALUB_IMM;
        oImmSel       = rv32i_pkg::IMM_I;
        oWbSel        = rv32i_pkg::WB_MEM;
        oIllegal      = oIllegal || iLoadIllegal;
      end
      rv32i_pkg::OPCODE_CLASS_STORE: begin
        oMemWrite = 1'b1;
        oBusCmd   = rv32i_pkg::BUS_CMD_WRITE;
        oMemSize  = iStoreMemSize;
        oAluBSel  = rv32i_pkg::ALUB_IMM;
        oImmSel   = rv32i_pkg::IMM_S;
        oIllegal  = oIllegal || iStoreIllegal;
      end
      rv32i_pkg::OPCODE_CLASS_BRANCH: begin
        oAluASel  = rv32i_pkg::ALUA_PC;
        oAluBSel  = rv32i_pkg::ALUB_IMM;
        oImmSel   = rv32i_pkg::IMM_B;
        oBranchOp = iBranchOp;
        oPcSel    = rv32i_pkg::PC_BRANCH;
        oIllegal  = oIllegal || iBranchIllegal;
      end
      rv32i_pkg::OPCODE_CLASS_UPPER_IMM: begin
        oRegWrite = 1'b1;
        oAluASel  = iUtypeAluASel;
        oAluBSel  = rv32i_pkg::ALUB_IMM;
        oImmSel   = rv32i_pkg::IMM_U;
        oIllegal  = oIllegal || iUtypeIllegal;
      end
      rv32i_pkg::OPCODE_CLASS_JUMP: begin
        oRegWrite = 1'b1;
        oAluASel  = iJumpAluASel;
        oAluBSel  = rv32i_pkg::ALUB_IMM;
        oImmSel   = iJumpImmSel;
        oPcSel    = iJumpPcSel;
        oWbSel    = rv32i_pkg::WB_PC4;
        oIllegal  = oIllegal || iJumpIllegal;
      end
      rv32i_pkg::OPCODE_CLASS_SYSTEM: begin
        oRegWrite  = iSystemRegWrite;
        oWbSel     = iSystemRegWrite ? rv32i_pkg::WB_CSR : rv32i_pkg::WB_ALU;
        oCsrUseImm = iSystemCsrUseImm;
        oCsrCmd    = iSystemCsrCmd;
        oSysOp     = iSysOp;
        oTrapReq   = iTrapReq;
        oIllegal   = oIllegal || iSystemIllegal;
      end
      default: begin
        // Keep default-safe outputs when the opcode class is unsupported.
      end
    endcase

    if (oIllegal || oTrapReq) begin
      oRegWrite     = 1'b0;
      oMemRead      = 1'b0;
      oMemWrite     = 1'b0;
      oBusCmd       = rv32i_pkg::BUS_CMD_IDLE;
      oLoadUnsigned = 1'b0;
      oMemSize      = rv32i_pkg::MEM_WORD;
      oBranchOp     = rv32i_pkg::BR_NONE;
      oCsrUseImm    = 1'b0;
      oCsrCmd       = rv32i_pkg::CSR_NONE;
    end

    if (oIllegal) begin
      oAluASel      = rv32i_pkg::ALUA_RS1;
      oAluBSel      = rv32i_pkg::ALUB_RS2;
      oImmSel       = rv32i_pkg::IMM_NONE;
      oPcSel        = rv32i_pkg::PC_PLUS4;
      oWbSel        = rv32i_pkg::WB_ALU;
      oAluOp        = rv32i_pkg::ALU_ADD;
      oCsrUseImm    = 1'b0;
      oCsrCmd       = rv32i_pkg::CSR_NONE;
      oSysOp        = rv32i_pkg::SYS_NONE;
      oTrapReq      = 1'b0;
    end
  end

endmodule
