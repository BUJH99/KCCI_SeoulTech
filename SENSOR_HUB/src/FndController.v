/*
[MODULE_INFO_START]
Name: FndController
Role: FND 스캔, 자리 선택, 점멸 효과를 통합 제어하는 모듈
Summary:
  - 1kHz 스캔 기준으로 자리 인덱스를 순환하며 출력합니다.
  - BCD 디코딩과 점멸/DP 처리를 결합해 최종 세그먼트 신호를 생성합니다.
[MODULE_INFO_END]
*/
module FndController (
    input  wire        iClk,
    input  wire        iRst,       // Active-high
    input  wire        iTick1kHz,   // FND ?????? ?????? (1ms)
    input  wire        iTick2Hz,    // ??????????(0.5s Pulse)
    input  wire [15:0] iDigitsBcd,  // 4??? BCD ???
    input  wire [3:0]  iBlinkMask,  // ????????????? ?????
    input  wire [3:0]  iDpMask,     // ?????DP ??? ?????
    output wire [6:0]  oSeg,        // 7-Segment (Active-Low)
    output wire        oDp,         // Decimal Point (Active-Low)
    output wire [3:0]  oDigitSel    // Anode Select (Active-Low)
);

    wire [1:0] wScanIdx;
    wire [3:0] wCurBcd;
    wire       wCurBlink;
    wire       wCurDp;
    wire       wBlanking;

    // 4-1. ???????? ????? ??? ???
    FndScanCounter uFndScanCounter (
        .iClk      (iClk),
        .iRst     (iRst),
        .iTick1kHz (iTick1kHz),
        .oScanIdx  (wScanIdx)
    );

    // 4-2. ???????? ??????????????? ???
    FndDigitSelector uFndDigitSelector (
        .iScanIdx   (wScanIdx),
        .iDigitsBcd (iDigitsBcd),
        .iBlinkMask (iBlinkMask),
        .iDpMask    (iDpMask),
        .oDigitSel  (oDigitSel),
        .oCurBcd    (wCurBcd),
        .oCurBlink  (wCurBlink),
        .oCurDp     (wCurDp)
    );

    // 4-3. ???????????????? ???
    FndBlinkEffect uFndBlinkEffect (
        .iClk       (iClk),
        .iRst      (iRst),
        .iTick2Hz   (iTick2Hz),
        .iCurBlink  (wCurBlink),
        .iCurDp     (wCurDp),
        .oBlanking  (wBlanking),
        .oFinalDp   (oDp)
    );

    // 4-4. ??? 7-Segment ????????????
    FndBcdDecoder uFndBcdDecoder (
        .iCurBcd    (wCurBcd),
        .iBlanking  (wBlanking),
        .oSeg       (oSeg)
    );

endmodule

