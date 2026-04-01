/*
[MODULE_INFO_START]
Name: DisplayMux
Role: 센서 BCD 변환과 모드별 표시 선택을 통합한 표시 경로 모듈
Summary:
  - 센서 이진 데이터를 FND 표시용 BCD로 변환합니다.
  - 현재 모드 기준으로 최종 표시 데이터와 마스크를 선택합니다.
[MODULE_INFO_END]
*/
module DisplayMux (
    input  wire [1:0]  iMode,

    // Core Outputs
    input  wire [15:0] iWatchData,
    input  wire [3:0]  iWatchBlinkMask,
    input  wire [3:0]  iWatchDotMask,

    input  wire [15:0] iStopData,
    input  wire [3:0]  iStopBlinkMask,
    input  wire [3:0]  iStopDotMask,

    input  wire [15:0] iHcsr04Distance,
    input  wire [15:0] iDht11Temp,
    input  wire [15:0] iDht11Humi,

    // Outputs to FND Controller
    output wire [15:0] oFndBcd,
    output wire [3:0]  oBlinkMask,
    output wire [3:0]  oDpMask
);

    wire [15:0] wHcsrBcd;
    wire [15:0] wDhtBcd;

    SensorBcdConverter uSensorBcdConverter (
        .iHcsr04Distance (iHcsr04Distance),
        .iDht11Temp      (iDht11Temp),
        .iDht11Humi      (iDht11Humi),
        .oHcsr04Bcd      (wHcsrBcd),
        .oDht11Bcd       (wDhtBcd)
    );

    DisplayModeSelector uDisplayModeSelector (
        .iMode           (iMode),
        .iWatchData      (iWatchData),
        .iWatchBlinkMask (iWatchBlinkMask),
        .iWatchDotMask   (iWatchDotMask),
        .iStopData       (iStopData),
        .iStopBlinkMask  (iStopBlinkMask),
        .iStopDotMask    (iStopDotMask),
        .iHcsr04Bcd      (wHcsrBcd),
        .iDht11Bcd       (wDhtBcd),
        .oFndBcd         (oFndBcd),
        .oBlinkMask      (oBlinkMask),
        .oDpMask         (oDpMask)
    );

endmodule
