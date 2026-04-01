/*
[MODULE_INFO_START]
Name: baud_rate_generator
Role: UART 오버샘플링용 보오레이트 틱을 생성하는 모듈
Summary:
  - 시스템 클록을 분주해 설정된 보오레이트의 샘플 틱을 만듭니다.
  - RX/TX 모듈이 공통으로 사용할 기준 샘플 타이밍을 제공합니다.
[MODULE_INFO_END]
*/
module baud_rate_generator #(
    parameter integer P_CLK_HZ      = 100000000,
    parameter integer P_BAUD        = 9600,
    parameter integer P_OVERSAMPLE  = 16
)(
    input       iClk,
    input       iRst,
    output reg  oSampleTick
);
  
    // Example: 100MHz / (9600 * 16) = ~651
    localparam integer LP_DIV       = P_CLK_HZ / (P_BAUD * P_OVERSAMPLE);
    localparam integer LP_CNT_WIDTH = $clog2(LP_DIV);

    reg [LP_CNT_WIDTH-1:0] rCnt;

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            rCnt        <= {LP_CNT_WIDTH{1'b0}};
            oSampleTick <= 1'b0;
        end else begin
            if (rCnt == (LP_DIV - 1)) begin
                rCnt        <= {LP_CNT_WIDTH{1'b0}};
                oSampleTick <= 1'b1;
            end else begin
                rCnt        <= rCnt + 1'b1;
                oSampleTick <= 1'b0;
            end
        end
    end
endmodule
