from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from parse_vivado_reports import flatten_metrics, parse_case


def test_parse_vivado_report_samples(tmp_path: Path) -> None:
    fixtures = Path(__file__).resolve().parent / "fixtures"
    reports = tmp_path / "vivado"
    reports.mkdir()
    for source_name, target_name in {
        "util_flat_sample.rpt": "util_flat.rpt",
        "util_hier_sample.rpt": "util_hier.rpt",
        "timing_summary_sample.rpt": "timing_summary.rpt",
        "timing_paths_sample.rpt": "timing_paths.rpt",
        "power_sample.rpt": "power.rpt",
        "methodology_sample.rpt": "methodology.rpt",
        "drc_sample.rpt": "drc.rpt",
    }.items():
        shutil.copyfile(fixtures / source_name, reports / target_name)
    (reports / "status.json").write_text(
        json.dumps({"status": "pass", "vivado_version": "2025.2"}),
        encoding="utf-8",
    )
    (reports / "timing_lutrom_fetch.rpt").write_text(
        "\n".join(
            [
                "Slack (MET) : 1.500ns",
                "Source: uRv32iCore/uFetchStage/uPc/oPc_reg[3]/C",
                "Destination: uRv32iCore/uIfIdReg/IFIDReg_reg[Instr][23]/D",
                "Path Group: ClkOut",
                "Data Path Delay: 22.500ns (logic 3.250ns route 19.250ns)",
                "Logic Levels: 9",
                "net (fo=1, routed) 1.000 2.000 uInstrFetchMemory/uProgramRam/gen_direct_ram.MemRam_reg_r2_0_127_23_23/DPRA1",
            ]
        ),
        encoding="utf-8",
    )
    (reports / "timing_program_fetch.rpt").write_text(
        "\n".join(
            [
                "Slack (MET) : 2.250ns",
                "Source: uRv32iCore/uFetchStage/uPc/oPc_reg[4]/C",
                "Destination: uRv32iCore/uIfIdReg/IFIDReg_reg[Instr][17]/D",
                "Path Group: ClkOut",
                "Data Path Delay: 18.750ns (logic 2.000ns route 16.750ns)",
                "Logic Levels: 6",
                "net (fo=1, routed) 1.000 2.000 uInstrFetchMemory/uProgramRam/gen_direct_ram.MemRam_reg_r2_0_127_17_17/DPRA1",
            ]
        ),
        encoding="utf-8",
    )

    runtime = tmp_path / "counters.json"
    runtime.write_text(
        json.dumps(
            {
                "cycle_count": 120,
                "retired_instr_count": 100,
                "fetch_wait_cycles": 10,
                "fetch_request_count": 110,
                "fetch_response_count": 100,
                "fetch_boot_request_count": 10,
                "fetch_program_request_count": 100,
                "fetch_unmapped_request_count": 0,
                "redirect_flush_count": 5,
                "prefetch_hit_count": 80,
                "prefetch_empty_count": 10,
                "discarded_prefetch_count": 4,
                "retire_boot_instr_count": 8,
                "retire_program_instr_count": 92,
                "retire_unmapped_instr_count": 0,
                "fetch_min_addr": 0,
                "fetch_max_addr": 4364,
                "retire_min_pc": 0,
                "retire_max_pc": 4352,
                "program_done": True,
                "watchdog_timeout": False,
            }
        ),
        encoding="utf-8",
    )

    manifest = tmp_path / "case_manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "case": {
                    "case_id": "lutrom_direct__8kb__mixed_firmware",
                    "variant": "lutrom_direct",
                    "size_bytes": 8192,
                    "program": "mixed_firmware",
                    "exec_region": "program_ram",
                    "vivado_level": "synth_only",
                },
                "project": {
                    "part": "xc7a35tcpg236-1",
                    "strategy": "Default",
                    "top": "TOP",
                    "clock_period_ns": 40.0,
                },
                "git_commit": "abc1234",
            }
        ),
        encoding="utf-8",
    )

    metrics = parse_case(manifest, reports, runtime)
    flat = flatten_metrics(metrics)

    assert flat["lut"] == 1234
    assert flat["depth_words"] == 2048
    assert flat["lutram"] == 200
    assert flat["top_bucket_lut"] == 5
    assert flat["top_bucket_lutram"] == 4
    assert flat["device_lut_util_pct"] == 5.93
    assert flat["instr_rom_lut"] == 42
    assert flat["program_ram_lutram"] == 64
    assert flat["instr_fetch_memory_lut"] == 128
    assert flat["instr_fetch_memory_lutram"] == 96
    assert flat["instr_bus_mux_lut"] == 7
    assert flat["fetch_stage_lut"] == 31
    assert flat["wns_ns"] == -0.125
    assert flat["overall_wns"] == -0.125
    assert flat["top_critical_path_class"] == "direct_fetch"
    assert flat["overall_top_path_class"] == "direct_fetch"
    assert flat["top_path_group"] == "iClk"
    assert flat["top_path_data_delay"] == 12.345
    assert flat["status"] == "timing_fail"
    assert flat["exec_region"] == "program_ram"
    assert flat["instr_path_in_top10"] is True
    assert flat["instr_path_score"] == 2.0
    assert flat["direct_fetch_path_found"] is True
    assert flat["direct_fetch_slack_ns"] == 1.5
    assert flat["direct_fetch_delay_ns"] == 22.5
    assert flat["direct_fetch_logic_delay_ns"] == 3.25
    assert flat["direct_fetch_route_delay_ns"] == 19.25
    assert flat["direct_fetch_route_ratio"] == 19.25 / 22.5
    assert flat["direct_fetch_logic_levels"] == 9
    assert flat["direct_fetch_from"] == "uRv32iCore/uFetchStage/uPc/oPc_reg[3]/C"
    assert flat["direct_fetch_to"] == "uRv32iCore/uIfIdReg/IFIDReg_reg[Instr][23]/D"
    assert flat["direct_fetch_path_class"] == "program_ram_lutram"
    assert flat["direct_fetch_actual_memory"] == "ProgramRam"
    assert flat["direct_fetch_wns"] == 1.5
    assert flat["direct_fetch_delay"] == 22.5
    assert flat["direct_fetch_source"] == "uRv32iCore/uFetchStage/uPc/oPc_reg[3]/C"
    assert flat["direct_fetch_destination"] == "uRv32iCore/uIfIdReg/IFIDReg_reg[Instr][23]/D"
    assert "uProgramRam" in flat["direct_fetch_first_mem_token"]
    assert flat["program_fetch_path_found"] is True
    assert flat["programram_fetch_delay"] == 18.75
    assert flat["program_fetch_delay_ns"] == 18.75
    assert flat["program_fetch_logic_delay_ns"] == 2.0
    assert flat["program_fetch_route_delay_ns"] == 16.75
    assert flat["program_fetch_logic_levels"] == 6
    assert flat["program_fetch_path_class"] == "program_ram_lutram"
    assert flat["cpi"] == 1.2
    assert flat["fetch_wait_ratio"] == 10 / 120
    assert flat["fetch_program_ratio"] == 100 / 110
    assert flat["retire_program_ratio"] == 92 / 100
    assert flat["fetch_address_span_bytes"] == 4368
    assert flat["retire_pc_span_bytes"] == 4356
    assert flat["drc_error_count"] == 1
    assert flat["methodology_warning_count"] == 1


def test_empty_vivado_collection_report_error_is_recorded(tmp_path: Path) -> None:
    reports = tmp_path / "vivado"
    reports.mkdir()
    (reports / "status.json").write_text(
        json.dumps({"status": "pass", "vivado_version": "2025.2"}),
        encoding="utf-8",
    )
    (reports / "timing_bootrom_fetch.rpt").write_text(
        "report_error: missing through cells for pattern: BootRom\n",
        encoding="utf-8",
    )
    manifest = tmp_path / "case_manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "case": {
                    "case_id": "lutrom_direct__4kb__ifetch_capacity_nop__bootrom_only",
                    "variant": "lutrom_direct",
                    "size_bytes": 4096,
                    "program": "ifetch_capacity_nop",
                    "exec_region": "boot",
                    "ifetch_build_mode": "bootrom_only",
                    "vivado_level": "route",
                },
                "project": {"clock_period_ns": 40.0},
                "run": {"vivado": True, "xsim": False},
            }
        ),
        encoding="utf-8",
    )

    metrics = parse_case(manifest, reports, None)

    assert any("timing_bootrom_fetch.rpt: report_error" in item for item in metrics["quality"]["parse_errors"])
    assert metrics["case"]["status"] == "parse_fail"
    assert flatten_metrics(metrics)["parse_error_count"] >= 1
