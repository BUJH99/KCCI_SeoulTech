/*
[MODULE_INFO_START]
Name: I2cMasterCtrl
Role: I2C master transaction FSM, divider, timeout, and error-pulse controller
Summary:
  - Sequences START, address, register, data, repeated START, ACK/NACK, STOP, and DONE phases
  - Owns divider ticks, timeout/error latches, RX-valid/DONE pulses, and open-drain drive requests
  - Delegates byte shift, bit count, ACK capture, and RX byte assembly to I2cMasterDatapath
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cMasterCtrl (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iCoreRstPulse,
  input  logic        iStartAttemptPulse,
  input  logic        iStartAcceptedPulse,
  input  logic        iInvalidCmdPulse,
  input  logic        iRwLatch,
  input  logic [2:0]  iLenLatch,
  input  logic [15:0] iClkDivLatch,
  input  logic [31:0] iWdataLatch,
  input  logic        iSdaInSync,
  input  logic        iTxBit,
  input  logic [2:0]  iBitCnt,
  input  logic        iAckBit,
  input  logic [7:0]  iRxByteData,
  input  logic        iRxByteCompletePulse,

  output logic        oBusy,
  output logic        oStartIdleWindow,
  output logic        oDonePulse,
  output logic        oRxValidPulse,
  output logic        oAckOk,
  output logic [31:0] oRxData,
  output logic        oNackPulse,
  output logic        oArbLostPulse,
  output logic        oBusErrPulse,
  output logic        oTimeoutPulse,
  output logic        oLoadAddrWrPulse,
  output logic        oLoadRegAddrPulse,
  output logic        oLoadAddrRdPulse,
  output logic        oLoadWrBytePulse,
  output logic [7:0]  oWrByteData,
  output logic        oPrepareRdPulse,
  output logic        oNextRdBytePulse,
  output logic        oTxBitAdvancePulse,
  output logic        oRxSamplePulse,
  output logic        oRxBitAdvancePulse,
  output logic        oAckCapturePulse,
  output logic        oSclDriveLow,
  output logic        oSdaDriveLow
);

  typedef enum logic [4:0] {
    IDLE,
    START_HIGH,
    START_SDA_LOW,
    START_SCL_LOW,
    TX_SETUP,
    TX_HIGH,
    TX_LOW,
    ACK_SETUP,
    ACK_HIGH,
    ACK_LOW,
    RX_SETUP,
    RX_HIGH,
    RX_LOW,
    MACK_SETUP,
    MACK_HIGH,
    MACK_LOW,
    STOP_SDA_LOW,
    STOP_SCL_HIGH,
    STOP_SDA_RELEASE,
    DONE
  } state_e;

  typedef enum logic [2:0] {
    SEG_ADDR_WR,
    SEG_REG_ADDR,
    SEG_WRITE_DATA,
    SEG_ADDR_RD,
    SEG_READ_DATA
  } segment_e;

  localparam logic [23:0] LP_TIMEOUT_CYCLES = 24'hFF_FFFF;

  state_e   state;
  state_e   state_d;
  segment_e segment;

  logic [2:0]  ByteIdx;
  logic [15:0] ClkDivCnt;
  logic [23:0] TimeoutCnt;
  logic        Tick;
  logic        TickWillAssert;
  logic        TimeoutNow;
  logic        AckFailed;
  logic        ErrLatched;
  logic        NackSamplePulse;
  logic        ArbLostNow;
  logic        RdMoreBytes;
  logic        LoadAddrWrPulse_d;
  logic        LoadRegAddrPulse_d;
  logic        LoadAddrRdPulse_d;
  logic        LoadWrBytePulse_d;
  logic        PrepareRdPulse_d;
  logic        NextRdBytePulse_d;
  logic        TxBitAdvancePulse_d;
  logic        RxSamplePulse_d;
  logic        RxBitAdvancePulse_d;
  logic        AckCapturePulse_d;

  assign Tick             = (ClkDivCnt == iClkDivLatch);
  assign TickWillAssert   = (iClkDivLatch == 16'd0) ? Tick : (ClkDivCnt == (iClkDivLatch - 1'b1));
  assign TimeoutNow       = oBusy && !ErrLatched && (TimeoutCnt == LP_TIMEOUT_CYCLES);
  assign RdMoreBytes    = ((ByteIdx + 1'b1) < iLenLatch);
  assign NackSamplePulse       = oAckCapturePulse && iAckBit;
  assign ArbLostNow            = (state == TX_HIGH) && Tick && iTxBit && !iSdaInSync;

  always_comb begin
    oBusy            = 1'b0;
    oStartIdleWindow = 1'b0;

    unique case (state)
      IDLE: begin
        oStartIdleWindow = 1'b1;
      end

      DONE: begin
      end

      default: begin
        oBusy = 1'b1;
      end
    endcase
  end

  always_comb begin
    unique case (ByteIdx[1:0])
      2'd0: begin
        oWrByteData = ((segment == SEG_REG_ADDR) && !iRwLatch) ? iWdataLatch[7:0] : iWdataLatch[15:8];
      end

      2'd1: begin
        oWrByteData = iWdataLatch[23:16];
      end

      default: begin
        oWrByteData = iWdataLatch[31:24];
      end
    endcase
  end

  always_comb begin
    LoadAddrWrPulse_d    = 1'b0;
    LoadRegAddrPulse_d   = 1'b0;
    LoadAddrRdPulse_d    = 1'b0;
    LoadWrBytePulse_d = 1'b0;
    PrepareRdPulse_d   = 1'b0;
    NextRdBytePulse_d  = 1'b0;
    TxBitAdvancePulse_d  = 1'b0;
    RxSamplePulse_d      = 1'b0;
    RxBitAdvancePulse_d  = 1'b0;
    AckCapturePulse_d    = 1'b0;

    if (!iCoreRstPulse) begin
      unique case (state)
        START_SCL_LOW: begin
          LoadAddrWrPulse_d = TickWillAssert && (segment == SEG_ADDR_WR);
        end

        ACK_LOW: begin
          if (TickWillAssert && !AckFailed) begin
            LoadRegAddrPulse_d   = (segment == SEG_ADDR_WR);
            LoadAddrRdPulse_d    = (segment == SEG_REG_ADDR) && iRwLatch;
            LoadWrBytePulse_d = ((segment == SEG_REG_ADDR) && !iRwLatch)
                                || ((segment == SEG_WRITE_DATA) && RdMoreBytes);
            PrepareRdPulse_d   = (segment == SEG_ADDR_RD);
          end
        end

        TX_LOW: begin
          TxBitAdvancePulse_d = TickWillAssert && (iBitCnt != 3'd0);
        end

        ACK_HIGH: begin
          AckCapturePulse_d = TickWillAssert;
        end

        RX_HIGH: begin
          RxSamplePulse_d = TickWillAssert;
        end

        RX_LOW: begin
          RxBitAdvancePulse_d = TickWillAssert && (iBitCnt != 3'd0);
        end

        MACK_LOW: begin
          NextRdBytePulse_d = TickWillAssert && RdMoreBytes;
        end

        default: begin
        end
      endcase
    end
  end

  always_comb begin
    oSclDriveLow = 1'b0;
    oSdaDriveLow = 1'b0;

    unique case (state)
      START_SDA_LOW: begin
        oSdaDriveLow = 1'b1;
      end

      START_SCL_LOW,
      TX_SETUP,
      TX_LOW: begin
        oSclDriveLow = 1'b1;
        oSdaDriveLow = !iTxBit;
      end

      TX_HIGH: begin
        oSdaDriveLow = !iTxBit;
      end

      ACK_SETUP,
      ACK_LOW,
      RX_SETUP,
      RX_LOW: begin
        oSclDriveLow = 1'b1;
      end

      MACK_SETUP,
      MACK_LOW: begin
        oSclDriveLow = 1'b1;
        oSdaDriveLow = RdMoreBytes;
      end

      MACK_HIGH: begin
        oSdaDriveLow = RdMoreBytes;
      end

      STOP_SDA_LOW: begin
        oSclDriveLow = 1'b1;
        oSdaDriveLow = 1'b1;
      end

      STOP_SCL_HIGH: begin
        oSdaDriveLow = 1'b1;
      end

      default: begin
      end
    endcase
  end

  always_comb begin
    state_d = state;

    if (iCoreRstPulse) begin
      state_d = IDLE;
    end else if (TimeoutNow || ArbLostNow) begin
      state_d = STOP_SDA_LOW;
    end else begin
      unique case (state)
        IDLE: begin
          if (iStartAttemptPulse) begin
            state_d = iStartAcceptedPulse ? START_HIGH : DONE;
          end
        end

        START_HIGH: begin
          if (Tick) begin
            state_d = START_SDA_LOW;
          end
        end

        START_SDA_LOW: begin
          if (Tick) begin
            state_d = START_SCL_LOW;
          end
        end

        START_SCL_LOW: begin
          if (Tick) begin
            state_d = TX_SETUP;
          end
        end

        TX_SETUP: begin
          if (Tick) begin
            state_d = TX_HIGH;
          end
        end

        TX_HIGH: begin
          if (Tick) begin
            state_d = TX_LOW;
          end
        end

        TX_LOW: begin
          if (Tick) begin
            state_d = (iBitCnt == 3'd0) ? ACK_SETUP : TX_SETUP;
          end
        end

        ACK_SETUP: begin
          if (Tick) begin
            state_d = ACK_HIGH;
          end
        end

        ACK_HIGH: begin
          if (Tick) begin
            state_d = ACK_LOW;
          end
        end

        ACK_LOW: begin
          if (Tick) begin
            if (AckFailed) begin
              state_d = STOP_SDA_LOW;
            end else begin
              unique case (segment)
                SEG_ADDR_WR: begin
                  state_d = TX_SETUP;
                end

                SEG_REG_ADDR: begin
                  state_d = iRwLatch ? START_HIGH : TX_SETUP;
                end

                SEG_WRITE_DATA: begin
                  state_d = RdMoreBytes ? TX_SETUP : STOP_SDA_LOW;
                end

                SEG_ADDR_RD: begin
                  state_d = RX_SETUP;
                end

                default: begin
                  state_d = STOP_SDA_LOW;
                end
              endcase
            end
          end
        end

        RX_SETUP: begin
          if (Tick) begin
            state_d = RX_HIGH;
          end
        end

        RX_HIGH: begin
          if (Tick) begin
            state_d = RX_LOW;
          end
        end

        RX_LOW: begin
          if (Tick) begin
            state_d = (iBitCnt == 3'd0) ? MACK_SETUP : RX_SETUP;
          end
        end

        MACK_SETUP: begin
          if (Tick) begin
            state_d = MACK_HIGH;
          end
        end

        MACK_HIGH: begin
          if (Tick) begin
            state_d = MACK_LOW;
          end
        end

        MACK_LOW: begin
          if (Tick) begin
            state_d = RdMoreBytes ? RX_SETUP : STOP_SDA_LOW;
          end
        end

        STOP_SDA_LOW: begin
          if (Tick) begin
            state_d = STOP_SCL_HIGH;
          end
        end

        STOP_SCL_HIGH: begin
          if (Tick) begin
            state_d = STOP_SDA_RELEASE;
          end
        end

        STOP_SDA_RELEASE: begin
          if (Tick) begin
            state_d = DONE;
          end
        end

        DONE: begin
          state_d = IDLE;
        end

        default: begin
          state_d = IDLE;
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
      oLoadAddrWrPulse    <= 1'b0;
      oLoadRegAddrPulse   <= 1'b0;
      oLoadAddrRdPulse    <= 1'b0;
      oLoadWrBytePulse <= 1'b0;
      oPrepareRdPulse   <= 1'b0;
      oNextRdBytePulse  <= 1'b0;
      oTxBitAdvancePulse  <= 1'b0;
      oRxSamplePulse      <= 1'b0;
      oRxBitAdvancePulse  <= 1'b0;
      oAckCapturePulse    <= 1'b0;
    end else begin
      oLoadAddrWrPulse    <= LoadAddrWrPulse_d;
      oLoadRegAddrPulse   <= LoadRegAddrPulse_d;
      oLoadAddrRdPulse    <= LoadAddrRdPulse_d;
      oLoadWrBytePulse <= LoadWrBytePulse_d;
      oPrepareRdPulse   <= PrepareRdPulse_d;
      oNextRdBytePulse  <= NextRdBytePulse_d;
      oTxBitAdvancePulse  <= TxBitAdvancePulse_d;
      oRxSamplePulse      <= RxSamplePulse_d;
      oRxBitAdvancePulse  <= RxBitAdvancePulse_d;
      oAckCapturePulse    <= AckCapturePulse_d;
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      ClkDivCnt  <= '0;
      TimeoutCnt <= '0;
    end else begin
      if (iCoreRstPulse) begin
        ClkDivCnt  <= '0;
        TimeoutCnt <= '0;
      end else if (oBusy) begin
        TimeoutCnt <= TimeoutCnt + 1'b1;
        if (Tick) begin
          ClkDivCnt <= '0;
        end else begin
          ClkDivCnt <= ClkDivCnt + 1'b1;
        end
      end else begin
        ClkDivCnt  <= '0;
        TimeoutCnt <= '0;
      end
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      AckFailed     <= 1'b0;
      ErrLatched  <= 1'b0;
      oNackPulse    <= 1'b0;
      oArbLostPulse <= 1'b0;
      oBusErrPulse <= 1'b0;
      oTimeoutPulse <= 1'b0;
    end else begin
      oNackPulse     <= 1'b0;
      oArbLostPulse  <= 1'b0;
      oBusErrPulse <= 1'b0;
      oTimeoutPulse  <= 1'b0;

      if (iCoreRstPulse) begin
        AckFailed    <= 1'b0;
        ErrLatched <= 1'b0;
      end else begin
        if (iStartAttemptPulse) begin
          AckFailed    <= 1'b0;
          ErrLatched <= !iStartAcceptedPulse;
          if (iInvalidCmdPulse) begin
            oBusErrPulse <= 1'b1;
          end
        end

        if (TimeoutNow) begin
          ErrLatched <= 1'b1;
          oTimeoutPulse <= 1'b1;
        end

        if (ArbLostNow) begin
          ErrLatched <= 1'b1;
          oArbLostPulse <= 1'b1;
        end

        if (NackSamplePulse) begin
          AckFailed    <= 1'b1;
          ErrLatched <= 1'b1;
          oNackPulse   <= 1'b1;
        end
      end
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      segment       <= SEG_ADDR_WR;
      ByteIdx       <= '0;
      oDonePulse    <= 1'b0;
      oRxValidPulse <= 1'b0;
      oAckOk        <= 1'b0;
      oRxData       <= '0;
    end else begin
      oDonePulse    <= 1'b0;
      oRxValidPulse <= 1'b0;

      if (iCoreRstPulse) begin
        segment <= SEG_ADDR_WR;
        ByteIdx <= '0;
        oAckOk  <= 1'b0;
      end else begin
        unique case (state)
          IDLE: begin
            if (iStartAttemptPulse) begin
              segment <= SEG_ADDR_WR;
              ByteIdx <= '0;
              oAckOk  <= 1'b0;
              oRxData <= '0;
            end
          end

          ACK_LOW: begin
            if (Tick && !AckFailed) begin
              unique case (segment)
                SEG_ADDR_WR: begin
                  segment <= SEG_REG_ADDR;
                end

                SEG_REG_ADDR: begin
                  if (iRwLatch) begin
                    segment <= SEG_ADDR_RD;
                  end else begin
                    segment <= SEG_WRITE_DATA;
                    ByteIdx <= '0;
                  end
                end

                SEG_WRITE_DATA: begin
                  if (RdMoreBytes) begin
                    ByteIdx <= ByteIdx + 1'b1;
                  end
                end

                SEG_ADDR_RD: begin
                  segment <= SEG_READ_DATA;
                  ByteIdx <= '0;
                end

                default: begin
                end
              endcase
            end
          end

          RX_HIGH: begin
            if (iRxByteCompletePulse) begin
              unique case (ByteIdx[1:0])
                2'd0: begin
                  oRxData[7:0] <= iRxByteData;
                end

                2'd1: begin
                  oRxData[15:8] <= iRxByteData;
                end

                2'd2: begin
                  oRxData[23:16] <= iRxByteData;
                end

                default: begin
                  oRxData[31:24] <= iRxByteData;
                end
              endcase
            end
          end

          MACK_LOW: begin
            if (Tick && RdMoreBytes) begin
              ByteIdx <= ByteIdx + 1'b1;
            end
          end

          DONE: begin
            oDonePulse    <= !ErrLatched;
            oRxValidPulse <= !ErrLatched && iRwLatch;
            oAckOk        <= !ErrLatched;
          end

          default: begin
          end
        endcase
      end
    end
  end

endmodule
