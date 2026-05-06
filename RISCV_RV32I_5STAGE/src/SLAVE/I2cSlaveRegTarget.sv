/*
[MODULE_INFO_START]
Name: I2cSlaveRegTarget
Role: Minimal I2C register target for the SLAVE display/status contract
Summary:
  - Implements a compact 7-bit-addressed I2C target for register pointer, writes, and reads
  - Exposes write pulses for DISPLAY_MODE, ERROR_CODE W1C, and BRIGHTNESS registers
  - Reads SLAVE_ID, DISPLAY_MODE, STATUS, LAST_FRAME_ID, ERROR_CODE, and BRIGHTNESS bytes
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveRegTarget #(
  parameter logic [6:0] P_I2C_ADDR = 7'h42
) (
  input  logic       iClk,
  input  logic       iRstn,
  input  logic       iScl,
  input  logic       iSdaIn,
  input  logic [7:0] iSlaveId,
  input  logic [1:0] iDisplayMode,
  input  logic [7:0] iStatus,
  input  logic [7:0] iLastFrameId,
  input  logic [7:0] iErrorCode,
  input  logic [7:0] iBrightness,

  output logic       oSdaOut,
  output logic       oSdaOe,
  output logic       oDisplayModeWriteEn,
  output logic [7:0] oDisplayModeWriteData,
  output logic       oBrightnessWriteEn,
  output logic [7:0] oBrightnessWriteData,
  output logic [7:0] oErrorClearMask
);

  typedef enum logic [2:0] {
    LP_I2C_IDLE,
    LP_I2C_ADDR,
    LP_I2C_REG,
    LP_I2C_WRITE,
    LP_I2C_READ,
    LP_I2C_ACK
  } i2c_state_e;

  i2c_state_e State;
  i2c_state_e ReturnState;

  logic       Scl_d1;
  logic       Scl_d2;
  logic       Sda_d1;
  logic       Sda_d2;
  logic [7:0] ShiftReg;
  logic [7:0] ShiftNext;
  logic [7:0] ReadData;
  logic [7:0] RegPtr;
  logic [2:0] BitCnt;
  logic       ReadTransfer;
  logic       AddrMatched;
  logic       SclRise;
  logic       SclFall;
  logic       StartSeen;
  logic       StopSeen;

  assign SclRise   = Scl_d1 && !Scl_d2;
  assign SclFall   = !Scl_d1 && Scl_d2;
  assign StartSeen = Scl_d1 && Sda_d2 && !Sda_d1;
  assign StopSeen  = Scl_d1 && !Sda_d2 && Sda_d1;
  assign ShiftNext = {ShiftReg[6:0], Sda_d1};
  assign oSdaOut   = 1'b0;

  always_comb begin
    unique case (RegPtr)
      8'h00:   ReadData = iSlaveId;
      8'h04:   ReadData = {6'd0, iDisplayMode};
      8'h08:   ReadData = iStatus;
      8'h0C:   ReadData = iLastFrameId;
      8'h10:   ReadData = iErrorCode;
      8'h14:   ReadData = iBrightness;
      default: ReadData = 8'd0;
    endcase
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      Scl_d1                <= 1'b1;
      Scl_d2                <= 1'b1;
      Sda_d1                <= 1'b1;
      Sda_d2                <= 1'b1;
      State                 <= LP_I2C_IDLE;
      ReturnState           <= LP_I2C_IDLE;
      ShiftReg              <= '0;
      RegPtr                <= '0;
      BitCnt                <= '0;
      ReadTransfer          <= 1'b0;
      AddrMatched           <= 1'b0;
      oSdaOe                <= 1'b0;
      oDisplayModeWriteEn   <= 1'b0;
      oDisplayModeWriteData <= '0;
      oBrightnessWriteEn    <= 1'b0;
      oBrightnessWriteData  <= '0;
      oErrorClearMask       <= '0;
    end else begin
      Scl_d1              <= iScl;
      Scl_d2              <= Scl_d1;
      Sda_d1              <= iSdaIn;
      Sda_d2              <= Sda_d1;
      oDisplayModeWriteEn <= 1'b0;
      oBrightnessWriteEn  <= 1'b0;
      oErrorClearMask     <= '0;

      if (StartSeen) begin
        State       <= LP_I2C_ADDR;
        BitCnt      <= 3'd7;
        ShiftReg    <= '0;
        oSdaOe      <= 1'b0;
        AddrMatched <= 1'b0;
      end else if (StopSeen) begin
        State  <= LP_I2C_IDLE;
        oSdaOe <= 1'b0;
      end else begin
        unique case (State)
          LP_I2C_IDLE: begin
            oSdaOe <= 1'b0;
          end

          LP_I2C_ADDR: begin
            if (SclRise) begin
              ShiftReg <= ShiftNext;
              if (BitCnt == 3'd0) begin
                AddrMatched  <= (ShiftNext[7:1] == P_I2C_ADDR);
                ReadTransfer <= ShiftNext[0];
                ReturnState  <= ShiftNext[0] ? LP_I2C_READ : LP_I2C_REG;
                State        <= LP_I2C_ACK;
              end else begin
                BitCnt <= BitCnt - 1'b1;
              end
            end
          end

          LP_I2C_REG: begin
            if (SclRise) begin
              ShiftReg <= ShiftNext;
              if (BitCnt == 3'd0) begin
                RegPtr      <= ShiftNext;
                ReturnState <= LP_I2C_WRITE;
                State       <= LP_I2C_ACK;
              end else begin
                BitCnt <= BitCnt - 1'b1;
              end
            end
          end

          LP_I2C_WRITE: begin
            if (SclRise) begin
              ShiftReg <= ShiftNext;
              if (BitCnt == 3'd0) begin
                unique case (RegPtr)
                  8'h04: begin
                    oDisplayModeWriteEn   <= AddrMatched;
                    oDisplayModeWriteData <= ShiftNext;
                  end
                  8'h10: begin
                    oErrorClearMask <= AddrMatched ? ShiftNext : 8'd0;
                  end
                  8'h14: begin
                    oBrightnessWriteEn   <= AddrMatched;
                    oBrightnessWriteData <= ShiftNext;
                  end
                  default: begin
                  end
                endcase

                RegPtr      <= RegPtr + 8'd4;
                ReturnState <= LP_I2C_WRITE;
                State       <= LP_I2C_ACK;
              end else begin
                BitCnt <= BitCnt - 1'b1;
              end
            end
          end

          LP_I2C_READ: begin
            if (SclFall) begin
              oSdaOe   <= AddrMatched && !ReadData[BitCnt];
              ShiftReg <= ReadData;
              if (BitCnt == 3'd0) begin
                RegPtr      <= RegPtr + 8'd4;
                ReturnState <= LP_I2C_READ;
                State       <= LP_I2C_ACK;
              end else begin
                BitCnt <= BitCnt - 1'b1;
              end
            end
          end

          LP_I2C_ACK: begin
            oSdaOe <= AddrMatched;
            if (SclFall) begin
              oSdaOe <= 1'b0;
              BitCnt <= 3'd7;
              State  <= ReturnState;
            end
          end

          default: begin
            State <= LP_I2C_IDLE;
          end
        endcase
      end
    end
  end

endmodule
