/*
[MODULE_INFO_START]
Name: NextPcMux
Role: Next-PC selector for the RV32I 5-stage pipeline CPU
Summary:
  - Computes the sequential PC+4 path from the current fetch PC
  - Applies prioritized trap and redirect overrides before the PC register update
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module NextPcMux (
  input  logic        [31:0] iPc,
  input  logic               iTrapRedirectValid,
  input  logic        [31:0] iTrapRedirectPc,
  input  logic               iIdRedirectValid,
  input  logic        [31:0] iIdRedirectPc,
  input  logic               iExRedirectValid,
  input  logic        [31:0] iExRedirectPc,

  output logic        [31:0] oNextPc
);

  logic [31:0] PcPlus4;

  assign PcPlus4 = iPc + 32'd4;
  assign oNextPc = (iTrapRedirectValid) ? iTrapRedirectPc :
                   (iExRedirectValid)   ? iExRedirectPc   :
                   (iIdRedirectValid)   ? iIdRedirectPc   :
                    PcPlus4;


endmodule
