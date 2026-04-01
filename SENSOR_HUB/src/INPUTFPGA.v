/*
[MODULE_INFO_START]
Name: INPUTFPGA
Role: FPGA 물리 입력 경로를 정리해 상위 제어로 전달하는 모듈
Summary:
  - 버튼 입력은 디바운스를 거쳐 펄스로 변환합니다.
  - 스위치 입력은 동기화해 안정적인 레벨 신호로 출력합니다.
[MODULE_INFO_END]
*/
module INPUTFPGA(
    input  wire [4:0] iBtnAsync,
    input  wire [2:0] iSwAsync,
    input  wire       iClk,
    input  wire       iRst,
    output wire [4:0] oBtnPulse,
    output wire [2:0] oSwLevel
);

    DebounceWrapper uDebounceWrapper (
        .iBtnAsync   (iBtnAsync),
        .iClk        (iClk),
        .iRst        (iRst),
        .oBtnPulse   (oBtnPulse)
    );

    SwitchInput uSwitchInput (
        .iSwAsync(iSwAsync),
        .iClk    (iClk),
        .iRst    (iRst),
        .oSwLevel(oSwLevel)
    );

endmodule
