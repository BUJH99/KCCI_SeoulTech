/*
[MODULE_INFO_START]
Name: SensorControlUnit
Role: 센서 자동/수동 측정 시작 신호를 생성하는 제어 모듈
Summary:
  - 주기 설정값에 따라 HC-SR04와 DHT11 자동 측정을 트리거합니다.
  - 수동 요청이 들어오면 자동 동작과 별도로 즉시 측정을 시작합니다.
[MODULE_INFO_END]
*/
module SensorControlUnit #(
    parameter integer P_HCSR_AUTO_PERIOD_MS  = 100,
    parameter integer P_DHT11_AUTO_PERIOD_MS = 2000
)(
    input  wire        iClk,
    input  wire        iRst,
    input  wire        iTick1kHz,
    
    // Command context
    input  wire        iCmdValid,
    input  wire [4:0]  iCmdCode,
    input  wire [1:0]  iMode,
    
    // Output Pulses to Cores
    output wire        oHcsrStart,
    output wire        oDht11Start,
    output wire        oHcsrAutoRun,
    output wire        oDht11AutoRun
);

    // ----------------------------------------------------
    // 1. HC-SR04 Trigger Logic
    // ----------------------------------------------------
    // PC 'H' request (cmd 18) should also trigger a fresh measurement.
    wire wHcsrManual     = iCmdValid &&
                           (((iCmdCode == 5'd11) && (iMode == 2'd2)) ||
                            (iCmdCode == 5'd18));
    wire wHcsrAutoToggle = iCmdValid && (iCmdCode == 5'd10) && (iMode == 2'd2);
    
    localparam integer LP_HCSR_AUTO_MAX = (P_HCSR_AUTO_PERIOD_MS > 0) ? (P_HCSR_AUTO_PERIOD_MS - 1) : 0;
    localparam integer LP_DHT11_AUTO_MAX = (P_DHT11_AUTO_PERIOD_MS > 0) ? (P_DHT11_AUTO_PERIOD_MS - 1) : 0;

    reg hcsrAutoRun;
    reg [15:0] hcsrAutoMsCnt;

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            hcsrAutoRun   <= 1'b0;
            hcsrAutoMsCnt <= 7'd0;
        end else begin
            if (wHcsrAutoToggle) begin
                hcsrAutoRun <= ~hcsrAutoRun;
            end
            
            if (hcsrAutoRun && iTick1kHz) begin
                if (hcsrAutoMsCnt >= LP_HCSR_AUTO_MAX) hcsrAutoMsCnt <= 16'd0;
                else hcsrAutoMsCnt <= hcsrAutoMsCnt + 1;
            end else if (!hcsrAutoRun) begin
                hcsrAutoMsCnt <= 16'd0;
            end
        end
    end
    
    wire wHcsrAutoPulse = (hcsrAutoRun && iTick1kHz && (hcsrAutoMsCnt == LP_HCSR_AUTO_MAX));
    assign oHcsrStart   = wHcsrManual | wHcsrAutoPulse;
    assign oHcsrAutoRun = hcsrAutoRun;

    // ----------------------------------------------------
    // 2. DHT11 Trigger Logic
    // ----------------------------------------------------
    // PC 'J' request (cmd 19) should also trigger a fresh measurement.
    wire wDht11Manual     = iCmdValid &&
                            (((iCmdCode == 5'd13) && (iMode == 2'd3)) ||
                             (iCmdCode == 5'd19));
    wire wDht11AutoToggle = iCmdValid && (iCmdCode == 5'd12) && (iMode == 2'd3);
    
    reg dht11AutoRun;
    reg [15:0] dht11AutoMsCnt;

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            dht11AutoRun   <= 1'b0;
            dht11AutoMsCnt <= 11'd0;
        end else begin
            if (wDht11AutoToggle) begin
                dht11AutoRun <= ~dht11AutoRun;
            end
            
            if (dht11AutoRun && iTick1kHz) begin
                if (dht11AutoMsCnt >= LP_DHT11_AUTO_MAX) dht11AutoMsCnt <= 16'd0;
                else dht11AutoMsCnt <= dht11AutoMsCnt + 1;
            end else if (!dht11AutoRun) begin
                dht11AutoMsCnt <= 16'd0;
            end
        end
    end
    
    wire wDht11AutoPulse = (dht11AutoRun && iTick1kHz && (dht11AutoMsCnt == LP_DHT11_AUTO_MAX));
    assign oDht11Start   = wDht11Manual | wDht11AutoPulse;
    assign oDht11AutoRun = dht11AutoRun;

endmodule

