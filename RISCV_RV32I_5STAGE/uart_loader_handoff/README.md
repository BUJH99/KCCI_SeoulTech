# UART Loader Handoff

이 폴더는 다른 RISC-V/FPGA SoC 프로젝트에 UART ROM bootloader를 넘기기 위한 최소 묶음이다.

## 폴더 구성

```text
uart_loader_handoff/
  rom_loader/
    firmware_sources/
      uart_loader_main.c      # FPGA ROM에서 실행되는 UART bootloader C 코드
      startup.S               # _start, stack init, .data copy, .bss clear, main 호출
    linker_scripts/
      linker_c.ld             # ROM bootloader용 linker script
    build_scripts/
      build_uart_loader.ps1   # uart_loader.mem 빌드 스크립트
      bin_to_mem.py           # raw bin을 Verilog readmemh용 .mem으로 변환
  pc_tools/
    make_loader_packet.py     # RAM app bin을 RAXI packet으로 감싸기
    send_loader_packet.py     # packet을 UART로 보내기
    loader_gui.py             # optional GUI
  ram_app_support/
    linker_scripts/
      linker_ram.ld           # UART로 받은 앱을 SRAM에서 실행하기 위한 linker script
    build_scripts/
      build_ram_app.ps1       # C RAM app 빌드 + packet 생성
      download_ram_app.ps1    # C RAM app 빌드 + UART 다운로드
  artifacts/
    uart_loader.mem           # 현재 프로젝트에서 이미 빌드된 ROM image
    uart_loader.dump          # disassembly 참고용
    uart_loader.map           # symbol/address map 참고용
  docs/
    UART_LOADER_WORKFLOW.md
    RAM_LOADER_LINKER_IRQ_DEBUG_KO.md
```

## PC 쪽 loader는 Python만 있으면 되나?

PC에서 UART로 코드를 보내는 쪽은 Python tool이면 된다.

필수:

```text
pc_tools/make_loader_packet.py
pc_tools/send_loader_packet.py
```

GUI가 필요하면:

```text
pc_tools/loader_gui.py
```

단, FPGA 안에서 먼저 돌아가는 ROM bootloader는 Python이 아니라 C/ASM으로 빌드한 ROM image다.

```text
rom_loader/firmware_sources/uart_loader_main.c
rom_loader/firmware_sources/startup.S
rom_loader/linker_scripts/linker_c.ld
artifacts/uart_loader.mem
```

## ld 파일은 뭐 하는 애인가?

`.ld`는 linker script다. 컴파일된 코드/데이터를 어느 주소에 놓을지 정한다.

### `linker_c.ld`

ROM bootloader용이다.

현재 주소 가정:

```text
ROM  origin = 0x00000000
SRAM origin = 0x20000100
stack top   = 0x20004000
```

CPU reset 후 PC가 `0x00000000`에서 시작하므로 bootloader의 `.text`는 ROM에 배치된다.

### `linker_ram.ld`

UART로 다운로드한 C app용이다.

현재 주소 가정:

```text
RAM app origin = 0x20001000
RAM app length = 0x3000
stack top      = 0x20004000
```

즉 PC에서 보낸 앱은 SRAM `0x20001000`에 올라가고, bootloader가 그 주소로 jump한다.

## 현재 bootloader가 가정하는 SoC 주소

`rom_loader/firmware_sources/uart_loader_main.c` 안의 값이다.

```c
GPIOA_BASE    = 0x40010000
UART_BASE     = 0x40050000
SRAM_BASE     = 0x20000000
SRAM_APP_BASE = 0x20001000
SRAM_END      = 0x20004000
```

UART register offset:

```text
UART_CTRL    0x00
UART_STATUS  0x04
UART_BAUDDIV 0x08
UART_RXDATA  0x10
RX_VALID bit = status[2]
```

친구 SoC의 주소맵이나 UART register가 다르면 `uart_loader_main.c`와 linker script를 반드시 수정해야 한다.

## Packet format

PC tool이 보내는 packet은 little-endian이다.

```text
magic       4 bytes  "RAXI"
load_addr   4 bytes
byte_count  4 bytes
entry_addr  4 bytes
checksum    4 bytes  payload byte sum
payload     N bytes  word-padded raw binary
```

기본 RAM app:

```text
load_addr = 0x20001000
entry     = 0x20001000
```

## 이식할 때 체크리스트

1. ROM이 reset PC `0x00000000`에 보이는지 확인한다.
2. SRAM에 CPU instruction fetch path가 연결되어 있는지 확인한다.
3. `uart_loader_main.c`의 UART/GPIO/SRAM base 주소를 친구 SoC에 맞춘다.
4. `linker_c.ld`의 ROM/SRAM 주소를 친구 SoC에 맞춘다.
5. RAM app을 쓸 거면 `linker_ram.ld`의 `SRAM_APP` 주소도 맞춘다.
6. `uart_loader.mem`을 ROM init file로 넣는다.
7. PC에서 `make_loader_packet.py`와 `send_loader_packet.py`로 RAM app packet을 보낸다.

