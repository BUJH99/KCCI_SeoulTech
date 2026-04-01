/*
[MODULE_INFO_START]
Name: FndBcdDecoder
Role: BCD 값과 블랭킹 제어를 7세그먼트 출력으로 디코딩하는 모듈
Summary:
  - 입력 BCD에 해당하는 7세그먼트 패턴을 생성합니다.
  - 블랭킹이 활성화되면 해당 자리의 세그먼트를 소등합니다.
[MODULE_INFO_END]
*/
module FndBcdDecoder (
    input  wire [3:0] iCurBcd,
    input  wire       iBlanking,
    output reg  [6:0] oSeg
);
    always @(*) begin
        if (iBlanking) begin
            oSeg = 7'b111_1111;
        end else begin
            case (iCurBcd)
                4'h0: oSeg = 7'b100_0000;
                4'h1: oSeg = 7'b111_1001;
                4'h2: oSeg = 7'b010_0100;
                4'h3: oSeg = 7'b011_0000;
                4'h4: oSeg = 7'b001_1001;
                4'h5: oSeg = 7'b001_0010;
                4'h6: oSeg = 7'b000_0010;
                4'h7: oSeg = 7'b101_1000;
                4'h8: oSeg = 7'b000_0000;
                4'h9: oSeg = 7'b001_0000;
                4'hA: oSeg = 7'b000_1000;
                4'hB: oSeg = 7'b000_0011;
                4'hC: oSeg = 7'b100_0110;
                4'hD: oSeg = 7'b010_0001;
                4'hE: oSeg = 7'b000_0110;
                4'hF: oSeg = 7'b000_1110;
                default: oSeg = 7'b111_1111;
            endcase
        end
    end
endmodule
