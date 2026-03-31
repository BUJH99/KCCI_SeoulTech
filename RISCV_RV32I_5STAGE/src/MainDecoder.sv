/*
[MODULE_INFO_START]
Name: MainDecoder
Role: Opcode classifier
Summary:
  - Maps the raw opcode to a coarse ISA instruction class
  - Flags unsupported opcodes before any type-specific decode is attempted
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module MainDecoder (
  input  logic [6:0]                    iOpcode,
  output rv32i_pkg::OpcodeClassE      oOpcodeClass,
  output logic                          oIllegalOpcode
);

  // ==== 1. Opcode Classification Assessment ====
  
  // Categorize 7-bit opcode string into architectural groups.
  always_comb begin
    oOpcodeClass   = rv32i_pkg::OPCODE_CLASS_ILLEGAL;
    oIllegalOpcode = 1'b0;

    unique case (iOpcode)
      rv32i_pkg::LP_OPCODE_RTYPE:   oOpcodeClass = rv32i_pkg::OPCODE_CLASS_RTYPE;
      rv32i_pkg::LP_OPCODE_OPIMM:   oOpcodeClass = rv32i_pkg::OPCODE_CLASS_OPIMM;
      rv32i_pkg::LP_OPCODE_LOAD:    oOpcodeClass = rv32i_pkg::OPCODE_CLASS_LOAD;
      rv32i_pkg::LP_OPCODE_STORE:   oOpcodeClass = rv32i_pkg::OPCODE_CLASS_STORE;
      rv32i_pkg::LP_OPCODE_BRANCH:  oOpcodeClass = rv32i_pkg::OPCODE_CLASS_BRANCH;
      
      rv32i_pkg::LP_OPCODE_LUI,
      rv32i_pkg::LP_OPCODE_AUIPC:   oOpcodeClass = rv32i_pkg::OPCODE_CLASS_UPPER_IMM;
      
      rv32i_pkg::LP_OPCODE_JAL,
      rv32i_pkg::LP_OPCODE_JALR:    oOpcodeClass = rv32i_pkg::OPCODE_CLASS_JUMP;
      
      rv32i_pkg::LP_OPCODE_MISCMEM,
      rv32i_pkg::LP_OPCODE_SYSTEM:  oOpcodeClass = rv32i_pkg::OPCODE_CLASS_SYSTEM;
      
      // Strict fallback ensures undocumented machine behavior doesn't disrupt pipeline
      default: begin
        oIllegalOpcode = 1'b1;
      end
    endcase
  end

endmodule
