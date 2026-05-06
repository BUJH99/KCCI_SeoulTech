/*
[MODULE_INFO_START]
Name: InterruptController
Role: Single-context machine-mode PLIC-lite interrupt controller
Summary:
  - Wraps APB registers, per-source gateways, pending state, priority selection, and compact vector-table extension
  - Exposes pending, enable, claim, complete, threshold, priority, info, and vector-entry registers
  - Forwards one machine external interrupt into the existing CSR/trap path
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InterruptController #(
  parameter int unsigned P_NUM_SOURCES    = rv32i_pkg::LP_INTC_NUM_SOURCES,
  parameter int unsigned P_PRIORITY_WIDTH = rv32i_pkg::LP_INTC_PRIORITY_WIDTH
) (
  input  logic                         iClk,
  input  logic                         iRstn,
  input  logic                         iPsel,
  input  logic                         iPenable,
  input  logic                         iPwrite,
  input  logic [11:0]                  iPaddr,
  input  logic [3:0]                   iPstrb,
  input  logic [31:0]                  iPwdata,
  input  logic [P_NUM_SOURCES-1:0]     iIrqVec,

  output logic [31:0]                  oPrdata,
  output logic                         oPready,
  output logic                         oPslverr,
  output logic                         oVectorValid,
  output logic [31:0]                  oVectorPc,
  output logic [31:0]                  oSelectedSourceId,
  output logic                         oMachineExtIrq
);

  localparam int unsigned LP_NUM_VECTOR_ENTRIES = P_NUM_SOURCES + 1;

  logic [P_NUM_SOURCES-1:0] PendingSetVec;
  logic [P_NUM_SOURCES-1:0] GatewayBlockedVec;
  logic [P_NUM_SOURCES-1:0] CompleteAcceptVec;
  logic [P_NUM_SOURCES-1:0] PendingVec;
  logic [P_NUM_SOURCES-1:0] InServiceVec;
  logic [P_NUM_SOURCES-1:0] EnableVec;
  logic [P_NUM_SOURCES-1:0] ClaimPendingVec;
  logic [P_NUM_SOURCES-1:0] ClaimSelVec;
  logic [P_NUM_SOURCES-1:0] CompleteSelVec;
  logic                     ClaimReadEn;
  logic                     CompleteWriteEn;
  logic [31:0]              CompleteId;
  logic [31:0]              ClaimId;
  logic                     VectorEnable;
  logic [((P_NUM_SOURCES + 1) * P_PRIORITY_WIDTH)-1:0] PriorityEntryFlat;
  logic [P_PRIORITY_WIDTH-1:0] Threshold;
  logic [(LP_NUM_VECTOR_ENTRIES*32)-1:0] VectorEntryFlat;
  logic                     SelectedSourceValid;

  genvar SourceIdx;
  generate
    for (SourceIdx = 0; SourceIdx < P_NUM_SOURCES; SourceIdx = SourceIdx + 1) begin : genIntcGateway
      IntcGateway uIntcGateway (
        .iClk             (iClk),
        .iRstn            (iRstn),
        .iRawIrq          (iIrqVec[SourceIdx]),
        .iCompleteAccept  (CompleteAcceptVec[SourceIdx]),
        .oPendingSetPulse (PendingSetVec[SourceIdx]),
        .oBlocked         (GatewayBlockedVec[SourceIdx])
      );
    end
  endgenerate

  IntcRegIf #(
    .P_NUM_SOURCES    (P_NUM_SOURCES),
    .P_PRIORITY_WIDTH (P_PRIORITY_WIDTH)
  ) uIntcRegIf (
    .iClk               (iClk),
    .iRstn              (iRstn),
    .iPsel              (iPsel),
    .iPenable           (iPenable),
    .iPwrite            (iPwrite),
    .iPaddr             (iPaddr),
    .iPstrb             (iPstrb),
    .iPwdata            (iPwdata),
    .iPendingVec        (PendingVec),
    .iClaimId           (ClaimId),
    .oEnableVec         (EnableVec),
    .oClaimReadEn       (ClaimReadEn),
    .oCompleteWriteEn   (CompleteWriteEn),
    .oCompleteId        (CompleteId),
    .oVectorEnable      (VectorEnable),
    .oPriorityEntryFlat (PriorityEntryFlat),
    .oThreshold         (Threshold),
    .oVectorEntryFlat   (VectorEntryFlat),
    .oPrdata            (oPrdata),
    .oPready            (oPready),
    .oPslverr           (oPslverr)
  );

  IntcPendingCtrl #(
    .P_NUM_SOURCES(P_NUM_SOURCES)
  ) uIntcPendingCtrl (
    .iClk               (iClk),
    .iRstn              (iRstn),
    .iPendingSetVec     (PendingSetVec),
    .iClaimReadEn       (ClaimReadEn),
    .iClaimSelVec       (ClaimSelVec),
    .iCompleteWriteEn   (CompleteWriteEn),
    .iCompleteSelVec    (CompleteSelVec),
    .oPendingVec        (PendingVec),
    .oInServiceVec      (InServiceVec),
    .oCompleteAcceptVec (CompleteAcceptVec)
  );

  IntcPriorityClaim #(
    .P_NUM_SOURCES    (P_NUM_SOURCES),
    .P_PRIORITY_WIDTH (P_PRIORITY_WIDTH)
  ) uIntcPriorityClaim (
    .iPendingVec          (PendingVec),
    .iEnableVec           (EnableVec),
    .iPriorityEntryFlat   (PriorityEntryFlat),
    .iThreshold           (Threshold),
    .iCompleteId          (CompleteId),
    .oClaimPendingVec     (ClaimPendingVec),
    .oClaimSelVec         (ClaimSelVec),
    .oCompleteSelVec      (CompleteSelVec),
    .oClaimId             (ClaimId),
    .oSelectedSourceId    (oSelectedSourceId),
    .oSelectedSourceValid (SelectedSourceValid),
    .oMachineExtIrq       (oMachineExtIrq)
  );

  IntcVectorTable #(
    .P_NUM_SOURCES(P_NUM_SOURCES)
  ) uIntcVectorTable (
    .iVectorEnable        (VectorEnable),
    .iVectorEntryFlat     (VectorEntryFlat),
    .iSelectedSourceValid (SelectedSourceValid),
    .iSelectedSourceId    (oSelectedSourceId),
    .oVectorValid         (oVectorValid),
    .oVectorPc            (oVectorPc)
  );

endmodule