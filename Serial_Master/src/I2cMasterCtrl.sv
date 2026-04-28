/*
[MODULE_INFO_START]
Name: I2cMasterCtrl
Role: High-level control-state machine for the I2C master subsystem
Summary:
  - Executes START, address, data, repeated-START, and STOP phases for single-byte register transactions
  - Keeps the protocol FSM separate from the byte-oriented datapath and open-drain IO adapter
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterCtrl (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iTxnStart,
  input  logic       iTxnRw,
  input  logic [7:0] iTxnRegAddr,
  input  logic [7:0] iTxnWrData,
  input  logic       iTick,
  input  logic       iSclSync,
  input  logic       iSdaSync,
  input  logic       iTxBit,
  input  logic       iLastBit,
  input  logic       iAckBit,
  output logic       oDivEnable,
  output logic       oBusy,
  output logic       oDone,
  output logic       oSclLevel,
  output logic       oSdaDriveLow,
  output logic       oLoadTxByte,
  output logic [7:0] oTxByte,
  output logic       oClearBitCnt,
  output logic       oTxAdvance,
  output logic       oRxSample,
  output logic       oCaptureAck
);

  import CommPkg::*;

  typedef enum logic [2:0] {
    I2C_MASTER_PHASE_DEVADDR_W,
    I2C_MASTER_PHASE_REGADDR,
    I2C_MASTER_PHASE_WRITE_DATA,
    I2C_MASTER_PHASE_DEVADDR_R,
    I2C_MASTER_PHASE_READ_DATA
  } i2c_master_phase_e;

  i2c_master_state_e state, state_d;
  i2c_master_phase_e phase, phase_d;
  logic [1:0]        StartStep, StartStep_d;
  logic              StartRepeated, StartRepeated_d;
  logic              AckPhase, AckPhase_d;
  logic              TxnRwLatched, TxnRwLatched_d;
  logic [7:0]        RegAddrLatched, RegAddrLatched_d;
  logic [7:0]        WrDataLatched, WrDataLatched_d;
  logic              SclLevel, SclLevel_d;
  logic              SdaDriveLow, SdaDriveLow_d;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      state          <= I2C_MASTER_IDLE;
      phase          <= I2C_MASTER_PHASE_DEVADDR_W;
      StartStep      <= '0;
      StartRepeated  <= 1'b0;
      AckPhase       <= 1'b0;
      TxnRwLatched   <= 1'b0;
      RegAddrLatched <= '0;
      WrDataLatched  <= '0;
      SclLevel       <= 1'b1;
      SdaDriveLow    <= 1'b0;
    end else begin
      state          <= state_d;
      phase          <= phase_d;
      StartStep      <= StartStep_d;
      StartRepeated  <= StartRepeated_d;
      AckPhase       <= AckPhase_d;
      TxnRwLatched   <= TxnRwLatched_d;
      RegAddrLatched <= RegAddrLatched_d;
      WrDataLatched  <= WrDataLatched_d;
      SclLevel       <= SclLevel_d;
      SdaDriveLow    <= SdaDriveLow_d;
    end
  end

  always_comb begin
    state_d          = state;
    phase_d          = phase;
    StartStep_d      = StartStep;
    StartRepeated_d  = StartRepeated;
    AckPhase_d       = AckPhase;
    TxnRwLatched_d   = TxnRwLatched;
    RegAddrLatched_d = RegAddrLatched;
    WrDataLatched_d  = WrDataLatched;
    SclLevel_d       = SclLevel;
    SdaDriveLow_d    = SdaDriveLow;

    unique case (state)
      I2C_MASTER_IDLE: begin
        SclLevel_d    = 1'b1;
        SdaDriveLow_d = 1'b0;
        if (iTxnStart) begin
          state_d          = I2C_MASTER_START;
          phase_d          = I2C_MASTER_PHASE_DEVADDR_W;
          StartStep_d      = 2'd0;
          StartRepeated_d  = 1'b0;
          AckPhase_d       = 1'b0;
          TxnRwLatched_d   = iTxnRw;
          RegAddrLatched_d = iTxnRegAddr;
          WrDataLatched_d  = iTxnWrData;
          SclLevel_d       = 1'b1;
          SdaDriveLow_d    = 1'b1;
        end
      end

      I2C_MASTER_START: begin
        if (!StartRepeated) begin
          SclLevel_d    = 1'b1;
          SdaDriveLow_d = 1'b1;
          if (iTick) begin
            SclLevel_d    = 1'b0;
            SdaDriveLow_d = 1'b1;
            AckPhase_d    = 1'b0;
            StartStep_d   = 2'd0;
            state_d       = I2C_MASTER_ADDR;
          end
        end else begin
          unique case (StartStep)
            2'd0: begin
              SclLevel_d    = 1'b0;
              SdaDriveLow_d = 1'b0;
              if (iTick) begin
                SclLevel_d  = 1'b1;
                StartStep_d = 2'd1;
              end
            end

            2'd1: begin
              SclLevel_d    = 1'b1;
              SdaDriveLow_d = 1'b0;
              if (iSclSync) begin
                SdaDriveLow_d = 1'b1;
              end
              if (iTick && iSclSync) begin
                StartStep_d = 2'd2;
              end
            end

            2'd2: begin
              SclLevel_d    = 1'b1;
              SdaDriveLow_d = 1'b1;
              if (iTick) begin
                SclLevel_d      = 1'b0;
                StartRepeated_d = 1'b0;
                StartStep_d     = 2'd0;
                AckPhase_d      = 1'b0;
                state_d         = I2C_MASTER_ADDR;
                phase_d         = I2C_MASTER_PHASE_DEVADDR_R;
              end
            end

            default: begin
              StartStep_d = 2'd0;
            end
          endcase
        end
      end

      I2C_MASTER_ADDR,
      I2C_MASTER_DATA: begin
        if (!AckPhase) begin
          if (phase == I2C_MASTER_PHASE_READ_DATA) begin
            SdaDriveLow_d = 1'b0;
          end else begin
            SdaDriveLow_d = !iTxBit;
          end

          if (iTick) begin
            if (!SclLevel) begin
              SclLevel_d = 1'b1;
            end else if (iSclSync) begin
              SclLevel_d = 1'b0;
              if (iLastBit) begin
                AckPhase_d = 1'b1;
              end
            end
          end
        end else begin
          SdaDriveLow_d = 1'b0;

          if (iTick) begin
            if (!SclLevel) begin
              SclLevel_d = 1'b1;
            end else if (iSclSync) begin
              SclLevel_d = 1'b0;

              if (phase == I2C_MASTER_PHASE_READ_DATA) begin
                state_d       = I2C_MASTER_STOP;
                SdaDriveLow_d = 1'b1;
              end else if (!iSdaSync) begin
                unique case (phase)
                  I2C_MASTER_PHASE_DEVADDR_W: begin
                    phase_d    = I2C_MASTER_PHASE_REGADDR;
                    AckPhase_d = 1'b0;
                    state_d    = I2C_MASTER_ADDR;
                  end

                  I2C_MASTER_PHASE_REGADDR: begin
                    AckPhase_d = 1'b0;
                    if (TxnRwLatched) begin
                      state_d         = I2C_MASTER_START;
                      phase_d         = I2C_MASTER_PHASE_DEVADDR_R;
                      StartRepeated_d = 1'b1;
                      StartStep_d     = 2'd0;
                      SdaDriveLow_d   = 1'b0;
                      SclLevel_d      = 1'b0;
                    end else begin
                      phase_d    = I2C_MASTER_PHASE_WRITE_DATA;
                      state_d    = I2C_MASTER_DATA;
                    end
                  end

                  I2C_MASTER_PHASE_WRITE_DATA: begin
                    state_d       = I2C_MASTER_STOP;
                    SdaDriveLow_d = 1'b1;
                  end

                  I2C_MASTER_PHASE_DEVADDR_R: begin
                    phase_d    = I2C_MASTER_PHASE_READ_DATA;
                    AckPhase_d = 1'b0;
                    state_d    = I2C_MASTER_DATA;
                  end

                  default: begin
                    state_d       = I2C_MASTER_STOP;
                    SdaDriveLow_d = 1'b1;
                  end
                endcase
              end else begin
                state_d       = I2C_MASTER_STOP;
                SdaDriveLow_d = 1'b1;
              end
            end
          end
        end
      end

      I2C_MASTER_STOP: begin
        if (!SclLevel) begin
          SdaDriveLow_d = 1'b1;
          if (iTick) begin
            SclLevel_d = 1'b1;
          end
        end else begin
          SdaDriveLow_d = 1'b1;
          if (iTick && iSclSync) begin
            SdaDriveLow_d = 1'b0;
            state_d       = I2C_MASTER_IDLE;
          end
        end
      end

      default: begin
        state_d       = I2C_MASTER_IDLE;
        SclLevel_d    = 1'b1;
        SdaDriveLow_d = 1'b0;
      end
    endcase
  end

  always_comb begin
    oDivEnable    = (state != I2C_MASTER_IDLE);
    oBusy         = (state != I2C_MASTER_IDLE);
    oDone         = 1'b0;
    oSclLevel     = SclLevel;
    oSdaDriveLow  = SdaDriveLow;
    oLoadTxByte   = 1'b0;
    oTxByte       = 8'h00;
    oClearBitCnt  = 1'b0;
    oTxAdvance    = 1'b0;
    oRxSample     = 1'b0;
    oCaptureAck   = 1'b0;

    unique case (state)
      I2C_MASTER_IDLE: begin
        oSclLevel    = 1'b1;
        oSdaDriveLow = 1'b0;
      end

      I2C_MASTER_START: begin
        if (!StartRepeated) begin
          oSclLevel    = 1'b1;
          oSdaDriveLow = 1'b1;
          if (iTick) begin
            oLoadTxByte  = 1'b1;
            oClearBitCnt = 1'b1;
            oTxByte      = {LP_I2C_DEV_ADDR, 1'b0};
          end
        end else begin
          unique case (StartStep)
            2'd0: begin
              oSclLevel    = 1'b0;
              oSdaDriveLow = 1'b0;
            end

            2'd1: begin
              oSclLevel    = 1'b1;
              oSdaDriveLow = iSclSync;
            end

            2'd2: begin
              oSclLevel    = 1'b1;
              oSdaDriveLow = 1'b1;
              if (iTick) begin
                oLoadTxByte  = 1'b1;
                oClearBitCnt = 1'b1;
                oTxByte      = {LP_I2C_DEV_ADDR, 1'b1};
              end
            end

            default: begin
              oSclLevel    = 1'b0;
              oSdaDriveLow = 1'b0;
            end
          endcase
        end
      end

      I2C_MASTER_ADDR,
      I2C_MASTER_DATA: begin
        if (!AckPhase) begin
          if (phase == I2C_MASTER_PHASE_READ_DATA) begin
            oSdaDriveLow = 1'b0;
          end else begin
            oSdaDriveLow = !iTxBit;
          end

          if (iTick && SclLevel && iSclSync) begin
            if (phase == I2C_MASTER_PHASE_READ_DATA) begin
              oRxSample = 1'b1;
            end else begin
              oTxAdvance = 1'b1;
            end
          end
        end else begin
          oSdaDriveLow = 1'b0;
          if (iTick && SclLevel && iSclSync) begin
            if (phase == I2C_MASTER_PHASE_READ_DATA) begin
            end else begin
              oCaptureAck = 1'b1;
              if (!iSdaSync) begin
                unique case (phase)
                  I2C_MASTER_PHASE_DEVADDR_W: begin
                    oLoadTxByte  = 1'b1;
                    oClearBitCnt = 1'b1;
                    oTxByte      = RegAddrLatched;
                  end

                  I2C_MASTER_PHASE_REGADDR: begin
                    if (!TxnRwLatched) begin
                      oLoadTxByte  = 1'b1;
                      oClearBitCnt = 1'b1;
                      oTxByte      = WrDataLatched;
                    end
                  end

                  I2C_MASTER_PHASE_DEVADDR_R: begin
                    oClearBitCnt = 1'b1;
                  end

                  default: begin
                  end
                endcase
              end
            end
          end
        end
      end

      I2C_MASTER_STOP: begin
        if (SclLevel && iSclSync && iTick) begin
          oDone = 1'b1;
        end
      end

      default: begin
        oSclLevel    = 1'b1;
        oSdaDriveLow = 1'b0;
      end
    endcase
  end

endmodule
