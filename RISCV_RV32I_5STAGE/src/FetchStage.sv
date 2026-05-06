/*
[MODULE_INFO_START]
Name: FetchStage
Role: Fetch-stage wrapper for the RV32I 5-stage pipeline CPU
Summary:
  - Owns only the IF datapath: program-counter update, instruction-bus request, and IF/ID payload assembly
  - Receives centralized pipeline control from the top-level PipelineControl block
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module FetchStage (
  input  logic                     iClk,
  input  logic                     iRstn,
  input  logic                     iPcWe,
  input  logic                     iFetchValid,
  input  logic                     iTrapRedirectValid,
  input  logic [31:0]              iTrapRedirectPc,
  input  logic                     iIdRedirectValid,
  input  logic [31:0]              iIdRedirectPc,
  input  logic                     iExRedirectValid,
  input  logic [31:0]              iExRedirectPc,
  input  rv32i_pkg::InstrBusRsp_t  iInstrBusRsp,

  output rv32i_pkg::InstrBusReq_t  oInstrBusReq,
  output logic [31:0]              oPc,
  output rv32i_pkg::IFID_t         oIFIDData
);

  import rv32i_pkg::*;

  // ==== 1. Internal Signal Declarations ====

  logic [31:0]              NextPc;
  NextPcMux uNextPcMux (
    .iPc               (oPc),
    .iTrapRedirectValid(iTrapRedirectValid),
    .iTrapRedirectPc   (iTrapRedirectPc),
    .iIdRedirectValid  (iIdRedirectValid),
    .iIdRedirectPc     (iIdRedirectPc),
    .iExRedirectValid  (iExRedirectValid),
    .iExRedirectPc     (iExRedirectPc),
    .oNextPc           (NextPc)
  );

  // ==== 2. Program Counter ====

  // Instantiates the architecturally registered program counter
  Pc uPc (
    .iClk   (iClk),
    .iRstn  (iRstn),
    .iPcWe  (iPcWe),
    .iNextPc(NextPc),
    .oPc    (oPc)
  );

  // ==== 3. Instruction Bus Request ====

  assign oInstrBusReq.ReqValid = iFetchValid;
  assign oInstrBusReq.ReqAddr  = oPc;

  // ==== 4. IF/ID Payload Assembly ====

  always_comb begin
    oIFIDData       = '0;
    oIFIDData.Valid = iFetchValid;
    oIFIDData.Pc    = oPc;
    oIFIDData.Instr = iInstrBusRsp.RspRdata;
  end

endmodule
