/*
[MODULE_INFO_START]
Name: SystemDecoder
Role: Misc-memory and system policy decoder
Summary:
  - Handles FENCE-class legal NOP behavior
  - Decodes ECALL and EBREAK into trap requests
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SystemDecoder (
  input  logic [6:0]         iOpcode,
  input  logic [2:0]         iFunct3,
  input  logic [11:0]        iImm12,
  output logic               oRegWrite,
  output logic               oCsrUseImm,
  output rv32i_pkg::csr_cmd_e oCsrCmd,
  output rv32i_pkg::sys_op_e oSysOp,
  output logic               oTrapReq,
  output logic               oIllegal
);

  always_comb begin
    oRegWrite  = 1'b0;
    oCsrUseImm = 1'b0;
    oCsrCmd    = rv32i_pkg::CSR_NONE;
    oSysOp   = rv32i_pkg::SYS_NONE;
    oTrapReq = 1'b0;
    oIllegal = 1'b0;

    unique case (iOpcode)
      rv32i_pkg::LP_OPCODE_MISCMEM: begin
        oIllegal = (iFunct3 != 3'b000);
        if (!oIllegal) begin
          oSysOp = rv32i_pkg::SYS_FENCE;
        end
      end
      rv32i_pkg::LP_OPCODE_SYSTEM: begin
        oIllegal = 1'b1;
        if (iFunct3 == 3'b000) begin
          unique case (iImm12)
            rv32i_pkg::LP_SYSTEM_ECALL: begin
              oSysOp   = rv32i_pkg::SYS_ECALL;
              oTrapReq = 1'b1;
              oIllegal = 1'b0;
            end
            rv32i_pkg::LP_SYSTEM_EBREAK: begin
              oSysOp   = rv32i_pkg::SYS_EBREAK;
              oTrapReq = 1'b1;
              oIllegal = 1'b0;
            end
            rv32i_pkg::LP_SYSTEM_MRET: begin
              oSysOp   = rv32i_pkg::SYS_MRET;
              oIllegal = 1'b0;
            end
            default: oIllegal = 1'b1;
          endcase
        end else if (rv32i_pkg::IsSupportedCsrAddr(iImm12)) begin
          oRegWrite  = 1'b1;
          oCsrUseImm = iFunct3[2];
          oIllegal   = 1'b0;

          unique case (iFunct3[1:0])
            2'b01: oCsrCmd = rv32i_pkg::CSR_RW;
            2'b10: oCsrCmd = rv32i_pkg::CSR_RS;
            2'b11: oCsrCmd = rv32i_pkg::CSR_RC;
            default: oIllegal = 1'b1;
          endcase
        end
      end
      default: oIllegal = 1'b1;
    endcase
  end

endmodule
