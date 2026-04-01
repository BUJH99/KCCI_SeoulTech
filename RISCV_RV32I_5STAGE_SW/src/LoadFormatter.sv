/*
[MODULE_INFO_START]
Name: LoadFormatter
Role: MEM-stage load data formatter
Summary:
  - Extracts byte, half-word, or word data from a raw 32-bit memory read
  - Applies RV32I sign/zero extension for MEM-stage load results
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module LoadFormatter (
  input  logic                  iMemRead,
  input  rv32i_pkg::MemSizeE  iMemSize,
  input  logic                  iLoadUnsigned,
  input  logic [31:0]           iAddr,
  input  logic [31:0]           iRdData,

  output logic [31:0]           oLoadData
);

  import rv32i_pkg::*;

  logic [7:0]  RdByte;
  logic [15:0] RdHalf;

  // ==== 1. Sub-word Extraction ====

  always_comb begin
    RdByte = iRdData[7:0];

    unique case (iAddr[1:0])
      2'd0:    RdByte = iRdData[7:0];
      2'd1:    RdByte = iRdData[15:8];
      2'd2:    RdByte = iRdData[23:16];
      2'd3:    RdByte = iRdData[31:24];
    endcase
  end

  always_comb begin
    RdHalf = iRdData[15:0];

    unique case (iAddr[1])
      1'b0:    RdHalf = iRdData[15:0];
      1'b1:    RdHalf = iRdData[31:16];
    endcase
  end

  // ==== 2. Load Formatting ====

  always_comb begin
    oLoadData   = iRdData;

    if (iMemRead) begin
      unique case (iMemSize)
        MEM_BYTE: begin
          if (iLoadUnsigned) begin
            oLoadData = {24'd0, RdByte};
          end else begin
            oLoadData = {{24{RdByte[7]}}, RdByte};
          end
        end

        MEM_HALF: begin
          if (iLoadUnsigned) begin
            oLoadData = {16'd0, RdHalf};
          end else begin
            oLoadData = {{16{RdHalf[15]}}, RdHalf};
          end
        end

        MEM_WORD: begin
          oLoadData = iRdData;
        end
      endcase
    end
  end

endmodule
