/*
[MODULE_INFO_START]
Name: APB_Timer
Role: APB timer wrapper for register and timer-core submodules
Summary:
  - Preserves the external APB timer slave contract and machine timer pending output
  - Delegates register decode, storage, readback, sticky status, and PSLVERR policy to TimerReg
  - Delegates prescale/count/period/compare datapath and event pulse generation to TimerCore
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APB_Timer #(
  parameter int unsigned P_CLK_HZ = 25_000_000
) (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iPsel,
  input  logic        iPenable,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,

  output logic [31:0] oPrdata,
  output logic        oPready,
  output logic        oPslverr,
  output logic        oTimerIrqPending
);

  logic        AccessEn;
  logic        CtrlEn;
  logic        CtrlPeriodic;
  logic        CtrlIntEn;
  logic        ClearCntPulse;
  logic        CntWrPulse;
  logic [31:0] CntWrData;
  logic [31:0] Prescale;
  logic [31:0] Period;
  logic [31:0] Cnt;
  logic [31:0] Compare;
  logic        MatchPulse;
  logic        OverflowPulse;

  assign oPready  = 1'b1;
  assign AccessEn = iPsel && iPenable && oPready;

  TimerReg #(
    .P_CLK_HZ(P_CLK_HZ)
  ) uTimerReg (
    .iClk              (iClk),
    .iRst              (iRst),
    .iAccessEn         (AccessEn),
    .iPwrite           (iPwrite),
    .iPaddr            (iPaddr),
    .iPstrb            (iPstrb),
    .iPwdata           (iPwdata),
    .iCoreCnt        (Cnt),
    .iCoreMatchPulse   (MatchPulse),
    .iCoreOverflowPulse(OverflowPulse),
    .oPrdata           (oPrdata),
    .oPslverr          (oPslverr),
    .oCtrlEn       (CtrlEn),
    .oCtrlPeriodic     (CtrlPeriodic),
    .oCtrlIntEn    (CtrlIntEn),
    .oClearCntPulse  (ClearCntPulse),
    .oCntWrPulse  (CntWrPulse),
    .oCntWrData   (CntWrData),
    .oPrescale         (Prescale),
    .oPeriod           (Period),
    .oCompare          (Compare),
    .oTimerIrqPending  (oTimerIrqPending)
  );

  TimerCore uTimerCore (
    .iClk            (iClk),
    .iRst            (iRst),
    .iEn         (CtrlEn),
    .iPeriodic       (CtrlPeriodic),
    .iClearCntPulse(ClearCntPulse),
    .iCntWrPulse(CntWrPulse),
    .iCntWrData (CntWrData),
    .iPrescale       (Prescale),
    .iPeriod         (Period),
    .iCompare        (Compare),
    .oCnt          (Cnt),
    .oMatchPulse     (MatchPulse),
    .oOverflowPulse  (OverflowPulse)
  );

endmodule
