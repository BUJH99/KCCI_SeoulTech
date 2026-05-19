/*
[MODULE_INFO_START]
Name: soc_addr_pkg
Role: Generated SoC address constants for the RV32I 5-stage SoC
Summary:
  - Mirrors soc.yml memory and APB windows for RTL consumers
  - Keeps InstDma, ProgramRam, and APB decode constants in one package
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

package soc_addr_pkg;
  localparam logic [31:0] LP_SOC_BOOT_ROM_BASE    = 32'h0000_0000;
  localparam logic [31:0] LP_SOC_BOOT_ROM_SIZE    = 32'h0000_1000;
  localparam logic [31:0] LP_SOC_PROGRAM_RAM_BASE = 32'h0000_1000;
  localparam logic [31:0] LP_SOC_PROGRAM_RAM_SIZE = 32'h0000_F000;
  localparam logic [31:0] LP_SOC_DATA_RAM_BASE    = 32'h0000_0000;
  localparam logic [31:0] LP_SOC_DATA_RAM_SIZE    = 32'h0000_0400;

  localparam logic [31:0] LP_SOC_APB_BASE       = 32'h4000_0000;
  localparam logic [31:0] LP_SOC_APB_SIZE       = 32'h0001_0000;
  localparam logic [31:0] LP_SOC_APB_UART_BASE  = 32'h4000_0000;
  localparam logic [31:0] LP_SOC_APB_GPIO_BASE  = 32'h4000_1000;
  localparam logic [31:0] LP_SOC_APB_I2C_BASE   = 32'h4000_2000;
  localparam logic [31:0] LP_SOC_APB_INTC_BASE  = 32'h4000_3000;
  localparam logic [31:0] LP_SOC_APB_SPI_BASE   = 32'h4000_4000;
  localparam logic [31:0] LP_SOC_APB_FND_BASE   = 32'h4000_5000;
  localparam logic [31:0] LP_SOC_APB_TIMER_BASE = 32'h4000_6000;
  localparam logic [31:0] LP_SOC_APB_INST_DMA_BASE = 32'h4000_7000;
endpackage
