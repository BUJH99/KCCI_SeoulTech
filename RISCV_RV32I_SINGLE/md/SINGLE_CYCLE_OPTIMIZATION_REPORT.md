# SINGLE_CYCLE Optimization Report

## 🧭 Summary

| Item | Value |
| --- | --- |
| Overall verdict | ❌ FAIL |
| Program image | `Bubble Sort.mem` |
| Worst endpoint | `uDesign/timingRetainMetric_reg/D` |
| Primary bottleneck | Timing Metric at 19.583 ns |
| Runtime winner | 5-stage pipeline (414.924 ns faster) |
| First action | Start with the worst endpoint and reduce the longest combinational cone before changing constraints. |

## 🧠 Analysis Result

| Field | Result |
| --- | --- |
| Overall Verdict | ❌ FAIL |
| Primary Bottleneck | Timing Metric at 19.583 ns |
| Root Cause Candidates | 3 candidate(s) promoted from parsed timing artifacts |
| Recommended Next Actions | 3 action(s) |

### Root Cause Candidates

| Severity | Category | Finding | Evidence | Impact |
| --- | --- | --- | --- | --- |
| ❌ FAIL | Timing Closure | Negative setup timing | WNS -9.583 ns, failing endpoints 3559 | The current single-cycle implementation does not meet the requested clock period. |
| ⚠️ WARN | Routing | Route-dominant timing paths | Average route share 80.5%, max route share 80.6% | Physical distance or fanout is likely contributing more than logic depth on the critical paths. |
| ⚠️ WARN | Repeated Archetype | Repeated critical path signature | `Pc -> DataRam -> ImmGen -> AluOperandSel -> Alu -> Pc -> DataRam -> Pc -> Alu -> Pc -> CoreTrapGate -> Pc -> Regfile -> Regfile CE` covers 99.0% of parsed top100 paths (99 hits) | One structural pattern dominates timing, so a targeted RTL/placement fix should move many paths together. |

## 📊 Key Metrics

- `Delta` is `5-stage reference - single-cycle`.
- Runtime and CPI are estimated from the selected timing-program trace.

| Metric | Single-Cycle | 5-Stage Reference | Delta |
| --- | ---: | ---: | ---: |
| WNS (ns) | -9.583 | -0.417 | +9.166 |
| Minimum Period (ns) | 19.583 | 10.417 | -9.166 |
| Fmax (MHz) | 51.06 | 96.00 | +44.93 |
| LUTs | 2355 | 2304 | -51 |
| Registers | 1319 | 1729 | +410 |
| Cycles | 93 | 135 | +42 |
| CPI | 1.000 | 1.452 | +0.452 |
| Runtime | 1821.219 ns (1.821 us) | 1406.295 ns (1.406 us) | -414.924 ns |
| Pipeline Speedup (x) | 1.000x | 1.295x | +0.295x |

## 🎯 Recommended Actions

1. Start with the worst endpoint and reduce the longest combinational cone before changing constraints.
2. Prioritize placement locality, high-fanout cleanup, and register duplication before deep RTL rewrites.
3. Optimize the repeated signature first, then regenerate the report to confirm the distribution changes.

## 📁 Evidence

| Evidence | Location |
| --- | --- |
| Artifact directory | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort` |
| Timing summary | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort/actual_timing_summary.rpt` |
| Parsed timing paths | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort/actual_timing_paths.tsv` |
| Top timing report | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort/actual_timing_top100.rpt` |
| Utilization summary | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort/actual_utilization.rpt` |
| Standalone report | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_SINGLE/md/SINGLE_CYCLE_OPTIMIZATION_REPORT.md` |
| Companion pipeline artifacts | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_5STAGE/.analysis/pipeline_perf/programs/bubble_sort/pipeline` |

<details>
<summary>Compact timing evidence</summary>

### Canonical Timing Families

| Family | Worst Endpoint | Minimum Period (ns) | Est. Fmax (MHz) | Top Paths |
| --- | --- | ---: | ---: | ---: |
| Timing Metric | `uDesign/timingRetainMetric_reg/D` | 19.583 | 51.06 | 20 |

### Top100 Timing Distribution

| Metric | Worst | P90 | Median | Average |
| --- | ---: | ---: | ---: | ---: |
| Slack (ns) | -9.583 | -9.583 | -9.577 | -9.565 |
| Data path delay (ns) | 19.432 | 19.432 | 19.426 | 19.414 |
| Route delay (ns) | 15.630 | 15.630 | 15.630 | 15.630 |
| Route share (%) | 80.6 | 80.6 | 80.5 | 80.5 |
| Logic levels | 22.0 | 22.0 | 22.0 | 22.0 |

### Program Coverage Context

| Class | Instruction Count | Active Family Hints |
| --- | ---: | --- |
| RTYPE | 2 | Timing Metric, ALU Writeback |
| OPIMM | 14 | Timing Metric, ALU Writeback |
| LOAD | 2 | Timing Metric, Load Writeback |
| STORE | 8 | NA |
| BRANCH | 3 | PC Feedback, Branch Target |
| UPPER_IMM | 0 | Timing Metric, ALU Writeback |
| JUMP | 3 | Timing Metric, PC Feedback, Jump Target, JALR Target |
| SYSTEM | 0 | PC Feedback |

</details>

