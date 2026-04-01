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
  
  output rv32i_pkg::CTRL_DEC_t oCtrlDec
);

  // ==== 1. System/Fence Instruction Decoding ====

  // Matches FENCE and SYSTEM traps (ECALL, EBREAK)
  always_comb begin
    oCtrlDec = rv32i_pkg::LP_CTRL_DEC_DEFAULT;

    unique case (iOpcode)
      
      // FENCE instructions are treated as Datapath NOPs in this simple pipeline
      rv32i_pkg::LP_OPCODE_MISCMEM: begin
        oCtrlDec.Illegal = (iFunct3 != 3'b000);
        if (!oCtrlDec.Illegal) begin
          oCtrlDec.Ctrl.SysOp = rv32i_pkg::SYS_FENCE;
        end
      end
      
      // Environment calls and Breakpoints map to the Trap interface
      rv32i_pkg::LP_OPCODE_SYSTEM: begin
        if (iFunct3 == 3'b000) begin
          oCtrlDec.Illegal = 1'b0;

          unique case (iImm12)
            rv32i_pkg::LP_SYSTEM_ECALL: begin
              oCtrlDec.Ctrl.SysOp = rv32i_pkg::SYS_ECALL;
              oCtrlDec.TrapReq    = 1'b1;
            end
            
            rv32i_pkg::LP_SYSTEM_EBREAK: begin
              oCtrlDec.Ctrl.SysOp = rv32i_pkg::SYS_EBREAK;
              oCtrlDec.TrapReq    = 1'b1;
            end

            rv32i_pkg::LP_SYSTEM_MRET: begin
              oCtrlDec.Ctrl.SysOp = rv32i_pkg::SYS_MRET;
            end
            
            default: oCtrlDec.Illegal = 1'b1;
          endcase
        end else if (rv32i_pkg::IsSupportedCsrAddr(iImm12)) begin
          oCtrlDec.Illegal       = 1'b0;
          oCtrlDec.Ctrl.RegWrite = 1'b1;
          oCtrlDec.Ctrl.CsrUseImm = iFunct3[2];

          unique case (iFunct3[1:0])
            2'b01: oCtrlDec.Ctrl.CsrCmd = rv32i_pkg::CSR_RW;
            2'b10: oCtrlDec.Ctrl.CsrCmd = rv32i_pkg::CSR_RS;
            2'b11: oCtrlDec.Ctrl.CsrCmd = rv32i_pkg::CSR_RC;
            default: oCtrlDec.Illegal   = 1'b1;
          endcase
        end else begin
          oCtrlDec.Illegal = 1'b1;
        end
      end
      
      default: oCtrlDec.Illegal = 1'b1;
    endcase
  end

endmodule
