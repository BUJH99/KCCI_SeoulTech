/*
[MODULE_INFO_START]
Name: ControlUnit
Role: 시계, 스톱워치, 센서 코어를 통합 제어하는 상위 모듈
Summary:
  - 공통 명령 인터페이스를 각 기능 코어에 분배합니다.
  - 표시 데이터, 확장 데이터, 상태 정보를 취합해 외부로 출력합니다.
[MODULE_INFO_END]
*/
module ControlUnit #(
    parameter integer P_SYS_CLK_HZ            = 100_000_000,
    parameter integer P_HCSR_AUTO_PERIOD_MS   = 100,
    parameter integer P_DHT11_AUTO_PERIOD_MS  = 2000,
    parameter integer P_DHT11_START_LOW_US    = 18_000
)(
    input  wire        iClk,
    input  wire        iRst,
    input  wire        iTick1kHz,

    input  wire [1:0]  iMode,
    input  wire        iCmdValid,
    input  wire [4:0]  iCmdCode,

    input  wire        iEcho,
    output wire        oTrig,
    inout  wire        ioDhtData,

    output wire [15:0] oWatchData,
    output wire [31:0] oWatchFullData,
    output wire [3:0]  oWatchBlinkMask,
    output wire [3:0]  oWatchDotMask,
    output wire        oWatchEditActive,

    output wire [15:0] oStopData,
    output wire [31:0] oStopFullData,
    output wire [3:0]  oStopBlinkMask,
    output wire [3:0]  oStopDotMask,
    output wire        oStopEditActive,

    output wire [15:0] oHcsr04Distance,
    output wire        oHcsr04Valid,
    output wire        oHcsr04AutoRun,

    output wire [15:0] oDht11Temp,
    output wire [15:0] oDht11Humi,
    output wire        oDht11Valid,
    output wire        oDht11AutoRun
);

    localparam [1:0] LP_MODE_HCSR04           = 2'd2;
    localparam [1:0] LP_MODE_DHT11            = 2'd3;
    localparam [4:0] LP_CMD_MODE_LOCAL_RESET  = 5'd3;

    wire wHcsrModeLocalClear;
    wire wDhtModeLocalClear;

    assign wHcsrModeLocalClear = iCmdValid &&
                                 (iCmdCode == LP_CMD_MODE_LOCAL_RESET) &&
                                 (iMode == LP_MODE_HCSR04);
    assign wDhtModeLocalClear  = iCmdValid &&
                                 (iCmdCode == LP_CMD_MODE_LOCAL_RESET) &&
                                 (iMode == LP_MODE_DHT11);

    WatchCore uWatchCore (
        .iClk       (iClk),
        .iRst      (iRst),
        .iTick1kHz  (iTick1kHz),
        .iMode      (iMode),
        .iCmdValid  (iCmdValid),
        .iCmdCode   (iCmdCode),
        .oFndData   (oWatchData),
        .oFullData  (oWatchFullData),
        .oBlinkMask (oWatchBlinkMask),
        .oDotMask   (oWatchDotMask),
        .oEditActive(oWatchEditActive)
    );

    StopwatchCore uStopwatchCore (
        .iClk       (iClk),
        .iRst      (iRst),
        .iTick1kHz  (iTick1kHz),
        .iMode      (iMode),
        .iCmdValid  (iCmdValid),
        .iCmdCode   (iCmdCode),
        .oFndData   (oStopData),
        .oFullData  (oStopFullData),
        .oBlinkMask (oStopBlinkMask),
        .oDotMask   (oStopDotMask),
        .oEditActive(oStopEditActive)
    );

    wire wHcsrStart;
    wire wDht11Start;
    wire [15:0] wHcsr04DistanceCore;
    wire        wHcsr04ValidCore;
    wire [15:0] wDht11TempCore;
    wire [15:0] wDht11HumiCore;
    wire        wDht11ValidCore;

    reg  [15:0] rHcsr04Distance;
    reg  [15:0] rDht11Temp;
    reg  [15:0] rDht11Humi;
    reg         rHcsr04Valid;
    reg         rDht11Valid;

    SensorControlUnit #(
        .P_HCSR_AUTO_PERIOD_MS  (P_HCSR_AUTO_PERIOD_MS),
        .P_DHT11_AUTO_PERIOD_MS (P_DHT11_AUTO_PERIOD_MS)
    ) uSensorControlUnit (
        .iClk         (iClk),
        .iRst        (iRst),
        .iTick1kHz    (iTick1kHz),
        .iCmdValid    (iCmdValid),
        .iCmdCode     (iCmdCode),
        .iMode        (iMode),
        .oHcsrStart   (wHcsrStart),
        .oDht11Start  (wDht11Start),
        .oHcsrAutoRun (oHcsr04AutoRun),
        .oDht11AutoRun(oDht11AutoRun)
    );

    Hcsr04Core #(
        .P_SYS_CLK_HZ (P_SYS_CLK_HZ)
    ) uHcsr04Core (
        .iClk       (iClk),
        .iRst      (iRst),
        .iStart     (wHcsrStart),
        .iEcho      (iEcho),
        .oTrig      (oTrig),
        .oDistance  (wHcsr04DistanceCore),
        .oValid     (wHcsr04ValidCore)
    );

    Dht11Core #(
        .P_SYS_CLK_HZ   (P_SYS_CLK_HZ),
        .P_START_LOW_US (P_DHT11_START_LOW_US)
    ) uDht11Core (
        .iClk       (iClk),
        .iRst      (iRst),
        .iStart     (wDht11Start),
        .ioData     (ioDhtData),
        .oTemp      (wDht11TempCore),
        .oHumi      (wDht11HumiCore),
        .oValid     (wDht11ValidCore)
    );

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            rHcsr04Distance <= 16'd0;
            rDht11Temp      <= 16'd0;
            rDht11Humi      <= 16'd0;
            rHcsr04Valid    <= 1'b0;
            rDht11Valid     <= 1'b0;
        end else begin
            rHcsr04Valid <= 1'b0;
            rDht11Valid  <= 1'b0;

            if (wHcsrModeLocalClear) begin
                rHcsr04Distance <= 16'd0;
            end else if (wHcsr04ValidCore) begin
                rHcsr04Distance <= wHcsr04DistanceCore;
                rHcsr04Valid    <= 1'b1;
            end

            if (wDhtModeLocalClear) begin
                rDht11Temp <= 16'd0;
                rDht11Humi <= 16'd0;
            end else if (wDht11ValidCore) begin
                rDht11Temp  <= wDht11TempCore;
                rDht11Humi  <= wDht11HumiCore;
                rDht11Valid <= 1'b1;
            end
        end
    end

    assign oHcsr04Distance = rHcsr04Distance;
    assign oHcsr04Valid    = rHcsr04Valid;
    assign oDht11Temp      = rDht11Temp;
    assign oDht11Humi      = rDht11Humi;
    assign oDht11Valid     = rDht11Valid;

endmodule

