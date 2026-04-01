/*
[MODULE_INFO_START]
Name: SwitchInput
Role: 비동기 스위치 입력을 시스템 클록 도메인으로 동기화하는 모듈
Summary:
  - 각 스위치 비트에 2단 동기화기를 적용합니다.
  - 상위 제어 로직이 사용할 안정적인 스위치 레벨을 출력합니다.
[MODULE_INFO_END]
*/
module SwitchInput(
    input  wire [2:0] iSwAsync,
    input  wire       iClk,
    input  wire       iRst,
    output wire [2:0] oSwLevel
);

    genvar idxSw;
    generate
        for (idxSw = 0; idxSw < 3; idxSw = idxSw + 1) begin: genSwSync
            sync_2ff uSwSync2ff (
                .iAsync(iSwAsync[idxSw]),
                .iClk  (iClk),
                .iRst  (iRst),
                .oSync (oSwLevel[idxSw])
            );
        end
    endgenerate

endmodule
