/*
[MODULE_INFO_START]
Name: IfIdReg
Role: IF/ID pipeline register with explicit flush and hold control
Summary:
  - Invalidates only the valid bit on flush so squash control does not fan out across the full bundle
  - Keeps the IF/ID bundle visible at top-level hierarchy for debug and TB checks
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module IfIdReg (
  input  logic               iClk,
  input  logic               iRstn,
  input  logic               iFlush,
  input  logic               iHold,
  input  rv32i_pkg::IFID_t   iData,
  
  output rv32i_pkg::IFID_t   oData
);

  import rv32i_pkg::*;

  // ==== 1. Pipeline Register Storage ====
  
  IFID_t IFIDReg;

  // ==== 2. Synchronous Update Logic ====

  // Updates the pipeline register with stall and flush capabilities.
  // Hold takes priority over data capture, and Flush invalidates the instruction without
  // zeroing out the datapath signals (saving toggle power).
  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      IFIDReg <= '0;
    end else begin
    
      // Evaluate Valid Bit Status
      if (iFlush) begin
        IFIDReg.Valid <= 1'b0;
      end else if (!iHold) begin
        IFIDReg.Valid <= iData.Valid;
      end

      // Evaluate Payload Status Update
      if (!iHold) begin
        IFIDReg.Pc    <= iData.Pc;
        IFIDReg.Instr <= iData.Instr;
      end
      
    end
  end

  assign oData = IFIDReg;

endmodule
