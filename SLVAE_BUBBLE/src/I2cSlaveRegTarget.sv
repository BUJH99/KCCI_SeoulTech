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
  input  logic        iRstn,
  input  logic        iScl,
  input  logic        iSdaIn,
  input  logic [31:0] iSlaveId,
  input  logic [7:0]  iDisplayMode,
  input  logic [31:0] iStatus,
  input  logic [15:0] iLastFrameId,
  input  logic [15:0] iErrorCode,
  input  logic [7:0]  iBrightness,
  input  logic [15:0] iCompareCount,
  input  logic [15:0] iSwapCount,
  input  logic [15:0] iTotalCount,

  output logic        oSdaOut,
  output logic        oSdaOe,
  output logic        oDisplayModeWriteEn,
  output logic [7:0]  oDisplayModeWriteData,
  output logic        oBrightnessWriteEn,
  output logic [7:0]  oBrightnessWriteData,
  output logic [15:0] oErrorClearMask,
  output logic        oInvalidRegPulse
);

  logic       sclRise;
  logic       sclFall;
  logic       startSeen;
  logic       stopSeen;
  logic       sdaSample;
  logic [7:0] shiftNext;
  logic [2:0] bitCnt;
  logic       byteComplete;
  logic       byteResetPulse;
  logic       shiftInPulse;
  logic       readBitAdvancePulse;
  logic       regPtrLoadPulse;
  logic [7:0] regPtrLoadAddr;
  logic       regPtrIncPulse;
  logic [7:0] regPtr;
  logic       writeBytePulse;
  logic [7:0] writeByteData;
  logic       readByteStartPulse;
  logic [7:0] readByteData;
  logic       addrMatched;
  logic       sdaDriveLow;

  I2cSlaveInputSync uI2cSlaveInputSync (
    .iClk        (iClk),
    .iRstn       (iRstn),
    .iScl        (iScl),
    .iSdaIn      (iSdaIn),
    .oSclRise    (sclRise),
    .oSclFall    (sclFall),
    .oStartSeen  (startSeen),
    .oStopSeen   (stopSeen),
    .oSdaSample  (sdaSample)
  );

  I2cSlaveByteShift uI2cSlaveByteShift (
    .iClk                 (iClk),
    .iRstn                (iRstn),
    .iSdaSample           (sdaSample),
    .iByteResetPulse      (byteResetPulse),
    .iShiftInPulse        (shiftInPulse),
    .iReadBitAdvancePulse (readBitAdvancePulse),
    .oShiftNext           (shiftNext),
    .oBitCnt              (bitCnt),
    .oByteComplete        (byteComplete)
  );

  I2cSlaveRegPointer uI2cSlaveRegPointer (
    .iClk           (iClk),
    .iRstn          (iRstn),
    .iLoadPulse     (regPtrLoadPulse),
    .iLoadAddr      (regPtrLoadAddr),
    .iIncrementPulse(regPtrIncPulse),
    .oRegPtr        (regPtr)
  );

  I2cSlaveRegMap uI2cSlaveRegMap (
    .iClk                  (iClk),
    .iRstn                 (iRstn),
    .iAddrMatched          (addrMatched),
    .iRegPtr               (regPtr),
    .iWriteBytePulse       (writeBytePulse),
    .iWriteByteData        (writeByteData),
    .iReadByteStartPulse   (readByteStartPulse),
    .iSlaveId              (iSlaveId),
    .iDisplayMode          (iDisplayMode),
    .iStatus               (iStatus),
    .iLastFrameId          (iLastFrameId),
    .iErrorCode            (iErrorCode),
    .iBrightness           (iBrightness),
    .iCompareCount         (iCompareCount),
    .iSwapCount            (iSwapCount),
    .iTotalCount           (iTotalCount),
    .oReadByteData         (readByteData),
    .oDisplayModeWriteEn   (oDisplayModeWriteEn),
    .oDisplayModeWriteData (oDisplayModeWriteData),
    .oBrightnessWriteEn    (oBrightnessWriteEn),
    .oBrightnessWriteData  (oBrightnessWriteData),
    .oErrorClearMask       (oErrorClearMask),
    .oInvalidRegPulse      (oInvalidRegPulse)
  );

  I2cSlaveProtocolFsm #(
    .P_I2C_ADDR (P_I2C_ADDR)
  ) uI2cSlaveProtocolFsm (
    .iClk                 (iClk),
    .iRstn                (iRstn),
    .iSclRise             (sclRise),
    .iSclFall             (sclFall),
    .iStartSeen           (startSeen),
    .iStopSeen            (stopSeen),
    .iSdaSample           (sdaSample),
    .iShiftNext           (shiftNext),
    .iBitCnt              (bitCnt),
    .iByteComplete        (byteComplete),
    .iReadByteData        (readByteData),
    .oByteResetPulse      (byteResetPulse),
    .oShiftInPulse        (shiftInPulse),
    .oReadBitAdvancePulse (readBitAdvancePulse),
    .oRegPtrLoadPulse     (regPtrLoadPulse),
    .oRegPtrLoadAddr      (regPtrLoadAddr),
    .oRegPtrIncPulse      (regPtrIncPulse),
    .oWriteBytePulse      (writeBytePulse),
    .oWriteByteData       (writeByteData),
    .oReadByteStartPulse  (readByteStartPulse),
    .oAddrMatched         (addrMatched),
    .oSdaDriveLow         (sdaDriveLow)
  );

  I2cSlaveOpenDrainDrive uI2cSlaveOpenDrainDrive (
    .iSdaDriveLow (sdaDriveLow),
    .oSdaOut      (oSdaOut),
    .oSdaOe       (oSdaOe)
  );

endmodule
