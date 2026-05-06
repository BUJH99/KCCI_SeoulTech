/*
[MODULE_INFO_START]
Name: IntcVectorTable
Role: INTC per-source vector target calculator
Summary:
  - Converts the selected 1-based interrupt source ID into a handler PC
  - Uses the programmed table-entry PC when per-source vectoring is enabled
  - Does not claim or clear interrupt pending state; software still owns CLAIM/COMPLETE
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module IntcVectorTable #(
  parameter int unsigned P_NUM_SOURCES = 2
) (
  input  logic        iVectorEnable,
  input  logic [((P_NUM_SOURCES + 1) * 32)-1:0] iVectorEntryFlat,
  input  logic        iSelectedSourceValid,
  input  logic [31:0] iSelectedSourceId,

  output logic        oVectorValid,
  output logic [31:0] oVectorPc
);

  localparam int unsigned LP_NUM_VECTOR_ENTRIES = P_NUM_SOURCES + 1;

  logic [31:0] TableEntryPc;
  int unsigned EntryIdx;

  always_comb begin
    TableEntryPc = '0;

    for (EntryIdx = 0; EntryIdx < LP_NUM_VECTOR_ENTRIES; EntryIdx = EntryIdx + 1) begin
      if (iSelectedSourceId == (EntryIdx + 32'd0)) begin
        TableEntryPc = iVectorEntryFlat[(EntryIdx * 32) +: 32];
      end
    end

    oVectorValid = iVectorEnable
                && iSelectedSourceValid
                && (iSelectedSourceId != 32'd0)
                && (TableEntryPc[31:2] != 30'd0);
    oVectorPc    = {TableEntryPc[31:2], 2'b00};
  end

endmodule
