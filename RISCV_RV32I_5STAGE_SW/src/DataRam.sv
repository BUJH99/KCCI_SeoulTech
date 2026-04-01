/*
[MODULE_INFO_START]
Name: DataRam
Role: Word-oriented data memory array
Summary:
  - Provides 32-bit word storage with byte-enable writes for the RV32I data path
  - Exposes raw word readback so MEM-stage formatters can own ISA-specific access behavior
  - Uses inferred block RAM so larger software demos have practical scratch space
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module DataRam #(
  parameter int unsigned P_ADDR_WIDTH = 12,
  parameter int unsigned P_DATA_WIDTH = 32
)(
  input  logic                    iClk,
  input  logic                    iWrEn,
  input  logic [(P_DATA_WIDTH/8)-1:0] iByteEn,
  input  logic [31:0]             iAddr,
  input  logic [P_DATA_WIDTH-1:0] iWrData,
  
  output logic [P_DATA_WIDTH-1:0] oRdWord
);

  // ==== 1. Memory Parameters & Storage ====

  localparam int unsigned LP_DEPTH      = (1 << P_ADDR_WIDTH);
  localparam int unsigned LP_BYTE_COUNT = (P_DATA_WIDTH / 8);

  // Terminal-game software needs a roomier scratch/data space than the
  // original demo image, so steer the inferred memory into block RAM.
  (* ram_style = "block" *) logic [P_DATA_WIDTH-1:0] MemRam [0:LP_DEPTH-1];
  
  logic [P_ADDR_WIDTH-1:0] Addr;
  integer                  ByteIdx;

  // ==== 2. Memory Read Access ====

  assign Addr = iAddr[P_ADDR_WIDTH+1:2];
  assign oRdWord  = MemRam[Addr];

  // ==== 3. Memory Write Operation ====

  always_ff @(posedge iClk) begin
    if (iWrEn) begin
      for (ByteIdx = 0; ByteIdx < LP_BYTE_COUNT; ByteIdx = ByteIdx + 1) begin
        if (iByteEn[ByteIdx]) begin
          MemRam[Addr][(ByteIdx * 8) +: 8] <= iWrData[(ByteIdx * 8) +: 8];
        end
      end
    end
  end

endmodule
