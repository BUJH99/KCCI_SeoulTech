/*
[MODULE_INFO_START]
Name: DoubleDabble
Role: 이진수를 BCD로 변환하는 Double Dabble 알고리즘 모듈
Summary:
  - 14비트 이진 입력을 4자리 BCD 출력으로 변환합니다.
  - FND 표시와 ASCII 포맷팅에 공통으로 사용할 수 있는 BCD 값을 생성합니다.
[MODULE_INFO_END]
*/
module DoubleDabble (
    input  wire [13:0] iBin,
    output reg  [15:0] oBcd
);
    integer i;
    always @(*) begin
        oBcd = 16'd0;
        for (i = 13; i >= 0; i = i - 1) begin
            if (oBcd[3:0] >= 5)   oBcd[3:0]   = oBcd[3:0] + 3;
            if (oBcd[7:4] >= 5)   oBcd[7:4]   = oBcd[7:4] + 3;
            if (oBcd[11:8] >= 5)  oBcd[11:8]  = oBcd[11:8] + 3;
            if (oBcd[15:12] >= 5) oBcd[15:12] = oBcd[15:12] + 3;
            oBcd = {oBcd[14:0], iBin[i]};
        end
    end
endmodule
