/*
[MODULE_INFO_START]
Name: EdgePulse
Role: 레벨 신호의 상승 에지를 1클록 펄스로 바꾸는 모듈
Summary:
  - 이전 샘플과 현재 샘플을 비교해 상승 에지를 검출합니다.
  - 검출 시점에 한 클록 동안만 펄스를 출력합니다.
[MODULE_INFO_END]
*/
module EdgePulse (
    input  wire iClk,
    input  wire iRst,
    input  wire iLevel,
    output wire oPulse
);

    reg level_d1;

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            level_d1 <= 1'b0;
        end else begin
            level_d1 <= iLevel;
        end
    end

    assign oPulse = iLevel & ~level_d1;

endmodule
