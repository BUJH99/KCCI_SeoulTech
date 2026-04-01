/*
[MODULE_INFO_START]
Name: sync_2ff
Role: 비동기 입력을 위한 2단 플립플롭 동기화기
Summary:
  - 메타안정성 전파를 줄이기 위해 2단 레지스터를 사용합니다.
  - 단일 비트 신호를 안전하게 동기화해 출력합니다.
[MODULE_INFO_END]
*/
module sync_2ff (
    input  wire  iAsync,
    input  wire  iClk,
    input  wire  iRst,
    output wire  oSync
);

    reg      rSync_d1;
    reg      rSync_d2;

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            rSync_d1 <= 1'b0;
            rSync_d2 <= 1'b0;
        end else begin
            rSync_d1 <= iAsync;
            rSync_d2 <= rSync_d1;
        end
    end

    assign oSync = rSync_d2;

endmodule
