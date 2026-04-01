/*
[MODULE_INFO_START]
Name: BcdCounter
Role: 2자리 BCD 값을 증감하고 캐리를 제공하는 범용 카운터
Summary:
  - 증가/감소/틱 조건에 따라 BCD 값을 갱신합니다.
  - 설정된 최대값에 도달하면 롤오버와 캐리 출력을 제공합니다.
[MODULE_INFO_END]
*/
module BcdCounter #(
    parameter P_MAX_TENS = 5,
    parameter P_MAX_ONES = 9,
    parameter P_RST_TENS = 0,
    parameter P_RST_ONES = 0
)(
    input  wire       iClk,
    input  wire       iRst,

    // Controls
    input  wire       iTick,  // 다음 자리 증가 틱 (Pulse)
    input  wire       iInc,   // 강제 증가 (Pulse)
    input  wire       iDec,   // 강제 감소 (Pulse)
    input  wire       iReset, // 동기 리셋 (초기화)

    // Outputs
    output reg  [3:0] oTens,
    output reg  [3:0] oOnes,
    output wire       oCarry  // 최대값 도달 시 iTick에서 발생하는 캐리 출력
);

    reg [3:0] tens_d, ones_d;

    // Tick 발생 시 현재 값이 최대값(MAX_TENS, MAX_ONES)과 일치하면 캐리 발생
    assign oCarry = iTick && (oTens == P_MAX_TENS) && (oOnes == P_MAX_ONES);

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            oTens <= P_RST_TENS[3:0];
            oOnes <= P_RST_ONES[3:0];
        end else begin
            oTens <= tens_d;
            oOnes <= ones_d;
        end
    end

    // Combinational logic for counting
    always @(*) begin
        // 기본값 유지
        tens_d = oTens;
        ones_d = oOnes;

        if (iReset) begin
            tens_d = P_RST_TENS[3:0];
            ones_d = P_RST_ONES[3:0];
        end else if (iInc || iTick) begin
            // 최대값에 도달하면 00으로 롤오버
            if (oTens == P_MAX_TENS && oOnes == P_MAX_ONES) begin
                tens_d = 4'd0;
                ones_d = 4'd0;
            end else if (oOnes == 4'd9) begin
                // 1의 자리가 9일 때 -> 10의 자리는 1 증가, 1의 자리는 0
                tens_d = oTens + 1'b1;
                ones_d = 4'd0;
            end else begin
                // 1의 자리만 1 증가
                ones_d = oOnes + 1'b1;
            end
        end else if (iDec) begin
            // 00 언더플로우 -> 최대값으로 롤백
            if (oTens == 4'd0 && oOnes == 4'd0) begin
                tens_d = P_MAX_TENS;
                ones_d = P_MAX_ONES;
            end else if (oOnes == 4'd0) begin
                // 1의 자리가 0일 때 -> 10의 자리는 1 감소, 1의 자리는 9
                tens_d = oTens - 1'b1;
                ones_d = 4'd9;
            end else begin
                // 1의 자리만 1 감소
                ones_d = oOnes - 1'b1;
            end
        end
    end

endmodule
