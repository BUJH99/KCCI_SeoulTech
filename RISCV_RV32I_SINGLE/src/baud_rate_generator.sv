/*
[MODULE_INFO_START]
Name: baud_rate_generator
Role: UART 오버샘플링용 보오레이트 틱을 생성하는 모듈
Summary:
  - 시스템 클록을 분주해 설정된 보오레이트의 샘플 틱을 만듭니다.
  - RX/TX 모듈이 공통으로 사용할 기준 샘플 타이밍을 제공합니다.
[MODULE_INFO_END]
*/
`timescale 1ns / 1ps

module baud_rate_generator #(
    parameter int unsigned P_CLK_HZ     = 100_000_000,
    parameter int unsigned P_BAUD       = 9_600,
    parameter int unsigned P_OVERSAMPLE = 16
)(
    input  logic iClk,
    input  logic iRst,
    output logic oSampleTick
);

    localparam int unsigned LP_DIV_RAW   = P_CLK_HZ / (P_BAUD * P_OVERSAMPLE);
    localparam int unsigned LP_DIV       = (LP_DIV_RAW > 0) ? LP_DIV_RAW : 1;
    localparam int unsigned LP_CNT_WIDTH = (LP_DIV > 1) ? $clog2(LP_DIV) : 1;
    localparam logic [LP_CNT_WIDTH-1:0] LP_DIV_LAST = LP_CNT_WIDTH'(LP_DIV - 1);

    logic [LP_CNT_WIDTH-1:0] Cnt;

    always_ff @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            Cnt         <= '0;
            oSampleTick <= 1'b0;
        end else if (Cnt == LP_DIV_LAST) begin
            Cnt         <= '0;
            oSampleTick <= 1'b1;
        end else begin
            Cnt         <= Cnt + 1'b1;
            oSampleTick <= 1'b0;
        end
    end
endmodule
