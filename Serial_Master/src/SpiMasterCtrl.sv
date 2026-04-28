/*
[MODULE_INFO_START]
Name: SpiMasterCtrl
Role: Control-state machine for the SPI master subsystem
Summary:
  - Drives the SPI Mode-0 START/DATA/STOP sequencing using divider ticks
  - Separates control strobes from the datapath so frame formatting remains outside the FSM
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiMasterCtrl (
  input  logic iClk,
  input  logic iRst,
  input  logic iTxnStart,
  input  logic iTick,
  input  logic iBitsDone,
  output logic oDivEnable,
  output logic oCsActive,
  output logic oSclkLevel,
  output logic oLoadFrame,
  output logic oSampleRx,
  output logic oShiftTx,
  output logic oCaptureFrame,
  output logic oBusy,
  output logic oDone
);

  import CommPkg::*;

  spi_master_state_e state, state_d;
  logic              SclkLevel, SclkLevel_d;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      state     <= SPI_MASTER_IDLE;
      SclkLevel <= 1'b0;
    end else begin
      state     <= state_d;
      SclkLevel <= SclkLevel_d;
    end
  end

  always_comb begin
    state_d     = state;
    SclkLevel_d = SclkLevel;

    unique case (state)
      SPI_MASTER_IDLE: begin
        SclkLevel_d = 1'b0;
        if (iTxnStart) begin
          state_d = SPI_MASTER_START;
        end
      end

      SPI_MASTER_START: begin
        SclkLevel_d = 1'b0;
        state_d     = SPI_MASTER_DATA;
      end

      SPI_MASTER_DATA: begin
        if (iTick) begin
          if (!SclkLevel) begin
            SclkLevel_d = 1'b1;
          end else begin
            SclkLevel_d = 1'b0;
            if (iBitsDone) begin
              state_d = SPI_MASTER_STOP;
            end
          end
        end
      end

      SPI_MASTER_STOP: begin
        SclkLevel_d = 1'b0;
        state_d     = SPI_MASTER_IDLE;
      end

      default: begin
        state_d     = SPI_MASTER_IDLE;
        SclkLevel_d = 1'b0;
      end
    endcase
  end

  always_comb begin
    oDivEnable    = 1'b0;
    oCsActive     = 1'b0;
    oSclkLevel    = SclkLevel;
    oLoadFrame    = 1'b0;
    oSampleRx     = 1'b0;
    oShiftTx      = 1'b0;
    oCaptureFrame = 1'b0;
    oBusy         = (state != SPI_MASTER_IDLE);
    oDone         = 1'b0;

    unique case (state)
      SPI_MASTER_IDLE: begin
        oSclkLevel = 1'b0;
        if (iTxnStart) begin
          oLoadFrame = 1'b1;
        end
      end

      SPI_MASTER_START: begin
        oCsActive  = 1'b1;
        oSclkLevel = 1'b0;
      end

      SPI_MASTER_DATA: begin
        oCsActive  = 1'b1;
        oDivEnable = 1'b1;
        if (iTick) begin
          if (!SclkLevel) begin
            oSampleRx = 1'b1;
          end else begin
            oShiftTx = 1'b1;
          end
        end
      end

      SPI_MASTER_STOP: begin
        oSclkLevel    = 1'b0;
        oCaptureFrame = 1'b1;
        oDone         = 1'b1;
      end

      default: begin
        oSclkLevel = 1'b0;
      end
    endcase
  end

endmodule
