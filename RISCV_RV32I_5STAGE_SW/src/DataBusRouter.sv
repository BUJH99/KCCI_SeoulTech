/*
[MODULE_INFO_START]
Name: DataBusRouter
Role: Top-level native data-bus decode for RAM versus APB MMIO regions
Summary:
  - Separates the MEM-stage native request into the direct DataRam path or the APB MMIO path
  - Flags unmapped accesses so the enclosing fabric can return a load/store access fault
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module DataBusRouter (
  input  rv32i_pkg::DataBusReq_t iReq,

  output logic                   oRamSel,
  output logic                   oApbSel,
  output logic                   oDecodeErr
);

  import rv32i_pkg::*;

  assign oRamSel    = iReq.ReqValid && (iReq.ReqAddr[31:14] == LP_DATA_RAM_BASE[31:14]);
  assign oApbSel    = iReq.ReqValid && (iReq.ReqAddr[31:14] == LP_APB_UART_BASE[31:14]);
  assign oDecodeErr = iReq.ReqValid && !oRamSel && !oApbSel;

endmodule
