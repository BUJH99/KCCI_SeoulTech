/*
[MODULE_INFO_START]
Name: WriteBackStage
Role: Write-back-stage wrapper for the RV32I 5-stage pipeline CPU
Summary:
  - Selects architectural WB data from ALU, MEM, or PC+4
  - Produces retire-observation signals without depending on regfile read-during-write behavior
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module WriteBackStage (
  input  rv32i_pkg::MEMWB_t        iMEMWB,
  
  output logic [31:0]              oWbWriteData,
  output logic                     oWbWriteEn,
  output logic                     oRetireValid,
  output logic [31:0]              oRetirePc,
  output logic [4:0]               oRetireRdAddr,
  output logic [31:0]              oRetireWrData,
  output logic                     oRetireRegWrite
);

  import rv32i_pkg::*;

  // ==== 1. Writeback Data Multiplexing ====

  // Routes the correct dataplane result out of the MEM/WB pipeline register 
  // into the architectural Register File port
  always_comb begin
    oWbWriteData = iMEMWB.AluResult;
    
    unique case (iMEMWB.WbSel)
      WB_MEM:   oWbWriteData = iMEMWB.MemRdData;
      WB_PC4:   oWbWriteData = iMEMWB.PcPlus4;
    endcase
  end

  // ==== 2. Register File Write Control ====

  // Validates the register write request (avoiding dead/killed instruction side-effects)
  assign oWbWriteEn      = iMEMWB.Valid
                        && !iMEMWB.Kill
                        && iMEMWB.RegWrite;

  // ==== 3. Retirement Verification Probes ====
  assign oRetireValid    = iMEMWB.Valid && !iMEMWB.Kill;
  assign oRetirePc       = iMEMWB.Pc;
  assign oRetireRdAddr   = iMEMWB.RdAddr;
  assign oRetireWrData   = oWbWriteData;
  assign oRetireRegWrite = oWbWriteEn;

endmodule
