/*
[MODULE_INFO_START]
Name: Regfile
Role: 32x32 register file
Summary:
  - Provides two combinational read ports and one synchronous write port
  - Enforces x0 as a hard-wired zero register
  - Resolves same-cycle WB hazards with local write-through on the read ports
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

  // ==== 1. Memory Array ====
  
  logic [31:0] MemReg [0:31];
  integer      Idx;

  // ==== 2. Asynchronous Read Ports ====
  
  // Read ports are combinational. If WB writes the same address in this cycle,
  // return the incoming WB value so ID sees the architecturally newest data.
  always_comb begin
    oRs1RdData = '0;
    oRs2RdData = '0;

    if (iRs1Addr != '0) begin
      oRs1RdData = MemReg[iRs1Addr];
      if (iRdWrEn && (iRdAddr == iRs1Addr)) begin
        oRs1RdData = iRdWrData;
      end
    end

    if (iRs2Addr != '0) begin
      oRs2RdData = MemReg[iRs2Addr];
      if (iRdWrEn && (iRdAddr == iRs2Addr)) begin
        oRs2RdData = iRdWrData;
      end
    end
  end

  // ==== 3. Synchronous Write Port ====
  
  // Writes occur on the clock edge. x0 is never architecturally writable.
  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      for (Idx = 0; Idx < 32; Idx = Idx + 1) begin
        MemReg[Idx] <= '0;
      end
    end else begin
      if (iRdWrEn && (iRdAddr != '0)) begin
        MemReg[iRdAddr] <= iRdWrData;
      end

      // Reinforce x0 = 0 in case of accidental overwrite attempts
      MemReg[0] <= '0;
    end
  end

  // ==== 4. Debug Probe ====
  
  assign oTimingProbe = MemReg[10][10];

endmodule
