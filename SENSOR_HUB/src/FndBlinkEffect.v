/*
[MODULE_INFO_START]
Name: FndBlinkEffect
Role: 점멸 마스크와 DP 정보를 반영해 최종 표시 신호를 만드는 모듈
Summary:
  - 2Hz 토글 신호를 기반으로 자리별 점멸 여부를 결정합니다.
  - 점멸 상태와 DP 입력을 조합해 최종 표시 제어를 출력합니다.
[MODULE_INFO_END]
*/
module FndBlinkEffect (
    input  wire       iClk,
    input  wire       iRst,
    input  wire       iTick2Hz,
    input  wire       iCurBlink,
    input  wire       iCurDp,
    output wire       oBlanking,
    output wire       oFinalDp
);
    reg blinkToggle;

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            blinkToggle <= 1'b0;
        end else if (iTick2Hz) begin
            blinkToggle <= ~blinkToggle;
        end
    end

    assign oBlanking = (iCurBlink == 1'b1) && (blinkToggle == 1'b0);
    assign oFinalDp  = iCurDp ? ~blinkToggle : 1'b1; // Active Low
endmodule

