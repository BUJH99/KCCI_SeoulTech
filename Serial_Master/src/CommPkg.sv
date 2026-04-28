/*
[MODULE_INFO_START]
Name: CommPkg
Role: Shared package for the Serial Master and Serial Slave projects
Summary:
  - Defines protocol constants, register addresses, and FSM enum types used by the SPI/I2C communication blocks
  - Keeps transaction-related types in one place so duplicated Master/Slave projects stay protocol-compatible
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

package CommPkg;

  localparam int unsigned LP_CLK_HZ         = 100_000_000;
  localparam int unsigned LP_POLL_CYCLES    = 1_000_000;
  localparam int unsigned LP_SPI_DIV        = 100;
  localparam int unsigned LP_I2C_DIV        = 4000;
  localparam int unsigned LP_SPI_FRAME_BITS = 16;
  localparam int unsigned LP_I2C_BYTE_BITS  = 8;

  localparam logic [7:0] LP_REG_WRITE = 8'h01;
  localparam logic [7:0] LP_REG_READ  = 8'h02;
  localparam logic [6:0] LP_I2C_DEV_ADDR = 7'h5A;

  typedef enum logic {
    PROTOCOL_SPI = 1'b0,
    PROTOCOL_I2C = 1'b1
  } protocol_e;

  typedef enum logic [2:0] {
    MASTER_SEQ_IDLE,
    MASTER_SEQ_WRITE_REQ,
    MASTER_SEQ_WRITE_WAIT,
    MASTER_SEQ_READ_REQ,
    MASTER_SEQ_READ_WAIT,
    MASTER_SEQ_COMMIT
  } master_seq_state_e;

  typedef enum logic [1:0] {
    SPI_MASTER_IDLE,
    SPI_MASTER_START,
    SPI_MASTER_DATA,
    SPI_MASTER_STOP
  } spi_master_state_e;

  typedef enum logic [2:0] {
    I2C_MASTER_IDLE,
    I2C_MASTER_START,
    I2C_MASTER_ADDR,
    I2C_MASTER_DATA,
    I2C_MASTER_STOP
  } i2c_master_state_e;

  typedef enum logic [1:0] {
    SPI_SLAVE_IDLE,
    SPI_SLAVE_START,
    SPI_SLAVE_DATA,
    SPI_SLAVE_STOP
  } spi_slave_state_e;

  typedef enum logic [2:0] {
    I2C_SLAVE_IDLE,
    I2C_SLAVE_START,
    I2C_SLAVE_ADDR,
    I2C_SLAVE_DATA,
    I2C_SLAVE_STOP
  } i2c_slave_state_e;

endpackage
