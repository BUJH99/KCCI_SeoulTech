/*
[MODULE_INFO_START]
Name: I2cSlaveProtocolFsm
Role: I2C SLAVE protocol FSM for address, register, write, and read phases
Summary:
  - Owns address matching, ACK drive windows, repeated-start handling, and protocol state
  - Produces byte-shifter, register-pointer, and register-map control pulses
  - Does not decode display/status register addresses directly
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveProtocolFsm #(
  parameter logic [6:0] P_I2C_ADDR = 7'h42
) (
  input  logic       iClk,
  input  logic       iRst,
  input  logic       iSclRise,
  input  logic       iSclFall,
  input  logic       iStartSeen,
  input  logic       iStopSeen,
  input  logic       iSdaSample,
  input  logic [7:0] iShiftNext,
  input  logic [2:0] iBitCnt,
  input  logic       iByteComplete,
  input  logic [7:0] iRdByteData,

  output logic       oByteRstPulse,
  output logic       oShiftInPulse,
  output logic       oRdBitAdvancePulse,
  output logic       oRegPtrLoadPulse,
  output logic [7:0] oRegPtrLoadAddr,
  output logic       oRegPtrIncPulse,
  output logic       oWrBytePulse,
  output logic [7:0] oWrByteData,
  output logic       oRdByteStartPulse,
  output logic       oAddrMatched,
  output logic       oSdaDriveLow
);

  typedef enum logic [2:0] {
    IDLE,
    ADDR,
    ACK_DRIVE,
    REG,
    WRITE,
    READ,
    READ_ACK,
    IGNORE
  } state_e;

  state_e state;
  state_e state_d;
  state_e ackTarget;
  state_e ackTarget_d;
  logic   AddrMatched;
  logic   AddrMatched_d;
  logic   SdaDriveLow;
  logic   SdaDriveLow_d;
  logic   AckDriveActive;
  logic   AckDriveActive_d;
  logic   AckHighSeen;
  logic   AckHighSeen_d;
  logic   RdByteDoneSeen;
  logic   RdByteDoneSeen_d;

  // I2C slave edge-qualified pulses intentionally remain Mealy to preserve SCL/SDA timing.
  assign oShiftInPulse        = !iStartSeen && !iStopSeen && iSclRise
                              && ((state == ADDR) || (state == REG) || (state == WRITE));
  assign oRdBitAdvancePulse = !iStartSeen && !iStopSeen && iSclRise && (state == READ);
  assign oByteRstPulse      = iStartSeen
                              || (!iStopSeen && (state == ACK_DRIVE) && iSclFall && AckHighSeen)
                              || (!iStopSeen && (state == READ_ACK) && iSclRise && !iSdaSample);
  assign oRegPtrLoadPulse     = !iStartSeen && !iStopSeen && (state == REG) && iSclRise && iByteComplete;
  assign oRegPtrLoadAddr      = iShiftNext;
  assign oWrBytePulse      = !iStartSeen && !iStopSeen && (state == WRITE) && iSclRise && iByteComplete;
  assign oWrByteData       = iShiftNext;
  assign oRegPtrIncPulse      = oWrBytePulse
                              || (!iStartSeen && !iStopSeen && (state == READ) && iSclRise && iByteComplete);
  assign oRdByteStartPulse  = !iStartSeen && !iStopSeen && (state == READ) && iSclFall && (iBitCnt == 3'd7);
  assign oAddrMatched         = AddrMatched;
  assign oSdaDriveLow         = SdaDriveLow;

  always_comb begin
    state_d            = state;
    ackTarget_d        = ackTarget;
    AddrMatched_d      = AddrMatched;
    SdaDriveLow_d      = SdaDriveLow;
    AckDriveActive_d   = AckDriveActive;
    AckHighSeen_d      = AckHighSeen;
    RdByteDoneSeen_d = RdByteDoneSeen;

    if (iStartSeen) begin
      state_d            = ADDR;
      ackTarget_d        = IDLE;
      AddrMatched_d      = 1'b0;
      SdaDriveLow_d      = 1'b0;
      AckDriveActive_d   = 1'b0;
      AckHighSeen_d      = 1'b0;
      RdByteDoneSeen_d = 1'b0;
    end else if (iStopSeen) begin
      state_d            = IDLE;
      SdaDriveLow_d      = 1'b0;
      AckDriveActive_d   = 1'b0;
      AckHighSeen_d      = 1'b0;
      RdByteDoneSeen_d = 1'b0;
    end else begin
      unique case (state)
        IDLE: begin
          SdaDriveLow_d      = 1'b0;
          AckDriveActive_d   = 1'b0;
          AckHighSeen_d      = 1'b0;
          RdByteDoneSeen_d = 1'b0;
        end

        ADDR: begin
          if (iSclRise && iByteComplete) begin
            AddrMatched_d      = (iShiftNext[7:1] == P_I2C_ADDR);
            ackTarget_d        = iShiftNext[0] ? READ : REG;
            state_d            = ACK_DRIVE;
            AckDriveActive_d   = 1'b0;
            AckHighSeen_d      = 1'b0;
            RdByteDoneSeen_d = 1'b0;
          end
        end

        ACK_DRIVE: begin
          if (!AckDriveActive) begin
            SdaDriveLow_d = 1'b0;
            if (iSclFall) begin
              AckDriveActive_d = 1'b1;
              SdaDriveLow_d    = AddrMatched;
            end
          end else begin
            SdaDriveLow_d = AddrMatched;
            if (iSclRise) begin
              AckHighSeen_d = 1'b1;
            end

            if (iSclFall && AckHighSeen) begin
              SdaDriveLow_d      = AddrMatched && (ackTarget == READ) && !iRdByteData[3'd7];
              AckDriveActive_d   = 1'b0;
              AckHighSeen_d      = 1'b0;
              RdByteDoneSeen_d = 1'b0;
              state_d            = AddrMatched ? ackTarget : IGNORE;
            end
          end
        end

        REG: begin
          if (iSclRise && iByteComplete) begin
            ackTarget_d        = WRITE;
            state_d            = ACK_DRIVE;
            AckDriveActive_d   = 1'b0;
            AckHighSeen_d      = 1'b0;
            RdByteDoneSeen_d = 1'b0;
          end
        end

        WRITE: begin
          if (iSclRise && iByteComplete) begin
            ackTarget_d        = WRITE;
            state_d            = ACK_DRIVE;
            AckDriveActive_d   = 1'b0;
            AckHighSeen_d      = 1'b0;
            RdByteDoneSeen_d = 1'b0;
          end
        end

        READ: begin
          if (iSclFall) begin
            if (RdByteDoneSeen) begin
              SdaDriveLow_d      = 1'b0;
              RdByteDoneSeen_d = 1'b0;
              state_d            = READ_ACK;
            end else begin
              SdaDriveLow_d = AddrMatched && !iRdByteData[iBitCnt];
            end
          end

          if (iSclRise && iByteComplete) begin
            RdByteDoneSeen_d = 1'b1;
          end
        end

        READ_ACK: begin
          SdaDriveLow_d = 1'b0;
          if (iSclRise) begin
            if (!iSdaSample) begin
              state_d            = READ;
              RdByteDoneSeen_d = 1'b0;
            end else begin
              state_d            = IDLE;
              RdByteDoneSeen_d = 1'b0;
            end
          end
        end

        IGNORE: begin
          SdaDriveLow_d      = 1'b0;
          RdByteDoneSeen_d = 1'b0;
        end

        default: begin
          state_d            = IDLE;
          SdaDriveLow_d      = 1'b0;
          AckDriveActive_d   = 1'b0;
          AckHighSeen_d      = 1'b0;
          RdByteDoneSeen_d = 1'b0;
        end
      endcase
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      state <= IDLE;
    end else begin
      state <= state_d;
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      ackTarget        <= IDLE;
      AddrMatched      <= 1'b0;
      SdaDriveLow      <= 1'b0;
      AckDriveActive   <= 1'b0;
      AckHighSeen      <= 1'b0;
      RdByteDoneSeen <= 1'b0;
    end else begin
      ackTarget        <= ackTarget_d;
      AddrMatched      <= AddrMatched_d;
      SdaDriveLow      <= SdaDriveLow_d;
      AckDriveActive   <= AckDriveActive_d;
      AckHighSeen      <= AckHighSeen_d;
      RdByteDoneSeen <= RdByteDoneSeen_d;
    end
  end

endmodule
