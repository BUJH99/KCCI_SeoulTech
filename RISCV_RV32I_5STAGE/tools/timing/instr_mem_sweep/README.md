# Instruction Memory Sweep

Routed WNS remains the final whole-SoC performance KPI. The sweep now records the image/content policy next to each WNS row so pure instruction-memory capacity scaling is not mixed with workload-content expansion.

## Default Characterization

- Size list: 4KB through 32KB in 1KB steps.
- Depth increment: every 1KB adds exactly 256 words.
- Power-of-two depths: 4KB, 8KB, 16KB, 32KB.
- Non-power-of-two depths: all other 5KB through 31KB cases.
- Capacity benchmarks are generated as prefix slices of one canonical 32KB image.

## Benchmark Modes

| Mode | Classification | Pure Size KPI |
|---|---|---|
| `ifetch_capacity_nop` | `pure_same_program_capacity` | valid |
| `ifetch_capacity_prbs` | `high_entropy_capacity` | valid |
| `ifetch_capacity_toggle` | `address_toggle_capacity` | valid |
| `mixed_firmware` | `mixed_content_expansion` | invalid for pure scaling, retained for workload stress |

## Image Build Modes

| Mode | BootRom image | ProgramRam image |
|---|---|---|
| `bootrom_only` | variable benchmark image | fixed NOP/minimal image |
| `programram_only` | fixed trampoline/minimal boot image | variable benchmark image |
| `combined_real` | fixed trampoline/minimal boot image | variable benchmark image |
| `duplicated_stress` | variable benchmark image | same variable benchmark image |

## Example Runs

```powershell
python .\tools\timing\instr_mem_sweep\run_instr_mem_sweep.py --mode full --vivado-level route --only-program ifetch_capacity_nop --only-variant lutrom_direct --only-ifetch-build-mode bootrom_only
python .\tools\timing\instr_mem_sweep\run_instr_mem_sweep.py --mode full --vivado-level route --only-program ifetch_capacity_prbs --only-variant lutrom_direct --only-ifetch-build-mode programram_only
```

Seed repeats can be requested with `--run-seed`, `--placer-seed`, and `--router-seed`. The summary groups matching cases and reports WNS min/mean/max/stddev without using seed repetition to hide content-changing `mixed_firmware` behavior.
