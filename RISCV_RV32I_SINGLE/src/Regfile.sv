/*
[MODULE_INFO_START]
Name: Regfile
Role: 32x32 register file
Summary:
  - Provides two combinational read ports and one synchronous write port
  - Enforces x0 as a hard-wired zero register
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module Regfile (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic [4:0]  iRs1Addr,
  input  logic [4:0]  iRs2Addr,
  input  logic [4:0]  iRdAddr,
  input  logic [31:0] iRdWrData,
  input  logic        iRdWrEn,
  output logic [31:0] oRs1RdData,
  output logic [31:0] oRs2RdData,
  output logic        oTimingProbe
);

  logic [31:0] memReg [0:31];
  integer      idx;

  always_comb begin
    oRs1RdData = '0;
    oRs2RdData = '0;

    if (iRs1Addr != '0) begin
      oRs1RdData = memReg[iRs1Addr];
    end

    if (iRs2Addr != '0) begin
      oRs2RdData = memReg[iRs2Addr];
    end
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      for (idx = 0; idx < 32; idx = idx + 1) begin
        memReg[idx] <= '0;
      end
    end else begin
      if (iRdWrEn && (iRdAddr != '0)) begin
        memReg[iRdAddr] <= iRdWrData;
      end

      memReg[0] <= '0;
    end
  end

  assign oTimingProbe = memReg[10][10];

endmodule
