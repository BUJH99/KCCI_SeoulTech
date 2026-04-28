/*
[MODULE_INFO_START]
Name: GpioCommandPulse
Role: GPIO level command synchronizer and edge pulse generator
Summary:
  - Synchronizes Vitis-driven GPIO control bits into iClk
  - Emits one-cycle pulses on rising edges of each command bit
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module GpioCommandPulse #(
  parameter int unsigned P_WIDTH = 3
) (
  input  logic                 iClk,
  input  logic                 iRstn,
  input  logic [P_WIDTH-1:0]   iCmdLevel,

  output logic [P_WIDTH-1:0]   oCmdPulse
);

  logic [P_WIDTH-1:0] cmdMeta;
  logic [P_WIDTH-1:0] cmdSync;
  logic [P_WIDTH-1:0] cmdSyncD1;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      cmdMeta   <= '0;
      cmdSync   <= '0;
      cmdSyncD1 <= '0;
      oCmdPulse <= '0;
    end else begin
      cmdMeta   <= iCmdLevel;
      cmdSync   <= cmdMeta;
      cmdSyncD1 <= cmdSync;
      oCmdPulse <= cmdSync & ~cmdSyncD1;
    end
  end

endmodule
