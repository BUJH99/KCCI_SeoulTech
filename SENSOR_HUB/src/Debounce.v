/*
[MODULE_INFO_START]
Name: Debounce
Role: 단일 버튼 입력을 동기화하고 디바운스하는 모듈
Summary:
  - sync_2ff로 비동기 입력을 시스템 클록 도메인으로 동기화합니다.
  - CounterFilter와 에지 검출을 통해 1클록 버튼 펄스를 생성합니다.
[MODULE_INFO_END]
*/
module Debounce (
    input  wire iClk,
    input  wire iRst,
    input  wire iBtnAsync,
    output wire oBtnPulse
);

    wire sync2Filter_Sync;
    wire wDebouncedLevel;

    sync_2ff uSync2ff (
        .iAsync(iBtnAsync),
        .iClk  (iClk),
        .iRst  (iRst),
        .oSync (sync2Filter_Sync)
    );

    CounterFilter #(
        .MAX_COUNT(1999999)
    ) uCounterFilter (
        .iClk(iClk),
        .iRst(iRst),
        .iIn (sync2Filter_Sync),
        .oOut(wDebouncedLevel)
    );

    EdgePulse uEdgePulse (
        .iClk  (iClk),
        .iRst  (iRst),
        .iLevel(wDebouncedLevel),
        .oPulse(oBtnPulse)
    );

endmodule
