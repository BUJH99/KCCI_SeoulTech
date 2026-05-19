/*
[MODULE_INFO_START]
Name: sort_demo_pkg
Role: Shared protocol constants for the Bubble Sort SPI/I2C demo
Summary:
  - Freezes the v1 SPI trace frame magic, version, frame length, and frame types
  - Defines the SLAVE I2C register address and register offsets used by RTL and firmware
  - Keeps protocol values separate from the RV32I pipeline package
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

package sort_demo_pkg;
  localparam logic [7:0] SORT_FRAME_MAGIC0  = 8'hA5;
  localparam logic [7:0] SORT_FRAME_MAGIC1  = 8'h5A;
  localparam logic [7:0] SORT_FRAME_VERSION = 8'h01;

  localparam logic [7:0] SORT_FRAME_TYPE_TRACE   = 8'h01;
  localparam logic [7:0] SORT_FRAME_TYPE_SUMMARY = 8'h02;
  localparam logic [7:0] SORT_FRAME_TYPE_ERROR   = 8'hE0;

  localparam int unsigned SORT_TRACE_FRAME_BYTES = 24;

  localparam logic [7:0] SORT_PHASE_IDLE      = 8'h00;
  localparam logic [7:0] SORT_PHASE_LOAD      = 8'h01;
  localparam logic [7:0] SORT_PHASE_COMPARE   = 8'h02;
  localparam logic [7:0] SORT_PHASE_SWAP      = 8'h03;
  localparam logic [7:0] SORT_PHASE_PASS_DONE = 8'h04;
  localparam logic [7:0] SORT_PHASE_DONE      = 8'h05;
  localparam logic [7:0] SORT_PHASE_PAUSED    = 8'h06;
  localparam logic [7:0] SORT_PHASE_ERROR     = 8'hE0;

  localparam logic [6:0] SORT_SLAVE_I2C_ADDR = 7'h42;

  localparam logic [7:0] SORT_SLAVE_REG_SLAVE_ID      = 8'h00;
  localparam logic [7:0] SORT_SLAVE_REG_DISPLAY_MODE  = 8'h04;
  localparam logic [7:0] SORT_SLAVE_REG_STATUS        = 8'h08;
  localparam logic [7:0] SORT_SLAVE_REG_LAST_FRAME_ID = 8'h0C;
  localparam logic [7:0] SORT_SLAVE_REG_ERROR_CODE    = 8'h10;
  localparam logic [7:0] SORT_SLAVE_REG_BRIGHTNESS    = 8'h14;
  localparam logic [7:0] SORT_SLAVE_REG_COMPARE_COUNT = 8'h18;
  localparam logic [7:0] SORT_SLAVE_REG_SWAP_COUNT    = 8'h1C;
  localparam logic [7:0] SORT_SLAVE_REG_TOTAL_COUNT   = 8'h20;
endpackage
