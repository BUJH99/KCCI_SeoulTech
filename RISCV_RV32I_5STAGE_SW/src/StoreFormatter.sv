/*
[MODULE_INFO_START]
Name: StoreFormatter
Role: MEM-stage store write formatter
Summary:
  - Converts RV32I store size and byte address into byte enables and lane-aligned write data
  - Builds byte enables and lane data for MEM-stage stores
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module StoreFormatter (
  input  logic                  iMemWrite,
  input  rv32i_pkg::MemSizeE  iMemSize,
  input  logic [31:0]           iAddr,
  input  logic [31:0]           iStoreData,

  output logic [3:0]            oByteEn,
  output logic [31:0]           oWrData
);

  import rv32i_pkg::*;

  // ==== 1. Store Formatting ====

  always_comb begin
    oByteEn     = 4'b0000;
    oWrData     = '0;

    if (iMemWrite) begin
      unique case (iMemSize)
        MEM_BYTE: begin
          oWrData = {4{iStoreData[7:0]}};

          unique case (iAddr[1:0])
            2'd0:    oByteEn = 4'b0001;
            2'd1:    oByteEn = 4'b0010;
            2'd2:    oByteEn = 4'b0100;
            2'd3:    oByteEn = 4'b1000;
          endcase
        end

        MEM_HALF: begin
          oWrData     = {2{iStoreData[15:0]}};

          if (!iAddr[0]) begin
            oByteEn = iAddr[1] ? 4'b1100 : 4'b0011;
          end
        end

        MEM_WORD: begin
          oWrData     = iStoreData;

          if (iAddr[1:0] == 2'b00) begin
            oByteEn = 4'b1111;
          end
        end

      endcase
    end
  end

endmodule
