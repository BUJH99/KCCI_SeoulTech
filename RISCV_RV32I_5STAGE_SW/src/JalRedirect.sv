/*
[MODULE_INFO_START]
Name: JalRedirect
Role: Decode-stage JAL redirect calculator
Summary:
  - Forms the decode-stage JAL redirect target from the latched PC and immediate
  - Identifies whether the current decode result requests a JAL redirect
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module JalRedirect (
  input  logic               iValid,
  input  logic [31:0]        iPc,
  input  logic [31:0]        iImm,
  input  rv32i_pkg::PcSelE iPcSel,

  output logic [31:0]        oRedirectPc,
  output logic               oRedirectReq,
  output logic               oRedirectMisaligned
);

  assign oRedirectPc         = iPc + iImm;
  assign oRedirectReq        = iValid && (iPcSel == rv32i_pkg::PC_JAL);
  assign oRedirectMisaligned = oRedirectReq && oRedirectPc[1];

endmodule
