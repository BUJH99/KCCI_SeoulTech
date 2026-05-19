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
  input  logic       iRstn,
  input  logic       iSclRise,
  input  logic       iSclFall,
  input  logic       iStartSeen,
  input  logic       iStopSeen,
  input  logic       iSdaSample,
  input  logic [7:0] iShiftNext,
  input  logic [2:0] iBitCnt,
  input  logic       iByteComplete,
  input  logic [7:0] iReadByteData,

  output logic       oByteResetPulse,
  output logic       oShiftInPulse,
  output logic       oReadBitAdvancePulse,
  output logic       oRegPtrLoadPulse,
  output logic [7:0] oRegPtrLoadAddr,
  output logic       oRegPtrIncPulse,
  output logic       oWriteBytePulse,
  output logic [7:0] oWriteByteData,
  output logic       oReadByteStartPulse,
  output logic       oAddrMatched,
  output logic       oSdaDriveLow
);

  typedef enum logic [2:0] {
    S_IDLE,
    S_ADDR,
    S_ACK_DRIVE,
    S_REG,
    S_WRITE,
    S_READ,
    S_READ_ACK,
    S_IGNORE
  } state_e;

  state_e state;
  state_e stateAfterAck;
  logic   ackDriveActive;
  logic   ackHighSeen;
  logic   readByteDoneSeen;

  assign oShiftInPulse        = !iStartSeen && !iStopSeen && iSclRise
                              && ((state == S_ADDR) || (state == S_REG) || (state == S_WRITE));
  assign oReadBitAdvancePulse = !iStartSeen && !iStopSeen && iSclRise && (state == S_READ);
  assign oByteResetPulse      = iStartSeen
                              || (!iStopSeen && (state == S_ACK_DRIVE) && iSclFall && ackHighSeen)
                              || (!iStopSeen && (state == S_READ_ACK) && iSclRise && !iSdaSample);
  assign oRegPtrLoadPulse     = !iStartSeen && !iStopSeen && (state == S_REG) && iSclRise && iByteComplete;
  assign oRegPtrLoadAddr      = iShiftNext;
  assign oWriteBytePulse      = !iStartSeen && !iStopSeen && (state == S_WRITE) && iSclRise && iByteComplete;
  assign oWriteByteData       = iShiftNext;
  assign oRegPtrIncPulse      = oWriteBytePulse
                              || (!iStartSeen && !iStopSeen && (state == S_READ) && iSclRise && iByteComplete);
  assign oReadByteStartPulse  = !iStartSeen && !iStopSeen && (state == S_READ) && iSclFall && (iBitCnt == 3'd7);

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      state         <= S_IDLE;
      stateAfterAck <= S_IDLE;
      oAddrMatched  <= 1'b0;
      oSdaDriveLow  <= 1'b0;
      ackDriveActive <= 1'b0;
      ackHighSeen    <= 1'b0;
      readByteDoneSeen <= 1'b0;
    end else begin
      if (iStartSeen) begin
        state          <= S_ADDR;
        oAddrMatched   <= 1'b0;
        oSdaDriveLow   <= 1'b0;
        ackDriveActive <= 1'b0;
        ackHighSeen    <= 1'b0;
        readByteDoneSeen <= 1'b0;
      end else if (iStopSeen) begin
        state          <= S_IDLE;
        oSdaDriveLow   <= 1'b0;
        ackDriveActive <= 1'b0;
        ackHighSeen    <= 1'b0;
        readByteDoneSeen <= 1'b0;
      end else begin
        unique case (state)
          S_IDLE: begin
            oSdaDriveLow   <= 1'b0;
            ackDriveActive <= 1'b0;
            ackHighSeen    <= 1'b0;
            readByteDoneSeen <= 1'b0;
          end

          S_ADDR: begin
            if (iSclRise && iByteComplete) begin
              oAddrMatched   <= (iShiftNext[7:1] == P_I2C_ADDR);
              stateAfterAck  <= iShiftNext[0] ? S_READ : S_REG;
              state          <= S_ACK_DRIVE;
              ackDriveActive <= 1'b0;
              ackHighSeen    <= 1'b0;
              readByteDoneSeen <= 1'b0;
            end
          end

          S_ACK_DRIVE: begin
            if (!ackDriveActive) begin
              oSdaDriveLow <= 1'b0;
              if (iSclFall) begin
                ackDriveActive <= 1'b1;
                oSdaDriveLow   <= oAddrMatched;
              end
            end else begin
              oSdaDriveLow <= oAddrMatched;
              if (iSclRise) begin
                ackHighSeen <= 1'b1;
              end

              if (iSclFall && ackHighSeen) begin
                oSdaDriveLow   <= oAddrMatched && (stateAfterAck == S_READ) && !iReadByteData[3'd7];
                ackDriveActive <= 1'b0;
                ackHighSeen    <= 1'b0;
                readByteDoneSeen <= 1'b0;
                state          <= oAddrMatched ? stateAfterAck : S_IGNORE;
              end
            end
          end

          S_REG: begin
            if (iSclRise && iByteComplete) begin
              stateAfterAck  <= S_WRITE;
              state          <= S_ACK_DRIVE;
              ackDriveActive <= 1'b0;
              ackHighSeen    <= 1'b0;
              readByteDoneSeen <= 1'b0;
            end
          end

          S_WRITE: begin
            if (iSclRise && iByteComplete) begin
              stateAfterAck  <= S_WRITE;
              state          <= S_ACK_DRIVE;
              ackDriveActive <= 1'b0;
              ackHighSeen    <= 1'b0;
              readByteDoneSeen <= 1'b0;
            end
          end

          S_READ: begin
            if (iSclFall) begin
              if (readByteDoneSeen) begin
                oSdaDriveLow     <= 1'b0;
                readByteDoneSeen <= 1'b0;
                state            <= S_READ_ACK;
              end else begin
                oSdaDriveLow <= oAddrMatched && !iReadByteData[iBitCnt];
              end
            end

            if (iSclRise && iByteComplete) begin
              readByteDoneSeen <= 1'b1;
            end
          end

          S_READ_ACK: begin
            oSdaDriveLow <= 1'b0;
            if (iSclRise) begin
              if (!iSdaSample) begin
                state            <= S_READ;
                readByteDoneSeen <= 1'b0;
              end else begin
                state            <= S_IDLE;
                readByteDoneSeen <= 1'b0;
              end
            end
          end

          S_IGNORE: begin
            oSdaDriveLow     <= 1'b0;
            readByteDoneSeen <= 1'b0;
          end

          default: begin
            state          <= S_IDLE;
            oSdaDriveLow   <= 1'b0;
            ackDriveActive <= 1'b0;
            ackHighSeen    <= 1'b0;
            readByteDoneSeen <= 1'b0;
          end
        endcase
      end
    end
  end

endmodule
