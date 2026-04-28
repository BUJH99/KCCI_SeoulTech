/*
[MODULE_INFO_START]
Name: I2cSlaveCtrl
Role: Synchronous control-state machine for the I2C slave subsystem
Summary:
  - Decodes START/STOP conditions, address bytes, register bytes, write data, and read-data transmit phases
  - Generates ACK timing and transaction-valid pulses entirely from synchronized edge pulses on the 100MHz system clock
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveCtrl (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iStartPulse,
  input  logic       iStopPulse,
  input  logic       iSclRise,
  input  logic       iSclFall,
  input  logic [7:0] iRxByte,
  input  logic       iTxBit,
  input  logic       iLastBit,
  input  logic [7:0] iTxnReadData,
  output logic       oStartFrame,
  output logic       oLoadTxByte,
  output logic [7:0] oTxByte,
  output logic       oClearBitCnt,
  output logic       oSampleRxBit,
  output logic       oAdvanceTxBit,
  output logic       oSdaDriveLow,
  output logic       oTxnValid,
  output logic       oTxnWrite,
  output logic [7:0] oTxnAddr,
  output logic [7:0] oTxnWdata
);

  import CommPkg::*;

  typedef enum logic [1:0] {
    I2C_SLAVE_PHASE_DEVICE,
    I2C_SLAVE_PHASE_REGADDR,
    I2C_SLAVE_PHASE_WRITE_DATA,
    I2C_SLAVE_PHASE_READ_DATA
  } i2c_slave_phase_e;

  i2c_slave_state_e state, state_d;
  i2c_slave_phase_e phase, phase_d;
  logic             AckPhase, AckPhase_d;
  logic             AckDriveLow, AckDriveLow_d;
  logic             TxMode, TxMode_d;
  logic             TxHold, TxHold_d;
  logic             BytePending, BytePending_d;
  logic [7:0]       RegAddr, RegAddr_d;
  logic             SdaDriveLow, SdaDriveLow_d;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      state        <= I2C_SLAVE_IDLE;
      phase        <= I2C_SLAVE_PHASE_DEVICE;
      AckPhase     <= 1'b0;
      AckDriveLow  <= 1'b0;
      TxMode       <= 1'b0;
      TxHold       <= 1'b0;
      BytePending  <= 1'b0;
      RegAddr      <= '0;
      SdaDriveLow  <= 1'b0;
    end else begin
      state        <= state_d;
      phase        <= phase_d;
      AckPhase     <= AckPhase_d;
      AckDriveLow  <= AckDriveLow_d;
      TxMode       <= TxMode_d;
      TxHold       <= TxHold_d;
      BytePending  <= BytePending_d;
      RegAddr      <= RegAddr_d;
      SdaDriveLow  <= SdaDriveLow_d;
    end
  end

  always_comb begin
    state_d       = state;
    phase_d       = phase;
    AckPhase_d    = AckPhase;
    AckDriveLow_d = AckDriveLow;
    TxMode_d      = TxMode;
    TxHold_d      = TxHold;
    BytePending_d = BytePending;
    RegAddr_d     = RegAddr;
    SdaDriveLow_d = SdaDriveLow;

    if (iStopPulse) begin
      state_d       = I2C_SLAVE_STOP;
      AckPhase_d    = 1'b0;
      AckDriveLow_d = 1'b0;
      TxMode_d      = 1'b0;
      TxHold_d      = 1'b0;
      BytePending_d = 1'b0;
      SdaDriveLow_d = 1'b0;
    end else if (iStartPulse) begin
      state_d       = I2C_SLAVE_START;
      phase_d       = I2C_SLAVE_PHASE_DEVICE;
      AckPhase_d    = 1'b0;
      AckDriveLow_d = 1'b0;
      TxMode_d      = 1'b0;
      TxHold_d      = 1'b0;
      BytePending_d = 1'b0;
      SdaDriveLow_d = 1'b0;
    end else begin
      unique case (state)
        I2C_SLAVE_IDLE: begin
          SdaDriveLow_d = 1'b0;
        end

        I2C_SLAVE_START: begin
          SdaDriveLow_d = 1'b0;
          state_d       = I2C_SLAVE_ADDR;
        end

        I2C_SLAVE_ADDR,
        I2C_SLAVE_DATA: begin
          if (!AckPhase) begin
            if (!TxMode) begin
              SdaDriveLow_d = 1'b0;

              if (iSclRise && iLastBit) begin
                BytePending_d = 1'b1;
              end

              if (iSclFall && BytePending) begin
                BytePending_d = 1'b0;

                unique case (phase)
                  I2C_SLAVE_PHASE_DEVICE: begin
                    if (iRxByte[7:1] == LP_I2C_DEV_ADDR) begin
                      AckPhase_d    = 1'b1;
                      AckDriveLow_d = 1'b1;

                      if (iRxByte[0]) begin
                        phase_d  = I2C_SLAVE_PHASE_READ_DATA;
                        TxMode_d = 1'b1;
                        TxHold_d = 1'b1;
                        state_d  = I2C_SLAVE_DATA;
                      end else begin
                        phase_d  = I2C_SLAVE_PHASE_REGADDR;
                        TxMode_d = 1'b0;
                        state_d  = I2C_SLAVE_ADDR;
                      end
                    end else begin
                      AckPhase_d    = 1'b1;
                      AckDriveLow_d = 1'b0;
                      TxMode_d      = 1'b0;
                      state_d       = I2C_SLAVE_IDLE;
                    end
                  end

                  I2C_SLAVE_PHASE_REGADDR: begin
                    RegAddr_d      = iRxByte;
                    phase_d        = I2C_SLAVE_PHASE_WRITE_DATA;
                    AckPhase_d     = 1'b1;
                    AckDriveLow_d  = 1'b1;
                    state_d        = I2C_SLAVE_DATA;
                  end

                  default: begin
                    AckPhase_d     = 1'b1;
                    AckDriveLow_d  = 1'b1;
                    state_d        = I2C_SLAVE_DATA;
                  end
                endcase
              end
            end else begin
              SdaDriveLow_d = !iTxBit;

              if (iSclFall && iLastBit) begin
                AckPhase_d    = 1'b1;
                AckDriveLow_d = 1'b0;
              end
            end
          end else begin
            SdaDriveLow_d = AckDriveLow;

            if (iSclFall) begin
              AckPhase_d    = 1'b0;
              AckDriveLow_d = 1'b0;
              SdaDriveLow_d = 1'b0;

              if (phase == I2C_SLAVE_PHASE_READ_DATA) begin
                if (TxHold) begin
                  state_d  = I2C_SLAVE_DATA;
                  TxHold_d = 1'b0;
                end else begin
                  TxMode_d = 1'b0;
                  TxHold_d = 1'b0;
                  state_d  = I2C_SLAVE_STOP;
                end
              end else if (!AckDriveLow) begin
                TxMode_d = 1'b0;
                TxHold_d = 1'b0;
                state_d  = I2C_SLAVE_IDLE;
              end else if (phase == I2C_SLAVE_PHASE_DEVICE) begin
                if (TxMode) begin
                  state_d = I2C_SLAVE_DATA;
                end else begin
                  state_d = I2C_SLAVE_ADDR;
                end
              end else begin
                state_d = I2C_SLAVE_DATA;
              end
            end
          end
        end

        I2C_SLAVE_STOP: begin
          SdaDriveLow_d = 1'b0;
          state_d       = I2C_SLAVE_IDLE;
        end

        default: begin
          state_d       = I2C_SLAVE_IDLE;
          SdaDriveLow_d = 1'b0;
        end
      endcase
    end
  end

  always_comb begin
    oStartFrame   = 1'b0;
    oLoadTxByte   = 1'b0;
    oTxByte       = 8'h00;
    oClearBitCnt  = 1'b0;
    oSampleRxBit  = 1'b0;
    oAdvanceTxBit = 1'b0;
    oSdaDriveLow  = SdaDriveLow;
    oTxnValid     = 1'b0;
    oTxnWrite     = 1'b0;
    oTxnAddr      = RegAddr;
    oTxnWdata     = iRxByte;

    if (iStopPulse) begin
      oSdaDriveLow = 1'b0;
    end else if (iStartPulse) begin
      oStartFrame  = 1'b1;
      oClearBitCnt = 1'b1;
      oSdaDriveLow = 1'b0;
    end else begin
      unique case (state)
        I2C_SLAVE_START: begin
          oClearBitCnt = 1'b1;
          oSdaDriveLow = 1'b0;
        end

        I2C_SLAVE_ADDR,
        I2C_SLAVE_DATA: begin
          if (!AckPhase) begin
            if (!TxMode) begin
              oSdaDriveLow = 1'b0;

              if (iSclRise) begin
                oSampleRxBit = 1'b1;
              end

              if (iSclFall && BytePending) begin
                unique case (phase)
                  I2C_SLAVE_PHASE_DEVICE: begin
                    if ((iRxByte[7:1] == LP_I2C_DEV_ADDR) && iRxByte[0]) begin
                      oLoadTxByte = 1'b1;
                      oTxByte     = iTxnReadData;
                    end
                  end

                  I2C_SLAVE_PHASE_WRITE_DATA: begin
                    oTxnValid = 1'b1;
                    oTxnWrite = 1'b1;
                  end

                  default: begin
                  end
                endcase
              end
            end else begin
              oSdaDriveLow = !iTxBit;
              if (iSclFall) begin
                oAdvanceTxBit = 1'b1;
              end
            end
          end else begin
            oSdaDriveLow = AckDriveLow;

            if (iSclFall) begin
              if (phase == I2C_SLAVE_PHASE_READ_DATA) begin
                if (TxHold) begin
                  oClearBitCnt = 1'b1;
                end
              end else if (AckDriveLow) begin
                oClearBitCnt = 1'b1;
              end
            end
          end
        end

        I2C_SLAVE_STOP: begin
          oSdaDriveLow = 1'b0;
        end

        default: begin
          oSdaDriveLow = SdaDriveLow;
        end
      endcase
    end
  end

endmodule
