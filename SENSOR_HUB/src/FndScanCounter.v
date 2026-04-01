/*
[MODULE_INFO_START]
Name: FndScanCounter
Role: FND 자리 스캔을 위한 2비트 인덱스를 생성하는 카운터
Summary:
  - 1kHz 틱마다 스캔 인덱스를 증가시켜 4자리를 순환합니다.
  - 리셋 시 스캔 시작 위치를 초기값으로 복원합니다.
[MODULE_INFO_END]
*/
module FndScanCounter (
    input  wire       iClk,
    input  wire       iRst,
    input  wire       iTick1kHz,
    output reg  [1:0] oScanIdx
);
    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            oScanIdx <= 2'd0;
        end else if (iTick1kHz) begin
            oScanIdx <= oScanIdx + 1'b1;
        end
    end
endmodule

