/*
[MODULE_INFO_START]
Name: CounterFilter
Role: 입력 신호의 안정 시간을 카운터로 확인하는 필터
Summary:
  - 입력 변화가 설정된 기간 동안 유지될 때만 출력을 갱신합니다.
  - 짧은 글리치를 제거해 디바운스 품질을 높입니다.
[MODULE_INFO_END]
*/
module CounterFilter #(

    parameter MAX_COUNT = 1999999 
)(
    input  wire iClk,
    input  wire iRst,
    input  wire iIn,
    output reg  oOut
);

    localparam CNT_WIDTH = $clog2(MAX_COUNT);

    reg [CNT_WIDTH-1:0] cnt;

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            cnt  <= 0;
            oOut <= 1'b0;
        end else if (iIn == oOut) begin
            cnt  <= 0;
        end else if (cnt == MAX_COUNT) begin
            cnt  <= 0;
            oOut <= iIn;
        end else begin
            cnt  <= cnt + 1'b1;
        end
    end

endmodule