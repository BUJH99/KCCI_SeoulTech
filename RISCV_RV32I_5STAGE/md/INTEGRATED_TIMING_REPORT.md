# INTEGRATED_TIMING_REPORT

- This report keeps one category per timing program image.
- Re-running one timing flow refreshes only that flow's detail block for the selected program.

<!-- PROGRAM_SECTION:full_coverage:START -->
## Full Coverage.mem

- Program key: `full_coverage`

### Single-Cycle Optimization Detail

<!-- DETAIL_SECTION:single_cycle:full_coverage:START -->
- Source project: `RISCV_RV32I_SINGLE`
- Source artifacts: `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage`
- Standalone report path: `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_SINGLE/md/SINGLE_CYCLE_OPTIMIZATION_REPORT.md`
- Detail updated: `2026-04-29 21:15:01 KST`

#### 🧭 Summary

| Item | Value |
| --- | --- |
| Overall verdict | ❌ FAIL |
| Program image | `Full Coverage.mem` |
| Worst endpoint | `uDesign/timingRetainMetric_reg/D` |
| Primary bottleneck | Timing Metric at 15.215 ns |
| Runtime winner | 5-stage pipeline (210.018 ns faster) |
| First action | Start with the worst endpoint and reduce the longest combinational cone before changing constraints. |

#### 🧠 Analysis Result

| Field | Result |
| --- | --- |
| Overall Verdict | ❌ FAIL |
| Primary Bottleneck | Timing Metric at 15.215 ns |
| Root Cause Candidates | 3 candidate(s) promoted from parsed timing artifacts |
| Recommended Next Actions | 3 action(s) |

##### Root Cause Candidates

| Severity | Category | Finding | Evidence | Impact |
| --- | --- | --- | --- | --- |
| ❌ FAIL | Timing Closure | Negative setup timing | WNS -5.215 ns, failing endpoints 2049 | The current single-cycle implementation does not meet the requested clock period. |
| ⚠️ WARN | Routing | Route-dominant timing paths | Average route share 74.1%, max route share 74.1% | Physical distance or fanout is likely contributing more than logic depth on the critical paths. |
| ⚠️ WARN | Repeated Archetype | Repeated critical path signature | `Pc -> decode/control -> DataRam readback -> Regfile D` covers 99.0% of parsed top100 paths (99 hits) | One structural pattern dominates timing, so a targeted RTL/placement fix should move many paths together. |

#### 📊 Key Metrics

- `Delta` is `5-stage reference - single-cycle`.
- Runtime and CPI are estimated from the selected timing-program trace.

| Metric | Single-Cycle | 5-Stage Reference | Delta |
| --- | ---: | ---: | ---: |
| WNS (ns) | -5.215 | 0.002 | +5.217 |
| Minimum Period (ns) | 15.215 | 9.998 | -5.217 |
| Fmax (MHz) | 65.72 | 100.02 | +34.30 |
| LUTs | 1843 | 2403 | +560 |
| Registers | 1025 | 1739 | +714 |
| Cycles | 92 | 119 | +27 |
| CPI | 1.000 | 1.293 | +0.293 |
| Runtime | 1399.780 ns (1.400 us) | 1189.762 ns (1.190 us) | -210.018 ns |
| Pipeline Speedup (x) | 1.000x | 1.177x | +0.177x |

#### 🎯 Recommended Actions

1. Start with the worst endpoint and reduce the longest combinational cone before changing constraints.
2. Prioritize placement locality, high-fanout cleanup, and register duplication before deep RTL rewrites.
3. Optimize the repeated signature first, then regenerate the report to confirm the distribution changes.

#### 📁 Evidence

| Evidence | Location |
| --- | --- |
| Artifact directory | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage` |
| Timing summary | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_timing_summary.rpt` |
| Parsed timing paths | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_timing_paths.tsv` |
| Top timing report | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_timing_top100.rpt` |
| Utilization summary | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_utilization.rpt` |
| Standalone report | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_SINGLE/md/SINGLE_CYCLE_OPTIMIZATION_REPORT.md` |
| Companion pipeline artifacts | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_5STAGE/.analysis/pipeline_perf/programs/full_coverage/pipeline` |
<!-- DETAIL_SECTION:single_cycle:full_coverage:END -->

### Pipeline Performance Detail

<!-- DETAIL_SECTION:pipeline_perf:full_coverage:START -->
- Source report: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\md\PIPELINE_PERF_REPORT.md`
- Detail updated: `2026-05-05 02:17:20 대한민국 표준시`

- Program key: `full_coverage`
- Last updated: `2026-05-05 02:17:20 대한민국 표준시`

#### 🧭 Summary

| Item | Value |
| --- | --- |
| Overall verdict | ⚠️ WARN |
| Primary bottleneck | EX Stage (ID/EX -> EX/MEM) / EX at 9.729 ns |
| Route status | fully routed |
| Runtime winner | NA |
| Instruction-focus coverage | ℹ️ INFO Skipped instruction-focus rerun for selected program `Full Coverage.mem`. |
| First action | Check placement locality around the worst boundary and reduce high-fanout control/data nets. |

#### 🧠 Analysis Result

| Field | Result |
| --- | --- |
| Overall Verdict | ⚠️ WARN |
| Primary Bottleneck | EX Stage (ID/EX -> EX/MEM) / EX at 9.729 ns |
| Root Cause Candidates | 3 candidate(s) promoted from parsed timing artifacts |
| Recommended Next Actions | 3 action(s) |

##### Root Cause Candidates

| Severity | Category | Finding | Evidence | Impact |
| --- | --- | --- | --- | --- |
| ⚠️ WARN | Routing | Route-dominant stage paths | Average route share 77.7%, max route share 84.6% | Stage timing is likely limited by physical locality or fanout, not only logic depth. |
| ⚠️ WARN | Stage Boundary | EX Stage (ID/EX -> EX/MEM) | EX Stage (ID/EX -> EX/MEM) reaches 9.729 ns | This register-to-register boundary is the best first target for pipeline timing closure. |
| ⚠️ WARN | Instruction Focus | Incomplete instruction-focus coverage | Skipped instruction-focus rerun for selected program `Full Coverage.mem`. | Class/mnemonic-level attribution may be incomplete for this program image. |

#### 📊 Key Metrics

- `Delta` is `5-stage pipeline - single-cycle`.
- Runtime and CPI are estimated from the selected timing-program trace.
- 5-stage execution model: `retired + 4 fill + load-use stalls + 2-cycle taken branches/JALR + 1-cycle decode-resolved JAL before the terminal self-loop`.

| Metric | Single-Cycle | 5-Stage Pipeline | Delta |
| --- | ---: | ---: | ---: |
| WNS (ns) | NA | 0.009 | NA |
| Minimum Period (ns) | NA | 9.991 | NA |
| Fmax (MHz) | NA | 100.090 | NA |
| LUTs | NA | 2525 | NA |
| Registers | NA | 1850 | NA |
| Cycles | 92 | 118 | +26 |
| CPI | 1.000 | 1.283 | +0.283 |
| Runtime | NA | 1178.938 ns (1.179 us) | NA |
| Pipeline Speedup (x) | NA | NA | NA |

#### 🎯 Recommended Actions

1. Check placement locality around the worst boundary and reduce high-fanout control/data nets.
2. Inspect `EX Stage (ID/EX -> EX/MEM)` fan-in and split or retime the dominant logic before changing unrelated stages.
3. Rerun instruction-focus mode for the missing classes or narrow the focus filter to the failing mnemonic set.

#### 📁 Evidence

| Evidence | Location |
| --- | --- |
| Artifact root | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage` |
| Single-cycle artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage\single_cycle` |
| 5-stage artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage\pipeline` |
| Instruction-focus artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage\instruction_focus` |
| Program memory | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\src\timing_programs\Full Coverage.mem` |
| Instruction source | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\src\timing_programs\Full Coverage.s` |
<!-- DETAIL_SECTION:pipeline_perf:full_coverage:END -->
<!-- PROGRAM_SECTION:full_coverage:END -->

<!-- PROGRAM_SECTION:bubble_sort:START -->
## Bubble Sort.mem

- Program key: `bubble_sort`

### Single-Cycle Optimization Detail

<!-- DETAIL_SECTION:single_cycle:bubble_sort:START -->
- Source project: `RISCV_RV32I_SINGLE`
- Source artifacts: `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort`
- Standalone report path: `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_SINGLE/md/SINGLE_CYCLE_OPTIMIZATION_REPORT.md`
- Detail updated: `2026-04-29 21:15:13 KST`

#### 🧭 Summary

| Item | Value |
| --- | --- |
| Overall verdict | ❌ FAIL |
| Program image | `Bubble Sort.mem` |
| Worst endpoint | `uDesign/timingRetainMetric_reg/D` |
| Primary bottleneck | Timing Metric at 19.583 ns |
| Runtime winner | 5-stage pipeline (414.924 ns faster) |
| First action | Start with the worst endpoint and reduce the longest combinational cone before changing constraints. |

#### 🧠 Analysis Result

| Field | Result |
| --- | --- |
| Overall Verdict | ❌ FAIL |
| Primary Bottleneck | Timing Metric at 19.583 ns |
| Root Cause Candidates | 3 candidate(s) promoted from parsed timing artifacts |
| Recommended Next Actions | 3 action(s) |

##### Root Cause Candidates

| Severity | Category | Finding | Evidence | Impact |
| --- | --- | --- | --- | --- |
| ❌ FAIL | Timing Closure | Negative setup timing | WNS -9.583 ns, failing endpoints 3559 | The current single-cycle implementation does not meet the requested clock period. |
| ⚠️ WARN | Routing | Route-dominant timing paths | Average route share 80.5%, max route share 80.6% | Physical distance or fanout is likely contributing more than logic depth on the critical paths. |
| ⚠️ WARN | Repeated Archetype | Repeated critical path signature | `Pc -> DataRam -> ImmGen -> AluOperandSel -> Alu -> Pc -> DataRam -> Pc -> Alu -> Pc -> CoreTrapGate -> Pc -> Regfile -> Regfile CE` covers 99.0% of parsed top100 paths (99 hits) | One structural pattern dominates timing, so a targeted RTL/placement fix should move many paths together. |

#### 📊 Key Metrics

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

#### 🎯 Recommended Actions

1. Start with the worst endpoint and reduce the longest combinational cone before changing constraints.
2. Prioritize placement locality, high-fanout cleanup, and register duplication before deep RTL rewrites.
3. Optimize the repeated signature first, then regenerate the report to confirm the distribution changes.

#### 📁 Evidence

| Evidence | Location |
| --- | --- |
| Artifact directory | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort` |
| Timing summary | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort/actual_timing_summary.rpt` |
| Parsed timing paths | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort/actual_timing_paths.tsv` |
| Top timing report | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort/actual_timing_top100.rpt` |
| Utilization summary | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/bubble_sort/actual_utilization.rpt` |
| Standalone report | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_SINGLE/md/SINGLE_CYCLE_OPTIMIZATION_REPORT.md` |
| Companion pipeline artifacts | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_5STAGE/.analysis/pipeline_perf/programs/bubble_sort/pipeline` |
<!-- DETAIL_SECTION:single_cycle:bubble_sort:END -->

### Pipeline Performance Detail

<!-- DETAIL_SECTION:pipeline_perf:bubble_sort:START -->
- Source report: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\md\PIPELINE_PERF_REPORT.md`
- Detail updated: `2026-05-06 02:35:33 대한민국 표준시`

- Program key: `bubble_sort`
- Last updated: `2026-05-06 02:35:33 대한민국 표준시`

#### 🧭 Summary

| Item | Value |
| --- | --- |
| Overall verdict | ⚠️ WARN |
| Primary bottleneck | EX Stage (ID/EX -> EX/MEM) / EX at 9.998 ns |
| Route status | fully routed |
| Runtime winner | NA |
| Instruction-focus coverage | ℹ️ INFO Skipped instruction-focus rerun for selected program `Bubble Sort.mem`. |
| First action | Check placement locality around the worst boundary and reduce high-fanout control/data nets. |

#### 🧠 Analysis Result

| Field | Result |
| --- | --- |
| Overall Verdict | ⚠️ WARN |
| Primary Bottleneck | EX Stage (ID/EX -> EX/MEM) / EX at 9.998 ns |
| Root Cause Candidates | 3 candidate(s) promoted from parsed timing artifacts |
| Recommended Next Actions | 3 action(s) |

##### Root Cause Candidates

| Severity | Category | Finding | Evidence | Impact |
| --- | --- | --- | --- | --- |
| ⚠️ WARN | Routing | Route-dominant stage paths | Average route share 78.9%, max route share 85.3% | Stage timing is likely limited by physical locality or fanout, not only logic depth. |
| ⚠️ WARN | Stage Boundary | EX Stage (ID/EX -> EX/MEM) | EX Stage (ID/EX -> EX/MEM) reaches 9.998 ns | This register-to-register boundary is the best first target for pipeline timing closure. |
| ⚠️ WARN | Instruction Focus | Incomplete instruction-focus coverage | Skipped instruction-focus rerun for selected program `Bubble Sort.mem`. | Class/mnemonic-level attribution may be incomplete for this program image. |

#### 📊 Key Metrics

- `Delta` is `5-stage pipeline - single-cycle`.
- Runtime and CPI are estimated from the selected timing-program trace.
- 5-stage execution model: `retired + 4 fill + load-use stalls + 2-cycle taken branches/JALR + 1-cycle decode-resolved JAL before the terminal self-loop`.

| Metric | Single-Cycle | 5-Stage Pipeline | Delta |
| --- | ---: | ---: | ---: |
| WNS (ns) | NA | 0.002 | NA |
| Minimum Period (ns) | NA | 9.998 | NA |
| Fmax (MHz) | NA | 100.020 | NA |
| LUTs | NA | 2863 | NA |
| Registers | NA | 2177 | NA |
| Cycles | 93 | 126 | +33 |
| CPI | 1.000 | 1.355 | +0.355 |
| Runtime | NA | 1259.748 ns (1.260 us) | NA |
| Pipeline Speedup (x) | NA | NA | NA |

#### 🎯 Recommended Actions

1. Check placement locality around the worst boundary and reduce high-fanout control/data nets.
2. Inspect `EX Stage (ID/EX -> EX/MEM)` fan-in and split or retime the dominant logic before changing unrelated stages.
3. Rerun instruction-focus mode for the missing classes or narrow the focus filter to the failing mnemonic set.

#### 📁 Evidence

| Evidence | Location |
| --- | --- |
| Artifact root | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort` |
| Single-cycle artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort\single_cycle` |
| 5-stage artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort\pipeline` |
| Instruction-focus artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort\instruction_focus` |
| Program memory | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\src\timing_programs\Bubble Sort.mem` |
| Instruction source | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\src\timing_programs\Bubble Sort.s` |
<!-- DETAIL_SECTION:pipeline_perf:bubble_sort:END -->
<!-- PROGRAM_SECTION:bubble_sort:END -->
