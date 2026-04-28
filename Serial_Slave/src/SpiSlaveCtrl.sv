/*
[MODULE_INFO_START]
Name: SpiSlaveCtrl
Role: Synchronous control-state machine for the SPI slave subsystem
Summary:
  - Waits for synchronized CS/SCLK edge pulses and converts them into datapath strobes
  - Emits a transaction-valid pulse only when a complete 16-bit frame is observed before CS deasserts
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiSlaveCtrl (
  input  logic iClk,
  input  logic iRst,
  input  logic iCsFall,
  input  logic iCsRise,
  input  logic iSclkRise,
  input  logic iSclkFall,
  input  logic iFrameDone,
  output logic oStartFrame,
  output logic oSampleMosi,
  output logic oShiftMiso,
  output logic oTxnValid,
  output logic oBusy
);

  import CommPkg::*;

  spi_slave_state_e state, state_d;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      state <= SPI_SLAVE_IDLE;
    end else begin
      state <= state_d;
    end
  end

  always_comb begin
    state_d = state;

    unique case (state)
      SPI_SLAVE_IDLE: begin
        if (iCsFall) begin
          state_d = SPI_SLAVE_START;
        end
      end

      SPI_SLAVE_START: begin
        state_d = SPI_SLAVE_DATA;
      end

      SPI_SLAVE_DATA: begin
        if (iCsRise) begin
          state_d = SPI_SLAVE_STOP;
        end
      end

      SPI_SLAVE_STOP: begin
        state_d = SPI_SLAVE_IDLE;
      end

      default: begin
        state_d = SPI_SLAVE_IDLE;
      end
    endcase
  end

  always_comb begin
    oStartFrame = 1'b0;
    oSampleMosi = 1'b0;
    oShiftMiso  = 1'b0;
    oTxnValid   = 1'b0;
    oBusy       = (state != SPI_SLAVE_IDLE);

    unique case (state)
      SPI_SLAVE_IDLE: begin
        if (iCsFall) begin
          oStartFrame = 1'b1;
        end
      end

      SPI_SLAVE_DATA: begin
        if (iSclkRise) begin
          oSampleMosi = 1'b1;
        end
        if (iSclkFall) begin
          oShiftMiso = 1'b1;
        end
      end

      SPI_SLAVE_STOP: begin
        if (iFrameDone) begin
          oTxnValid = 1'b1;
        end
      end

      default: begin
      end
    endcase
  end

endmodule
