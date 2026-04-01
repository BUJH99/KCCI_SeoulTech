/*
[MODULE_INFO_START]
Name: HazardUnit
Role: Hazard-detection unit for the RV32I 5-stage pipeline CPU
Summary:
  - Detects the single-cycle load-use interlock
  - Leaves ALU-result forwarding to the EX-local forwarding unit and stalls only when a load result arrives too late
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module HazardUnit (
  input  logic                      iIfValid,
  input  logic                      iIdUseRs1,
  input  logic                      iIdUseRs2,
  input  logic [4:0]                iIdRs1Addr,
  input  logic [4:0]                iIdRs2Addr,
  input  rv32i_pkg::IDEX_t          iIDEX,
  
  output logic                      oLoadUseStall
);

  import rv32i_pkg::*;

  // ==== 1. Load-Use Data Hazard Detect ====

  // A value loaded in EX is not available until MEM, so the immediately following
  // consumer cannot be repaired by forwarding and must insert one bubble.
  assign oLoadUseStall = iIfValid
                      && iIDEX.Valid
                      && !iIDEX.Kill
                      && iIDEX.Ctrl.MemRead
                      && iIDEX.RdValid
                      && ( ((iIDEX.RdAddr == iIdRs1Addr) && iIdUseRs1 && (iIdRs1Addr != '0))
                         ||((iIDEX.RdAddr == iIdRs2Addr) && iIdUseRs2 && (iIdRs2Addr != '0)) );

endmodule
