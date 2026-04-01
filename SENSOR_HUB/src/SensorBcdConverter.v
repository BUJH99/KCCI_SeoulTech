/*
[MODULE_INFO_START]
Name: SensorBcdConverter
Role: 센서 측정 값을 표시용 BCD 형식으로 변환하는 모듈
Summary:
  - HC-SR04 거리 값은 최대 표시 범위로 제한한 뒤 BCD로 변환합니다.
  - DHT11 온습도 데이터의 정수부를 추출해 BCD 출력으로 변환합니다.
[MODULE_INFO_END]
*/
module SensorBcdConverter (
    input  wire [15:0] iHcsr04Distance,
    input  wire [15:0] iDht11Temp,
    input  wire [15:0] iDht11Humi,
    output wire [15:0] oHcsr04Bcd,
    output wire [15:0] oDht11Bcd
);
    // HC-SR04 BCD Conversion
    wire [13:0] wHcsrBin = (iHcsr04Distance > 16'd9999) ? 14'd9999 : iHcsr04Distance[13:0];
    DoubleDabble uHcsrDabble (
        .iBin (wHcsrBin),
        .oBcd (oHcsr04Bcd)
    );

    // DHT11 BCD Conversion: [Humi(2digit)][Temp(2digit)]
    wire [15:0] wDhtTempBcd;
    wire [15:0] wDhtHumiBcd;

    wire [13:0] wDhtTempBin = iDht11Temp[15:8];
    wire [13:0] wDhtHumiBin = iDht11Humi[15:8];

    DoubleDabble uDhtTempDabble (
        .iBin (wDhtTempBin),
        .oBcd (wDhtTempBcd)
    );

    DoubleDabble uDhtHumiDabble (
        .iBin (wDhtHumiBin),
        .oBcd (wDhtHumiBcd)
    );

    assign oDht11Bcd = {wDhtHumiBcd[7:0], wDhtTempBcd[7:0]};
endmodule
