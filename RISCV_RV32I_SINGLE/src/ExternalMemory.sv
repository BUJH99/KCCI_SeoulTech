/*
[MODULE_INFO_START]
Name: ExternalMemory
Role: External word-addressed data memory for the single-cycle core
Summary:
  - Stores raw 32-bit words and exposes combinational readback for the current word address
  - Applies byte-enable writes so sub-word stores are handled outside the memory array
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ExternalMemory #(
  parameter int unsigned P_ADDR_WIDTH = 8,
  parameter int unsigned P_DATA_WIDTH = 32
)(
  input  logic                         iClk,
  input  logic                         iReadEn,
  input  logic                         iWriteEn,
  input  logic [31:0]                  iAddr,
  input  logic [P_DATA_WIDTH-1:0]      iWrData,
  input  logic [(P_DATA_WIDTH/8)-1:0]  iByteEn,
  output logic [P_DATA_WIDTH-1:0]      oRdData
);

  localparam int unsigned LP_DEPTH = (1 << P_ADDR_WIDTH);

  (* ram_style = "distributed" *) logic [P_DATA_WIDTH-1:0] memRam [0:LP_DEPTH-1];
  logic [P_ADDR_WIDTH-1:0] wordAddr;
  int unsigned             byteLane;

  assign wordAddr = iAddr[P_ADDR_WIDTH+1:2];
  assign oRdData  = iReadEn ? memRam[wordAddr] : '0;

  always_ff @(posedge iClk) begin
    if (iWriteEn) begin
      for (byteLane = 0; byteLane < (P_DATA_WIDTH / 8); byteLane = byteLane + 1) begin
        if (iByteEn[byteLane]) begin
          memRam[wordAddr][(byteLane * 8) +: 8] <= iWrData[(byteLane * 8) +: 8];
        end
      end
    end
  end

endmodule
