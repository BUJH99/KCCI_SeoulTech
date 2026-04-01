/*
[MODULE_INFO_START]
Name: DebounceWrapper
Role: 다중 버튼 채널에 Debounce를 적용하는 래퍼
Summary:
  - 버튼 채널 수만큼 Debounce 인스턴스를 생성합니다.
  - 각 버튼의 안정화된 펄스를 벡터 형태로 제공합니다.
[MODULE_INFO_END]
*/
module DebounceWrapper(
    input  wire [4:0] iBtnAsync,
    input  wire       iClk,
    input  wire       iRst,
    output wire [4:0] oBtnPulse
);

    genvar idxBtn;
    generate
        for (idxBtn = 0; idxBtn < 5; idxBtn = idxBtn + 1) begin: genDebounce
            Debounce uDebounce (
                .iClk        (iClk),
                .iRst        (iRst),
                .iBtnAsync   (iBtnAsync[idxBtn]),
                .oBtnPulse   (oBtnPulse[idxBtn])
            );
        end
    endgenerate

endmodule
