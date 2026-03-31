/*
[MODULE_INFO_START]
Name: sync_2ff
Role: 비동기 입력을 위한 2단 플립플롭 동기화기
Summary:
  - 메타안정성 전파를 줄이기 위해 2단 레지스터를 사용합니다.
  - 단일 비트 신호를 안전하게 동기화해 출력합니다.
[MODULE_INFO_END]
*/
`timescale 1ns / 1ps

module sync_2ff (
    input  logic iAsync,
    input  logic iClk,
    input  logic iRst,
    output logic oSync
);

    logic Sync_d1;
    logic Sync_d2;

    always_ff @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            Sync_d1 <= 1'b0;
            Sync_d2 <= 1'b0;
        end else begin
            Sync_d1 <= iAsync;
            Sync_d2 <= Sync_d1;
        end
    end

    assign oSync = Sync_d2;
endmodule
