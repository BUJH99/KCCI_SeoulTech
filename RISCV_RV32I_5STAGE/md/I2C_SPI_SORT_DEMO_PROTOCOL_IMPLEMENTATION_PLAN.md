# I2C/SPI Sort Demo Protocol Implementation Plan

## 1. Decision

이 문서는 `PLIC_LITE_V1_I2C_SPI_IMPLEMENTATION_PLAN.md`의 후속 계획서이다. PLIC-lite v1은 먼저 구현하고, I2C/SPI master/slave 코어는 그 다음 단계에서 구현한다.

목표는 Bubble Sort demo에서 I2C와 SPI가 서로 겹치지 않는 역할을 갖도록, protocol/register/frame 계약을 먼저 고정하는 것이다.

```text
UART = PC command/data plane
GPIO = local human command plane
SPI  = MASTER -> SLAVE high-rate sort trace data plane
I2C  = MASTER <-> SLAVE low-rate control/status plane
FND  = human-visible display plane
```

## 2. Scope

이 문서가 정의하는 것:

- MASTER SPI controller 요구사항
- SLAVE SPI trace receiver 요구사항
- Bubble Sort trace frame binary layout
- MASTER I2C controller 요구사항
- SLAVE I2C register target 요구사항
- APB register map 초안
- IRQ 발생 조건
- firmware transaction sequence
- testbench 및 board bring-up 단계
- `src/SLAVE/` 아래에 second-FPGA용 SLAVE RTL을 분리 배치하는 repo 구조

이 문서가 지금 구현하지 않는 것:

- 실제 RTL 작성
- timing closure
- board pin constraint 확정
- full-featured general-purpose I2C/SPI IP
- DMA 기반 streaming
- multi-master I2C arbitration 완전 지원
- SLAVE RTL을 MASTER `TOP.sv` 내부에 local block으로 통합

## 3. Dependency Order

권장 구현 순서:

```text
1. PLIC-lite v1
   - gateway
   - priority/threshold
   - claim/complete
   - UART/GPIO 검증

2. I2C/SPI interrupt stub
   - I2C_EVENT/I2C_ERROR/SPI_EVENT/SPI_ERROR source ID 검증
   - priority policy 검증

3. SPI sort trace path
   - MASTER SPI mode0 transmitter
   - SLAVE SPI trace receiver
   - trace frame checksum/decoder

4. I2C control/status path
   - MASTER I2C single-master command engine
   - SLAVE I2C register target

5. End-to-end Bubble Sort demo
   - UART array input
   - GPIO start/pause/step/reset
   - MASTER FND progress
   - SPI trace frame stream
   - I2C display mode/status
   - SLAVE FND counter display
```

Reason:

```text
PLIC-lite가 먼저 안정되어야 I2C/SPI 코어는 IRQ_STATUS를 세우고 raw IRQ를 올리는 역할에만 집중할 수 있다.
```

## 4. Topology

Target demo topology:

```text
PC
  UART
    |
    v
MASTER RV32I SoC
  - UART RX/TX
  - GPIO buttons/LEDs
  - APB_FND for MASTER FND
  - APB_SPI master
  - APB_I2C master
  - PLIC-lite v1
    |
    | SPI SCLK/CSN/MOSI/MISO
    | I2C SCL/SDA
    v
SLAVE display target
  - separate FPGA RTL under src/SLAVE/
  - SPI trace frame receiver
  - I2C register target
  - FND display controller
```

SLAVE target is a separate FPGA design:

| Area | Meaning |
| --- | --- |
| `src/SLAVE/` | synthesizable SLAVE FPGA RTL |
| `tb/` | protocol simulation models and MASTER/SLAVE integration tests |
| `constrs/` | later board pin constraints for MASTER and SLAVE targets |

Preferred path:

```text
tb model first -> src/SLAVE RTL -> second FPGA board target
```

Do not instantiate the SLAVE display target inside MASTER `TOP.sv` for the real demo. MASTER only exposes SPI/I2C pins. SLAVE has its own top module under `src/SLAVE/`.

Build boundary:

```text
MASTER FPGA top = current project top `Top`
SLAVE FPGA top  = planned `src/SLAVE/SortDisplaySlaveTop.sv`
```

The current `fpga_auto.yml` points at the MASTER top. A later SLAVE build flow should select `SortDisplaySlaveTop` explicitly or use a SLAVE-specific build target/manifest.

## 5. Signal-Level Contract

SPI pins:

| Signal | Direction from MASTER | Meaning |
| --- | --- | --- |
| `oSpiSclk` | output | SPI serial clock |
| `oSpiCsn` | output | active-low chip select |
| `oSpiMosi` | output | MASTER to SLAVE data |
| `iSpiMiso` | input | optional SLAVE status/echo data |

I2C pins:

| Signal | Direction from MASTER | Meaning |
| --- | --- | --- |
| `ioI2cScl` | open-drain bidirectional | I2C clock line |
| `ioI2cSda` | open-drain bidirectional | I2C data line |

Implementation note:

```text
FPGA top should expose I2C output-enable style signals internally:
  SclOeLow, SdaOeLow
and only drive 0, never drive 1.
```

## 6. SPI Protocol Decision

SPI v1 mode:

| Item | v1 value |
| --- | --- |
| mode | SPI mode 0 |
| CPOL | 0 |
| CPHA | 0 |
| bit order | MSB first |
| word size | 8-bit byte stream |
| CS | active low, one frame per CS assertion |
| MISO | optional status/echo, not required for first demo |

SPI v1 only needs MASTER-to-SLAVE trace streaming. MISO can return a simple status byte later, but the first implementation may tie MISO readback to zero or ignore it.

Reserved future features:

- CPOL/CPHA mode selection
- LSB-first mode
- multi-CS
- RX FIFO with meaningful response packets
- DMA or burst APB writes

## 7. Bubble Sort Trace Frame

Frame size:

```text
24 bytes fixed length
one SPI CS assertion carries exactly one 24-byte trace frame
```

Byte layout:

| Byte | Field | Meaning |
| ---: | --- | --- |
| 0 | `MAGIC0` | `0xA5` |
| 1 | `MAGIC1` | `0x5A` |
| 2 | `VERSION` | `0x01` |
| 3 | `FRAME_TYPE` | `0x01=TRACE`, `0x02=SUMMARY`, `0xE0=ERROR` |
| 4 | `FRAME_ID[7:0]` | frame counter low |
| 5 | `FRAME_ID[15:8]` | frame counter high |
| 6 | `PHASE` | Bubble Sort phase |
| 7 | `FLAGS` | swap/done/paused/valid bits |
| 8 | `ARRAY_LEN` | number of active array elements |
| 9 | `PASS_IDX` | outer loop pass index |
| 10 | `COMPARE_IDX` | inner loop compare index |
| 11 | `LEFT_IDX` | compared left index |
| 12 | `RIGHT_IDX` | compared right index |
| 13 | `LEFT_VALUE` | compared left value, 8-bit |
| 14 | `RIGHT_VALUE` | compared right value, 8-bit |
| 15 | `CHANGED_IDX` | swapped/changed index or `0xFF` |
| 16 | `COMPARE_COUNT[7:0]` | compare count low |
| 17 | `COMPARE_COUNT[15:8]` | compare count high |
| 18 | `SWAP_COUNT[7:0]` | swap count low |
| 19 | `SWAP_COUNT[15:8]` | swap count high |
| 20 | `TOTAL_COUNT[7:0]` | total operation count low |
| 21 | `TOTAL_COUNT[15:8]` | total operation count high |
| 22 | `STATUS_CODE` | status/error/subphase code |
| 23 | `CHECKSUM` | XOR of bytes 0..22 |

`PHASE` values:

| Value | Name | Meaning |
| ---: | --- | --- |
| `0x00` | `IDLE` | no active sort |
| `0x01` | `LOAD` | array input/load preview |
| `0x02` | `COMPARE` | comparing two values |
| `0x03` | `SWAP` | swap occurred |
| `0x04` | `PASS_DONE` | one outer pass completed |
| `0x05` | `DONE` | sort completed |
| `0x06` | `PAUSED` | sort paused |
| `0xE0` | `ERROR` | demo/protocol error |

`FLAGS` bits:

| Bit | Name | Meaning |
| ---: | --- | --- |
| 0 | `SWAP` | current step swapped values |
| 1 | `DONE` | sort complete |
| 2 | `PAUSED` | sort is paused |
| 3 | `VALID_VALUES` | left/right values are valid |
| 4 | `FRAME_DROPPED_BEFORE` | firmware detected a dropped previous frame |
| 7:5 | reserved | write 0 |

Checksum:

```text
CHECKSUM = byte0 ^ byte1 ^ ... ^ byte22
```

Rationale:

- 24 bytes is small enough for simple SPI hardware.
- Frame is fixed-length, so SLAVE decoder does not need dynamic length handling.
- Counts are 16-bit, enough for small FPGA demo arrays.
- SLAVE FND can select one counter through I2C `DISPLAY_MODE`.

## 8. SPI MASTER APB Register Map

Recommended base:

```text
LP_APB_SPI_BASE = 0x4000_4000
```

Register map:

| Offset | Name | Access | Meaning |
| ---: | --- | --- | --- |
| `0x000` | `CTRL` | RW | enable, start, reset FIFOs, mode bits |
| `0x004` | `STATUS` | RO | busy, tx_ready, rx_valid, frame_done, error |
| `0x008` | `TXDATA` | WO | write one byte into TX FIFO |
| `0x00C` | `RXDATA` | RO | read one byte from RX FIFO/status stream |
| `0x010` | `CLKDIV` | RW | SPI SCLK divider |
| `0x014` | `CS_CTRL` | RW | CS select/manual hold options |
| `0x018` | `FRAME_LEN` | RW | bytes to transmit, v1 uses 24 |
| `0x01C` | `IRQ_STATUS` | RW1C | sticky event/error causes |
| `0x020` | `IRQ_ENABLE` | RW | IRQ cause mask |

`CTRL` bits:

| Bit | Name | Meaning |
| ---: | --- | --- |
| 0 | `ENABLE` | enable SPI core |
| 1 | `START` | self-clearing start transfer |
| 2 | `TX_FIFO_CLR` | clear TX FIFO |
| 3 | `RX_FIFO_CLR` | clear RX FIFO |
| 4 | `CPOL` | reserved in v1, keep 0 |
| 5 | `CPHA` | reserved in v1, keep 0 |
| 6 | `LSB_FIRST` | reserved in v1, keep 0 |

`STATUS` bits:

| Bit | Name | Meaning |
| ---: | --- | --- |
| 0 | `BUSY` | transfer active |
| 1 | `TX_READY` | TX FIFO can accept at least one byte |
| 2 | `TX_EMPTY` | TX FIFO empty |
| 3 | `RX_VALID` | RX FIFO has data |
| 4 | `FRAME_DONE` | last transfer completed |
| 5 | `ERROR` | any error cause is set |

`IRQ_STATUS` bits:

| Bit | Cause | Group |
| ---: | --- | --- |
| 0 | `FRAME_DONE` | event |
| 1 | `TX_READY` | event |
| 2 | `RX_VALID` | event |
| 8 | `RX_OVERFLOW` | error |
| 9 | `TX_UNDERFLOW` | error |
| 10 | `MODE_ERROR` | error |
| 11 | `FRAME_DROPPED` | error |

IRQ outputs:

```text
oEventIrq = |(IRQ_STATUS[2:0] & IRQ_ENABLE[2:0])
oErrorIrq = |(IRQ_STATUS[11:8] & IRQ_ENABLE[11:8])
```

## 9. SPI MASTER Core FSM

Minimal v1 FSM:

```text
IDLE
  wait CTRL.START && CTRL.ENABLE && FRAME_LEN != 0

LOAD_BYTE
  pop next byte from TX FIFO
  if TX FIFO empty before FRAME_LEN bytes:
    set TX_UNDERFLOW
    go ERROR_STOP

SHIFT_BITS
  drive MOSI on falling edge
  sample MISO on rising edge
  shift 8 bits

NEXT_BYTE
  if sent byte count == FRAME_LEN:
    go DONE
  else:
    go LOAD_BYTE

DONE
  deassert CS
  set FRAME_DONE
  return IDLE

ERROR_STOP
  deassert CS
  set ERROR
  return IDLE
```

SCLK generation:

```text
SCLK frequency = iClk / (2 * (CLKDIV + 1))
```

v1 constraints:

- `FRAME_LEN` must be 24 for sort trace frames.
- `START` is ignored while `BUSY=1`.
- If `CTRL.CPOL/CPHA/LSB_FIRST` are nonzero in v1, set `MODE_ERROR`.
- `TX_READY` can be used by firmware to fill the FIFO.

## 10. SPI SLAVE Trace Receiver

SLAVE SPI receiver role:

```text
receive 24-byte frame
validate magic/version/checksum
update latest counters
update LAST_FRAME_ID
raise local status/error flags
drive SLAVE FND according to I2C DISPLAY_MODE
```

Suggested files:

```text
src/SLAVE/SortDisplaySlaveTop.sv
src/SLAVE/SpiTraceSlave.sv
src/SLAVE/SortTraceFrameDecoder.sv
src/SLAVE/SortSlaveRegs.sv
```

Minimal slave FSM:

```text
WAIT_CS_LOW
  reset bit/byte counters

SHIFT_BYTE
  sample MOSI on SCLK rising edge
  assemble byte MSB first

STORE_BYTE
  store byte into frame buffer
  if byte_count == 24:
    go VALIDATE
  else:
    go SHIFT_BYTE

VALIDATE
  check magic/version/checksum
  if valid:
    update counters/registers
  else:
    set ERROR_CODE

WAIT_CS_HIGH
  require CS high before next frame
```

SLAVE frame handling:

| Frame field | SLAVE use |
| --- | --- |
| `FRAME_ID` | `LAST_FRAME_ID` register |
| `PHASE` | optional display status |
| `PASS_IDX` | PASS display mode |
| `COMPARE_COUNT` | COMPARE display mode |
| `SWAP_COUNT` | SWAP display mode |
| `TOTAL_COUNT` | TOTAL display mode |
| `STATUS_CODE` | status/error register |

MISO v1:

```text
optional
can return 0x00 for every byte
future: return previous frame ACK/status
```

## 11. I2C Protocol Decision

I2C v1 mode:

| Item | v1 value |
| --- | --- |
| speed | standard mode or low-speed FPGA-safe divider |
| address width | 7-bit |
| MASTER role | single master |
| SLAVE address | default `0x42` |
| register address | 8-bit |
| register data | 8/16/32-bit depending on register |
| clock stretching | not required in v1 |

Required transaction types:

```text
single register write:
  START
  SLA+W
  REG_ADDR
  DATA0..DATAn
  STOP

single register read:
  START
  SLA+W
  REG_ADDR
  REPEATED_START
  SLA+R
  DATA0..DATAn
  STOP
```

## 12. I2C MASTER APB Register Map

Recommended base:

```text
LP_APB_I2C_BASE = 0x4000_2000
```

Register map:

| Offset | Name | Access | Meaning |
| ---: | --- | --- | --- |
| `0x000` | `CTRL` | RW | enable, start, reset, rw |
| `0x004` | `STATUS` | RO | busy, done, ack, rx_valid, error |
| `0x008` | `SLAVE_ADDR` | RW | 7-bit slave address |
| `0x00C` | `REG_ADDR` | RW | 8-bit target register address |
| `0x010` | `WDATA` | RW | write payload, little endian |
| `0x014` | `RDATA` | RO | read payload, little endian |
| `0x018` | `LEN` | RW | number of data bytes, 1..4 |
| `0x01C` | `CLKDIV` | RW | SCL divider |
| `0x020` | `IRQ_STATUS` | RW1C | sticky event/error causes |
| `0x024` | `IRQ_ENABLE` | RW | IRQ cause mask |

`CTRL` bits:

| Bit | Name | Meaning |
| ---: | --- | --- |
| 0 | `ENABLE` | enable I2C master |
| 1 | `START` | self-clearing command start |
| 2 | `RW` | `0=write`, `1=read` |
| 3 | `CORE_RESET` | clear FSM/error state |

`STATUS` bits:

| Bit | Name | Meaning |
| ---: | --- | --- |
| 0 | `BUSY` | transaction active |
| 1 | `DONE` | last transaction complete |
| 2 | `ACK_OK` | all required ACKs received |
| 3 | `RX_VALID` | read data valid |
| 4 | `ERROR` | any error cause is set |

`IRQ_STATUS` bits:

| Bit | Cause | Group |
| ---: | --- | --- |
| 0 | `DONE` | event |
| 1 | `RX_VALID` | event |
| 2 | `TX_READY` | event |
| 3 | `SLAVE_STATUS_READY` | event |
| 8 | `NACK` | error |
| 9 | `ARB_LOST` | error |
| 10 | `BUS_ERROR` | error |
| 11 | `TIMEOUT` | error |

IRQ outputs:

```text
oEventIrq = |(IRQ_STATUS[3:0] & IRQ_ENABLE[3:0])
oErrorIrq = |(IRQ_STATUS[11:8] & IRQ_ENABLE[11:8])
```

## 13. I2C MASTER Core FSM

Write transaction FSM:

```text
IDLE
  wait CTRL.START && CTRL.ENABLE && RW=0

START_COND
  SDA falls while SCL high

SEND_ADDR_W
  shift {SLAVE_ADDR, 1'b0}
  wait ACK

SEND_REG_ADDR
  shift REG_ADDR
  wait ACK

SEND_DATA
  shift WDATA byte 0..LEN-1
  wait ACK per byte

STOP_COND
  SDA rises while SCL high
  set DONE
  return IDLE
```

Read transaction FSM:

```text
IDLE
  wait CTRL.START && CTRL.ENABLE && RW=1

START_COND
SEND_ADDR_W
SEND_REG_ADDR
REPEATED_START
SEND_ADDR_R
READ_DATA
  sample LEN bytes
  ACK all except final byte
  NACK final byte
STOP_COND
  set RX_VALID and DONE
  return IDLE
```

Error behavior:

| Error | Cause |
| --- | --- |
| NACK on address/register/data | `NACK` |
| SDA mismatch while driving high/released | `ARB_LOST` |
| illegal bus condition | `BUS_ERROR` |
| transaction exceeds timeout counter | `TIMEOUT` |

v1 simplification:

```text
single-master design may implement ARB_LOST detection lightly, but the IRQ bit is reserved from the start.
```

## 14. I2C SLAVE Register Target

SLAVE address:

```text
7'h42
```

Register map visible to MASTER:

| Offset | Name | Access | Width | Meaning |
| ---: | --- | --- | ---: | --- |
| `0x00` | `SLAVE_ID` | RO | 32 | fixed ID, e.g. `0x534C5631` |
| `0x04` | `DISPLAY_MODE` | RW | 8 | selected SLAVE FND counter |
| `0x08` | `STATUS` | RO | 32 | ready, busy, error, phase |
| `0x0C` | `LAST_FRAME_ID` | RO | 16 | last accepted SPI frame |
| `0x10` | `ERROR_CODE` | RO/W1C | 16 | protocol/display errors |
| `0x14` | `BRIGHTNESS` | RW | 8 | optional FND brightness |
| `0x18` | `COMPARE_COUNT` | RO | 16 | latest compare count |
| `0x1C` | `SWAP_COUNT` | RO | 16 | latest swap count |
| `0x20` | `TOTAL_COUNT` | RO | 16 | latest total count |

`DISPLAY_MODE` values:

| Value | Name | SLAVE FND shows |
| ---: | --- | --- |
| 0 | `PASS` | pass index/count |
| 1 | `COMPARE` | compare count |
| 2 | `SWAP` | swap count |
| 3 | `TOTAL` | total operation count |
| 4 | `FRAME_ID` | last frame ID |
| 5 | `STATUS` | status/error code |

`STATUS` bits:

| Bit | Name | Meaning |
| ---: | --- | --- |
| 0 | `READY` | slave can receive frames |
| 1 | `SPI_ACTIVE` | SPI CS currently active |
| 2 | `FRAME_VALID` | last frame valid |
| 3 | `ERROR` | error code nonzero |
| 7:4 | `PHASE` | latest frame phase |

I2C SLAVE behavior:

- ACK valid address.
- ACK valid register writes.
- For invalid register address, set `ERROR_CODE.INVALID_REG`.
- v1 may still ACK invalid register access and return zero, as long as error status is set.
- No clock stretching required in v1.

## 15. MASTER Firmware Flow

Initialization:

```text
1. Configure PLIC-lite priorities:
   I2C/SPI error high
   UART/GPIO command medium-high
   SPI event low

2. Configure SPI:
   mode0
   FRAME_LEN=24
   CLKDIV safe value
   enable FRAME_DONE and error IRQs

3. Configure I2C:
   SLAVE_ADDR=0x42
   CLKDIV safe value
   enable DONE/RX_VALID and error IRQs

4. Probe SLAVE:
   read SLAVE_ID
   write DISPLAY_MODE default
   read STATUS

5. Configure UART/GPIO/FND.
```

Bubble Sort step flow:

```text
for each compare/swap/pass event:
  update MASTER FND display state
  build 24-byte trace frame
  write frame bytes to SPI TXDATA
  write SPI FRAME_LEN=24
  write SPI CTRL.START
  continue or wait depending on trace policy
```

Trace policy options:

| Policy | Meaning |
| --- | --- |
| blocking | wait for SPI frame done every step |
| nonblocking | skip/delay frame if SPI busy |
| visible-rate | emit frames only at FND-visible update rate |

Recommended v1:

```text
visible-rate or blocking
```

This keeps the demo readable and avoids needing DMA.

## 16. Interrupt Handling Contract

PLIC source mapping from the PLIC-lite plan:

| Source | Handler action |
| --- | --- |
| `GPIO` | start/pause/step/reset command |
| `UART_RX` | parse array input or PC command |
| `I2C_EVENT` | mark transaction done, consume read data |
| `I2C_ERROR` | stop demo or show error |
| `SPI_EVENT` | mark trace frame sent or TX ready |
| `SPI_ERROR` | stop trace stream or show error |

Handler skeleton:

```text
id = INTC.CLAIM
switch id:
  GPIO:
    read/clear GPIO IRQ status
    update demo command flags

  UART_RX:
    drain UART RX
    parse array/command

  I2C_EVENT:
    read I2C IRQ_STATUS
    clear causes
    update i2c_done/i2c_rx_valid flags

  I2C_ERROR:
    read I2C IRQ_STATUS/STATUS
    clear causes
    set demo error

  SPI_EVENT:
    read SPI IRQ_STATUS
    clear causes
    update spi_frame_done/spi_tx_ready flags

  SPI_ERROR:
    read SPI IRQ_STATUS/STATUS
    clear causes
    set demo error

INTC.COMPLETE = id
mret
```

Important:

```text
clear peripheral IRQ_STATUS before writing INTC.COMPLETE
```

## 17. MASTER FND and SLAVE FND Coordination

MASTER FND:

```text
local APB_FND
firmware directly writes current display value
shows data values and sort progress
does not generate interrupts
```

SLAVE FND:

```text
not memory-mapped to MASTER
updates from latest SPI trace frame
display mode selected by I2C DISPLAY_MODE
does not need an interrupt back to MASTER in v1
```

Recommended display examples:

| Demo state | MASTER FND | SLAVE FND |
| --- | --- | --- |
| load | input value preview | frame/status or blank |
| compare | left/right values | compare count |
| swap | swapped values or marker | swap count |
| pass done | pass index | pass count |
| done | final values/done marker | total count |
| error | error code | error code |

## 18. RTL File Plan

MASTER-side new files:

```text
src/APB_SPI.sv
src/SpiRegs.sv
src/SpiMasterCore.sv
src/SpiTxFifo.sv
src/SpiRxFifo.sv

src/APB_I2C.sv
src/I2cRegs.sv
src/I2cMasterCore.sv

src/sort_demo_pkg.sv
```

SLAVE-side second-FPGA files:

```text
src/SLAVE/SortDisplaySlaveTop.sv
src/SLAVE/SpiTraceSlave.sv
src/SLAVE/SortTraceFrameDecoder.sv
src/SLAVE/I2cSlaveRegTarget.sv
src/SLAVE/SortSlaveRegs.sv
src/SLAVE/SlaveFndController.sv
```

Optional testbench-only files:

```text
tb/SpiTraceSlaveModel.sv
tb/I2cSlaveRegModel.sv
tb/tb_spi_sort_trace.sv
tb/tb_i2c_slave_regs.sv
tb/tb_sort_demo_protocol.sv
```

Package constants in `sort_demo_pkg.sv`:

```systemverilog
localparam logic [7:0] SORT_FRAME_MAGIC0 = 8'hA5;
localparam logic [7:0] SORT_FRAME_MAGIC1 = 8'h5A;
localparam logic [7:0] SORT_FRAME_VERSION = 8'h01;
localparam int unsigned SORT_TRACE_FRAME_BYTES = 24;
```

## 19. Implementation Phases

### Phase 0: Freeze protocol

- [ ] Freeze 24-byte SPI trace frame.
- [ ] Freeze I2C SLAVE register map.
- [ ] Add `sort_demo_pkg.sv` constants.
- [ ] Add firmware header constants.

### Phase 1: SPI trace path in simulation

- [ ] Implement SPI mode0 byte transmitter model or RTL.
- [ ] Implement SPI trace slave receiver model.
- [ ] Validate 24-byte frame capture.
- [ ] Validate checksum failure path.

### Phase 2: APB SPI MASTER

- [ ] Implement `APB_SPI`.
- [ ] Implement `SpiRegs`.
- [ ] Implement `SpiMasterCore`.
- [ ] Add TX/RX FIFO or minimal byte buffer.
- [ ] Add FRAME_DONE/TX_READY/error IRQ causes.
- [ ] Connect to PLIC-lite stub or real source.

### Phase 3: SLAVE display target

- [ ] Implement `src/SLAVE/SortDisplaySlaveTop.sv`.
- [ ] Implement `src/SLAVE/SpiTraceSlave.sv`.
- [ ] Implement `src/SLAVE/SortTraceFrameDecoder.sv`.
- [ ] Update counter registers from valid frames.
- [ ] Drive SLAVE FND display formatter.

### Phase 4: I2C control/status path in simulation

- [ ] Implement I2C master transaction model or RTL.
- [ ] Implement I2C slave register model.
- [ ] Validate DISPLAY_MODE write.
- [ ] Validate LAST_FRAME_ID read.
- [ ] Validate ERROR_CODE read/clear.

### Phase 5: APB I2C MASTER

- [ ] Implement `APB_I2C`.
- [ ] Implement `I2cRegs`.
- [ ] Implement `I2cMasterCore`.
- [ ] Add DONE/RX_VALID/NACK/TIMEOUT IRQ causes.
- [ ] Connect to PLIC-lite stub or real source.

### Phase 6: I2C SLAVE register target

- [ ] Implement `src/SLAVE/I2cSlaveRegTarget.sv`.
- [ ] Implement `src/SLAVE/SortSlaveRegs.sv`.
- [ ] Connect display mode/status to `src/SLAVE/SortDisplaySlaveTop.sv`.
- [ ] Validate I2C repeated-start read.

### Phase 7: Firmware integration

- [ ] Add SPI frame encoder.
- [ ] Add SPI send helper.
- [ ] Add I2C register read/write helpers.
- [ ] Add SLAVE probe/init.
- [ ] Add Bubble Sort trace emission.
- [ ] Add MASTER/SLAVE FND demo modes.

### Phase 8: End-to-end demo

- [ ] PC sends array over UART.
- [ ] MASTER FND previews input.
- [ ] GPIO or UART starts sort.
- [ ] MASTER FND shows progress.
- [ ] SPI sends trace frames.
- [ ] SLAVE FND shows selected counter.
- [ ] I2C changes SLAVE display mode while demo is running.
- [ ] UART reports final array and counts.

## 20. Verification Plan

### SPI unit tests

- [ ] mode0 SCLK/MOSI timing.
- [ ] CS low for exactly one frame.
- [ ] 24-byte transfer completes.
- [ ] TX underflow sets error.
- [ ] invalid CPOL/CPHA in v1 sets `MODE_ERROR`.
- [ ] FRAME_DONE IRQ fires.
- [ ] TX_READY IRQ can be masked.

### SPI slave/frame tests

- [ ] valid magic/version/checksum accepted.
- [ ] bad magic rejected.
- [ ] bad checksum rejected.
- [ ] LAST_FRAME_ID updates.
- [ ] compare/swap/total counters update.
- [ ] DISPLAY_MODE controls FND output selection.

### I2C master tests

- [ ] START/STOP generation.
- [ ] single register write.
- [ ] repeated-start register read.
- [ ] NACK sets error.
- [ ] timeout sets error.
- [ ] DONE/RX_VALID IRQ fires.

### I2C slave tests

- [ ] address match ACK.
- [ ] DISPLAY_MODE write updates register.
- [ ] STATUS read returns current status.
- [ ] LAST_FRAME_ID read follows SPI frame.
- [ ] ERROR_CODE W1C clears selected bits.

### Integrated protocol tests

- [ ] SPI frame updates SLAVE counters.
- [ ] I2C changes which counter SLAVE FND displays.
- [ ] SPI error is visible through I2C `ERROR_CODE`.
- [ ] MASTER firmware sends frame after Bubble Sort compare.
- [ ] MASTER firmware sends summary after Bubble Sort done.

### PLIC integration tests

- [ ] SPI_EVENT source fires on FRAME_DONE.
- [ ] SPI_ERROR source fires on underflow/bad mode.
- [ ] I2C_EVENT source fires on DONE/RX_VALID.
- [ ] I2C_ERROR source fires on NACK/TIMEOUT.
- [ ] error priorities beat SPI_EVENT.
- [ ] UART/GPIO command priority beats frequent SPI_EVENT.

## 21. Bring-Up Strategy

Recommended bring-up order:

```text
1. Tie I2C/SPI IRQ stubs into PLIC-lite and verify priorities.
2. Run SPI master against loopback or trace slave model.
3. Run I2C master against slave register model.
4. Integrate src/SLAVE/SortDisplaySlaveTop in simulation.
5. Add MASTER firmware helpers.
6. Move to board-level pins and constraints.
7. Program/connect the second FPGA SLAVE target.
```

Board notes:

- I2C needs pull-ups on SCL/SDA.
- SPI lines should have a known idle state.
- If MASTER and SLAVE use different clocks, SPI and I2C already cross clock domains at protocol level.
- SLAVE internal updates from SPI SCLK domain to FND clock domain need CDC handling.

## 22. Risks and Guardrails

Risk: SPI trace frames are too frequent for firmware/APB.

Guardrail:

```text
Use blocking or visible-rate trace policy in v1.
Avoid DMA until the basic demo works.
```

Risk: I2C implementation grows into a general IP project.

Guardrail:

```text
v1 supports only single-master 7-bit register read/write transactions.
No clock stretching required.
```

Risk: SLAVE target scope is unclear.

Guardrail:

```text
SLAVE synthesizable RTL lives under src/SLAVE/.
Simulation models can live in tb/, but real demo SLAVE is a second FPGA.
MASTER TOP must not depend on an internal SLAVE block.
```

Risk: SPI and I2C duplicate responsibilities.

Guardrail:

```text
SPI carries trace frames only.
I2C carries display mode/status/error registers only.
```

Risk: byte order confusion.

Guardrail:

```text
SPI sends bytes in ascending byte index.
Multi-byte numeric fields are little endian inside the frame.
```

## 23. Definition of Done

Protocol implementation is done when:

- SPI MASTER can transmit one valid 24-byte Bubble Sort trace frame.
- SPI SLAVE can validate and decode that frame.
- SLAVE counters update from SPI frames.
- I2C MASTER can write `DISPLAY_MODE`.
- I2C MASTER can read `STATUS`, `LAST_FRAME_ID`, and count registers.
- I2C/SPI event/error IRQs connect cleanly to PLIC-lite.
- MASTER firmware can emit trace frames during Bubble Sort.
- SLAVE FND display mode can be changed through I2C.
- End-to-end demo shows MASTER progress and SLAVE real-time count display.
