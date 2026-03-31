/*
[MODULE_INFO_START]
Name: FwdMux
Role: Execute-stage forwarding data multiplexer
Summary:
  - Selects forwarded RS1 and RS2 values from register, EX/MEM, or MEM/WB sources
  - Normalizes EX/MEM forwarding data to the final writeback value domain
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module FwdMux (
  input  logic [31:0]                    iRs1Data,
  input  logic [31:0]                    iRs2Data,
  input  logic [31:0]                    iExMemFwdData,
  input  logic [31:0]                    iMemWbWriteData,
  input  rv32i_pkg::ForwardSelE        iRs1FwdSel,
  input  rv32i_pkg::ForwardSelE        iRs2FwdSel,

  output logic [31:0]                    oRs1Data,
  output logic [31:0]                    oRs2Data
);

  import rv32i_pkg::*;

  always_comb begin
    // RS1 forwarding selection
    unique case (iRs1FwdSel)
      FWD_NONE:   oRs1Data = iRs1Data;
      FWD_EX_MEM: oRs1Data = iExMemFwdData;
      FWD_MEM_WB: oRs1Data = iMemWbWriteData;
      default:    oRs1Data = iRs1Data;
    endcase

    // RS2 forwarding selection
    unique case (iRs2FwdSel)
      FWD_NONE:   oRs2Data = iRs2Data;
      FWD_EX_MEM: oRs2Data = iExMemFwdData;
      FWD_MEM_WB: oRs2Data = iMemWbWriteData;
      default:    oRs2Data = iRs2Data;
    endcase
  end

endmodule
