# TCM, BRAM, NPU Performance Test Plan

## Goal

RISC-V 5-stage core를 NPU 제어용 MCU로 사용할 때, instruction/data memory 구조를 바꿨을 때의 실제 이득을 확인한다.

최종 판단은 Fmax만 보지 않는다.

```text
runtime = cycle_count * clock_period
effective_perf = Fmax / CPI
```

따라서 각 구조는 다음 세 가지를 같이 본다.

- timing: WNS, minimum period, Fmax
- execution: cycle count, CPI, stall/bubble/wait cycle
- cost: LUT, FF, BRAM, routing congestion

## Baseline Assumption

현재 구조는 다음에 가깝다.

```text
RISC-V
 ├─ InstrRom: distributed ROM, combinational read
 ├─ DataRam : distributed RAM, combinational read + synchronous write
 └─ APB     : UART/GPIO/INTC low-speed MMIO
```

현재 성능 병목은 APB가 아니라 pipeline 내부, 특히 EX boundary 쪽이다. 따라서 peripheral bus 변경보다 instruction/data memory 구조 변경은 큰 program image, BRAM 전환, NPU memory sharing 상황에서 평가해야 한다.

## Recommended Final Direction

가장 적합한 목표 구조는 다음이다.

```text
RISC-V 5-stage MCU
 ├─ I-TCM BRAM
 │    └─ 2-4 entry prefetch queue
 ├─ D-TCM BRAM
 │    └─ optional 1-entry store buffer
 └─ control/MMIO fabric
      ├─ NPU control registers
      ├─ DMA control registers
      └─ AXI-Lite to APB bridge
           ├─ GPIO
           ├─ FND
           ├─ UART
           └─ Timer/INTC

NPU data path
 ├─ AXI DMA
 ├─ AXI-Stream NPU
 └─ NPU scratchpad/Data BRAM
```

핵심 원칙:

- CPU instruction/data hot path는 local TCM으로 유지한다.
- NPU bulk data는 CPU load/store가 아니라 DMA/scratchpad로 이동한다.
- GPIO/FND/UART 같은 저속 peripheral은 APB 뒤에 둔다.
- CPU I-fetch와 NPU DMA가 같은 bus를 매 cycle 경쟁하게 만들지 않는다.

## Structures To Test

### A. Current LUTROM/LUTRAM Baseline

```text
PC -> distributed InstrRom -> IF/ID
MEM -> distributed DataRam -> load formatter
```

Purpose:

- 현재 구조 기준값.
- 작은 program에서는 가장 단순하고 빠를 수 있다.
- 큰 program image에서 LUT/routing이 얼마나 나빠지는지 확인한다.

Expected:

- small image: good Fmax, zero read wait
- large image: LUT 증가, route delay 증가, IF path가 critical path가 될 수 있음

### B. Naive BRAM Instruction Memory

```text
PC request -> BRAM
next cycle -> instruction
pipeline waits if instruction not ready
```

Purpose:

- BRAM만 단순 치환했을 때의 손해를 확인한다.
- BRAM latency를 pipeline에 흡수하지 않으면 CPI가 얼마나 나빠지는지 본다.

Expected:

- Fmax는 좋아질 수 있음
- fetch wait 때문에 CPI 악화 가능
- 좋은 최종 구조는 아니고 비교용 baseline

### C. BRAM-Aware I-TCM Pipeline

```text
cycle N   : PC0 -> I-BRAM addr
cycle N+1 : PC4 -> I-BRAM addr, instr0 -> IF/ID
cycle N+2 : PC8 -> I-BRAM addr, instr1 -> IF/ID
```

Purpose:

- BRAM 1-cycle latency를 IF pipeline에 흡수한다.
- 순차 fetch는 첫 fill 이후 1 instruction/cycle throughput을 목표로 한다.

Expected:

- 큰 instruction memory에서 Fmax 안정화
- sequential code에서는 거의 zero-wait처럼 동작
- taken branch/jump/trap에서는 target fetch penalty가 남음

### D. BRAM-Aware I-TCM + Prefetch Queue

```text
I-BRAM -> prefetch queue -> IF/ID
redirect -> queue flush -> target fetch
```

Recommended starting point:

- queue depth: 2, 4, 8 entries 비교
- first target: 4 entries

Purpose:

- BRAM latency와 짧은 refill hiccup을 숨긴다.
- sequential code와 short straight-line blocks에서 fetch wait를 줄인다.

Expected:

- sequential test에서 fetch wait 거의 0
- branch-heavy test에서는 flush penalty 남음
- queue가 너무 크면 작은 I-cache와 비슷해져 control/timing 비용 증가

### E. Harvard BRAM TCM

```text
I-TCM BRAM: instruction fetch only
D-TCM BRAM: load/store only
```

Purpose:

- IF와 MEM stage가 같은 cycle에 동시에 memory를 접근할 수 있게 한다.
- unified memory structural hazard를 제거한다.

Expected:

- load/store-heavy code에서 instruction fetch 충돌 없음
- CPU-local code/data에는 AHB/AXI보다 예측 가능
- Basys3급 FPGA에서 가장 현실적인 MCU memory 구조

### F. Harvard BRAM TCM + Prefetch + Store Buffer

```text
I side:
  I-TCM BRAM -> 4-entry prefetch queue -> IF/ID

D side:
  MEM store -> 1-entry store buffer -> D-TCM BRAM
  MEM load  -> D-TCM BRAM -> WB/forward
```

Purpose:

- 최종 후보 구조.
- instruction fetch wait, store-induced stall, I/D memory conflict를 동시에 줄인다.

Expected:

- best practical MCU structure for this project
- still simple enough for FPGA timing
- NPU/DMA path와 CPU-local path를 분리하기 좋음

## Optional Structures

### G. Tiny Direct-Mapped I-Cache

Use only after D structure is measured.

Purpose:

- loop/branch target reuse를 잡는다.
- 큰 prefetch FIFO보다 branch-heavy code에 더 강하다.

Cost:

- tag/valid 비교
- miss/refill FSM
- flush/invalidate policy
- timing 검증 증가

### H. Unified AHB/AXI Memory Fabric

```text
CPU I/D + DMA + NPU -> shared interconnect -> memory
```

Use only when multiple masters must share the same large memory.

Risk:

- CPU fetch가 DMA/NPU와 경쟁한다.
- arbitration wait가 생긴다.
- 현재 MCU-style core의 deterministic timing이 나빠질 수 있다.

## Metrics To Collect

### Timing Metrics

- post-synth WNS
- post-opt WNS
- post-place WNS
- post-route WNS
- minimum period
- estimated Fmax
- critical path stage/family
- route delay share
- high fanout nets

### Execution Metrics

Add counters or simulation trace fields for:

- total cycles
- retired instructions
- CPI
- fetch wait cycles
- prefetch empty cycles
- branch redirect flush count
- branch redirect penalty cycles
- load-use stall cycles
- memory wait cycles
- data bus wait cycles
- store buffer full stall cycles
- trap/interrupt redirect penalty cycles

Suggested derived metrics:

```text
CPI = total_cycles / retired_instructions
fetch_wait_rate = fetch_wait_cycles / total_cycles
branch_penalty_avg = branch_redirect_penalty_cycles / branch_redirect_flush_count
runtime_ns = total_cycles * clock_period_ns
```

### Resource Metrics

- LUT
- FF
- BRAM36/BRAM18
- URAM, if any
- mux count or large fan-in decode count
- max fanout
- implementation runtime

### Correctness Metrics

- register golden check pass/fail
- memory golden check pass/fail
- trap/interrupt behavior pass/fail
- NPU input/output buffer integrity
- DMA transfer completion and alignment

## Test Program Sets

### T0. Smoke

Purpose:

- 구조 변경 후 빠르게 sanity check.

Content:

- reset
- add/addi
- one load
- one store
- one branch not taken
- one branch taken
- one jal
- terminal self loop

Use:

- every RTL change
- simulation first
- then small Vivado run if needed

### T1. Linear Large Instruction Sweep

Purpose:

- large instruction memory에서 LUTROM vs BRAM Fmax 차이를 본다.
- branch가 거의 없는 상태에서 fetch throughput을 측정한다.

Content:

- instruction image size sweep: 32, 64, 128, 256, 512, 1K, 2K, 4K, 8K, 16K instructions
- mostly independent ALU/immediate instructions
- PC가 넓은 address range를 실제로 지나가게 구성

Important:

- 큰 ROM을 선언만 하고 실행하지 않으면 최적화되거나 실제 IF path 영향을 못 볼 수 있다.
- PC가 넓은 범위를 순차적으로 fetch해야 한다.
- x축은 위 sweep 크기를 모두 사용한다.
- x축은 log2 scale 또는 동일 간격 category scale을 사용한다.
- 1K 미만 구간은 LUTROM이 유리한 경계점을 찾기 위한 구간이므로 생략하지 않는다.

Expected signal:

- LUTROM은 size 증가에 따라 LUT/routing 증가
- BRAM-aware I-TCM은 Fmax가 더 안정적

### T2. Branch Heavy

Purpose:

- BRAM 1-cycle target fetch penalty, prefetch flush cost, redirect logic을 평가한다.

Content:

- taken branch loop
- alternating taken/not-taken branch
- jal forward/backward
- jalr register target
- nested small loops
- terminal self loop

Metrics:

- branch redirect count
- branch penalty cycles
- prefetch flush count
- fetch empty cycles after redirect

Expected signal:

- prefetch only으로는 taken redirect penalty가 남는다.
- later tiny BTB/I-cache가 필요한지 판단한다.

### T3. Load/Store Heavy

Purpose:

- D-TCM BRAM latency, load-use stall, store buffer 효과를 본다.

Content:

- repeated lw
- repeated sw
- lw followed immediately by dependent ALU
- lw with one independent instruction gap
- byte/halfword/word load-store
- unaligned access trap cases, if supported

Metrics:

- load-use stall cycles
- data memory wait cycles
- store buffer full cycles
- CPI

Expected signal:

- D-TCM은 deterministic하지만 load-use hazard는 남는다.
- store buffer는 store-heavy code의 stall을 줄일 수 있다.

### T4. Mixed MCU Firmware

Purpose:

- 실제 MCU control firmware 느낌의 평균 성능을 본다.

Content:

- loop
- branch
- load/store
- MMIO read/write
- interrupt enable/status polling
- UART/GPIO/FND register access

Metrics:

- CPI
- APB wait cycles
- fetch wait cycles
- branch penalty
- runtime

Expected signal:

- APB는 전체 성능 병목이 아닌지 확인
- peripheral access가 많은 경우 APB wait가 얼마나 보이는지 확인

### T5. NPU Control And DMA

Purpose:

- RISC-V가 NPU controller로 동작할 때 bus 구조가 CPU fetch를 방해하는지 본다.

Content:

- CPU writes NPU control registers
- CPU sets DMA source/destination/length
- DMA transfers input/weight/output
- NPU runs on scratchpad
- CPU waits by polling and by interrupt, both variants

Metrics:

- CPU cycles spent configuring NPU
- DMA busy time
- CPU stall during DMA
- interrupt latency
- NPU done to CPU response cycles
- data buffer correctness

Expected signal:

- CPU I/D TCM이 DMA path와 분리되어 있으면 CPU fetch stall이 줄어든다.
- NPU data should not move through APB.

## Test Matrix

Start with this matrix.

| Case | Memory Structure | Prefetch | Store Buffer | Main Question |
| --- | --- | --- | --- | --- |
| A | current LUTROM/LUTRAM | no | no | current baseline |
| B | naive I-BRAM | no | no | raw BRAM latency cost |
| C | pipelined I-TCM BRAM | no | no | BRAM latency absorption |
| D | pipelined I-TCM BRAM | 4-entry | no | fetch wait reduction |
| E | I-TCM + D-TCM BRAM | 4-entry | no | I/D conflict removal |
| F | I-TCM + D-TCM BRAM | 4-entry | 1-entry | final MCU candidate |

Run each case on:

| Test | Required |
| --- | --- |
| T0 Smoke | yes |
| T1 Linear Large | yes |
| T2 Branch Heavy | yes |
| T3 Load/Store Heavy | yes |
| T4 Mixed MCU Firmware | yes |
| T5 NPU Control And DMA | after NPU/DMA shell exists |

## Decision Rules

Use these rules to choose the next architecture.

### Keep LUTROM/LUTRAM If

- program image stays tiny
- Fmax is not limited by instruction memory
- BRAM must be saved for NPU scratchpad

### Move To BRAM I-TCM If

- instruction memory is 1KB or larger
- LUT usage grows too much
- IF path or ROM routing appears in timing critical paths
- firmware includes drivers, printf, DMA setup, NPU control

### Add Prefetch If

- BRAM I-TCM creates fetch wait cycles
- sequential code CPI is worse than expected
- branch penalty is acceptable but refill bubbles are visible

### Add Tiny I-Cache/BTB Later If

- branch-heavy code dominates runtime
- loops suffer repeated target refill
- prefetch queue gives limited benefit

### Avoid Unified Shared Bus For CPU I-Fetch If

- DMA/NPU can hold the bus for many cycles
- CPU must keep deterministic control latency
- instruction fetch stall appears during DMA

## Recommended First Implementation Order

1. Add counters before changing architecture.
2. Build T0, T1, T2, T3 program images.
3. Measure current A baseline.
4. Implement B naive I-BRAM only.
5. Implement C pipelined I-TCM.
6. Add D 4-entry prefetch queue.
7. Convert data side to E D-TCM BRAM.
8. Add F 1-entry store buffer only if store stalls are visible.
9. Add NPU/DMA path and run T5.

## Minimal Counter Set

Start with these counters in hardware or simulation trace:

```text
cycle_count
retired_count
fetch_wait_count
prefetch_empty_count
redirect_flush_count
redirect_penalty_count
load_use_stall_count
mem_wait_count
store_buffer_full_count
apb_wait_count
```

These counters are enough to avoid guessing. The report should show both timing and runtime:

```text
Fmax improved but CPI worsened -> architecture may not be better
CPI improved but Fmax worsened -> check runtime
runtime improved and resources acceptable -> keep
```

## Graphs To Render

All graphs should be rendered per test set first, then combined only where the comparison remains readable. The main comparison key is the architecture case:

```text
A = current LUTROM/LUTRAM
B = naive I-BRAM
C = pipelined I-TCM BRAM
D = pipelined I-TCM BRAM + prefetch
E = I-TCM + D-TCM BRAM
F = I/D TCM + prefetch + store buffer
```

### Primary Score Graphs

These are the first graphs to look at when deciding whether a structure is better.

| Graph | Type | X Axis | Y Axis | Group/Color | Use |
| --- | --- | --- | --- | --- | --- |
| Runtime by structure | bar | architecture case A-F | runtime_ns | test set T0-T5 | Best single end-to-end score. Lower is better. |
| Effective performance | bar | architecture case A-F | effective_perf = Fmax / CPI | test set T0-T5 | Shows whether Fmax gain survived CPI loss. Higher is better. |
| Fmax by structure | bar | architecture case A-F | post-route Fmax MHz | test set T0-T5 | Hardware timing comparison. Higher is better. |
| CPI by structure | bar | architecture case A-F | CPI | test set T0-T5 | Pipeline efficiency comparison. Lower is better. |
| Cycle count by structure | bar | architecture case A-F | total_cycles | test set T0-T5 | Separates CPI/cycle penalty from Fmax. Lower is better. |

Recommended primary dashboard:

```text
top-left     : runtime_ns
top-right    : effective_perf
bottom-left  : Fmax
bottom-right : CPI
```

### Stall And Bubble Breakdown

Use stacked bars so the reason for CPI change is visible.

| Graph | Type | X Axis | Y Axis | Stack Components | Use |
| --- | --- | --- | --- | --- | --- |
| CPI breakdown | stacked bar | architecture case A-F | cycles per instruction | ideal_base, fetch_wait, redirect_penalty, load_use, mem_wait, apb_wait, store_buffer_full | Shows why CPI changed. |
| Total stall cycles | stacked bar | architecture case A-F | cycles | fetch_wait, prefetch_empty, redirect_penalty, load_use, mem_wait, apb_wait, store_buffer_full | Shows absolute stall cost. |
| Fetch wait ratio | bar or line | architecture case A-F | fetch_wait_cycles / total_cycles | test set | Validates I-TCM/prefetch benefit. |
| Redirect penalty average | bar | architecture case A-F | redirect_penalty_cycles / redirect_flush_count | branch-heavy variants | Shows branch/jump/trap cost. |
| Load-use stall rate | bar | architecture case A-F | load_use_stall_cycles / retired_instructions | load/store variants | Shows D-TCM/load pipeline behavior. |

For CPI breakdown, compute:

```text
CPI_total = total_cycles / retired_instructions
CPI_component = component_cycles / retired_instructions
ideal_base = retired_instructions / retired_instructions = 1.0
```

### Memory Scaling Graphs

These graphs answer the LUTROM vs BRAM question for large instruction images.

Standard instruction-count sweep:

```text
32, 64, 128, 256, 512, 1K, 2K, 4K, 8K, 16K
```

| Graph | Type | X Axis | Y Axis | Lines | Use |
| --- | --- | --- | --- | --- | --- |
| Fmax vs instruction image size | line | instruction count: 32 to 16K, doubling each step | post-route Fmax MHz | A, B, C, D | Shows when BRAM beats LUTROM. |
| Runtime vs instruction image size | line | instruction count | runtime_ns | A, B, C, D | Shows real performance, not just Fmax. |
| LUT usage vs instruction image size | line | instruction count | LUT count | A, B, C, D | Shows distributed ROM area growth. |
| BRAM usage vs instruction image size | step line | instruction count | BRAM18/BRAM36 count | B, C, D | Shows BRAM allocation steps. |
| IF criticality vs image size | line | instruction count | IF-related worst path delay ns | A, B, C, D | Shows whether instruction memory enters critical path. |

Expected interpretation:

- If A Fmax drops as instruction count grows and C/D stays stable, BRAM-aware I-TCM is winning.
- If B has good Fmax but poor runtime, naive BRAM latency is hurting CPI.
- If D improves runtime over C, prefetch is hiding refill bubbles.

### Prefetch Queue Sensitivity

Run this only for BRAM-aware structures.

| Graph | Type | X Axis | Y Axis | Lines/Groups | Use |
| --- | --- | --- | --- | --- | --- |
| Runtime vs prefetch depth | line | depth: 0, 2, 4, 8 | runtime_ns | T1/T2/T4 | Finds useful queue depth. |
| Fetch wait vs prefetch depth | line | depth | fetch_wait_cycles | T1/T2/T4 | Shows latency hiding. |
| Redirect waste vs prefetch depth | line | depth | flushed_prefetch_entries or redirect_penalty_cycles | T2 | Shows over-prefetch penalty. |
| LUT/FF vs prefetch depth | line | depth | LUT and FF count | separate lines | Shows hardware cost. |

Decision rule:

```text
Choose the smallest depth where runtime improvement flattens.
Default target: 4 entries.
```

### Branch Behavior Graphs

Use these for T2 Branch Heavy.

| Graph | Type | X Axis | Y Axis | Group/Color | Use |
| --- | --- | --- | --- | --- | --- |
| Branch penalty by pattern | grouped bar | branch pattern: not_taken, taken_loop, alternating, jal, jalr, trap | avg penalty cycles | architecture case | Shows which redirect type hurts. |
| Redirect count vs penalty | scatter | redirect_flush_count | redirect_penalty_cycles | architecture case | Shows whether penalty scales with redirects. |
| Branch-heavy runtime | bar | architecture case A-F | runtime_ns | branch pattern | Shows real branch workload impact. |

Important expected result:

- Prefetch helps sequential fetch but cannot remove all taken branch/jalr/trap penalty.
- If loop target repeatedly misses, tiny I-cache/BTB becomes worth testing later.

### Load/Store Behavior Graphs

Use these for T3 Load/Store Heavy.

| Graph | Type | X Axis | Y Axis | Group/Color | Use |
| --- | --- | --- | --- | --- | --- |
| Load-use penalty | grouped bar | load pattern: dependent_next, one_gap, two_gap | load_use_stall_cycles | architecture case | Shows forwarding/stall behavior. |
| Store throughput | bar | architecture case | store-heavy runtime_ns | store buffer on/off | Shows store buffer value. |
| Memory wait cycles | stacked bar | architecture case | cycles | d_tcm_wait, apb_wait, store_buffer_full | Separates D-TCM and APB effects. |
| D-side CPI | bar | architecture case | CPI | load/store variant | Shows data memory pipeline cost. |

### Resource And Cost Graphs

Use these to avoid picking a structure that wins runtime but burns too much FPGA.

| Graph | Type | X Axis | Y Axis | Stack/Color | Use |
| --- | --- | --- | --- | --- | --- |
| Resource usage | stacked bar | architecture case A-F | resource count | LUT, FF, BRAM18-equivalent | Area comparison. |
| LUT vs Fmax | scatter | LUT count | Fmax MHz | architecture case label | Finds expensive timing wins. |
| BRAM vs runtime | scatter | BRAM18-equivalent count | runtime_ns | architecture case label | Shows BRAM/performance tradeoff. |
| Runtime vs resource score | scatter | resource_score | runtime_ns | test set | Pareto comparison. |

Suggested resource score:

```text
resource_score = LUT + FF * 0.25 + BRAM18 * 512
```

The score is not an absolute truth. It is only for ranking tradeoffs on one FPGA target.

### NPU/DMA Graphs

Use after DMA/NPU shell exists.

| Graph | Type | X Axis | Y Axis | Group/Color | Use |
| --- | --- | --- | --- | --- | --- |
| CPU stall during DMA | bar | architecture case | CPU stall cycles while DMA busy | DMA size | Shows whether DMA blocks CPU. |
| DMA transfer time | line | transfer bytes | DMA busy cycles | burst/config variant | Validates data path bandwidth. |
| NPU job latency | stacked bar | NPU job size | cycles | CPU setup, DMA in, compute, DMA out, interrupt response | End-to-end accelerator view. |
| CPU control overhead | bar | NPU job size | CPU active cycles | polling vs interrupt | Shows controller overhead. |
| Scratchpad size sweep | line | scratchpad KB | NPU job latency cycles | tile size | Finds useful BRAM allocation. |

Expected target:

- CPU fetch should not stall heavily while DMA/NPU runs.
- Tensor data should not pass through APB.
- RISC-V should mostly pay setup and interrupt/poll overhead, not data movement cycles.

## Plot Naming Convention

Use stable file names so reports can link them.

```text
plots/runtime_by_structure_<test>.png
plots/fmax_by_structure_<test>.png
plots/cpi_breakdown_<test>.png
plots/memory_scaling_fmax.png
plots/memory_scaling_runtime.png
plots/prefetch_depth_sweep_<test>.png
plots/branch_penalty_<test>.png
plots/load_store_stalls_<test>.png
plots/resource_usage.png
plots/npu_job_latency.png
```

## Minimum Graph Set For Each Milestone

### Milestone 1: LUTROM vs BRAM

Required:

- Fmax vs instruction image size
- Runtime vs instruction image size
- LUT usage vs instruction image size
- CPI by structure

Use every instruction image size:

```text
32, 64, 128, 256, 512, 1K, 2K, 4K, 8K, 16K
```

### Milestone 2: BRAM-Aware Pipeline

Required:

- Runtime by structure
- CPI breakdown
- Fetch wait ratio
- IF criticality vs image size

### Milestone 3: Prefetch

Required:

- Runtime vs prefetch depth
- Fetch wait vs prefetch depth
- Redirect waste vs prefetch depth
- LUT/FF vs prefetch depth

### Milestone 4: D-TCM And Store Buffer

Required:

- Load-use penalty
- Store throughput
- Memory wait cycles
- Resource usage

### Milestone 5: NPU/DMA

Required:

- NPU job latency stacked bar
- DMA transfer time
- CPU stall during DMA
- CPU control overhead

## Recommended Report Layout

Each architecture report should show graphs in this order:

1. Runtime and effective performance
2. Fmax and CPI
3. CPI/stall breakdown
4. Memory scaling or queue-depth sweep
5. Resource usage
6. Test-specific detail, such as branch/load/NPU graphs

## Practical Basys3 Starting Sizes

Basys3 Artix-7 35T has limited BRAM, so start conservative.

Recommended first sizes:

```text
I-TCM BRAM       : 16KB
D-TCM BRAM       : 16KB
Prefetch queue   : 4 entries
Store buffer     : 1 entry
NPU scratchpad   : 64KB or more if BRAM allows
APB peripherals  : register only, no tensor data
```

If firmware grows:

```text
I-TCM 32KB
D-TCM 16KB
NPU scratchpad reduced or banked
```

If NPU tensor buffer is the priority:

```text
I-TCM 16KB
D-TCM 8KB
NPU scratchpad gets most remaining BRAM
```

## Final Recommendation

The best practical target for this project is:

```text
I/D split BRAM TCM
+ 4-entry instruction prefetch queue
+ optional 1-entry store buffer
+ NPU data moved by DMA/scratchpad
+ GPIO/FND/UART behind AXI-Lite to APB bridge
```

Do not judge by Fmax alone. Pick the structure with the best measured `cycle_count * clock_period` under T1-T5, while keeping BRAM available for NPU scratchpad.
