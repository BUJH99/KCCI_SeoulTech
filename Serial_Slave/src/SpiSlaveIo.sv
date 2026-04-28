/*
[MODULE_INFO_START]
Name: SpiSlaveIo
Role: Output adapter for the SPI slave MISO line
Summary:
  - Drives the MISO pin only while the SPI slave engine is active and selected
  - Forces a deterministic low level when SPI is inactive or protocol routing selects I2C
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiSlaveIo (
  input  logic iEnable,
  input  logic iMisoBit,
  output logic oJaMiso
);

  assign oJaMiso = iEnable ? iMisoBit : 1'b0;

endmodule
