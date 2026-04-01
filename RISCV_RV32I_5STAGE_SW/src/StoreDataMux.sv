/*
[MODULE_INFO_START]
Name: StoreDataMux
Role: Execute-stage store-data forwarding multiplexer
Summary:
  - Selects forwarded store data from register, EX/MEM, or MEM/WB sources
  - Keeps store-data forwarding separate from the ALU/branch operand path
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module StoreDataMux (
  input  logic [31:0]             iRs2Data,
  input  logic [31:0]             iExMemFwdData,
  input  logic [31:0]             iMemWbWriteData,
  input  rv32i_pkg::ForwardSelE iRs2FwdSel,

  output logic [31:0]             oStoreData
);

  import rv32i_pkg::*;

  always_comb begin
    // Store-data forwarding selection
    unique case (iRs2FwdSel)
      FWD_NONE:   oStoreData = iRs2Data;
      FWD_EX_MEM: oStoreData = iExMemFwdData;
      FWD_MEM_WB: oStoreData = iMemWbWriteData;
      default:    oStoreData = iRs2Data;
    endcase
  end

endmodule
