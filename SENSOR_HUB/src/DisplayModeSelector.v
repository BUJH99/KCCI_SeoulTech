/*
[MODULE_INFO_START]
Name: DisplayModeSelector
Role: 동작 모드에 맞는 FND 표시 데이터와 마스크를 선택하는 모듈
Summary:
  - 시계, 스톱워치, 센서 데이터 중 현재 모드의 출력 대상을 고릅니다.
  - 선택된 BCD 데이터와 점멸/점 마스크를 FND 경로로 전달합니다.
[MODULE_INFO_END]
*/
module DisplayModeSelector (
    input  wire [1:0]  iMode,
    input  wire [15:0] iWatchData,
    input  wire [3:0]  iWatchBlinkMask,
    input  wire [3:0]  iWatchDotMask,
    input  wire [15:0] iStopData,
    input  wire [3:0]  iStopBlinkMask,
    input  wire [3:0]  iStopDotMask,
    input  wire [15:0] iHcsr04Bcd,
    input  wire [15:0] iDht11Bcd,
    output reg  [15:0] oFndBcd,
    output reg  [3:0]  oBlinkMask,
    output reg  [3:0]  oDpMask
);
    always @(*) begin
        oFndBcd    = iWatchData;
        oBlinkMask = 4'b0000;
        oDpMask    = 4'b0000;

        case (iMode)
            2'd0: begin // WATCH
                oFndBcd    = iWatchData;
                oBlinkMask = iWatchBlinkMask;
                oDpMask    = iWatchDotMask;
            end
            2'd1: begin // STOPWATCH
                oFndBcd    = iStopData;
                oBlinkMask = iStopBlinkMask;
                oDpMask    = iStopDotMask;
            end
            2'd2: begin // HCSR04
                oFndBcd    = iHcsr04Bcd;
                oBlinkMask = 4'b0000;
                oDpMask    = 4'b0000;
            end
            2'd3: begin // DHT11
                oFndBcd    = iDht11Bcd; 
                oBlinkMask = 4'b0000;
                oDpMask    = 4'b0000;
            end
        endcase
    end
endmodule
