/*
[MODULE_INFO_START]
Name: IntcPendingCtrl
Role: Pending and in-service state controller for PLIC-lite interrupt sources
Summary:
  - Latches per-source gateway pulses into software-visible pending state
  - Moves claimed sources from pending into in-service state
  - Accepts COMPLETE only for in-service sources and returns a release pulse to the matching gateway
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module IntcPendingCtrl #(
  parameter int unsigned P_NUM_SOURCES = rv32i_pkg::LP_INTC_NUM_SOURCES
) (
  input  logic                         iClk,
  input  logic                         iRstn,
  input  logic [P_NUM_SOURCES-1:0]     iPendingSetVec,
  input  logic                         iClaimReadEn,
  input  logic [P_NUM_SOURCES-1:0]     iClaimSelVec,
  input  logic                         iCompleteWriteEn,
  input  logic [P_NUM_SOURCES-1:0]     iCompleteSelVec,

  output logic [P_NUM_SOURCES-1:0]     oPendingVec,
  output logic [P_NUM_SOURCES-1:0]     oInServiceVec,
  output logic [P_NUM_SOURCES-1:0]     oCompleteAcceptVec
);

  logic [P_NUM_SOURCES-1:0] PendingVec_d;
  logic [P_NUM_SOURCES-1:0] InServiceVec_d;

  assign oCompleteAcceptVec = iCompleteWriteEn ? (iCompleteSelVec & oInServiceVec) : '0;

  always_comb begin
    PendingVec_d   = oPendingVec | iPendingSetVec;
    InServiceVec_d = oInServiceVec;

    if (iClaimReadEn && (iClaimSelVec != '0)) begin
      PendingVec_d   = PendingVec_d & ~iClaimSelVec;
      InServiceVec_d = InServiceVec_d | iClaimSelVec;
    end

    if (iCompleteWriteEn) begin
      InServiceVec_d = InServiceVec_d & ~oCompleteAcceptVec;
    end
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oPendingVec   <= '0;
      oInServiceVec <= '0;
    end else begin
      oPendingVec   <= PendingVec_d;
      oInServiceVec <= InServiceVec_d;
    end
  end

endmodule
