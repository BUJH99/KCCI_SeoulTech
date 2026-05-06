/*
[MODULE_INFO_START]
Name: IntcPriorityClaim
Role: Priority and threshold selector for PLIC-lite interrupt claims
Summary:
  - Applies pending, enable, per-source priority, and single-context threshold policy
  - Selects the highest priority eligible source and breaks ties by lower source ID
  - Maps 1-based source IDs to claim and complete one-hot vectors while keeping ID 0 as no interrupt
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module IntcPriorityClaim #(
  parameter int unsigned P_NUM_SOURCES    = rv32i_pkg::LP_INTC_NUM_SOURCES,
  parameter int unsigned P_PRIORITY_WIDTH = rv32i_pkg::LP_INTC_PRIORITY_WIDTH
) (
  input  logic [P_NUM_SOURCES-1:0] iPendingVec,
  input  logic [P_NUM_SOURCES-1:0] iEnableVec,
  input  logic [((P_NUM_SOURCES + 1) * P_PRIORITY_WIDTH)-1:0] iPriorityEntryFlat,
  input  logic [P_PRIORITY_WIDTH-1:0] iThreshold,
  input  logic [31:0]              iCompleteId,

  output logic [P_NUM_SOURCES-1:0] oClaimPendingVec,
  output logic [P_NUM_SOURCES-1:0] oClaimSelVec,
  output logic [P_NUM_SOURCES-1:0] oCompleteSelVec,
  output logic [31:0]              oClaimId,
  output logic [31:0]              oSelectedSourceId,
  output logic                     oSelectedSourceValid,
  output logic                     oMachineExtIrq
);

  logic [P_PRIORITY_WIDTH-1:0] SourcePriority;
  logic [P_PRIORITY_WIDTH-1:0] BestPriority;
  logic                       Eligible;
  int unsigned                ClaimSourceId;
  int unsigned                CompleteSourceId;

  assign oMachineExtIrq       = oSelectedSourceValid;
  assign oSelectedSourceId    = oClaimId;

  always_comb begin
    oClaimPendingVec     = '0;
    oClaimSelVec         = '0;
    oClaimId             = 32'd0;
    oSelectedSourceValid = 1'b0;
    BestPriority         = '0;

    for (ClaimSourceId = 1; ClaimSourceId <= P_NUM_SOURCES; ClaimSourceId = ClaimSourceId + 1) begin
      SourcePriority = iPriorityEntryFlat[(ClaimSourceId * P_PRIORITY_WIDTH) +: P_PRIORITY_WIDTH];
      Eligible       = iPendingVec[ClaimSourceId-1]
                    && iEnableVec[ClaimSourceId-1]
                    && (SourcePriority > iThreshold);

      oClaimPendingVec[ClaimSourceId-1] = Eligible;

      if (Eligible && (!oSelectedSourceValid || (SourcePriority > BestPriority))) begin
        oClaimSelVec         = '0;
        oClaimSelVec[ClaimSourceId-1] = 1'b1;
        oClaimId             = 32'(ClaimSourceId);
        oSelectedSourceValid = 1'b1;
        BestPriority         = SourcePriority;
      end
    end
  end

  always_comb begin
    oCompleteSelVec = '0;

    for (CompleteSourceId = 1; CompleteSourceId <= P_NUM_SOURCES; CompleteSourceId = CompleteSourceId + 1) begin
      if (iCompleteId == 32'(CompleteSourceId)) begin
        oCompleteSelVec[CompleteSourceId-1] = 1'b1;
      end
    end
  end

endmodule
