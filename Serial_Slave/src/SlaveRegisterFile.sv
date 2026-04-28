/*
[MODULE_INFO_START]
Name: SlaveRegisterFile
Role: Register map implementation for the Serial Slave project
Summary:
  - Stores writes to register 0x01 and mirrors the low 7 bits onto LED[6:0]
  - Returns the live switch-backed payload for register 0x02 without requiring a stored read register
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SlaveRegisterFile (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iWriteEn,
  input  logic [7:0] iWriteAddr,
  input  logic [7:0] iWriteData,
  input  logic [7:0] iReadAddr,
  input  logic [6:0] iSwitchData,
  output logic [7:0] oReadData,
  output logic [6:0] oLedData
);

  import CommPkg::*;

  logic [7:0] WriteShadow;
  logic [6:0] LedData;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      WriteShadow <= '0;
      LedData     <= '0;
    end else if (iWriteEn && (iWriteAddr == LP_REG_WRITE)) begin
      WriteShadow <= iWriteData;
      LedData     <= iWriteData[6:0];
    end
  end

  always_comb begin
    unique case (iReadAddr)
      LP_REG_READ:  oReadData = {1'b0, iSwitchData};
      default:      oReadData = 8'h00;
    endcase
  end

  assign oLedData = LedData;

endmodule
