/*
[MODULE_INFO_START]
Name: FndBlinkEffect
Role: 점멸 마스크와 DP 정보를 반영해 최종 표시 신호를 만드는 모듈
Summary:
  - 2Hz 토글 신호를 기반으로 자리별 점멸 여부를 결정합니다.
  - 점멸 상태와 DP 입력을 조합해 최종 표시 제어를 출력합니다.
[MODULE_INFO_END]
*/
`timescale 1ns / 1ps

module FndBlinkEffect (
    input  logic iClk,
    input  logic iRst,
    input  logic iTick2Hz,
    input  logic iCurBlink,
    input  logic iCurDp,
    output logic oBlanking,
    output logic oFinalDp
);
    logic BlinkToggle;

    always_ff @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            BlinkToggle <= 1'b0;
        end else if (iTick2Hz) begin
            BlinkToggle <= ~BlinkToggle;
        end
    end

    assign oBlanking = iCurBlink && !BlinkToggle;
    assign oFinalDp  = iCurDp ? ~BlinkToggle : 1'b1;
endmodule
