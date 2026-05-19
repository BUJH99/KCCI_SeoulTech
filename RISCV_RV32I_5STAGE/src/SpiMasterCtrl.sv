/*
[MODULE_INFO_START]
Name: SpiMasterCtrl
Role: Frame FSM, divider, SCLK phase, and status-pulse controller for the SPI master core
Summary:
  - Sequences CS assertion, TX byte load/pop, byte transfer, CS deassertion, and DONE
  - Owns the SPI half-period divider and mode0 SCLK phase generation
  - Emits busy, done, TX FIFO pop, and underflow pulses for the APB register block
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiMasterCtrl (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iStartAttemptPulse,
  input  logic        iStartAcceptedPulse,
  input  logic [7:0]  iFrameLenLatch,
  input  logic [15:0] iClkDivLatch,
  input  logic        iTxFifoValid,
  input  logic        iByteDonePulse,

  output logic        oBusy,
  output logic        oDonePulse,
  output logic        oTxFifoPopPulse,
  output logic        oTxUnderflowPulse,
  output logic        oCsActive,
  output logic        oAssertCsActive,
  output logic        oLoadActive,
  output logic        oTransferActive,
  output logic        oDeassertCsActive,
  output logic        oStartIdleWindow,
  output logic        oStartDropWindow,
  output logic        oHalfPeriodDone,
  output logic        oSclkLevel
);

  typedef enum logic [2:0] {
    IDLE,
    ASSERT_CS,
    LOAD,
    TRANSFER,
    DEASSERT_CS,
    DONE
  } state_e;

  state_e state;
  state_e state_d;

  logic [7:0]  ByteCnt;
  logic [15:0] ClkDivCnt;
  logic        ErrLatched;

  always_comb begin
    state_d = state;

    unique case (state)
      IDLE: begin
        if (iStartAttemptPulse) begin
          state_d = iStartAcceptedPulse ? ASSERT_CS : DONE;
        end
      end

      ASSERT_CS: begin
        state_d = LOAD;
      end

      LOAD: begin
        if (oTxFifoPopPulse) begin
          state_d = TRANSFER;
        end else if (iTxFifoValid) begin
          state_d = LOAD;
        end else begin
          state_d = DEASSERT_CS;
        end
      end

      TRANSFER: begin
        if (iByteDonePulse) begin
          state_d = (ByteCnt == (iFrameLenLatch - 1'b1)) ? DEASSERT_CS : LOAD;
        end
      end

      DEASSERT_CS: begin
        state_d = DONE;
      end

      DONE: begin
        state_d = IDLE;
      end

      default: begin
        state_d = IDLE;
      end
    endcase
  end

  always_comb begin
    oBusy             = 1'b0;
    oCsActive         = 1'b0;
    oAssertCsActive   = 1'b0;
    oLoadActive       = 1'b0;
    oTransferActive   = 1'b0;
    oDeassertCsActive = 1'b0;
    oStartIdleWindow  = 1'b0;
    oStartDropWindow  = 1'b0;
    oHalfPeriodDone   = (ClkDivCnt == iClkDivLatch);

    unique case (state)
      IDLE: begin
        oStartIdleWindow = 1'b1;
      end

      ASSERT_CS: begin
        oBusy           = 1'b1;
        oCsActive       = 1'b1;
        oAssertCsActive = 1'b1;
        oStartDropWindow = 1'b1;
      end

      LOAD: begin
        oBusy            = 1'b1;
        oCsActive        = 1'b1;
        oLoadActive      = 1'b1;
        oStartDropWindow = 1'b1;
      end

      TRANSFER: begin
        oBusy            = 1'b1;
        oCsActive        = 1'b1;
        oTransferActive  = 1'b1;
        oStartDropWindow = 1'b1;
      end

      DEASSERT_CS: begin
        oBusy             = 1'b1;
        oDeassertCsActive = 1'b1;
        oStartDropWindow  = 1'b1;
      end

      default: begin
      end
    endcase
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
      ByteCnt <= '0;
    end else begin
      unique case (state)
        IDLE,
        ASSERT_CS: begin
          ByteCnt <= '0;
        end

        TRANSFER: begin
          if (iByteDonePulse) begin
            ByteCnt <= ByteCnt + 1'b1;
          end
        end

        default: begin
        end
      endcase
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      ClkDivCnt  <= '0;
      oSclkLevel <= 1'b0;
    end else begin
      if (state == TRANSFER) begin
        if (ClkDivCnt == iClkDivLatch) begin
          ClkDivCnt  <= '0;
          oSclkLevel <= ~oSclkLevel;
        end else begin
          ClkDivCnt <= ClkDivCnt + 1'b1;
        end
      end else begin
        ClkDivCnt  <= '0;
        oSclkLevel <= 1'b0;
      end
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      ErrLatched      <= 1'b0;
      oDonePulse        <= 1'b0;
      oTxFifoPopPulse   <= 1'b0;
      oTxUnderflowPulse <= 1'b0;
    end else begin
      oDonePulse        <= 1'b0;
      oTxFifoPopPulse   <= ((state == LOAD) || (state_d == LOAD)) && iTxFifoValid && !oTxFifoPopPulse;
      oTxUnderflowPulse <= 1'b0;

      unique case (state)
        IDLE: begin
          if (iStartAttemptPulse) begin
            ErrLatched <= !iStartAcceptedPulse;
          end
        end

        LOAD: begin
          if (!iTxFifoValid) begin
            ErrLatched      <= 1'b1;
            oTxUnderflowPulse <= 1'b1;
          end
        end

        DONE: begin
          oDonePulse <= !ErrLatched;
        end

        default: begin
        end
      endcase
    end
  end

endmodule
