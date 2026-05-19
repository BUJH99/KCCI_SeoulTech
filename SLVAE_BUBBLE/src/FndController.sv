/*
[MODULE_INFO_START]
Name: FndController
Role: FND 스캔, 자리 선택, 점멸 효과를 통합 제어하는 모듈
Summary:
  - 1kHz 스캔 기준으로 자리 인덱스를 순환하며 출력합니다.
  - BCD 디코딩과 점멸/DP 처리를 결합해 최종 세그먼트 신호를 생성합니다.
[MODULE_INFO_END]
*/
`timescale 1ns / 1ps

module FndController (
    input  logic        iClk,
    input  logic        iRst,
    input  logic        iTick1kHz,
    input  logic        iTick2Hz,
    input  logic [15:0] iDigitsBcd,
    input  logic [3:0]  iBlinkMask,
    input  logic [3:0]  iDpMask,
    output logic [6:0]  oSeg,
    output logic        oDp,
    output logic [3:0]  oDigitSel
);

    logic [1:0] ScanIdx;
    logic [3:0] CurBcd;
    logic       CurBlink;
    logic       CurDp;
    logic       Blanking;

    FndScanCounter uFndScanCounter (
        .iClk      (iClk),
        .iRst      (iRst),
        .iTick1kHz (iTick1kHz),
        .oScanIdx  (ScanIdx)
    );

    FndDigitSelector uFndDigitSelector (
        .iScanIdx   (ScanIdx),
        .iDigitsBcd (iDigitsBcd),
        .iBlinkMask (iBlinkMask),
        .iDpMask    (iDpMask),
        .oDigitSel  (oDigitSel),
        .oCurBcd    (CurBcd),
        .oCurBlink  (CurBlink),
        .oCurDp     (CurDp)
    );

    FndBlinkEffect uFndBlinkEffect (
        .iClk      (iClk),
        .iRst      (iRst),
        .iTick2Hz  (iTick2Hz),
        .iCurBlink (CurBlink),
        .iCurDp    (CurDp),
        .oBlanking (Blanking),
        .oFinalDp  (oDp)
    );

    FndBcdDecoder uFndBcdDecoder (
        .iCurBcd   (CurBcd),
        .iBlanking (Blanking),
        .oSeg      (oSeg)
    );
endmodule
