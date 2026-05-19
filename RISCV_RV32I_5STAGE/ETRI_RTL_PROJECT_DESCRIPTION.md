# [프로젝트명]

RV32I 5-Stage Pipeline SoC 및 Bubble Sort FPGA Demo

## [프로젝트 목표]

RV32I 명령어를 실행하는 5단계 파이프라인 CPU를 직접 설계하고, 이를 FPGA SoC 형태로 확장하는 것을 목표로 하였습니다. 단순히 명령어를 해석하는 CPU core에 그치지 않고, instruction ROM, data RAM, AXI4-Lite/APB bridge, UART, GPIO, I2C, SPI, FND, interrupt controller, timer를 memory-mapped peripheral로 연결하여 실제 embedded system에 가까운 구조를 구현하고자 했습니다.

또한 bare-metal firmware가 직접 만든 CPU 위에서 Bubble Sort demo를 실행하도록 하여, RTL CPU와 주변장치, interrupt, timer, firmware가 하나의 시스템으로 연동되는지를 확인하는 것을 목표로 하였습니다. 사용자는 UART 또는 GPIO 버튼으로 숫자 입력, 정렬 시작, 일시정지, 한 단계 실행, reset을 제어할 수 있으며, 정렬 진행 상태는 FND와 UART, SPI/I2C 기반 외부 slave 연동 경로로 관찰할 수 있도록 설계했습니다.

## [프로젝트 양식]

- 유형: FPGA 기반 RISC-V CPU/SoC RTL 설계 및 검증 프로젝트
- 진행 기간: 2026.05 기준 포트폴리오 정리
- 사용 언어/도구: SystemVerilog, Verilog, C, RISC-V Assembly, Vivado, XSim, RISC-V GCC
- 대상 보드: Basys3, Xilinx Artix-7 `xc7a35tcpg236-1`
- 설계 대상: RV32I 5-stage CPU core, SoC top, AXI4-Lite/APB bus, APB peripheral subsystem, Bubble Sort firmware demo
- 주요 기술: 5-stage pipeline, forwarding, hazard/stall control, PLIC 기반 INTC, CSR/trap/interrupt, AXI4-Lite/APB protocol 변환, MMIO, bare-metal firmware

## [프로젝트 개요]

본 프로젝트는 직접 설계한 `Rv32iCore`를 중심으로 FPGA에서 동작하는 RV32I SoC를 구성한 프로젝트입니다. CPU core는 Fetch, Decode, Execute, Memory, WriteBack의 5단계 pipeline으로 구성되며, 각 stage 사이에는 pipeline register를 두어 instruction flow를 분리했습니다. `Rv32iCore`는 instruction bus와 data bus를 외부로 노출하고, 최상위 `TOP` 모듈은 instruction ROM, data RAM, peripheral bus, 외부 입출력 핀을 통합하는 방식으로 CPU와 SoC wrapper의 역할을 분리했습니다.

CPU 내부에서는 opcode decode, immediate 생성, register file read/write, ALU 연산, branch/jump redirect, load/store formatting, CSR 명령, trap 및 interrupt 처리를 수행합니다. Data hazard는 forwarding path와 load-use stall로 처리하고, branch/jump/trap과 같은 control flow 변경은 pipeline flush 및 PC redirect 경로로 처리했습니다.

SoC bus 구조는 CPU native data bus를 RAM 영역과 APB MMIO 영역으로 나누는 방식으로 설계했습니다. 내부 data RAM은 즉시 응답 경로로 연결하고, peripheral 접근은 `DataBusAxiLiteMaster`와 `AxiLiteToApbBridge`를 거쳐 AXI4-Lite transaction 및 APB SETUP/ACCESS phase로 변환했습니다. APB bus에는 UART, GPIO, I2C, SPI, FND, interrupt controller, timer를 연결했습니다.

주요 memory map은 다음과 같습니다.

| Peripheral | Base Address | 역할 |
| --- | ---: | --- |
| UART | `0x4000_0000` | PC terminal 입출력 |
| GPIO | `0x4000_1000` | 보드 버튼 및 외부 입력 |
| I2C | `0x4000_2000` | 외부 slave register 접근 |
| INTC | `0x4000_3000` | interrupt pending, claim, complete 처리 |
| SPI | `0x4000_4000` | Bubble Sort trace frame 전송 |
| FND | `0x4000_5000` | 4-digit FND 표시 |
| Timer | `0x4000_6000` | 100 Hz machine timer interrupt 생성 |

Demo firmware는 4개 숫자를 입력받아 Bubble Sort를 수행합니다. Timer는 10 ms 단위 interrupt tick을 만들고, firmware는 이 tick을 기준으로 정렬 step, GPIO debounce, SPI/I2C timeout, slave 상태 확인을 처리합니다. 정렬 배열은 MASTER FND에 표시되고, 정렬 진행 trace는 SPI frame으로 전송되며, I2C는 외부 slave display의 설정 및 상태 확인에 사용됩니다.

## [담당 분야/역할]

- RV32I 5-stage pipeline 구조 설계 및 stage별 datapath/control path 구성
- Fetch, Decode, Execute, Memory, WriteBack stage 및 pipeline register 통합
- RV32I instruction decode, immediate generation, ALU control, branch/jump redirect 설계
- forwarding, load-use stall, hold/flush, pipeline redirect 우선순위 정리
- PLIC 기반 INTC, CSR, trap, `mret`, external interrupt, timer interrupt 처리 경로 구현
- CPU native data bus와 RAM/APB MMIO 영역을 분리하는 bus routing 설계
- AXI4-Lite master, AXI4-Lite to APB bridge, APB control/mux 경로 구성
- UART, GPIO, I2C, SPI, FND, INTC, Timer peripheral register interface 설계 및 통합
- Bubble Sort firmware의 MMIO register map, interrupt 기반 제어 흐름, SPI/I2C 연동 흐름 정리
- XSim testbench와 Vivado build report를 기반으로 기능 및 timing 결과 확인

## [프로젝트를 통해 느낀 점/해결방법]

### 1. Pipeline Hazard 및 Control Flow 처리

- 느낀 점: CPU 설계에서 어려운 부분은 단순 ALU 연산보다 여러 stage에 걸친 instruction flow를 안정적으로 유지하는 것이었습니다. 특히 load-use hazard, branch/jump redirect, trap, interrupt가 서로 다른 stage에서 발생할 수 있어 우선순위를 명확히 하지 않으면 잘못된 instruction이 retire될 수 있었습니다.
- 해결방법: pipeline 제어를 `hold`, `flush`, `redirect`, `trap enter` 조건으로 분리했습니다. Load-use hazard는 IF/ID hold와 ID/EX bubble 삽입으로 처리하고, branch/jump/trap redirect는 front-end flush와 PC 갱신 경로로 정리했습니다. 또한 forwarding unit을 통해 EX/MEM, MEM/WB 결과를 execute operand로 전달하여 불필요한 stall을 줄였습니다.

### 2. PLIC 기반 INTC 구축 및 CSR 제어

- Issue: 펌웨어가 정상적이고 일관되게 구동되기 위해서는 timer, UART, GPIO, I2C, SPI 등 여러 peripheral에서 발생하는 interrupt와 CPU 예외 상황을 안정적으로 처리하는 구조가 필요했습니다.
- Action: 핵심 시스템 레지스터인 `mstatus`, `mie`, `mip`, `mtvec`, `mepc`, `mcause`를 관리하는 `CsrFile`과 trap/interrupt 진입을 제어하는 `TrapController`를 설계했습니다. 또한 PLIC 구조를 참고한 INTC 기반 interrupt line routing을 구성하여 peripheral interrupt를 pending, claim, complete 흐름으로 처리하고, Trap Entry 및 `mret` 복귀 시 일관된 pipeline flush와 PC redirect가 수행되도록 제어했습니다.
- Result: 복합적인 interrupt 및 exception 상황을 안정적으로 처리하는 exception handling 아키텍처를 완성했고, firmware가 timer tick, 외부 interrupt, 예외 복귀를 신뢰성 있게 사용할 수 있는 기반을 확보했습니다.

### 3. CPU Native Bus와 Peripheral Bus의 Timing 차이

- 느낀 점: Data RAM은 즉시 응답할 수 있지만 APB peripheral은 SETUP/ACCESS phase와 `PREADY`를 기다려야 하므로, CPU memory stage가 peripheral 응답을 받을 때까지 안전하게 멈춰야 했습니다.
- 해결방법: CPU native data request, AXI4-Lite transaction, APB transfer를 각각 별도 제어 블록으로 나누었습니다. `DataBusMaster`는 RAM과 APB window를 decode하고, `DataBusAxiLiteMaster`는 native request를 AXI4-Lite read/write channel로 변환하며, `AxiLiteToApbBridge`는 APB phase를 생성하도록 설계했습니다. APB access가 완료될 때만 CPU에 response를 반환하여 pipeline과 peripheral timing을 분리했습니다.

### 4. SoC Memory Map과 Firmware 연동

- 느낀 점: 하드웨어 register map과 firmware header가 조금만 어긋나도 RTL은 정상이어도 software demo는 동작하지 않을 수 있었습니다. 특히 SPI/I2C timeout, timer tick, interrupt enable 순서가 firmware 전체 동작에 직접 영향을 주었습니다.
- 해결방법: RTL의 APB address map과 C header의 base address/offset을 동일하게 관리했습니다. Firmware에서는 MMIO access 함수를 통해 UART, GPIO, SPI, I2C, FND, Timer, INTC register를 제어하고, timer interrupt 기반으로 정렬 step과 주변장치 상태 확인을 분리했습니다. 긴 delay loop 대신 100 Hz tick 기반 상태 제어를 사용하여 UART/GPIO 입력과 정렬 진행을 함께 처리했습니다.

### 5. End-to-End Demo 및 검증

- 느낀 점: CPU core 단위 simulation만으로는 실제 SoC demo의 안정성을 확인하기 어려웠습니다. Firmware가 instruction ROM에서 실행되고, data bus가 RAM/MMIO를 오가며, peripheral과 interrupt가 함께 동작하는 end-to-end scenario가 필요했습니다.
- 해결방법: AXI4-Lite/APB bridge, timer/CSR/trap, Bubble Sort SoC scenario, master/slave preflight testbench를 구성하여 단계별로 검증했습니다. Vivado build report와 timing summary를 함께 확인하여 FPGA 구현 가능성도 검토했습니다.

## [결과물]

- RV32I 5-stage CPU RTL: `src/Rv32iCore.sv`
- SoC Top RTL: `src/TOP.sv`
- Pipeline/decoder/control RTL: `src/FetchStage.sv`, `src/DecodeStage.sv`, `src/ExecuteStage.sv`, `src/MemoryStage.sv`, `src/WriteBackStage.sv`, `src/HazardUnit.sv`, `src/ForwardUnit.sv`
- Bus/Peripheral RTL: `src/DataBusAxiLiteMaster.sv`, `src/AxiLiteToApbBridge.sv`, `src/APBMux.sv`, `src/APB_UART.sv`, `src/APB_GPIO.sv`, `src/APB_I2C.sv`, `src/APB_SPI.sv`, `src/APB_FND.sv`, `src/APB_Timer.sv`
- Interrupt/CSR RTL: `src/CsrFile.sv`, `src/TrapController.sv`, `src/InterruptController.sv`
- Bare-metal firmware: `sw/apps/hello_world/src/main.c`, `sw/startup/rv32i_startup.S`, `sw/linker/rv32i_bubble_sort_demo.ld`
- Testbench: `tb/tb_DataBusAxiLiteMaster.sv`, `tb/tb_AxiLiteToApbBridge.sv`, `tb/tb_APB_Timer.sv`, `tb/tb_CsrFile_Timer.sv`, `tb/tb_TOP_BubbleSortE2E.sv`
- Vivado output: `output/TOP.bit`, `output/reports/timing_summary.rpt`, `output/FINALReport/Final_Build_Report.html`
- 주요 성과: Vivado build SUCCESS, bitstream 생성 SUCCESS, timing pass 확인, Bubble Sort firmware 기반 SoC end-to-end demo 구조 구현
