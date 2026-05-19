/*
[MODULE_INFO_START]
Name: I2cSlaveRegTarget
Role: Wrapper for the SLAVE I2C register target
Summary:
  - Preserves the SortDisplaySlaveTop-facing I2C register target contract
  - Wires input sync, protocol FSM, byte shifter, register pointer, register map, and SDA drive blocks
  - Keeps I2C bus timing independent from display/status register decode
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cSlaveRegTarget #(
  parameter logic [6:0] P_I2C_ADDR = 7'h42
) (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iScl,
  input  logic        iSdaIn,
  input  logic [31:0] iSlaveId,
  input  logic [7:0]  iDisplayMode,
  input  logic [31:0] iStatus,
  input  logic [15:0] iLastFrameId,
  input  logic [15:0] iErrCode,
  input  logic [7:0]  iBrightness,
  input  logic [15:0] iCompareCnt,
  input  logic [15:0] iSwapCnt,
  input  logic [15:0] iTotalCnt,

  output logic        oSdaOut,
  output logic        oSdaOe,
  output logic        oDisplayModeWrEn,
  output logic [7:0]  oDisplayModeWrData,
  output logic        oBrightnessWrEn,
  output logic [7:0]  oBrightnessWrData,
  output logic [15:0] oErrClearMask,
  output logic        oInvalidRegPulse
);

  logic       SclRise;
  logic       SclFall;
  logic       StartSeen;
  logic       StopSeen;
  logic       SdaSample;
  logic [7:0] ShiftNext;
  logic [2:0] BitCnt;
  logic       ByteComplete;
  logic       ByteRstPulse;
  logic       ShiftInPulse;
  logic       RdBitAdvancePulse;
  logic       RegPtrLoadPulse;
  logic [7:0] RegPtrLoadAddr;
  logic       RegPtrIncPulse;
  logic [7:0] RegPtr;
  logic       WrBytePulse;
  logic [7:0] WrByteData;
  logic       RdByteStartPulse;
  logic [7:0] RdByteData;
  logic       AddrMatched;
  logic       SdaDriveLow;

  I2cSlaveInputSync uI2cSlaveInputSync (
    .iClk        (iClk),
    .iRst       (iRst),
    .iScl        (iScl),
    .iSdaIn      (iSdaIn),
    .oSclRise    (SclRise),
    .oSclFall    (SclFall),
    .oStartSeen  (StartSeen),
    .oStopSeen   (StopSeen),
    .oSdaSample  (SdaSample)
  );

  I2cSlaveByteShift uI2cSlaveByteShift (
    .iClk                 (iClk),
    .iRst                (iRst),
    .iSdaSample           (SdaSample),
    .iByteRstPulse      (ByteRstPulse),
    .iShiftInPulse        (ShiftInPulse),
    .iRdBitAdvancePulse (RdBitAdvancePulse),
    .oShiftNext           (ShiftNext),
    .oBitCnt              (BitCnt),
    .oByteComplete        (ByteComplete)
  );

  I2cSlaveRegPointer uI2cSlaveRegPointer (
    .iClk           (iClk),
    .iRst          (iRst),
    .iLoadPulse     (RegPtrLoadPulse),
    .iLoadAddr      (RegPtrLoadAddr),
    .iIncrementPulse(RegPtrIncPulse),
    .oRegPtr        (RegPtr)
  );

  I2cSlaveRegMap uI2cSlaveRegMap (
    .iClk                  (iClk),
    .iRst                 (iRst),
    .iAddrMatched          (AddrMatched),
    .iRegPtr               (RegPtr),
    .iWrBytePulse       (WrBytePulse),
    .iWrByteData        (WrByteData),
    .iRdByteStartPulse   (RdByteStartPulse),
    .iSlaveId              (iSlaveId),
    .iDisplayMode          (iDisplayMode),
    .iStatus               (iStatus),
    .iLastFrameId          (iLastFrameId),
    .iErrCode            (iErrCode),
    .iBrightness           (iBrightness),
    .iCompareCnt         (iCompareCnt),
    .iSwapCnt            (iSwapCnt),
    .iTotalCnt           (iTotalCnt),
    .oRdByteData         (RdByteData),
    .oDisplayModeWrEn   (oDisplayModeWrEn),
    .oDisplayModeWrData (oDisplayModeWrData),
    .oBrightnessWrEn    (oBrightnessWrEn),
    .oBrightnessWrData  (oBrightnessWrData),
    .oErrClearMask       (oErrClearMask),
    .oInvalidRegPulse      (oInvalidRegPulse)
  );

  I2cSlaveProtocolFsm #(
    .P_I2C_ADDR (P_I2C_ADDR)
  ) uI2cSlaveProtocolFsm (
    .iClk                 (iClk),
    .iRst                (iRst),
    .iSclRise             (SclRise),
    .iSclFall             (SclFall),
    .iStartSeen           (StartSeen),
    .iStopSeen            (StopSeen),
    .iSdaSample           (SdaSample),
    .iShiftNext           (ShiftNext),
    .iBitCnt              (BitCnt),
    .iByteComplete        (ByteComplete),
    .iRdByteData        (RdByteData),
    .oByteRstPulse      (ByteRstPulse),
    .oShiftInPulse        (ShiftInPulse),
    .oRdBitAdvancePulse (RdBitAdvancePulse),
    .oRegPtrLoadPulse     (RegPtrLoadPulse),
    .oRegPtrLoadAddr      (RegPtrLoadAddr),
    .oRegPtrIncPulse      (RegPtrIncPulse),
    .oWrBytePulse      (WrBytePulse),
    .oWrByteData       (WrByteData),
    .oRdByteStartPulse  (RdByteStartPulse),
    .oAddrMatched         (AddrMatched),
    .oSdaDriveLow         (SdaDriveLow)
  );

  I2cSlaveOpenDrainDrive uI2cSlaveOpenDrainDrive (
    .iSdaDriveLow (SdaDriveLow),
    .oSdaOut      (oSdaOut),
    .oSdaOe       (oSdaOe)
  );

endmodule
