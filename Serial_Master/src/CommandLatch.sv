/*
[MODULE_INFO_START]
Name: CommandLatch
Role: Captures the protocol select and outgoing write payload for one poll transaction
Summary:
  - Freezes the selected protocol at the start of a 10ms communication cycle
  - Freezes the 8-bit write payload so switch changes do not disturb an in-flight transaction
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module CommandLatch (
  input  logic             iClk,
  input  logic             iRst,
  input  logic             iLoad,
  input  CommPkg::protocol_e iProtocolSelRaw,
  input  logic [7:0]       iWriteDataRaw,
  output CommPkg::protocol_e oProtocolSel,
  output logic [7:0]       oWriteData
);

  import CommPkg::*;

  protocol_e ProtocolSel;
  logic [7:0] WriteData;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      ProtocolSel <= PROTOCOL_SPI;
      WriteData   <= '0;
    end else if (iLoad) begin
      ProtocolSel <= iProtocolSelRaw;
      WriteData   <= iWriteDataRaw;
    end
  end

  assign oProtocolSel = ProtocolSel;
  assign oWriteData   = WriteData;

endmodule
