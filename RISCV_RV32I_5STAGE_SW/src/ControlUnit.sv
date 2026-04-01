/*
[MODULE_INFO_START]
Name: ControlUnit
Role: Instruction-level control decoder
Summary:
  - Consumes pre-extracted RV32I instruction fields from DecodeStage
  - Classifies the opcode and delegates decode to ISA-aligned sub-decoders
  - Selects one class-specific decode result before passing it to the exception guard
  - Emits decode-stage operand-usage metadata for downstream hazard detection
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ControlUnit (
  input  logic                           [6:0]  iOpcode,
  input  logic                           [2:0]  iFunct3,
  input  logic                           [6:0]  iFunct7,
  input  logic                           [11:0] iImm12,
  input  logic                           [4:0]  iRs1Addr,
  output rv32i_pkg::CTRL_t               oCtrl,
  output logic                           oTrapReq,
  output logic                           oIllegal,
  output logic                           oUseRs1,
  output logic                           oUseRs2
);

  // ==== 1. Wire Declarations ====

  rv32i_pkg::OpcodeClassE OpcodeClass;

  logic                 IllegalOpcode;
  rv32i_pkg::CTRL_DEC_t RtypeCtrlDec;
  rv32i_pkg::CTRL_DEC_t OpimmCtrlDec;
  rv32i_pkg::CTRL_DEC_t LoadCtrlDec;
  rv32i_pkg::CTRL_DEC_t StoreCtrlDec;
  rv32i_pkg::CTRL_DEC_t BranchCtrlDec;
  rv32i_pkg::CTRL_DEC_t UtypeCtrlDec;
  rv32i_pkg::CTRL_DEC_t JumpCtrlDec;
  rv32i_pkg::CTRL_DEC_t SystemCtrlDec;
  rv32i_pkg::CTRL_DEC_t SelectedCtrlDec;

  // ==== 2. Opcode Classification & Distribution ====

  // Determine top-level ISA instruction class
  MainDecoder uMainDecoder (
    .iOpcode        (iOpcode),
    .oOpcodeClass   (OpcodeClass),
    .oIllegalOpcode (IllegalOpcode)
  );

  // ==== 4. Sub-Decoders ====

  RtypeDecoder uRtypeDecoder (
    .iFunct3  (iFunct3),
    .iFunct7  (iFunct7),
    .oCtrlDec (RtypeCtrlDec)
  );

  ItypeAluDecoder uItypeAluDecoder (
    .iFunct3  (iFunct3),
    .iFunct7  (iFunct7),
    .oCtrlDec (OpimmCtrlDec)
  );

  LoadDecoder uLoadDecoder (
    .iFunct3        (iFunct3),
    .oCtrlDec       (LoadCtrlDec)
  );

  StoreDecoder uStoreDecoder (
    .iFunct3  (iFunct3),
    .oCtrlDec (StoreCtrlDec)
  );

  BranchDecoder uBranchDecoder (
    .iFunct3    (iFunct3),
    .oCtrlDec   (BranchCtrlDec)
  );

  UtypeDecoder uUtypeDecoder (
    .iOpcode  (iOpcode),
    .oCtrlDec (UtypeCtrlDec)
  );

  JumpDecoder uJumpDecoder (
    .iOpcode  (iOpcode),
    .iFunct3  (iFunct3),
    .oCtrlDec (JumpCtrlDec)
  );

  SystemDecoder uSystemDecoder (
    .iOpcode  (iOpcode),
    .iFunct3  (iFunct3),
    .iImm12   (iImm12),
    .oCtrlDec (SystemCtrlDec)
  );

  // ==== 5. Final Control Composition ====

  // Selects the active candidate bundle for the current opcode class.
  ControlComposer uControlComposer (
    .iOpcodeClass     (OpcodeClass),
    .iOpimmCtrlDec    (OpimmCtrlDec),
    .iJumpCtrlDec     (JumpCtrlDec),
    .iLoadCtrlDec     (LoadCtrlDec),
    .iBranchCtrlDec   (BranchCtrlDec),
    .iRtypeCtrlDec    (RtypeCtrlDec),
    .iStoreCtrlDec    (StoreCtrlDec),
    .iSystemCtrlDec   (SystemCtrlDec),
    .iUtypeCtrlDec    (UtypeCtrlDec),
    .oCtrlDec         (SelectedCtrlDec)
  );

  // Applies final illegal/trap policy to the selected decode result.
  CtrlException uCtrlException (
    .iIllegalOpcode (IllegalOpcode),
    .iCtrlDec       (SelectedCtrlDec),
    .oCtrl          (oCtrl),
    .oTrapReq       (oTrapReq),
    .oIllegal       (oIllegal)
  );

  // Operand-use metadata belongs to decode semantics, while the HazardUnit
  // remains responsible only for interlock decisions.
  always_comb begin
    oUseRs1 = 1'b0;
    oUseRs2 = 1'b0;

    unique case (iOpcode)
      rv32i_pkg::LP_OPCODE_RTYPE,
      rv32i_pkg::LP_OPCODE_STORE,
      rv32i_pkg::LP_OPCODE_BRANCH: begin
        oUseRs1 = 1'b1;
        oUseRs2 = 1'b1;
      end

      rv32i_pkg::LP_OPCODE_OPIMM,
      rv32i_pkg::LP_OPCODE_LOAD,
      rv32i_pkg::LP_OPCODE_JALR: begin
        oUseRs1 = 1'b1;
      end

      rv32i_pkg::LP_OPCODE_SYSTEM: begin
        unique case (iFunct3)
          3'b001,
          3'b010,
          3'b011: oUseRs1 = (iRs1Addr != '0);
          default: begin
          end
        endcase
      end

      default: begin
      end
    endcase
  end

endmodule
