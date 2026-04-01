/*
[MODULE_INFO_START]
Name: InputPriority
Role: FPGA 입력과 PC 입력 사이의 우선순위를 결정하는 모듈
Summary:
  - 버튼과 스위치 이벤트에 대해 PC 입력 우선 정책을 적용합니다.
  - FPGA 스위치 레벨 변화를 감지해 이벤트 펄스로 변환합니다.
[MODULE_INFO_END]
*/
module InputPriority(
    input  wire       iClk,
    input  wire       iRst,
    input  wire [4:0] iBtnPulseFpga,
    input  wire [4:0] iBtnPulsePc,
    input  wire [2:0] iSwLevelFpga,
    input  wire [2:0] iSwPulsePc,
    output wire [4:0] oBtnPulse,
    output wire [2:0] oSwPulse
);

    reg  [2:0] swLevelPrev;
    wire [2:0] wSwTogglePulse;

    assign wSwTogglePulse = iSwLevelFpga ^ swLevelPrev;

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            swLevelPrev <= 3'b000;
        end else begin
            swLevelPrev <= iSwLevelFpga;
        end
    end

    assign oBtnPulse = iBtnPulsePc | (iBtnPulseFpga & ~iBtnPulsePc);
    assign oSwPulse  = iSwPulsePc  | (wSwTogglePulse & ~iSwPulsePc);

endmodule
