# PIPELINE_PERF_REPORT

- This report keeps one category per timing program image.
- Re-running a timing program refreshes only that program section below.

<!-- PROGRAM_SECTION:full_coverage:START -->
## Full Coverage.mem

- Program key: `full_coverage`
- Last updated: `2026-05-05 02:17:20 대한민국 표준시`

### 🧭 Summary

| Item | Value |
| --- | --- |
| Overall verdict | ⚠️ WARN |
| Primary bottleneck | EX Stage (ID/EX -> EX/MEM) / EX at 9.729 ns |
| Route status | fully routed |
| Runtime winner | NA |
| Instruction-focus coverage | ℹ️ INFO Skipped instruction-focus rerun for selected program `Full Coverage.mem`. |
| First action | Check placement locality around the worst boundary and reduce high-fanout control/data nets. |

### 🧠 Analysis Result

| Field | Result |
| --- | --- |
| Overall Verdict | ⚠️ WARN |
| Primary Bottleneck | EX Stage (ID/EX -> EX/MEM) / EX at 9.729 ns |
| Root Cause Candidates | 3 candidate(s) promoted from parsed timing artifacts |
| Recommended Next Actions | 3 action(s) |

#### Root Cause Candidates

| Severity | Category | Finding | Evidence | Impact |
| --- | --- | --- | --- | --- |
| ⚠️ WARN | Routing | Route-dominant stage paths | Average route share 77.7%, max route share 84.6% | Stage timing is likely limited by physical locality or fanout, not only logic depth. |
| ⚠️ WARN | Stage Boundary | EX Stage (ID/EX -> EX/MEM) | EX Stage (ID/EX -> EX/MEM) reaches 9.729 ns | This register-to-register boundary is the best first target for pipeline timing closure. |
| ⚠️ WARN | Instruction Focus | Incomplete instruction-focus coverage | Skipped instruction-focus rerun for selected program `Full Coverage.mem`. | Class/mnemonic-level attribution may be incomplete for this program image. |

### 📊 Key Metrics

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

### 🎯 Recommended Actions

1. Check placement locality around the worst boundary and reduce high-fanout control/data nets.
2. Inspect `EX Stage (ID/EX -> EX/MEM)` fan-in and split or retime the dominant logic before changing unrelated stages.
3. Rerun instruction-focus mode for the missing classes or narrow the focus filter to the failing mnemonic set.

### 📁 Evidence

| Evidence | Location |
| --- | --- |
| Artifact root | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage` |
| Single-cycle artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage\single_cycle` |
| 5-stage artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage\pipeline` |
| Instruction-focus artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\full_coverage\instruction_focus` |
| Program memory | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\src\timing_programs\Full Coverage.mem` |
| Instruction source | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\src\timing_programs\Full Coverage.s` |

<details>
<summary>Compact timing evidence</summary>

#### True Stage Boundary Timing

- True stage timing uses explicit `-from` launch pins and `-to` capture pins.
- WB is measured into the retained retire timing sink because there is no downstream pipeline register.

| Boundary | Stage | Data Path (ns) | Minimum Period (ns) | Fmax (MHz) | Logic Levels | Route Share (%) | Worst Start | Worst Endpoint | Reported Paths | Unique Paths |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | ---: |
| IF Stage (PC -> IF/ID) | IF | 5.693 | 5.870 | 170.358 | 4 | 83.278 | `uDesign/uRv32iCore/uFetchStage/uPc/oPc_reg[20]/C` | `uDesign/uRv32iCore/uIfIdReg/IFIDReg_reg[Instr][22]/D` | 20 | 10 |
| ID Stage (IF/ID -> ID/EX) | ID | 8.046 | 8.145 | 122.775 | 4 | 84.613 | `uDesign/uRv32iCore/uIfIdReg/IFIDReg_reg[Instr][16]_rep__1/C` | `uDesign/uRv32iCore/uIdExReg/IDEXReg_reg[Rs1Data][5]/D` | 20 | 3 |
| EX Stage (ID/EX -> EX/MEM) | EX | 9.607 | 9.729 | 102.785 | 16 | 64.734 | `uDesign/uRv32iCore/uIdExReg/IDEXReg_reg[Rs2Addr][0]/C` | `uDesign/uRv32iCore/uExMemReg/EXMEMReg_reg[AluResult][29]/D` | 20 | 1 |
| MEM Stage (EX/MEM -> MEM/WB) | MEM | 9.316 | 9.359 | 106.849 | 8 | 79.809 | `uDesign/uRv32iCore/uExMemReg/EXMEMReg_reg[MemWrite]/C` | `uDesign/uRv32iCore/uMemWbReg/MEMWBReg_reg[MemRdData][25]/D` | 20 | 10 |
| WB Stage (MEM/WB -> Retire Sink) | WB | 6.802 | 6.916 | 144.592 | 4 | 83.020 | `uDesign/uRv32iCore/uMemWbReg/MEMWBReg_reg[WbSel][1]/C` | `uDesign/uRv32iCore/TimingSinkReg_reg/D` | 20 | 1 |

#### Endpoint Family Timing

- Endpoint-family timing uses `-to` endpoint groups only, so control feedback from another stage can appear in a family row.

| Family | Stage | Data Path (ns) | Minimum Period (ns) | Fmax (MHz) | Worst Endpoint | Reported Paths | Unique Paths |
| --- | --- | ---: | ---: | ---: | --- | ---: | ---: |
| IF / IF-ID Boundary | IF | 9.984 | 9.950 | 100.503 | `uDesign/uRv32iCore/uIfIdReg/IFIDReg_reg[Valid]/D` | 20 | 1 |
| ID / ID-EX Boundary | ID | 9.681 | 9.683 | 103.274 | `uDesign/uRv32iCore/uIdExReg/IDEXReg_reg[Valid]/D` | 20 | 1 |
| EX / EX-MEM Boundary | EX | 9.768 | 9.890 | 101.112 | `uDesign/uRv32iCore/uExMemReg/EXMEMReg_reg[AluResult][29]/D` | 20 | 1 |
| MEM / MEM-WB Boundary | MEM | 9.316 | 9.359 | 106.849 | `uDesign/uRv32iCore/uMemWbReg/MEMWBReg_reg[MemRdData][25]/D` | 20 | 10 |
| WB / Retire Sink | WB | 6.802 | 6.916 | 144.592 | `uDesign/uRv32iCore/TimingSinkReg_reg/D` | 20 | 1 |
| CF / Next-PC Redirect | CF | 9.940 | 9.991 | 100.090 | `uDesign/uRv32iCore/uFetchStage/uPc/oPc_reg[16]/D` | 20 | 1 |

#### Focus Coverage Snapshot

| Check | Status | Detail |
| --- | --- | --- |
| Stage family coverage | ✅ PASS | 6/6 families resolved with post-route paths |
| True stage boundary coverage | ✅ PASS | 5/5 boundaries resolved with register-to-register paths |
| Instruction-focus coverage | ℹ️ INFO | Skipped instruction-focus rerun for selected program `Full Coverage.mem`. |

</details>
<!-- PROGRAM_SECTION:full_coverage:END -->

<!-- PROGRAM_SECTION:bubble_sort:START -->
## Bubble Sort.mem

- Program key: `bubble_sort`
- Last updated: `2026-05-06 02:35:33 대한민국 표준시`

### 🧭 Summary

| Item | Value |
| --- | --- |
| Overall verdict | ⚠️ WARN |
| Primary bottleneck | EX Stage (ID/EX -> EX/MEM) / EX at 9.998 ns |
| Route status | fully routed |
| Runtime winner | NA |
| Instruction-focus coverage | ℹ️ INFO Skipped instruction-focus rerun for selected program `Bubble Sort.mem`. |
| First action | Check placement locality around the worst boundary and reduce high-fanout control/data nets. |

### 🧠 Analysis Result

| Field | Result |
| --- | --- |
| Overall Verdict | ⚠️ WARN |
| Primary Bottleneck | EX Stage (ID/EX -> EX/MEM) / EX at 9.998 ns |
| Root Cause Candidates | 3 candidate(s) promoted from parsed timing artifacts |
| Recommended Next Actions | 3 action(s) |

#### Root Cause Candidates

| Severity | Category | Finding | Evidence | Impact |
| --- | --- | --- | --- | --- |
| ⚠️ WARN | Routing | Route-dominant stage paths | Average route share 78.9%, max route share 85.3% | Stage timing is likely limited by physical locality or fanout, not only logic depth. |
| ⚠️ WARN | Stage Boundary | EX Stage (ID/EX -> EX/MEM) | EX Stage (ID/EX -> EX/MEM) reaches 9.998 ns | This register-to-register boundary is the best first target for pipeline timing closure. |
| ⚠️ WARN | Instruction Focus | Incomplete instruction-focus coverage | Skipped instruction-focus rerun for selected program `Bubble Sort.mem`. | Class/mnemonic-level attribution may be incomplete for this program image. |

### 📊 Key Metrics

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

### 🎯 Recommended Actions

1. Check placement locality around the worst boundary and reduce high-fanout control/data nets.
2. Inspect `EX Stage (ID/EX -> EX/MEM)` fan-in and split or retime the dominant logic before changing unrelated stages.
3. Rerun instruction-focus mode for the missing classes or narrow the focus filter to the failing mnemonic set.

### 📁 Evidence

| Evidence | Location |
| --- | --- |
| Artifact root | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort` |
| Single-cycle artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort\single_cycle` |
| 5-stage artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort\pipeline` |
| Instruction-focus artifacts | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\.analysis\pipeline_perf\programs\bubble_sort\instruction_focus` |
| Program memory | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\src\timing_programs\Bubble Sort.mem` |
| Instruction source | `C:\Users\tbdk5\Desktop\MAIN\0_Working\git\Project\RISCV_RV32I_5STAGE\src\timing_programs\Bubble Sort.s` |

<details>
<summary>Compact timing evidence</summary>

#### True Stage Boundary Timing

- True stage timing uses explicit `-from` launch pins and `-to` capture pins.
- WB is measured into the retained retire timing sink because there is no downstream pipeline register.

| Boundary | Stage | Data Path (ns) | Minimum Period (ns) | Fmax (MHz) | Logic Levels | Route Share (%) | Worst Start | Worst Endpoint | Reported Paths | Unique Paths |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | ---: |
| IF Stage (PC -> IF/ID) | IF | 6.470 | 6.508 | 153.657 | 4 | 85.286 | `uDesign/uRv32iCore/uFetchStage/uPc/oPc_reg[29]/C` | `uDesign/uRv32iCore/uIfIdReg/IFIDReg_reg[Instr][7]/D` | 20 | 10 |
| ID Stage (IF/ID -> ID/EX) | ID | 8.025 | 8.022 | 124.657 | 9 | 73.670 | `uDesign/uRv32iCore/uIfIdReg/IFIDReg_reg[Instr][25]/C` | `uDesign/uRv32iCore/uIdExReg/IDEXReg_reg[Ctrl][AluBSel]/D` | 20 | 3 |
| EX Stage (ID/EX -> EX/MEM) | EX | 10.096 | 9.998 | 100.020 | 10 | 83.201 | `uDesign/uRv32iCore/uIdExReg/IDEXReg_reg[Rs1Addr][3]/C` | `uDesign/uRv32iCore/uExMemReg/EXMEMReg_reg[ExFwdData][13]/D` | 20 | 2 |
| MEM Stage (EX/MEM -> MEM/WB) | MEM | 7.692 | 8.238 | 121.389 | 7 | 77.275 | `uDesign/uRv32iCore/uExMemReg/EXMEMReg_reg[Valid]/C` | `uDesign/uRv32iCore/uMemWbReg/MEMWBReg_reg[MemRdData][3]/D` | 20 | 10 |
| WB Stage (MEM/WB -> Retire Sink) | WB | 5.889 | 5.941 | 168.322 | 4 | 78.876 | `uDesign/uRv32iCore/uMemWbReg/MEMWBReg_reg[WbSel][1]/C` | `uDesign/uRv32iCore/TimingSinkReg_reg/D` | 20 | 1 |

#### Endpoint Family Timing

- Endpoint-family timing uses `-to` endpoint groups only, so control feedback from another stage can appear in a family row.

| Family | Stage | Data Path (ns) | Minimum Period (ns) | Fmax (MHz) | Worst Endpoint | Reported Paths | Unique Paths |
| --- | --- | ---: | ---: | ---: | --- | ---: | ---: |
| IF / IF-ID Boundary | IF | 9.303 | 9.391 | 106.485 | `uDesign/uRv32iCore/uIfIdReg/IFIDReg_reg[Valid]/D` | 20 | 10 |
| ID / ID-EX Boundary | ID | 10.067 | 9.962 | 100.381 | `uDesign/uRv32iCore/uIdExReg/IDEXReg_reg[Valid]/D` | 20 | 1 |
| EX / EX-MEM Boundary | EX | 10.096 | 9.998 | 100.020 | `uDesign/uRv32iCore/uExMemReg/EXMEMReg_reg[ExFwdData][13]/D` | 20 | 2 |
| MEM / MEM-WB Boundary | MEM | 9.673 | 9.701 | 103.082 | `uDesign/uRv32iCore/uMemWbReg/MEMWBReg_reg[MemRdData][1]/D` | 20 | 2 |
| WB / Retire Sink | WB | 5.889 | 5.941 | 168.322 | `uDesign/uRv32iCore/TimingSinkReg_reg/D` | 20 | 1 |
| CF / Next-PC Redirect | CF | 9.810 | 9.991 | 100.090 | `uDesign/uRv32iCore/uFetchStage/uPc/oPc_reg[15]/D` | 20 | 10 |

#### Focus Coverage Snapshot

| Check | Status | Detail |
| --- | --- | --- |
| Stage family coverage | ✅ PASS | 6/6 families resolved with post-route paths |
| True stage boundary coverage | ✅ PASS | 5/5 boundaries resolved with register-to-register paths |
| Instruction-focus coverage | ℹ️ INFO | Skipped instruction-focus rerun for selected program `Bubble Sort.mem`. |

</details>
<!-- PROGRAM_SECTION:bubble_sort:END -->
