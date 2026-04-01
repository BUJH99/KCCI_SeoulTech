if {![info exists repo_root]} {
  set repo_root [file normalize [file join [file dirname [info script]] ".." ".." ".."]]
}

set repo_root [file normalize $repo_root]
set output_dir [file normalize $output_dir]

set normalized_source_files [list]
foreach rtl_file $source_files {
  lappend normalized_source_files [file normalize $rtl_file]
}
set source_files $normalized_source_files

source [file join $repo_root "templates" "contexts" "timing_verification" "adapters" "tcl" "common.tcl"]

riscv_timing_analysis::require_var source_files "source_files must be set before sourcing pipeline_perf_collect.tcl"
riscv_timing_analysis::require_var output_dir "output_dir must be set before sourcing pipeline_perf_collect.tcl"
riscv_timing_analysis::require_var part_name "part_name must be set before sourcing pipeline_perf_collect.tcl"
riscv_timing_analysis::require_var top_name "top_name must be set before sourcing pipeline_perf_collect.tcl"
riscv_timing_analysis::ensure_default clock_port "iClk"
riscv_timing_analysis::ensure_default reset_port "iRstn"
riscv_timing_analysis::ensure_default clk_period_ns 10.000
riscv_timing_analysis::ensure_default synth_directive "PerformanceOptimized"
riscv_timing_analysis::ensure_default opt_directive "Explore"
riscv_timing_analysis::ensure_default place_directive "Explore"
riscv_timing_analysis::ensure_default phys_opt_directive "AggressiveExplore"
riscv_timing_analysis::ensure_default route_directive "Explore"
riscv_timing_analysis::ensure_default post_route_phys_opt_directive "AggressiveExplore"
riscv_timing_analysis::ensure_default core_pblock_clock_region ""
riscv_timing_analysis::ensure_default family_configs {}
riscv_timing_analysis::maybe_cd_repo_root
riscv_timing_analysis::configure_max_threads

proc report_stage_artifacts {output_dir stage_key} {
  report_timing_summary -delay_type max -file [file join $output_dir "${stage_key}_timing_summary.rpt"]
  report_utilization -file [file join $output_dir "${stage_key}_utilization.rpt"]
  report_route_status -file [file join $output_dir "${stage_key}_route_status.rpt"]
}

proc render_family_pattern_list {patterns} {
  if {[llength $patterns] == 0} {
    return "none"
  }
  return [join $patterns ", "]
}

proc format_family_search_spec {family_config} {
  set instance_patterns [riscv_timing_analysis::dict_get_default $family_config instance_patterns {}]
  set ref_name_patterns [riscv_timing_analysis::dict_get_default $family_config ref_name_patterns {}]
  set endpoint_patterns [riscv_timing_analysis::dict_get_default $family_config endpoint_patterns {}]
  set pin_name_patterns [riscv_timing_analysis::dict_get_default $family_config pin_name_patterns [list D]]

  return "instance_patterns={[render_family_pattern_list $instance_patterns]} ref_name_patterns={[render_family_pattern_list $ref_name_patterns]} endpoint_patterns={[render_family_pattern_list $endpoint_patterns]} pin_name_patterns={[render_family_pattern_list $pin_name_patterns]}"
}

proc write_family_timing_artifacts {output_dir family_config clk_period_ns} {
  set family_key [dict get $family_config key]
  set family_base [file join $output_dir "${family_key}_timing"]
  set report_file "${family_base}_top20.rpt"
  set tsv_file "${family_base}_paths.tsv"
  set to_pins [riscv_timing_analysis::resolve_family_to_pins $family_config]
  set search_spec [format_family_search_spec $family_config]

  if {[llength $to_pins] == 0} {
    puts " \[WARN\] No pipeline timing endpoints matched family `${family_key}`. Searched ${search_spec}"
    set fh [open $report_file w]
    puts $fh "No pipeline timing endpoints matched family `${family_key}`. Searched ${search_spec}."
    close $fh
    riscv_timing_analysis::write_empty_timing_paths_tsv $tsv_file
    return
  }

  puts " \[INFO\] Family `${family_key}` resolved [llength $to_pins] endpoint pin(s)."
  report_timing -delay_type max -to $to_pins -max_paths 20 -file $report_file
  riscv_timing_analysis::write_timing_paths_tsv $tsv_file 20 $clk_period_ns $to_pins
}

proc apply_optional_core_pblock {core_pblock_clock_region} {
  if {$core_pblock_clock_region eq ""} {
    return
  }

  create_pblock pblock_core
  set core_cells [get_cells -hier -filter {REF_NAME !~ IBUF* && REF_NAME !~ OBUF* && REF_NAME !~ BUFG*}]
  add_cells_to_pblock [get_pblocks pblock_core] $core_cells
  resize_pblock [get_pblocks pblock_core] -add $core_pblock_clock_region
}

file mkdir $::output_dir

riscv_timing_analysis::load_source_files $::source_files
set total_progress_steps 5
riscv_timing_analysis::emit_progress 1 $total_progress_steps "Loaded pipeline RTL sources"

synth_design -top $::top_name -part $::part_name -directive $::synth_directive
riscv_timing_analysis::write_clock_and_reset_constraints $::clock_port $::reset_port $::clk_period_ns
apply_optional_core_pblock $::core_pblock_clock_region
report_stage_artifacts $::output_dir "post_synth"
riscv_timing_analysis::emit_progress 2 $total_progress_steps "Completed synthesis and post-synth reports"

opt_design -directive $::opt_directive
riscv_timing_analysis::write_clock_and_reset_constraints $::clock_port $::reset_port $::clk_period_ns
report_stage_artifacts $::output_dir "post_opt"
riscv_timing_analysis::emit_progress 3 $total_progress_steps "Completed logic optimization and post-opt reports"

place_design -directive $::place_directive
phys_opt_design -directive $::phys_opt_directive
riscv_timing_analysis::write_clock_and_reset_constraints $::clock_port $::reset_port $::clk_period_ns
report_stage_artifacts $::output_dir "post_place"
riscv_timing_analysis::emit_progress 4 $total_progress_steps "Completed placement and post-place reports"

route_design -directive $::route_directive
phys_opt_design -directive $::post_route_phys_opt_directive
riscv_timing_analysis::write_clock_and_reset_constraints $::clock_port $::reset_port $::clk_period_ns
report_stage_artifacts $::output_dir "post_route"
foreach family_config $::family_configs {
  write_family_timing_artifacts $::output_dir $family_config $::clk_period_ns
}
riscv_timing_analysis::emit_progress 5 $total_progress_steps "Completed routing and final timing reports"
