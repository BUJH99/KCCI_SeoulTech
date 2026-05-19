# InstrRom / ProgramRam 속도 판정 Sweep 계획

작성일: 2026-05-16

## 1. 목적

`RISCV_RV32I_5STAGE`의 instruction fetch 메모리를 언제까지 LUTROM/direct 구조로 유지하고, 어느 크기부터 BRAM 또는 BRAM+prefetch 구조로 전환할지 Vivado report와 cycle 지표로 판정한다.

판정 질문:

- 현재 zero-wait `InstrRom` / `ProgramRam` direct 구조가 코드 크기별로 언제까지 유리한가?
- `rom_style = "distributed"` / `ram_style = "distributed"`가 4KB, 8KB, 16KB 이상에서 LUT와 timing을 얼마나 먹는가?
- BRAM sync-read로 바꿨을 때 timing은 좋아지지만 fetch stall/CPI가 얼마나 증가하는가?
- BRAM + 2/4-entry I-prefetch queue가 stall을 얼마나 회복하는가?

## 2. 현재 기준 구조

현재 instruction path는 조합 read 기반이다.

```text
FetchStage
  oInstrBusReq.ReqAddr
      |
      v
InstrRom / ProgramRam zero-latency read
      |
      v
InstrBusMux
      |
      v
InstrBusRsp.RspRdata
      |
      v
FetchStage -> IF/ID
```

확인된 현재 구현:

| 파일 | 현재 구조 |
| --- | --- |
| `src/InstrRom.sv` | `(* rom_style = "distributed" *)`, 조합 read |
| `src/ProgramRam.sv` | `(* ram_style = "distributed" *)`, instruction fetch 조합 read |
| `src/InstrBusMux.sv` | BootRom / ProgramRam / NOP 조합 mux |
| `src/FetchStage.sv` | `ReqAddr = PC`, `IFIDData.Instr = RspRdata` |

중요 제약:

- Xilinx 7-series BRAM은 일반적으로 synchronous read이므로, 단순히 `rom_style = "block"`만 바꿔서는 현재 zero-latency 조합 fetch와 같은 동작을 기대하면 안 된다.
- BRAM variant는 instruction response latency를 명시적으로 받아들이거나, prefetch queue로 latency를 숨기는 구조가 필요하다.

## 3. 비교 Variant

### Variant A: LUTROM Direct

현재 구조를 기준으로 한다.

```text
FetchStage -> InstrRom/ProgramRam distributed read -> InstrBusMux -> FetchStage
```

목표:

- zero-wait direct fetch의 resource/timing 한계를 측정한다.
- PC to instruction critical path가 어느 코드 크기에서 나빠지는지 확인한다.

예상 특성:

- 작은 코드에서는 가장 단순하고 빠를 가능성이 높다.
- 코드 크기가 커질수록 LUT, LUTRAM, routing, PC-to-instr 조합 경로 부담이 증가한다.

### Variant B: BRAM Sync Read

instruction memory를 BRAM 기반 synchronous read로 바꾼다.

```text
FetchStage request PC
      |
      v
BRAM address register
      |
      v
next cycle instruction response
      |
      v
FetchStage accepts response
```

목표:

- LUT 감소량과 timing 개선량을 측정한다.
- 1-cycle read latency가 CPI/fetch wait에 주는 영향을 측정한다.

필요 변경:

- `InstrBusReq_t` / `InstrBusRsp_t`에 latency를 표현할 수 있도록 `RspReady` 또는 valid/ready 의미를 실제로 사용한다.
- branch/jump/trap/mret redirect 시 late response를 버릴 수 있는 flush/kill 처리가 필요하다.

### Variant C: BRAM + I-Prefetch Queue

BRAM sync-read 앞단 또는 뒤단에 2-entry / 4-entry prefetch queue를 둔다.

```text
BRAM/InstrBusMux -> I-Prefetch Queue -> FetchStage
```

또는 request 기준으로:

```text
Fetch PC stream -> Prefetch request engine -> BRAM -> queue -> FetchStage
```

목표:

- BRAM latency로 인한 fetch wait을 순차 실행에서 얼마나 숨기는지 측정한다.
- branch/jump/trap/mret flush 시 queue discard 비용을 측정한다.

Queue 후보:

| Queue depth | 목적 |
| ---: | --- |
| 2-entry | 최소 구현, BRAM 1-cycle latency 흡수 확인 |
| 4-entry | 순차 구간과 짧은 fabric stall 흡수 |
| 8-entry | 필요 시 sensitivity 확인, Basys3에서는 후순위 |

## 4. Sweep 크기

32-bit instruction 기준으로 다음 크기를 비교한다.

| Image size | Instruction count | BRAM 환산 |
| ---: | ---: | --- |
| 1KB | 256 inst | BRAM18보다 작음 |
| 2KB | 512 inst | BRAM18 하나급 |
| 4KB | 1024 inst | BRAM36 하나급 |
| 8KB | 2048 inst | BRAM36 두 개급 |
| 16KB | 4096 inst | BRAM36 네 개급 |
| 32KB | 8192 inst | BRAM36 여덟 개급 |

우선순위:

1. 4KB, 8KB, 16KB를 먼저 측정한다.
2. 결과가 애매하면 1KB, 2KB, 32KB를 추가한다.

## 5. 테스트 프로그램 이미지

각 크기별 `.mem`은 동작 성격이 다른 3종을 준비한다.

| 프로그램 | 목적 |
| --- | --- |
| `linear_sweep_<size>.mem` | 순차 fetch throughput 확인 |
| `branch_loop_<size>.mem` | loop/cache/prefetch 재사용성 확인 |
| `mixed_firmware_<size>.mem` | 실제 firmware에 가까운 jump/load/store/interrupt 흐름 확인 |

기본 생성 정책:

- 대부분 NOP로 채우지 않는다. NOP만 있으면 fetch 경로만 보이고 pipeline 현실성이 낮다.
- `addi`, `lw/sw`, `beq/bne`, `jal`, `mret` 후보를 섞어 routing과 control-flow 영향을 본다.
- branch target은 image 내부에 유지한다.

## 6. Vivado Report 수집

각 variant/size/program에 대해 동일한 part, 동일한 constraint, 동일한 Vivado strategy로 실행한다.

중요 원칙:

- 수동으로 Vivado를 켜서 case를 하나씩 돌리지 않는다.
- sweep matrix, `.mem` 생성, build directory 생성, Vivado batch 실행, report parsing, summary 생성까지 한 runner가 수행한다.
- 사람이 하는 일은 `manifest`를 수정하고 runner를 실행한 뒤 `summary.md`를 읽는 것으로 제한한다.

기본 Tcl:

```tcl
report_utilization -hierarchical -file output/instr_mem_sweep/<case>/util_hier.rpt
report_utilization -file output/instr_mem_sweep/<case>/util_flat.rpt
report_timing_summary -file output/instr_mem_sweep/<case>/timing_summary.rpt
report_timing -max_paths 30 -sort_by group -file output/instr_mem_sweep/<case>/timing_paths.rpt
report_clock_utilization -file output/instr_mem_sweep/<case>/clock_util.rpt
report_route_status -file output/instr_mem_sweep/<case>/route_status.rpt
report_methodology -file output/instr_mem_sweep/<case>/methodology.rpt
report_drc -file output/instr_mem_sweep/<case>/drc.rpt
report_power -file output/instr_mem_sweep/<case>/power.rpt
```

## 7. 자동화 구조

이 sweep은 별도 자동화 하위 폴더를 가진다.

```text
tools/timing/instr_mem_sweep/
  instr_mem_sweep.yml
  run_instr_mem_sweep.py
  generate_instr_mem.py
  parse_vivado_reports.py
  make_summary.py
  vivado_sweep.tcl
  templates/
    sweep_defines.svh.in
    instr_mem_variant_pkg.sv.in
```

출력은 모두 generated output으로 분리한다.

```text
output/instr_mem_sweep/
  cases/
    <case_id>/
      generated/
        instr_image.mem
        sweep_defines.svh
        case_manifest.json
      vivado/
        util_hier.rpt
        util_flat.rpt
        timing_summary.rpt
        timing_paths.rpt
        clock_util.rpt
        route_status.rpt
        methodology.rpt
        drc.rpt
        power.rpt
        vivado.log
      sim/
        xsim.log
        counters.json
  summary.csv
  summary.md
  summary.json
```

### 7.1 Sweep manifest

`instr_mem_sweep.yml`이 전체 실행 matrix를 정의한다.

```yaml
project:
  root: ../../..
  top: TOP
  part: xc7a35tcpg236-1
  xdc:
    - constrs/basys3_top.xdc

variants:
  - id: lutrom_direct
    instr_mem_impl: distributed
    latency: 0
    prefetch_depth: 0
  - id: bram_sync
    instr_mem_impl: block
    latency: 1
    prefetch_depth: 0
  - id: bram_prefetch2
    instr_mem_impl: block
    latency: 1
    prefetch_depth: 2
  - id: bram_prefetch4
    instr_mem_impl: block
    latency: 1
    prefetch_depth: 4

sizes_bytes:
  - 4096
  - 8192
  - 16384

programs:
  - linear_sweep
  - branch_loop
  - mixed_firmware

run:
  vivado: true
  xsim: true
  jobs: 1
  stop_on_fail: false
```

`jobs`는 Vivado license/PC 성능을 보고 나중에 늘린다. 기본은 안전하게 1이다.

### 7.2 Case ID 규칙

case directory는 deterministic하게 만든다.

```text
<variant>__<size_kb>kb__<program>

예:
lutrom_direct__8kb__linear_sweep
bram_prefetch4__16kb__mixed_firmware
```

### 7.3 Runner 책임

`run_instr_mem_sweep.py`는 다음 순서만 수행한다.

1. `instr_mem_sweep.yml` 로드
2. case matrix 생성
3. 각 case output directory 생성
4. `generate_instr_mem.py`로 `.mem` 생성
5. variant define/config 생성
6. XSIM 실행, 가능하면 runtime counter 추출
7. Vivado batch 실행
8. report parser 실행
9. `summary.csv`, `summary.json`, `summary.md` 생성

runner는 기본적으로 기존 source tree를 직접 덮어쓰지 않는다. 필요한 variant config는 generated include 또는 top parameter override로 주입한다.

### 7.4 Source 주입 방식

우선순위는 다음과 같다.

1. **parameter/define 기반 variant 선택**
   - `P_INSTR_MEM_IMPL`
   - `P_INSTR_MEM_LATENCY`
   - `P_PREFETCH_DEPTH`
   - `P_INSTR_INIT_FILE`
2. generated `sweep_defines.svh` include
3. 마지막 수단으로 generated wrapper file을 build file list에 추가

금지:

- runner가 `src/InstrRom.sv`, `src/ProgramRam.sv`, `src/TOP.sv`를 case마다 직접 수정하고 되돌리는 방식
- case별로 git checkout/reset을 반복하는 방식

### 7.5 Vivado batch 방식

`vivado_sweep.tcl`은 case manifest를 인자로 받는다.

실행 형태:

```powershell
vivado -mode batch -source tools/timing/instr_mem_sweep/vivado_sweep.tcl -tclargs output/instr_mem_sweep/cases/<case_id>/generated/case_manifest.json
```

Tcl 책임:

1. case manifest JSON 또는 key=value args 읽기
2. project root의 `src/**/*.sv`, `tb` 제외, 필요 XDC 로드
3. generated include path 추가
4. top generic/parameter override 적용
5. `synth_design`
6. `opt_design`, `place_design`, `route_design`는 옵션화
7. reports 생성

실행 레벨은 두 단계로 나눈다.

| Level | Vivado step | 목적 |
| --- | --- | --- |
| `synth_only` | `synth_design` + synth timing/util | 빠른 1차 resource/timing 경향 |
| `route` | synth + place + route | 최종 WNS/Fmax 판정 |

기본 sweep은 `synth_only`로 빠르게 돌리고, 후보 case만 `route`로 확정한다.

### 7.6 Report parser

`parse_vivado_reports.py`는 사람이 report를 열지 않아도 되도록 필요한 값만 추출한다. 모든 성능/자원 수치는 Vivado/XSIM output에서 parser가 뽑고, parser가 못 읽은 값은 사람이 임의 보정하지 않는다. 해당 값은 `null` 또는 `parse_error`로 남긴다.

case별 정규화 결과:

```text
output/instr_mem_sweep/cases/<case_id>/metrics/case_metrics.json
```

통합 결과:

```text
output/instr_mem_sweep/summary.csv
output/instr_mem_sweep/summary.json
output/instr_mem_sweep/summary.md
```

필수 추출 필드:

```text
case_id
variant
size_bytes
program
vivado_level
status
git_commit
vivado_version
part
strategy
top
clock_period_ns
lut
lut_logic
lut_as_memory
lutram
srl
ff
ramb18
ramb36
bram_tile
dsp
io
bufg
device_lut_util_pct
device_ff_util_pct
device_bram_util_pct
device_dsp_util_pct
instr_rom_lut
instr_rom_lutram
instr_rom_ramb18
instr_rom_ramb36
program_ram_lut
program_ram_lutram
program_ram_ramb18
program_ram_ramb36
instr_bus_mux_lut
fetch_stage_lut
rv32i_core_lut
wns_ns
tns_ns
whs_ns
ths_ns
fmax_est_mhz
critical_path_group
top_critical_path_from
top_critical_path_to
top_critical_path_logic_levels
top_critical_path_datapath_delay_ns
top_critical_path_route_delay_ns
instr_path_in_top10
instr_path_worst_delay_ns
instr_path_worst_logic_levels
instr_path_route_delay_ns
instr_path_score
total_power_w
dynamic_power_w
static_power_w
methodology_error_count
methodology_warning_count
drc_error_count
drc_warning_count
parse_error_count
```

`instr_path_in_top10`는 timing path text에서 다음 문자열 후보를 찾는다.

```text
FetchStage
InstrRom
ProgramRam
InstrBusMux
InstrBusReq
InstrBusRsp
IFIDData
ReqAddr
RspRdata
```

`instr_path_score`는 자동 summary용 보조 점수다.

```text
2.0: worst path source/destination이 FetchStage/InstrBus/InstrRom/ProgramRam 계열
1.0: instruction path가 top 10 timing path 안에 등장
0.5: instruction path가 top 30 timing path 안에 등장
0.0: instruction path 흔적 없음
```

Report별 parser 책임:

| Source | 추출 목적 |
| --- | --- |
| `util_flat.rpt` | 전체 device LUT/LUTRAM/FF/RAMB/DSP/IO/BUFG와 utilization percent |
| `util_hier.rpt` | `InstrRom`, `ProgramRam`, `InstrBusMux`, `FetchStage`, `Rv32iCore` module별 자원 |
| `timing_summary.rpt` | WNS/TNS/WHS/THS, clock period, failing path count |
| `timing_paths.rpt` | critical path source/destination, logic levels, data/route delay, instruction path 여부 |
| `clock_util.rpt` | clocking resource 변화 |
| `route_status.rpt` | routed case의 route completion status |
| `methodology.rpt` | methodology error/warning count |
| `drc.rpt` | DRC error/warning count |
| `power.rpt` | total/dynamic/static power |

parser 정확도 검증 fixture를 둔다.

```text
tools/timing/instr_mem_sweep/tests/fixtures/
  util_flat_sample.rpt
  util_hier_sample.rpt
  timing_summary_sample.rpt
  timing_paths_sample.rpt
  power_sample.rpt

tools/timing/instr_mem_sweep/tests/test_parse_vivado_reports.py
```

parser unit test는 최소 다음을 확인한다.

- comma가 포함된 숫자 표기와 percent를 정확히 파싱한다.
- hierarchical instance명이 `uInstrRom`, `uProgramRam`, `uInstrBusMux`, `uRv32iCore/uFetchStage`처럼 prefix를 포함해도 잡힌다.
- timing path에 instruction token이 있으면 `instr_path_in_top10`과 `instr_path_score`가 갱신된다.
- WNS가 negative이면 case status에 timing fail이 반영된다.

### 7.6.1 Metrics schema

`case_metrics.json`는 다음 구조를 따른다.

```json
{
  "case": {
    "case_id": "lutrom_direct__8kb__mixed_firmware",
    "variant": "lutrom_direct",
    "size_bytes": 8192,
    "program": "mixed_firmware",
    "vivado_level": "synth_only",
    "status": "pass"
  },
  "reproducibility": {
    "git_commit": "",
    "vivado_version": "",
    "part": "xc7a35tcpg236-1",
    "strategy": "Default",
    "top": "TOP",
    "clock_period_ns": 40.0
  },
  "resources": {
    "flat": {
      "lut": 0,
      "lut_logic": 0,
      "lut_as_memory": 0,
      "lutram": 0,
      "srl": 0,
      "ff": 0,
      "ramb18": 0,
      "ramb36": 0,
      "bram_tile": 0,
      "dsp": 0,
      "io": 0,
      "bufg": 0
    },
    "hier": {
      "InstrRom": {},
      "ProgramRam": {},
      "InstrBusMux": {},
      "FetchStage": {},
      "Rv32iCore": {}
    },
    "util_pct": {
      "lut": 0.0,
      "ff": 0.0,
      "bram": 0.0,
      "dsp": 0.0
    }
  },
  "timing": {
    "wns_ns": 0.0,
    "tns_ns": 0.0,
    "whs_ns": 0.0,
    "ths_ns": 0.0,
    "fmax_est_mhz": 0.0,
    "critical_path": {
      "group": "",
      "from": "",
      "to": "",
      "logic_levels": 0,
      "datapath_delay_ns": 0.0,
      "route_delay_ns": 0.0
    },
    "instruction_path": {
      "in_top10": false,
      "worst_delay_ns": 0.0,
      "logic_levels": 0,
      "route_delay_ns": 0.0,
      "score": 0.0
    }
  },
  "runtime": {},
  "power": {
    "total_w": null,
    "dynamic_w": null,
    "static_w": null
  },
  "quality": {
    "methodology_error_count": 0,
    "methodology_warning_count": 0,
    "drc_error_count": 0,
    "drc_warning_count": 0,
    "parse_errors": []
  }
}
```

`summary.csv`는 위 JSON에서 flat하게 뽑은 값만 담는다. 그래프/표 재가공도 `summary.csv`를 기준으로 한다.

### 7.7 Simulation counter 자동화

XSIM도 runner가 실행한다.

권장 방식:

- `tb/tb_InstrMemSweep.sv`를 만든다.
- case별 generated `.mem`과 variant define을 include path로 넘긴다.
- simulation 종료 시 `output/instr_mem_sweep/cases/<case_id>/sim/counters.json`을 출력한다.

counter JSON 예:

```json
{
  "cycle_count": 12000,
  "retired_instr_count": 9000,
  "fetch_wait_cycles": 300,
  "fetch_request_count": 9100,
  "fetch_response_count": 9000,
  "redirect_flush_count": 120,
  "prefetch_hit_count": 8200,
  "prefetch_empty_count": 240,
  "discarded_prefetch_count": 180,
  "program_done": true,
  "watchdog_timeout": false
}
```

simulation parser는 JSON이 없으면 log에서 다음 line 형식을 fallback으로 파싱한다.

```text
[INSTR_SWEEP] cycle_count=...
[INSTR_SWEEP] retired_instr_count=...
[INSTR_SWEEP] fetch_wait_cycles=...
```

### 7.8 Summary 생성

`make_summary.py`는 `summary.csv`와 `summary.md`를 생성한다.

`summary.md` 필수 섹션:

```text
1. Best implementation by size
2. Resource crossover
3. Timing crossover
4. Runtime/CPI impact
5. Recommendation for BootRom
6. Recommendation for ProgramRam / I-TCM
7. Cases requiring routed confirmation
8. Parser warnings and missing metrics
9. Raw report index
```

자동 판정 규칙 초안:

```text
if lutrom_direct WNS < 0 and bram_prefetch4 WNS >= 0:
    recommend bram_prefetch4
elif lutrom_direct instr_path_in_top10 and size >= 8192:
    recommend bram or bram_prefetch
elif bram_sync CPI penalty > 5% and bram_prefetch4 recovers at least 70% of penalty:
    recommend bram_prefetch4
elif lutrom_direct LUTRAM per KB grows superlinearly and BRAM usage remains within budget:
    recommend routed confirmation for BRAM variant
else:
    keep smaller/simpler implementation
```

자동 비교 그래프 후보:

```text
lut_by_size.png
lutram_by_size.png
bram_by_size.png
wns_by_size.png
cpi_by_size.png
fetch_wait_ratio_by_size.png
instr_path_score_by_size.png
```

## 8. 빠른 실행 모드와 확정 실행 모드

수동 지옥을 피하려면 처음부터 전체 route sweep를 돌리지 않는다.

### 8.1 Fast mode

목적:

- 1시간 내외로 큰 경향 확인
- 4KB/8KB/16KB
- `linear_sweep`, `mixed_firmware`
- `lutrom_direct`, `bram_sync`
- Vivado `synth_only`

예상 case 수:

```text
3 sizes * 2 programs * 2 variants = 12 cases
```

### 8.2 Full mode

목적:

- 최종 의사결정용
- 1KB/2KB/4KB/8KB/16KB/32KB
- 3 programs
- 4 variants
- synth_only 전체 + route 후보만

예상 case 수:

```text
6 sizes * 3 programs * 4 variants = 72 synth cases
route는 size별 대표 후보 8~12 cases만
```

### 8.3 Resume / skip

runner는 이미 완료된 case를 건너뛴다.

완료 판단:

```text
case_manifest.json 존재
vivado/status.json status == pass
sim/counters.json 존재 또는 sim skipped
```

옵션:

```text
--resume
--force-case <case_id>
--only-variant bram_prefetch4
--only-size 8192
--mode fast
--mode full
--vivado-level synth_only
--vivado-level route
```

## 9. Simulation / Runtime 지표

RTL simulation에서는 cycle 지표를 추가한다.

필수 counter:

| Counter | 의미 |
| --- | --- |
| `cycle_count` | 전체 실행 cycle |
| `retired_instr_count` | retire instruction 수 |
| `fetch_wait_cycles` | instruction response 때문에 fetch/pipeline이 기다린 cycle |
| `fetch_request_count` | instruction request 발행 횟수 |
| `fetch_response_count` | instruction response 수신 횟수 |
| `redirect_flush_count` | branch/jump/trap/mret flush 횟수 |
| `prefetch_hit_count` | prefetch queue에서 바로 공급한 횟수 |
| `prefetch_miss_or_empty_count` | queue empty로 fetch wait 발생한 횟수 |
| `discarded_prefetch_count` | redirect 때문에 버린 prefetched instruction 수 |
| `program_done` | test program 정상 종료 여부 |
| `watchdog_timeout` | simulation watchdog timeout 여부 |

계산 지표:

```text
CPI = cycle_count / retired_instr_count
fetch_wait_ratio = fetch_wait_cycles / cycle_count
fetch_response_efficiency = fetch_response_count / fetch_request_count
prefetch_useful_ratio = prefetch_hit_count / retired_instr_count
redirect_discard_avg = discarded_prefetch_count / redirect_flush_count
```

## 10. 판정 기준

report parser와 summary generator가 다음 기준을 자동 적용한다. 최종 판단은 `summary.md`에서 사람이 확인하되, 원본 `.rpt`를 일일이 열지 않는 것을 목표로 한다.

반드시 확인할 항목:

| Report | 확인 항목 |
| --- | --- |
| `util_hier.rpt` | `InstrRom`, `ProgramRam`, `InstrBusMux`, `FetchStage`의 LUT/LUTRAM/RAMB 사용량 |
| `timing_summary.rpt` | WNS, TNS, failing endpoint, target Fmax 가능성 |
| `timing_paths.rpt` | PC 또는 `ReqAddr`에서 `RspRdata/IFIDData.Instr`로 이어지는 critical path 여부 |
| `clock_util.rpt` | clocking resource 변화 |
| `route_status.rpt` | routed case의 route completion 여부 |
| `methodology.rpt` | methodology error/warning count |
| `drc.rpt` | DRC error/warning count |
| `power.rpt` | 큰 LUTROM과 BRAM 구조의 대략적 power 차이 |

판정할 resource columns:

```text
LUT
LUT Logic
LUT as Memory / LUTRAM
SRL
FF
RAMB18
RAMB36
BRAM Tile
DSP
IO
BUFG
```

### LUTROM Direct 유지

다음 조건이면 direct 구조를 유지한다.

```text
WNS >= 0
PC -> instr critical path가 top 10 timing path에 반복적으로 등장하지 않음
LUT/LUTRAM 증가가 전체 SoC와 NPU/DMA 계획에 부담되지 않음
CPI 이점이 BRAM+prefetch보다 명확함
```

예상 유지 구간:

```text
1KB ~ 4KB
```

### BRAM 전환

다음 조건이면 BRAM 전환을 권장한다.

```text
LUTROM에서 LUT/LUTRAM 사용량이 급증
PC -> InstrRom/ProgramRam -> InstrBusMux -> FetchStage 경로가 timing bottleneck
BRAM variant가 WNS/Fmax를 유의미하게 개선
NPU/DMA/DataBusFabric를 위해 LUT를 아껴야 함
```

예상 전환 후보:

```text
8KB 이상
```

### BRAM + Prefetch 채택

다음 조건이면 BRAM 단독보다 prefetch를 채택한다.

```text
BRAM 단독은 timing/resource가 좋지만 fetch_wait_cycles가 증가
2-entry 또는 4-entry prefetch가 fetch_wait_ratio와 CPI를 회복
redirect_discard_avg가 허용 가능
```

추천 default:

```text
ProgramRam / I-TCM 8KB 이상: BRAM + 4-entry prefetch 후보
BootRom 1~4KB: LUTROM direct 후보
```

## 11. 권장 실행 순서

수동 case 실행은 금지하고 runner 중심으로 진행한다.

1. `tools/timing/instr_mem_sweep/instr_mem_sweep.yml`에 fast mode matrix를 작성한다.
2. `run_instr_mem_sweep.py --mode fast --vivado-level synth_only --resume`로 1차 경향을 확인한다.
3. `summary.md`에서 4KB/8KB/16KB의 LUTROM direct resource/timing 변화와 BRAM 후보의 resource 변화를 본다.
4. 8KB 이상에서 instruction path critical 또는 LUTRAM 급증이 보이면 BRAM sync/prefetch prototype을 route 후보로 승격한다.
5. `run_instr_mem_sweep.py --mode full --vivado-level synth_only --resume`로 전체 synth sweep를 돌린다.
6. summary가 고른 후보 8~12개만 `--vivado-level route`로 확정한다.
7. 최종 표로 `BootRom`과 `ProgramRam/I-TCM`의 권장 구현을 분리 결정한다.

## 12. 최종 의사결정 형식

최종 결론은 다음 표로 남긴다.

| Memory | Size range | Recommended implementation | Reason |
| --- | ---: | --- | --- |
| BootRom | 1~4KB | LUTROM direct or BRAM | report 결과로 결정 |
| ProgramRam / I-TCM | 4KB | LUTROM direct vs BRAM 경계 | timing/resource 비교 |
| ProgramRam / I-TCM | 8KB+ | BRAM + prefetch 후보 | LUT 절약, timing 안정성 |
| ProgramRam / I-TCM | 16KB+ | BRAM 확정 후보 | LUTROM 부담 큼 |

## 13. 자동화 완료 기준

- runner가 source tree를 직접 덮어쓰지 않고 case별 generated config만 사용한다.
- `--resume` 실행 시 완료 case를 재실행하지 않는다.
- 실패 case가 있어도 전체 sweep가 중단되지 않고 `status`가 summary에 기록된다.
- `parse_vivado_reports.py` unit test가 sample Vivado report fixture를 통과한다.
- case마다 `metrics/case_metrics.json`이 생성되고 `parse_errors`가 summary에 노출된다.
- `summary.csv`, `summary.json`, `summary.md`가 runner 한 번으로 생성된다.
- Vivado `.rpt` 원본을 열지 않아도 size/variant별 resource/timing/runtime 경향이 보인다.

## 14. 실험 완료 기준

- 4KB/8KB/16KB에 대해 LUTROM direct report가 존재한다.
- 최소 8KB에 대해 BRAM sync-read report가 존재한다.
- 최소 8KB에 대해 BRAM + 4-entry prefetch simulation 결과가 존재한다.
- `summary.csv`와 `summary.md`에 resource/timing/runtime/power/quality 비교가 정리된다.
- `summary.md`에 missing metric과 parser warning이 별도 섹션으로 기록된다.
- 최종적으로 `BootRom`과 `ProgramRam/I-TCM` 각각의 구현 권장안이 분리되어 있다.
