# INTEGRATED_TIMING_REPORT

- This report keeps one category per timing program image.
- Re-running one timing flow refreshes only that flow's detail block for the selected program.

<!-- PROGRAM_SECTION:full_coverage:START -->
## Full Coverage.mem

- Program key: `full_coverage`

### Single-Cycle Optimization Detail

<!-- DETAIL_SECTION:single_cycle:full_coverage:START -->
- Source project: `RISCV_32I_SINGLE`
- Source artifacts: `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage`
- Standalone report path: `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/SINGLE_CYCLE_OPTIMIZATION_REPORT.md`
- Detail updated: `2026-03-30 20:00:11 KST`

#### Executive Summary

| Item | Value |
| --- | --- |
| Timing verdict | FAIL |
| Worst endpoint | `uDesign/timingRetainMetric_reg/D` |
| Worst structural bucket | `DataRam Readback To Regfile D` |
| Worst canonical family | `Timing Metric` |
| Runtime winner | 5-stage pipeline (148.733 ns faster) |
| First optimization target | `Route-Dominant Timing`: Top100 average route share is 74.1%, and 100 of 100 paths exceed 70% route share. |

#### Key Metrics

- `Delta` is `5-stage reference - single-cycle`.
- `Cycles`, `CPI`, and `Runtime` come from the selected timing-program trace model.
- `Pipeline Speedup` is runtime-based: `single-cycle runtime / 5-stage runtime`, so values above `1.000x` mean the pipeline is faster.
- Companion pipeline timing and utilization are pulled from the matching 5-stage artifact set when available.

| Metric | Single-Cycle | 5-Stage Reference | Delta |
| --- | ---: | ---: | ---: |
| WNS (ns) | -5.215 | -0.513 | +4.702 |
| Minimum Period (ns) | 15.215 | 10.513 | -4.702 |
| Fmax (MHz) | 65.72 | 95.12 | +29.40 |
| LUTs | 1843 | 2733 | +890 |
| Registers | 1025 | 1804 | +779 |
| Cycles | 92 | 119 | +27 |
| CPI | 1.000 | 1.293 | +0.293 |
| Runtime | 1399.780 ns (1.400 us) | 1251.047 ns (1.251 us) | -148.733 ns |
| Pipeline Speedup (x) | 1.000x | 1.119x | +0.119x |

#### Optimization Priority

1. `Route-Dominant Timing`: Top100 average route share is 74.1%, and 100 of 100 paths exceed 70% route share.
2. `Canonical Family Worst`: `Timing Metric` is the worst available family at 15.215 ns.
3. `DataRam / Writeback Structural Cone`: `DataRam Readback To Regfile D` appears 99 times in the parsed top100 paths.
4. `Repeated Critical Archetypes`: The most common exact path signature covers 99.0% of the parsed top100 paths.
5. `Methodology Hot Rule`: `TIMING-16` reports 1000 violations.

#### Critical Timing Structure

##### Canonical Timing Families

| Family | Focus | Worst Endpoint | Minimum Period (ns) | Est. Fmax (MHz) | Top Paths |
| --- | --- | --- | ---: | ---: | ---: |
| Timing Metric | Top-level retained writeback-derived timing sink | `uDesign/timingRetainMetric_reg/D` | 15.215 | 65.72 | 20 |

##### Program Coverage Context

| Class | Instruction Count | Active Family Hints |
| --- | ---: | --- |
| RTYPE | 16 | Timing Metric, ALU Writeback |
| OPIMM | 46 | Timing Metric, ALU Writeback |
| LOAD | 5 | Timing Metric, Load Writeback |
| STORE | 4 | NA |
| BRANCH | 13 | PC Feedback, Branch Target |
| UPPER_IMM | 3 | Timing Metric, ALU Writeback |
| JUMP | 3 | Timing Metric, PC Feedback, Jump Target, JALR Target |
| SYSTEM | 1 | PC Feedback |

##### Top100 Timing Distribution

| Metric | Worst | P90 | Median | Average |
| --- | ---: | ---: | ---: | ---: |
| Slack (ns) | -5.215 | -5.215 | -5.215 | -5.213 |
| Data path delay (ns) | 15.064 | 15.064 | 15.064 | 15.062 |
| Route delay (ns) | 11.163 | 11.163 | 11.163 | 11.163 |
| Route share (%) | 74.1 | 74.1 | 74.1 | 74.1 |
| Logic levels | 18.0 | 18.0 | 18.0 | 18.0 |
| Max fanout seen on path | 128.0 | 128.0 | 128.0 | 128.0 |

##### Path Family Buckets

| Bucket | Count | Worst Slack (ns) |
| --- | ---: | ---: |
| DataRam Readback To Regfile D | 99 | -2.907 |
| Other | 1 | -5.215 |

##### Repeated Exact Path Signatures

| Signature | Count | Worst Slack (ns) |
| --- | ---: | ---: |
| Pc -> decode/control -> DataRam readback -> Regfile D | 99 | -2.907 |
| Pc -> ImmGen -> DataRam -> Pc -> Timing Metric -> Timing Metric | 1 | -5.215 |

##### Start/End Module Pairs

| Start Module | End Module | Count |
| --- | --- | ---: |
| Pc | Timing Metric | 100 |

#### Implementation Footprint

##### Auto-Discovered Module Metrics

| Instance | Total Cells | FF | LUT | CARRY | RAM | MUXF | Other |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `uDesign` | 3499 | 1025 | 1781 | 77 | 160 | 438 | 18 |
| `uDesign/uDatapath` | 3200 | 992 | 1554 | 69 | 160 | 417 | 8 |
| `uDesign/uDatapath/uRegfile` | 1923 | 992 | 610 | 0 | 0 | 320 | 1 |
| `uDesign/uDatapath/uAlu` | 565 | 0 | 539 | 24 | 0 | 0 | 2 |
| `uDesign/uDatapath/uDataRam` | 337 | 0 | 81 | 0 | 160 | 96 | 0 |
| `uDesign/uDatapath/uBranchComparator` | 141 | 0 | 120 | 18 | 0 | 1 | 2 |
| `uDesign/uInstrRom` | 117 | 0 | 95 | 0 | 0 | 21 | 1 |
| `uDesign/uControlUnit` | 91 | 0 | 86 | 0 | 0 | 0 | 5 |
| `uDesign/uDatapath/uPcTargetGen` | 90 | 0 | 65 | 24 | 0 | 0 | 1 |
| `uDesign/uDatapath/uAluOperandSel` | 64 | 0 | 64 | 0 | 0 | 0 | 0 |
| `uDesign/uNextPcGen` | 44 | 0 | 35 | 8 | 0 | 0 | 1 |
| `uDesign/uControlUnit/uControlComposer` | 39 | 0 | 38 | 0 | 0 | 0 | 1 |

##### High-Fanout Nets

| Rank | Fanout | Driver | Net |
| --- | ---: | --- | --- |
| 2 | 262 | LUT2 | `uDesign/uPc/instr[11]` |
| 3 | 260 | LUT5 | `uDesign/uPc/instr[10]` |
| 4 | 192 | CARRY4 | `uDesign/uDatapath/memRam_reg_0_255_0_0_i_3_n_7` |
| 5 | 160 | CARRY4 | `uDesign/uDatapath/memRam_reg_0_255_0_0_i_3_n_6` |
| 6 | 134 | LUT2 | `uDesign/uPc/instr[12]` |
| 7 | 130 | LUT5 | `uDesign/uPc/instr[7]` |
| 8 | 129 | LUT6 | `uDesign/uDatapath/uAluOperandSel/aluB[4]` |
| 9 | 128 | CARRY4 | `uDesign/uDatapath/memRam_reg_0_255_0_0_i_4_n_7` |
| 10 | 128 | CARRY4 | `uDesign/uDatapath/memRam_reg_0_255_0_0_i_4_n_6` |
| 11 | 128 | CARRY4 | `uDesign/uDatapath/memRam_reg_0_255_0_0_i_5_n_5` |
| 12 | 128 | CARRY4 | `uDesign/uDatapath/memRam_reg_0_255_0_0_i_4_n_4` |
| 13 | 128 | CARRY4 | `uDesign/uDatapath/memRam_reg_0_255_0_0_i_4_n_5` |

##### Utilization Summary

| Resource | Used |
| --- | ---: |
| Slice LUTs | 1843 |
| Logic LUTs | 1715 |
| LUTRAM | 128 |
| Distributed RAM | 128 |
| Slice Registers | 1025 |
| F7 Mux | 321 |
| F8 Mux | 100 |
| Block RAM Tile | 0 |
| DSP | 0 |
| Bonded IOB | 2 |
| BUFGCTRL | 1 |

##### Actual Synth Instance Area

| Instance | Module | Cells |
| --- | --- | ---: |
| `uDesign` | TOP | 3314 |
| `uDatapath` | Datapath | 2010 |
| `uAluOperandSel` | AluOperandSel | 53 |
| `uDataRam` | DataRam | 49 |
| `uImmGen` | ImmGen | 32 |
| `uRegfile` | Regfile | 1863 |
| `uPc` | Pc | 1296 |

#### Appendix

##### Run Metadata

- Project: `RISCV_32I_SINGLE`
- Analysis mode: `single_cycle`
- ISA profile: `RV32I`
- Top: `TOP`
- Part: `xc7a35tcpg236-1`
- Program image: `Full Coverage.mem`
- Program memory: `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/src/InstructionFORTIMING.mem`
- Raw output directory: `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage`
- Companion pipeline artifacts: `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_5STAGE/.analysis/pipeline_perf/programs/full_coverage/pipeline`

##### Contract Resolution

| Item | Resolved Value |
| --- | --- |
| Manifest | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/fpga_auto.yml` |
| Profile | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/tools/timing_analysis_profile.json` |
| Manifest top | `Top` |
| Resolved top | `TOP` |
| Source file count | 29 |
| Probe family count | 1 |
| Program image | `Full Coverage.mem` |
| Program memory | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/src/InstructionFORTIMING.mem` |
| Instruction-class source | `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/src/InstructionFORTIMING.s` |

##### Analysis Health

| Check | Status | Detail |
| --- | --- | --- |
| Manifest loaded | PASS | /mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/fpga_auto.yml |
| Profile loaded | PASS | /mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/tools/timing_analysis_profile.json |
| Resolved source files | PASS | 29 |
| Probe families | PASS | 1 |
| Instruction-class source | PASS | /mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/src/InstructionFORTIMING.s |
| Metadata warning | WARN | Manifest top `Top` did not exactly match RTL; using discovered module `TOP`. |

##### Methodology / QoR Details

| Methodology Severity | Count |
| --- | ---: |
| Warning | 1000 |

| Rule | Severity | Description | Violations |
| --- | --- | --- | ---: |
| TIMING-16 | Warning | Large setup violation | 1000 |

Representative methodology findings:
- `TIMING-16#1` `Warning` `Large setup violation`. There is a large setup violation of -1.685 ns between uDesign/uPc/oPc_reg[28]/C (clocked by iClk) and uDesign/uDatapath/uRegfile/memReg_reg[10][2]/D (clocked by iClk). Large setup violations at the end of those stages might be difficult to fix during the post-placement implementation flow and could be the result of non-optimal XDC constraints or non-optimal design architecture
- `TIMING-16#2` `Warning` `Large setup violation`. There is a large setup violation of -1.685 ns between uDesign/uPc/oPc_reg[28]/C (clocked by iClk) and uDesign/uDatapath/uRegfile/memReg_reg[10][3]/D (clocked by iClk). Large setup violations at the end of those stages might be difficult to fix during the post-placement implementation flow and could be the result of non-optimal XDC constraints or non-optimal design architecture
- `TIMING-16#3` `Warning` `Large setup violation`. There is a large setup violation of -1.685 ns between uDesign/uPc/oPc_reg[28]/C (clocked by iClk) and uDesign/uDatapath/uRegfile/memReg_reg[10][4]/D (clocked by iClk). Large setup violations at the end of those stages might be difficult to fix during the post-placement implementation flow and could be the result of non-optimal XDC constraints or non-optimal design architecture

##### Raw Files

- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_timing_summary.rpt`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_timing_top100.rpt`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_timing_paths.tsv`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_high_fanout.rpt`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_utilization.rpt`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_methodology.rpt`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/actual_qor_suggestions.rpt`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/module_metrics.tsv`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/analysis_metadata.json`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/artifact_manifest.json`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/vivado_actual.log`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/vivado_hierarchical.log`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/vivado_run.log`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/timing_metric_timing_paths.tsv`
- `/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_SINGLE/.analysis/single_cycle_perf/programs/full_coverage/timing_metric_timing_top20.rpt`
<!-- DETAIL_SECTION:single_cycle:full_coverage:END -->

### Pipeline Performance Detail

<!-- DETAIL_SECTION:pipeline_perf:full_coverage:START -->
- Source report: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\md\PIPELINE_PERF_REPORT.md`
- Detail updated: `2026-03-30 22:46:42 대한민국 표준시`

- Program key: `full_coverage`
- Last updated: `2026-03-30 22:46:42 대한민국 표준시`

#### Executive Summary

| Item | Value |
| --- | --- |
| Timing verdict | FAIL |
| Worst stage family | `CF / Next-PC Redirect` / `CF` at 11.051 ns |
| Route status | fully routed |
| Runtime winner | Single-cycle (11.598 ns faster) |
| Instruction-focus coverage | Skipped instruction-focus rerun for selected program `Full Coverage.mem`. |
| First action | `Negative post-route slack`: pipeline WNS is -1.203 ns. |

#### Key Metrics

- `Delta` is `5-stage pipeline - single-cycle`.
- `Cycles`, `CPI`, and `Runtime` are estimated from the selected timing-program trace.
- `Pipeline Speedup` is runtime-based: `single-cycle runtime / 5-stage runtime`, so values above `1.000x` mean the pipeline is faster.
- 5-stage execution model: `retired + 4 fill + load-use stalls + 2-cycle taken branches/JALR + 1-cycle decode-resolved JAL before the terminal self-loop`.

| Metric | Single-Cycle | 5-Stage Pipeline | Delta |
| --- | ---: | ---: | ---: |
| WNS (ns) | -4.243 | -1.203 | +3.040 |
| Minimum Period (ns) | 14.243 | 11.203 | -3.040 |
| Fmax (MHz) | 70.210 | 89.262 | +19.052 |
| LUTs | 1975 | 2807 | +832 |
| Registers | 1066 | 1927 | +861 |
| Cycles | 92 | 118 | +26 |
| CPI | 1.000 | 1.283 | +0.283 |
| Runtime | 1310.356 ns (1.310 us) | 1321.954 ns (1.322 us) | 11.598 ns |
| Pipeline Speedup (x) | 1.000x | 0.991x | -0.009x |

#### Optimization Priority

1. `Negative post-route slack`: pipeline WNS is -1.203 ns.
2. `Worst stage family`: `CF / Next-PC Redirect` in `CF` reaches 11.051 ns.
3. `Instruction-focus coverage`: Skipped instruction-focus rerun for selected program `Full Coverage.mem`.
4. `Execution regression`: estimated runtime delta is 11.598 ns.

#### Timing Health

| Check | Status | Detail |
| --- | --- | --- |
| Stage family coverage | PASS | 6/6 families resolved with post-route paths |
| Instruction-focus coverage | INFO | Skipped instruction-focus rerun for selected program `Full Coverage.mem`. |
| IF / IF-ID Boundary | PASS | uDesign/uIfIdReg/IFIDReg_reg[Valid]/D |
| ID / ID-EX Boundary | PASS | uDesign/uIdExReg/IDEXReg_reg[Valid]/D |
| EX / EX-MEM Boundary | PASS | uDesign/uExMemReg/EXMEMReg_reg[RegWrite]/D |
| MEM / MEM-WB Boundary | PASS | uDesign/uMemWbReg/MEMWBReg_reg[MemRdData][16]/D |
| WB / Retire Sink | PASS | uDesign/TimingSinkReg_reg/D |
| CF / Next-PC Redirect | PASS | uDesign/uFetchStage/uPc/oPc_reg[6]/D |

#### Stage Timing Analysis

##### Pipeline Stage Family Timing

| Family | Stage | Data Path (ns) | Minimum Period (ns) | Fmax (MHz) | Worst Endpoint | Top Paths |
| --- | --- | ---: | ---: | ---: | --- | ---: |
| IF / IF-ID Boundary | IF | 10.466 | 10.586 | 94.464 | `uDesign/uIfIdReg/IFIDReg_reg[Valid]/D` | 20 |
| ID / ID-EX Boundary | ID | 9.473 | 9.510 | 105.152 | `uDesign/uIdExReg/IDEXReg_reg[Valid]/D` | 20 |
| EX / EX-MEM Boundary | EX | 10.560 | 10.902 | 91.726 | `uDesign/uExMemReg/EXMEMReg_reg[RegWrite]/D` | 20 |
| MEM / MEM-WB Boundary | MEM | 9.379 | 9.781 | 102.239 | `uDesign/uMemWbReg/MEMWBReg_reg[MemRdData][16]/D` | 20 |
| WB / Retire Sink | WB | 7.604 | 7.519 | 132.996 | `uDesign/TimingSinkReg_reg/D` | 20 |
| CF / Next-PC Redirect | CF | 10.928 | 11.051 | 90.490 | `uDesign/uFetchStage/uPc/oPc_reg[6]/D` | 20 |

#### Instruction-Focus Summary

- Focus builds resolved with measured timing: `0/0`.
- Focus runs use generated wrapper tops and focused images derived from the selected base program image.
- The original pipeline RTL is unchanged; only the nested ROM init-file parameter is overridden in the wrapper.
- Full measured and baseline-delta focus tables are moved to the appendix below.

#### Appendix

##### Run Metadata

- Single-cycle project: `RISCV_32I_SINGLE`
- Pipeline project: `RISCV_32I_5STAGE`
- Single-cycle top: `TOP`
- Pipeline top: `TOP`
- Part: `xc7a35tcpg236-1`
- Program image: `Full Coverage.mem`
- Program memory: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\src\timing_programs\Full Coverage.mem`
- Instruction source: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\src\timing_programs\Full Coverage.s`

##### Full Instruction-Focus Tables

- `Focused` tables below are actual per-focus Vivado timing results.
- `Delta` tables show `Focused - Base` where `Base` is the stage-family-mapped value from the unmodified pipeline build.

- No instruction-focus tables were generated for this run.

##### Artifacts

- Directives: synth `PerformanceOptimized`, opt `Explore`, place `Explore`, route `Explore`
- Phys-opt: `AggressiveExplore` / `AggressiveExplore`
- Pipeline floorplan: `disabled`
- Single-cycle artifacts: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage\single_cycle`
- 5-stage artifacts: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage\pipeline`
- Instruction-focus artifacts: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage\instruction_focus`
<!-- DETAIL_SECTION:pipeline_perf:full_coverage:END -->
<!-- PROGRAM_SECTION:full_coverage:END -->

<!-- PROGRAM_SECTION:bubble_sort:START -->
## Bubble Sort.mem

- Program key: `bubble_sort`

### Single-Cycle Optimization Detail

<!-- DETAIL_SECTION:single_cycle:bubble_sort:START -->
- Source project: `RISCV_32I_SINGLE`
- Source artifacts: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort`
- Standalone report path: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\md\SINGLE_CYCLE_OPTIMIZATION_REPORT.md`
- Detail updated: `2026-03-31 07:05:37 대한민국 표준시`

#### Executive Summary

| Item | Value |
| --- | --- |
| Timing verdict | FAIL |
| Worst endpoint | `uDesign/timingRetainMetric_reg/D` |
| Worst structural bucket | `DataRam Readback To Regfile D` |
| Worst canonical family | `Timing Metric` |
| Runtime winner | 5-stage pipeline (342.159 ns faster) |
| First optimization target | `Route-Dominant Timing`: Top100 average route share is 80.5%, and 100 of 100 paths exceed 70% route share. |

#### Key Metrics

- `Delta` is `5-stage reference - single-cycle`.
- `Cycles`, `CPI`, and `Runtime` come from the selected timing-program trace model.
- `Pipeline Speedup` is runtime-based: `single-cycle runtime / 5-stage runtime`, so values above `1.000x` mean the pipeline is faster.
- Companion pipeline timing and utilization are pulled from the matching 5-stage artifact set when available.

| Metric | Single-Cycle | 5-Stage Reference | Delta |
| --- | ---: | ---: | ---: |
| WNS (ns) | -9.583 | -0.956 | +8.627 |
| Minimum Period (ns) | 19.583 | 10.956 | -8.627 |
| Fmax (MHz) | 51.06 | 91.27 | +40.21 |
| LUTs | 2355 | 2808 | +453 |
| Registers | 1319 | 1919 | +600 |
| Cycles | 93 | 135 | +42 |
| CPI | 1.000 | 1.452 | +0.452 |
| Runtime | 1821.219 ns (1.821 us) | 1479.060 ns (1.479 us) | -342.159 ns |
| Pipeline Speedup (x) | 1.000x | 1.231x | +0.231x |

#### Optimization Priority

1. `Route-Dominant Timing`: Top100 average route share is 80.5%, and 100 of 100 paths exceed 70% route share.
2. `Canonical Family Worst`: `Timing Metric` is the worst available family at 19.583 ns.
3. `DataRam / Writeback Structural Cone`: `DataRam Readback To Regfile D` appears 99 times in the parsed top100 paths.
4. `Repeated Critical Archetypes`: The most common exact path signature covers 99.0% of the parsed top100 paths.
5. `Methodology Hot Rule`: `TIMING-16` reports 1000 violations.

#### Critical Timing Structure

##### Canonical Timing Families

| Family | Focus | Worst Endpoint | Minimum Period (ns) | Est. Fmax (MHz) | Top Paths |
| --- | --- | --- | ---: | ---: | ---: |
| Timing Metric | Top-level retained writeback-derived timing sink | `uDesign/timingRetainMetric_reg/D` | 19.583 | 51.06 | 20 |

##### Program Coverage Context

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

##### Top100 Timing Distribution

| Metric | Worst | P90 | Median | Average |
| --- | ---: | ---: | ---: | ---: |
| Slack (ns) | -9.583 | -9.583 | -9.577 | -9.565 |
| Data path delay (ns) | 19.432 | 19.432 | 19.426 | 19.414 |
| Route delay (ns) | 15.630 | 15.630 | 15.630 | 15.630 |
| Route share (%) | 80.6 | 80.6 | 80.5 | 80.5 |
| Logic levels | 22.0 | 22.0 | 22.0 | 22.0 |
| Max fanout seen on path | 130.0 | 130.0 | 130.0 | 130.0 |

##### Path Family Buckets

| Bucket | Count | Worst Slack (ns) |
| --- | ---: | ---: |
| DataRam Readback To Regfile D | 99 | -7.676 |
| ALU Writeback | 1 | -9.583 |

##### Repeated Exact Path Signatures

| Signature | Count | Worst Slack (ns) |
| --- | ---: | ---: |
| Pc -> DataRam -> ImmGen -> AluOperandSel -> Alu -> Pc -> DataRam -> Pc -> Alu -> Pc -> CoreTrapGate -> Pc -> Regfile -> Regfile CE | 99 | -7.676 |
| Pc -> DataRam -> ImmGen -> AluOperandSel -> Alu -> Pc -> DataRam -> Pc -> Datapath -> Timing Metric -> Timing Metric | 1 | -9.583 |

##### Start/End Module Pairs

| Start Module | End Module | Count |
| --- | --- | ---: |
| Pc | Timing Metric | 100 |

#### Implementation Footprint

##### Auto-Discovered Module Metrics

| Instance | Total Cells | FF | LUT | CARRY | RAM | MUXF | Other |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `uDesign` | 4936 | 1520 | 2693 | 74 | 160 | 442 | 47 |
| `uDesign/uDatapath` | 3032 | 992 | 1643 | 66 | 0 | 321 | 10 |
| `uDesign/uDatapath/uRegfile` | 1923 | 992 | 610 | 0 | 0 | 320 | 1 |
| `uDesign/uDatapath/uAlu` | 565 | 0 | 539 | 24 | 0 | 0 | 2 |
| `uDesign/uAPB_UART` | 472 | 201 | 234 | 0 | 0 | 25 | 12 |
| `uDesign/uAPB_UART/uUartCore` | 380 | 197 | 150 | 0 | 0 | 25 | 8 |
| `uDesign/uCsrFile` | 310 | 128 | 180 | 0 | 0 | 0 | 2 |
| `uDesign/uExternalMemory` | 300 | 0 | 44 | 0 | 160 | 96 | 0 |
| `uDesign/uAPB_UART/uUartCore/uRxFifo` | 232 | 141 | 66 | 0 | 0 | 24 | 1 |
| `uDesign/uAPBMASTER` | 206 | 87 | 117 | 0 | 0 | 0 | 2 |
| `uDesign/uDatapath/uBranchComparator` | 141 | 0 | 120 | 18 | 0 | 1 | 2 |
| `uDesign/uAPBMASTER/uAPBCtrl` | 125 | 87 | 37 | 0 | 0 | 0 | 1 |

##### High-Fanout Nets

| Rank | Fanout | Driver | Net |
| --- | ---: | --- | --- |
| 2 | 194 | LUT6 | `uDesign/uPc/memAddr[8]` |
| 3 | 170 | LUT2 | `uDesign/uPc/oPc_reg[10]_7` |
| 4 | 162 | LUT6 | `uDesign/uPc/memAddr[9]` |
| 5 | 130 | LUT6 | `uDesign/uPc/memAddr[7]` |
| 6 | 130 | LUT6 | `uDesign/uPc/memAddr[6]` |
| 7 | 130 | LUT6 | `uDesign/uPc/memAddr[5]` |
| 8 | 130 | LUT6 | `uDesign/uPc/memAddr[4]` |
| 9 | 130 | LUT6 | `uDesign/uPc/memAddr[3]` |
| 10 | 130 | LUT6 | `uDesign/uPc/memAddr[2]` |
| 11 | 129 | LUT3 | `uDesign/uDatapath/uAluOperandSel/aluB[2]` |
| 12 | 126 | LUT3 | `uDesign/uDatapath/uAluOperandSel/aluB[3]` |
| 13 | 126 | LUT3 | `uDesign/uDatapath/uAluOperandSel/aluB[1]` |

##### Utilization Summary

| Resource | Used |
| --- | ---: |
| Slice LUTs | 2355 |
| Logic LUTs | 2227 |
| LUTRAM | 128 |
| Distributed RAM | 128 |
| Slice Registers | 1319 |
| F7 Mux | 186 |
| F8 Mux | 60 |
| Block RAM Tile | 0 |
| DSP | 0 |
| Bonded IOB | 2 |
| BUFGCTRL | 1 |

##### Actual Synth Instance Area

| Instance | Module | Cells |
| --- | --- | ---: |
| `uDesign` | TOP | 4117 |
| `uInstrRom` | InstrRom | 39 |
| `uDatapath` | Datapath | 1839 |
| `uAluOperandSel` | AluOperandSel | 21 |
| `uImmGen` | ImmGen | 32 |
| `uRegfile` | Regfile | 1722 |
| `uExternalMemory` | ExternalMemory | 32 |
| `uCsrFile` | CsrFile | 157 |
| `uAPBMASTER` | APBMASTER | 226 |
| `uAPBCtrl` | APBCtrl | 226 |
| `uAPB_FND` | APB_FND | 29 |
| `uFndRegs` | FndRegs | 29 |

#### Appendix

##### Run Metadata

- Project: `RISCV_32I_SINGLE`
- Analysis mode: `single_cycle`
- ISA profile: `RV32I`
- Top: `TOP`
- Part: `xc7a35tcpg236-1`
- Program image: `Bubble Sort.mem`
- Program memory: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\src\timing_programs\Bubble Sort.mem`
- Raw output directory: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort`
- Companion pipeline artifacts: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort\pipeline`

##### Contract Resolution

| Item | Resolved Value |
| --- | --- |
| Manifest | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\fpga_auto.yml` |
| Profile | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\tools\timing_analysis_profile.json` |
| Manifest top | `Top` |
| Resolved top | `TOP` |
| Source file count | 62 |
| Probe family count | 1 |
| Program image | `Bubble Sort.mem` |
| Program memory | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\src\timing_programs\Bubble Sort.mem` |
| Instruction-class source | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\src\timing_programs\Bubble Sort.s` |

##### Analysis Health

| Check | Status | Detail |
| --- | --- | --- |
| Manifest loaded | PASS | C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\fpga_auto.yml |
| Profile loaded | PASS | C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\tools\timing_analysis_profile.json |
| Resolved source files | PASS | 62 |
| Probe families | PASS | 1 |
| Instruction-class source | PASS | C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\src\timing_programs\Bubble Sort.s |
| Metadata warning | WARN | Manifest top `Top` did not exactly match RTL; using discovered module `TOP`. |

##### Methodology / QoR Details

| Methodology Severity | Count |
| --- | ---: |
| Warning | 1000 |

| Rule | Severity | Description | Violations |
| --- | --- | --- | ---: |
| TIMING-16 | Warning | Large setup violation | 1000 |

Representative methodology findings:
- `TIMING-16#1` `Warning` `Large setup violation`. There is a large setup violation of -1.302 ns between uDesign/uPc/oPc_reg[20]/C (clocked by iClk) and uDesign/uAPBMASTER/uAPBCtrl/ReqAddr_reg[10]/D (clocked by iClk). Large setup violations at the end of those stages might be difficult to fix during the post-placement implementation flow and could be the result of non-optimal XDC constraints or non-optimal design architecture
- `TIMING-16#2` `Warning` `Large setup violation`. There is a large setup violation of -1.369 ns between uDesign/uPc/oPc_reg[20]/C (clocked by iClk) and uDesign/uAPBMASTER/uAPBCtrl/ReqAddr_reg[16]/D (clocked by iClk). Large setup violations at the end of those stages might be difficult to fix during the post-placement implementation flow and could be the result of non-optimal XDC constraints or non-optimal design architecture
- `TIMING-16#3` `Warning` `Large setup violation`. There is a large setup violation of -1.380 ns between uDesign/uPc/oPc_reg[20]/C (clocked by iClk) and uDesign/uAPBMASTER/uAPBCtrl/ReqAddr_reg[12]/D (clocked by iClk). Large setup violations at the end of those stages might be difficult to fix during the post-placement implementation flow and could be the result of non-optimal XDC constraints or non-optimal design architecture

Top visible QoR suggestion lines:
- RQS_XDC-1-1 (Generated): Paths above Max Net/LUT budgeting. Review paths and either reduce logic delays, add

##### Raw Files

- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\actual_timing_summary.rpt`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\actual_timing_top100.rpt`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\actual_timing_paths.tsv`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\actual_high_fanout.rpt`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\actual_utilization.rpt`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\actual_methodology.rpt`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\actual_qor_suggestions.rpt`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\module_metrics.tsv`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\analysis_metadata.json`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\artifact_manifest.json`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\vivado_actual.log`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\vivado_hierarchical.log`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\vivado_run.log`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\timing_metric_timing_paths.tsv`
- `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_SINGLE\.analysis\single_cycle_perf\programs\bubble_sort\timing_metric_timing_top20.rpt`
<!-- DETAIL_SECTION:single_cycle:bubble_sort:END -->

### Pipeline Performance Detail

<!-- DETAIL_SECTION:pipeline_perf:bubble_sort:START -->
- Source report: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\md\PIPELINE_PERF_REPORT.md`
- Detail updated: `2026-03-30 21:42:06 대한민국 표준시`

- Program key: `bubble_sort`
- Last updated: `2026-03-30 21:42:06 대한민국 표준시`

#### Executive Summary

| Item | Value |
| --- | --- |
| Timing verdict | FAIL |
| Worst stage family | `CF / Next-PC Redirect` / `CF` at 10.862 ns |
| Route status | fully routed |
| Runtime winner | Single-cycle (8.334 ns faster) |
| Instruction-focus coverage | Skipped instruction-focus rerun for selected program `Bubble Sort.mem`. |
| First action | `Negative post-route slack`: pipeline WNS is -0.956 ns. |

#### Key Metrics

- `Delta` is `5-stage pipeline - single-cycle`.
- `Cycles`, `CPI`, and `Runtime` are estimated from the selected timing-program trace.
- `Pipeline Speedup` is runtime-based: `single-cycle runtime / 5-stage runtime`, so values above `1.000x` mean the pipeline is faster.
- 5-stage execution model: `retired + 4 fill + load-use stalls + 2-cycle taken branches/JALR + 1-cycle decode-resolved JAL before the terminal self-loop`.

| Metric | Single-Cycle | 5-Stage Pipeline | Delta |
| --- | ---: | ---: | ---: |
| WNS (ns) | -4.754 | -0.956 | +3.798 |
| Minimum Period (ns) | 14.754 | 10.956 | -3.798 |
| Fmax (MHz) | 67.778 | 91.274 | +23.496 |
| LUTs | 1912 | 2808 | +896 |
| Registers | 1028 | 1919 | +891 |
| Cycles | 93 | 126 | +33 |
| CPI | 1.000 | 1.355 | +0.355 |
| Runtime | 1372.122 ns (1.372 us) | 1380.456 ns (1.380 us) | 8.334 ns |
| Pipeline Speedup (x) | 1.000x | 0.994x | -0.006x |

#### Optimization Priority

1. `Negative post-route slack`: pipeline WNS is -0.956 ns.
2. `Worst stage family`: `CF / Next-PC Redirect` in `CF` reaches 10.862 ns.
3. `Instruction-focus coverage`: Skipped instruction-focus rerun for selected program `Bubble Sort.mem`.
4. `Execution regression`: estimated runtime delta is 8.334 ns.

#### Timing Health

| Check | Status | Detail |
| --- | --- | --- |
| Stage family coverage | PASS | 6/6 families resolved with post-route paths |
| Instruction-focus coverage | INFO | Skipped instruction-focus rerun for selected program `Bubble Sort.mem`. |
| IF / IF-ID Boundary | PASS | uDesign/uIfIdReg/IFIDReg_reg[Valid]/D |
| ID / ID-EX Boundary | PASS | uDesign/uIdExReg/IDEXReg_reg[Valid]/D |
| EX / EX-MEM Boundary | PASS | uDesign/uExMemReg/EXMEMReg_reg[ExFwdData][0]/D |
| MEM / MEM-WB Boundary | PASS | uDesign/uMemWbReg/MEMWBReg_reg[MemRdData][4]/D |
| WB / Retire Sink | PASS | uDesign/TimingSinkReg_reg/D |
| CF / Next-PC Redirect | PASS | uDesign/uFetchStage/uPc/oPc_reg[26]/D |

#### Stage Timing Analysis

##### Pipeline Stage Family Timing

| Family | Stage | Data Path (ns) | Minimum Period (ns) | Fmax (MHz) | Worst Endpoint | Top Paths |
| --- | --- | ---: | ---: | ---: | --- | ---: |
| IF / IF-ID Boundary | IF | 10.403 | 10.541 | 94.868 | `uDesign/uIfIdReg/IFIDReg_reg[Valid]/D` | 20 |
| ID / ID-EX Boundary | ID | 10.414 | 10.442 | 95.767 | `uDesign/uIdExReg/IDEXReg_reg[Valid]/D` | 20 |
| EX / EX-MEM Boundary | EX | 10.645 | 10.635 | 94.029 | `uDesign/uExMemReg/EXMEMReg_reg[ExFwdData][0]/D` | 20 |
| MEM / MEM-WB Boundary | MEM | 9.335 | 9.313 | 107.377 | `uDesign/uMemWbReg/MEMWBReg_reg[MemRdData][4]/D` | 20 |
| WB / Retire Sink | WB | 6.654 | 6.763 | 147.863 | `uDesign/TimingSinkReg_reg/D` | 20 |
| CF / Next-PC Redirect | CF | 10.821 | 10.862 | 92.064 | `uDesign/uFetchStage/uPc/oPc_reg[26]/D` | 20 |

#### Instruction-Focus Summary

- Focus builds resolved with measured timing: `0/0`.
- Focus runs use generated wrapper tops and focused images derived from the selected base program image.
- The original pipeline RTL is unchanged; only the nested ROM init-file parameter is overridden in the wrapper.
- Full measured and baseline-delta focus tables are moved to the appendix below.

#### Appendix

##### Run Metadata

- Single-cycle project: `RISCV_32I_SINGLE`
- Pipeline project: `RISCV_32I_5STAGE`
- Single-cycle top: `TOP`
- Pipeline top: `TOP`
- Part: `xc7a35tcpg236-1`
- Program image: `Bubble Sort.mem`
- Program memory: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\src\timing_programs\Bubble Sort.mem`
- Instruction source: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\src\timing_programs\Bubble Sort.s`

##### Full Instruction-Focus Tables

- `Focused` tables below are actual per-focus Vivado timing results.
- `Delta` tables show `Focused - Base` where `Base` is the stage-family-mapped value from the unmodified pipeline build.

- No instruction-focus tables were generated for this run.

##### Artifacts

- Directives: synth `PerformanceOptimized`, opt `Explore`, place `Explore`, route `Explore`
- Phys-opt: `AggressiveExplore` / `AggressiveExplore`
- Pipeline floorplan: `disabled`
- Single-cycle artifacts: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort\single_cycle`
- 5-stage artifacts: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort\pipeline`
- Instruction-focus artifacts: `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\FPGA_Auto_Project\Project\RISCV_32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort\instruction_focus`
<!-- DETAIL_SECTION:pipeline_perf:bubble_sort:END -->
<!-- PROGRAM_SECTION:bubble_sort:END -->
