# SENSOR_HUB 프로젝트 설명서

## [프로젝트명]

SENSOR_HUB - FPGA 기반 Multi-Mode Sensor Hub 및 FND/UART Display Controller

## [프로젝트 목표]

본 프로젝트의 목표는 FPGA 보드에서 시계, 스톱워치, 초음파 거리 센서, 온습도 센서를 하나의 통합 시스템으로 제어하는 RTL 기반 Sensor Hub를 구현하는 것입니다. 각 기능을 독립 모듈로 나누고, 공통 입력 인터페이스와 공통 표시 인터페이스를 통해 여러 동작 모드를 전환할 수 있도록 설계하였습니다.

특히 HC-SR04 초음파 센서와 DHT11 온습도 센서처럼 timing protocol이 중요한 외부 장치를 Verilog FSM으로 직접 제어하고, 측정 결과를 4-digit FND와 UART ASCII 출력으로 확인할 수 있게 만드는 것을 목표로 하였습니다. FPGA 버튼/스위치뿐 아니라 PC UART 명령으로도 동일한 제어가 가능하도록 입력 경로를 통합하였습니다.

## [프로젝트 양식]

- 프로젝트 형태: FPGA RTL 기반 센서/표시/통신 통합 프로젝트
- 대상 보드: Basys3, Xilinx Artix-7 `xc7a35tcpg236-1`
- 사용 언어: Verilog
- 사용 도구: Vivado, XSim 기반 FPGA 개발 flow
- 주요 입출력: Push button, switch, 4-digit FND, HC-SR04, DHT11, UART RX/TX
- 상위 모듈: `TOP`
- 주요 기능 모드: Watch, Stopwatch, HC-SR04 거리 측정, DHT11 온습도 측정
- 주요 산출물: 센서 제어 RTL, 입력 병합 RTL, FND 표시 RTL, UART ASCII 송수신 RTL, FPGA project manifest

## [프로젝트 개요]

`TOP` 모듈은 전체 시스템을 다음과 같은 흐름으로 통합합니다.

1. `GlobalTickGen`에서 1 kHz tick과 2 Hz blink tick을 생성합니다.
2. `INPUTFPGA`가 보드 버튼과 스위치를 동기화하고 debounce 처리합니다.
3. `uart_interface`와 `ascii_decoder`가 PC에서 입력된 ASCII 명령을 버튼/스위치와 같은 명령 형태로 변환합니다.
4. `InputControl`이 FPGA 입력과 PC 입력을 우선순위에 따라 병합하고, `mode`와 `cmdCode` 형태의 공통 제어 신호로 압축합니다.
5. `ControlUnit`이 Watch, Stopwatch, HC-SR04, DHT11 기능 코어에 명령을 분배하고 결과를 취합합니다.
6. `DisplayMux`가 현재 모드에 맞는 데이터를 선택하고 BCD 변환, blink mask, decimal point mask를 FND 경로로 전달합니다.
7. `FndController`가 4-digit FND scan, segment decode, blink effect를 수행합니다.
8. `AsciiSender`가 현재 상태나 측정값을 UART TX ASCII stream으로 출력합니다.

동작 모드는 총 4개입니다.

| Mode | 기능 |
| --- | --- |
| Watch | 시계 동작, 표시 형식 전환, 편집 모드 지원 |
| Stopwatch | 스톱워치 실행/정지, 편집/초기화 지원 |
| HC-SR04 | 초음파 센서 trigger 생성, echo 폭 측정, 거리 표시 |
| DHT11 | 1-wire 방식 온습도 데이터 수신, checksum 검증, 온습도 표시 |

HC-SR04 core는 trigger pulse를 만든 뒤 echo 신호의 HIGH 폭을 계측하여 거리 값으로 변환합니다. Echo 시작 대기와 측정 구간에 timeout을 두어 센서 미응답 상황에서도 FSM이 멈추지 않도록 하였습니다.

DHT11 core는 start low 구간, 센서 응답 대기, 40-bit 데이터 수신, checksum 검증 과정을 FSM으로 구현하였습니다. 데이터 라인은 필요할 때만 low로 구동하고 나머지 구간에서는 high-Z로 해제하여 1-wire open-drain 성격의 통신을 처리하였습니다.

UART 명령은 `U`, `C`, `D`, `R`, `L`, `1`, `2`, `3`, `S`, `Q`, `T`, `Y`, `H`, `J`를 지원합니다. 이를 통해 PC terminal에서도 보드 버튼과 유사하게 모드 변경, reset, 측정 요청, 상태 조회를 수행할 수 있습니다.

## [담당 분야/역할]

프로젝트에서 RTL 모듈 분할, 센서 protocol FSM 설계, 입력/표시/통신 경로 통합을 담당하였습니다.

- `TOP` 기준 전체 data/control flow 구성
- FPGA button/switch 입력 동기화, debounce, edge pulse 생성
- FPGA 입력과 UART 입력을 하나의 command stream으로 병합하는 `InputControl` 설계
- Watch/Stopwatch core의 run/edit state machine 및 BCD counter 제어
- HC-SR04 trigger/echo 측정 FSM 설계 및 timeout 처리
- DHT11 1-wire start sequence, 40-bit receive, checksum 검증 FSM 설계
- Sensor data를 FND 표시용 BCD로 변환하고 모드별 display mux 구성
- UART RX/TX, FIFO, ASCII command decode, ASCII status/data sender 경로 통합
- FND scan counter, digit selector, BCD decoder, blink/dot mask 처리 경로 구성

## [프로젝트를 통해 느낀 점/해결방법]

센서 기반 FPGA 프로젝트에서는 CPU처럼 명령을 순차적으로 실행하는 것이 아니라, 외부 입력과 센서 응답이 언제 들어올지 모르는 상황을 clock 기반 FSM으로 안정적으로 받아야 한다는 점이 중요했습니다. 버튼, 스위치, UART RX, HC-SR04 echo, DHT11 data는 모두 FPGA clock 기준으로 비동기적이기 때문에, 동기화와 debounce가 없으면 같은 동작도 여러 번 실행되거나 잘못된 값으로 해석될 수 있었습니다.

이를 해결하기 위해 외부 입력은 `sync_2ff`, debounce, edge pulse를 거쳐 1-clock event로 정리하였습니다. 이후 FPGA 물리 입력과 PC UART 입력을 같은 명령 코드로 변환하여 `ControlUnit`이 입력 출처를 의식하지 않아도 되도록 구성하였습니다.

센서 protocol에서는 timeout 설계가 특히 중요했습니다. HC-SR04는 echo가 오지 않거나 너무 오래 유지될 수 있고, DHT11은 start 이후 응답 edge가 정상적으로 들어오지 않을 수 있습니다. 각 FSM에 대기 timeout과 측정 timeout을 두어 비정상 상황에서도 IDLE로 복귀할 수 있도록 하였고, 유효한 측정이 완료되었을 때만 표시 register를 갱신하도록 하였습니다.

또한 여러 기능을 하나의 FND에 표시하기 위해 각 기능 core가 자신의 표시 데이터와 blink/dot mask를 만들고, 최종 선택은 `DisplayMux`가 담당하도록 분리하였습니다. 이 구조 덕분에 새로운 센서나 기능 모드를 추가할 때도 공통 FND controller를 다시 작성하지 않고 선택 경로만 확장하면 됩니다.

## [결과물]

- Verilog RTL source 43개
- FPGA top integration: `TOP.v`
- 공통 tick/input path: `GlobalTickGen`, `INPUTFPGA`, `Debounce`, `EdgePulse`, `InputControl`
- 기능 core: `WatchCore`, `StopwatchCore`, `Hcsr04Core`, `Dht11Core`
- 표시 path: `DisplayMux`, `SensorBcdConverter`, `FndController`, `FndBcdDecoder`, `FndBlinkEffect`
- UART path: `uart_interface`, `uart_rx`, `uart_tx`, `rx_fifo`, `tx_fifo`, `ascii_decoder`, `AsciiSender`
- Sensor Hub 동작 모드 4종: Watch, Stopwatch, HC-SR04, DHT11
- PC UART 제어 및 상태/측정값 ASCII 출력 기능
- FPGA_AUTO project manifest: `fpga_auto.yml`

