/*
[MODULE_INFO_START]
Name: ExecuteCsrCtrl
Role: Execute-stage CSR operation helper for the RV32I 5-stage pipeline CPU
Summary:
  - Computes CSR write enable/data for CSRRW/CSRRS/CSRRC and their immediate forms
  - Qualifies MRET alongside CSR activity so ExecuteStage can stay focused on datapath packaging
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ExecuteCsrCtrl (
  input  logic                 iValid,
  input  logic                 iKill,
  input  logic                 iTrapActive,
  input  rv32i_pkg::CsrCmdE    iCsrCmd,
  input  logic                 iCsrUseImm,
  input  logic [4:0]           iRs1Addr,
  input  logic [31:0]          iRs1Data,
  input  logic [31:0]          iCsrRdata,
  input  logic [11:0]          iCsrAddr,
  input  rv32i_pkg::SysOpE     iSysOp,

  output logic                 oCsrActive,
  output logic                 oCsrWriteEn,
  output logic [11:0]          oCsrAddr,
  output logic [31:0]          oCsrWdata,
  output logic                 oMretValid
);

  import rv32i_pkg::*;

  logic [31:0] CsrOperand;

  assign oCsrActive = (iCsrCmd != CSR_NONE);
  assign CsrOperand = iCsrUseImm ? {27'd0, iRs1Addr} : iRs1Data;
  assign oCsrAddr   = iCsrAddr;
  assign oMretValid = iValid
                   && !iKill
                   && !iTrapActive
                   && (iSysOp == SYS_MRET);

  always_comb begin
    oCsrWdata   = iCsrRdata;
    oCsrWriteEn = 1'b0;

    if (iValid && !iKill && !iTrapActive && oCsrActive) begin
      unique case (iCsrCmd)
        CSR_RW: begin
          oCsrWdata   = CsrOperand;
          oCsrWriteEn = 1'b1;
        end

        CSR_RS: begin
          oCsrWdata   = iCsrRdata | CsrOperand;
          oCsrWriteEn = (CsrOperand != '0);
        end

        CSR_RC: begin
          oCsrWdata   = iCsrRdata & ~CsrOperand;
          oCsrWriteEn = (CsrOperand != '0);
        end

        default: begin
        end
      endcase
    end
  end

endmodule
