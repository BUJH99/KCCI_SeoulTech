/*
[MODULE_INFO_START]
Name: TimerReg
Role: APB-facing register block for the timer peripheral
Summary:
  - Implements timer register decode, readback, byte-strobe write handling, and PSLVERR policy
  - Stores control/configuration registers and tracks sticky IRQ, match, and overflow status bits
  - Converts COUNT writes and CLEAR_COUNT commands into core pulses while reading COUNT from TimerCore
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TimerReg #(
  parameter int unsigned P_CLK_HZ = 25_000_000
) (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iAccessEn,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic [31:0] iCoreCnt,
  input  logic        iCoreMatchPulse,
  input  logic        iCoreOverflowPulse,

  output logic [31:0] oPrdata,
  output logic        oPslverr,
  output logic        oCtrlEn,
  output logic        oCtrlPeriodic,
  output logic        oCtrlIntEn,
  output logic        oClearCntPulse,
  output logic        oCntWrPulse,
  output logic [31:0] oCntWrData,
  output logic [31:0] oPrescale,
  output logic [31:0] oPeriod,
  output logic [31:0] oCompare,
  output logic        oTimerIrqPending
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_TIMER_CTRL_OFFSET     = 12'h000;
  localparam logic [11:0] LP_TIMER_STATUS_OFFSET   = 12'h004;
  localparam logic [11:0] LP_TIMER_PRESCALE_OFFSET = 12'h008;
  localparam logic [11:0] LP_TIMER_PERIOD_OFFSET   = 12'h00C;
  localparam logic [11:0] LP_TIMER_COUNT_OFFSET    = 12'h010;
  localparam logic [11:0] LP_TIMER_COMPARE_OFFSET  = 12'h014;
  localparam logic [11:0] LP_TIMER_INFO_OFFSET     = 12'h018;

  localparam int unsigned LP_CTRL_ENABLE_BIT      = 0;
  localparam int unsigned LP_CTRL_PERIODIC_BIT    = 1;
  localparam int unsigned LP_CTRL_INT_ENABLE_BIT  = 2;
  localparam int unsigned LP_CTRL_CLEAR_COUNT_BIT = 3;
  localparam int unsigned LP_CTRL_START_BIT       = 4;
  localparam int unsigned LP_CTRL_STOP_BIT        = 5;

  localparam int unsigned LP_STATUS_IRQ_PENDING_BIT = 0;
  localparam int unsigned LP_STATUS_MATCH_BIT       = 1;
  localparam int unsigned LP_STATUS_OVERFLOW_BIT    = 2;
  localparam int unsigned LP_STATUS_RUNNING_BIT     = 8;

  localparam logic [2:0]  LP_STATUS_W1C_MASK = 3'b111;
  localparam logic [31:0] LP_TIMER_INFO      = 32'h0007_2001;
  localparam int unsigned LP_DEFAULT_PRESCALE = (P_CLK_HZ >= 1000)
                                              ? ((P_CLK_HZ / 1000) - 1)
                                              : 0;
  localparam logic [31:0] LP_DEFAULT_PRESCALE_WORD = LP_DEFAULT_PRESCALE;

  logic        WrEn;
  logic        OffsetValid;
  logic        IllegalWr;
  logic [31:0] WrData;
  logic [31:0] CtrlWord;
  logic [31:0] StatusWord;
  logic        CtrlEn;
  logic        CtrlPeriodic;
  logic        CtrlIntEn;
  logic [31:0] Prescale;
  logic [31:0] Period;
  logic [31:0] Compare;
  logic [2:0]  StatusSticky;
  logic        CtrlEn_d;
  logic        CtrlPeriodic_d;
  logic        CtrlIntEn_d;
  logic [31:0] Prescale_d;
  logic [31:0] Period_d;
  logic [31:0] Compare_d;
  logic [2:0]  StatusSticky_d;

  assign WrEn         = iAccessEn && iPwrite;
  assign WrData       = ByteWriteMerge(32'd0, iPwdata, iPstrb);
  assign IllegalWr    = WrEn && (iPaddr == LP_TIMER_INFO_OFFSET);
  assign oPslverr        = iAccessEn && (!OffsetValid || IllegalWr);
  assign oCtrlEn     = CtrlEn_d;
  assign oCtrlPeriodic   = CtrlPeriodic_d;
  assign oCtrlIntEn  = CtrlIntEn_d;
  assign oPrescale       = Prescale_d;
  assign oPeriod         = Period_d;
  assign oCompare        = Compare_d;
  assign oCntWrData = WrData;
  assign oTimerIrqPending = CtrlIntEn && StatusSticky[LP_STATUS_IRQ_PENDING_BIT];

  always_comb begin
    OffsetValid = 1'b1;

    unique case (iPaddr)
      LP_TIMER_CTRL_OFFSET,
      LP_TIMER_STATUS_OFFSET,
      LP_TIMER_PRESCALE_OFFSET,
      LP_TIMER_PERIOD_OFFSET,
      LP_TIMER_COUNT_OFFSET,
      LP_TIMER_COMPARE_OFFSET,
      LP_TIMER_INFO_OFFSET: begin
        OffsetValid = 1'b1;
      end

      default: begin
        OffsetValid = 1'b0;
      end
    endcase
  end

  always_comb begin
    CtrlWord   = '0;
    StatusWord = '0;

    CtrlWord[LP_CTRL_ENABLE_BIT]     = CtrlEn;
    CtrlWord[LP_CTRL_PERIODIC_BIT]   = CtrlPeriodic;
    CtrlWord[LP_CTRL_INT_ENABLE_BIT] = CtrlIntEn;

    StatusWord[LP_STATUS_IRQ_PENDING_BIT] = StatusSticky[LP_STATUS_IRQ_PENDING_BIT];
    StatusWord[LP_STATUS_MATCH_BIT]       = StatusSticky[LP_STATUS_MATCH_BIT];
    StatusWord[LP_STATUS_OVERFLOW_BIT]    = StatusSticky[LP_STATUS_OVERFLOW_BIT];
    StatusWord[LP_STATUS_RUNNING_BIT]     = CtrlEn;
  end

  always_comb begin
    oPrdata = '0;

    unique case (iPaddr)
      LP_TIMER_CTRL_OFFSET:     oPrdata = CtrlWord;
      LP_TIMER_STATUS_OFFSET:   oPrdata = StatusWord;
      LP_TIMER_PRESCALE_OFFSET: oPrdata = Prescale;
      LP_TIMER_PERIOD_OFFSET:   oPrdata = Period;
      LP_TIMER_COUNT_OFFSET:    oPrdata = iCoreCnt;
      LP_TIMER_COMPARE_OFFSET:  oPrdata = Compare;
      LP_TIMER_INFO_OFFSET:     oPrdata = LP_TIMER_INFO;
      default: begin
      end
    endcase
  end

  always_comb begin
    CtrlEn_d      = CtrlEn;
    CtrlPeriodic_d    = CtrlPeriodic;
    CtrlIntEn_d   = CtrlIntEn;
    Prescale_d        = Prescale;
    Period_d          = Period;
    Compare_d         = Compare;
    StatusSticky_d    = StatusSticky;
    oClearCntPulse  = 1'b0;
    oCntWrPulse  = 1'b0;

    if (WrEn && !oPslverr) begin
      unique case (iPaddr)
        LP_TIMER_CTRL_OFFSET: begin
          CtrlEn_d     = WrData[LP_CTRL_ENABLE_BIT];
          CtrlPeriodic_d   = WrData[LP_CTRL_PERIODIC_BIT];
          CtrlIntEn_d  = WrData[LP_CTRL_INT_ENABLE_BIT];
          oClearCntPulse = WrData[LP_CTRL_CLEAR_COUNT_BIT];

          if (WrData[LP_CTRL_START_BIT]) begin
            CtrlEn_d = 1'b1;
          end

          if (WrData[LP_CTRL_STOP_BIT]) begin
            CtrlEn_d = 1'b0;
          end
        end

        LP_TIMER_STATUS_OFFSET: begin
          StatusSticky_d = StatusSticky & ~WrData[2:0];
        end

        LP_TIMER_PRESCALE_OFFSET: begin
          Prescale_d = WrData;
        end

        LP_TIMER_PERIOD_OFFSET: begin
          Period_d = WrData;
        end

        LP_TIMER_COUNT_OFFSET: begin
          oCntWrPulse = 1'b1;
        end

        LP_TIMER_COMPARE_OFFSET: begin
          Compare_d = WrData;
        end

        default: begin
        end
      endcase
    end

    if (iCoreMatchPulse) begin
      StatusSticky_d[LP_STATUS_IRQ_PENDING_BIT] = 1'b1;
      StatusSticky_d[LP_STATUS_MATCH_BIT]       = 1'b1;
    end

    if (iCoreOverflowPulse) begin
      StatusSticky_d[LP_STATUS_IRQ_PENDING_BIT] = 1'b1;
      StatusSticky_d[LP_STATUS_OVERFLOW_BIT]    = 1'b1;
    end

    StatusSticky_d = StatusSticky_d & LP_STATUS_W1C_MASK;
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      CtrlEn    <= 1'b0;
      CtrlPeriodic  <= 1'b0;
      CtrlIntEn <= 1'b0;
      Prescale      <= LP_DEFAULT_PRESCALE_WORD;
      Period        <= '0;
      Compare       <= '1;
      StatusSticky  <= '0;
    end else begin
      CtrlEn    <= CtrlEn_d;
      CtrlPeriodic  <= CtrlPeriodic_d;
      CtrlIntEn <= CtrlIntEn_d;
      Prescale      <= Prescale_d;
      Period        <= Period_d;
      Compare       <= Compare_d;
      StatusSticky  <= StatusSticky_d;
    end
  end

endmodule
