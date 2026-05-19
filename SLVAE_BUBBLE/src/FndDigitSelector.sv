/*
[MODULE_INFO_START]
Name: FndDigitSelector
Role: 스캔 인덱스 기준으로 현재 자리의 데이터와 마스크를 추출하는 모듈
Summary:
  - 4자리 BCD와 마스크에서 현재 스캔 대상 자리의 값을 선택합니다.
  - 선택된 자리의 애노드 제어 신호와 표시 제어 정보를 함께 출력합니다.
[MODULE_INFO_END]
*/
`timescale 1ns / 1ps

module FndDigitSelector (
    input  logic [1:0]  iScanIdx,
    input  logic [15:0] iDigitsBcd,
    input  logic [3:0]  iBlinkMask,
    input  logic [3:0]  iDpMask,
    output logic [3:0]  oDigitSel,
    output logic [3:0]  oCurBcd,
    output logic        oCurBlink,
    output logic        oCurDp
);
    always_comb begin
        unique case (iScanIdx)
            2'd0: begin
                oDigitSel = 4'b1110;
                oCurBcd   = iDigitsBcd[3:0];
                oCurBlink = iBlinkMask[0];
                oCurDp    = iDpMask[0];
            end
            2'd1: begin
                oDigitSel = 4'b1101;
                oCurBcd   = iDigitsBcd[7:4];
                oCurBlink = iBlinkMask[1];
                oCurDp    = iDpMask[1];
            end
            2'd2: begin
                oDigitSel = 4'b1011;
                oCurBcd   = iDigitsBcd[11:8];
                oCurBlink = iBlinkMask[2];
                oCurDp    = iDpMask[2];
            end
            default: begin
                oDigitSel = 4'b0111;
                oCurBcd   = iDigitsBcd[15:12];
                oCurBlink = iBlinkMask[3];
                oCurDp    = iDpMask[3];
            end
        endcase
    end
endmodule
