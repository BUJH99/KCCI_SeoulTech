/*
[MODULE_INFO_START]
Name: SpiSlaveEdgeDetect
Role: Fabric-clock edge detector for synchronized SPI slave inputs
Summary:
  - Generates one-cycle rising/falling edge pulses for synchronized CS and SCLK signals
  - Keeps all slave control logic fully synchronous to the 100MHz system clock
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiSlaveEdgeDetect (
  input  logic iClk,
  input  logic iRst,
  input  logic iCsSync,
  input  logic iSclkSync,
  output logic oCsRise,
  output logic oCsFall,
  output logic oSclkRise,
  output logic oSclkFall
);

  logic CsPrev;
  logic SclkPrev;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      CsPrev   <= 1'b1;
      SclkPrev <= 1'b0;
      oCsRise  <= 1'b0;
      oCsFall  <= 1'b0;
      oSclkRise<= 1'b0;
      oSclkFall<= 1'b0;
    end else begin
      oCsRise   <= (!CsPrev && iCsSync);
      oCsFall   <= (CsPrev && !iCsSync);
      oSclkRise <= (!SclkPrev && iSclkSync);
      oSclkFall <= (SclkPrev && !iSclkSync);
      CsPrev    <= iCsSync;
      SclkPrev  <= iSclkSync;
    end
  end

endmodule
