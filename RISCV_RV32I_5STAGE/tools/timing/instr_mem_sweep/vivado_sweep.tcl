proc read_file_text {path} {
  set fh [open $path r]
  set data [read $fh]
  close $fh
  return $data
}

proc json_string {text key default_value} {
  set pattern [format {"%s"[ \t\r\n]*:[ \t\r\n]*"([^"]*)"} $key]
  if {[regexp $pattern $text -> value]} {
    return $value
  }
  return $default_value
}

proc json_number {text key default_value} {
  set pattern [format {"%s"[ \t\r\n]*:[ \t\r\n]*([-0-9.]+)} $key]
  if {[regexp $pattern $text -> value]} {
    return $value
  }
  return $default_value
}

proc recursive_glob {dir pattern} {
  set result [list]
  foreach item [glob -nocomplain -directory $dir *] {
    if {[file isdirectory $item]} {
      foreach nested [recursive_glob $item $pattern] {
        lappend result $nested
      }
    } elseif {[string match $pattern [file tail $item]]} {
      lappend result [file normalize $item]
    }
  }
  return $result
}

proc write_status {path status message vivado_version vivado_level} {
  set safe_message [string map {"\"" "'" "\\" "/" "\n" " " "\r" " "} $message]
  set fh [open $path w]
  puts $fh "{"
  puts $fh "  \"status\": \"$status\","
  puts $fh "  \"message\": \"$safe_message\","
  puts $fh "  \"vivado_version\": \"$vivado_version\","
  puts $fh "  \"vivado_level\": \"$vivado_level\""
  puts $fh "}"
  close $fh
}

proc safe_report {script report_name} {
  if {[catch {uplevel 1 $script} err]} {
    set fh [open $report_name w]
    puts $fh "report_error: $err"
    close $fh
  }
}

proc write_report_error {report_name message} {
  set fh [open $report_name w]
  puts $fh "report_error: $message"
  close $fh
}

proc note_seed_param {vivado_dir name value param_name} {
  if {$value eq ""} {
    return
  }
  set report_name [file join $vivado_dir "seed_settings.txt"]
  set fh [open $report_name a]
  if {[catch {set_param $param_name $value} err]} {
    puts $fh "$name=$value param=$param_name status=ignored message=$err"
  } else {
    puts $fh "$name=$value param=$param_name status=applied"
  }
  close $fh
}

proc report_pc_to_ifid_path {vivado_dir report_file through_pattern} {
  set report_name [file join $vivado_dir $report_file]
  set pc_cells [get_cells -hier -quiet -regexp {.*uRv32iCore/uFetchStage/uPc/oPc_reg\[[0-9]+\]}]
  set ifid_instr_pins [get_pins -hier -quiet -regexp {.*uRv32iCore/uIfIdReg/IFIDReg_reg\[Instr\]\[[0-9]+\]/D}]

  if {([llength $pc_cells] == 0) || ([llength $ifid_instr_pins] == 0)} {
    write_report_error $report_name "missing PC-to-IFID endpoints; pc_cells=[llength $pc_cells], ifid_instr_pins=[llength $ifid_instr_pins]"
    return
  }

  if {$through_pattern eq ""} {
    report_timing \
      -from $pc_cells \
      -to $ifid_instr_pins \
      -max_paths 20 \
      -sort_by slack \
      -file $report_name
  } else {
    set through_cells [get_cells -hier -quiet -regexp $through_pattern]
    if {[llength $through_cells] == 0} {
      write_report_error $report_name "missing through cells for pattern: $through_pattern"
      return
    }

    report_timing \
      -from $pc_cells \
      -through $through_cells \
      -to $ifid_instr_pins \
      -max_paths 20 \
      -sort_by slack \
      -file $report_name
  }
}

proc active_fetch_through_pattern {ifetch_build_mode} {
  if {$ifetch_build_mode eq "bootrom_only"} {
    return {.*(uInstrRom|BootRom|MemRom|gen_direct_rom).*}
  }
  if {$ifetch_build_mode eq "programram_only"} {
    return {.*(uProgramRam|ProgramRam|MemRam|gen_direct_ram).*}
  }
  return ""
}

proc report_direct_fetch_path {vivado_dir ifetch_build_mode {report_file "timing_direct_fetch.rpt"}} {
  report_pc_to_ifid_path $vivado_dir $report_file [active_fetch_through_pattern $ifetch_build_mode]
}

proc report_clocked_only_path {vivado_dir} {
  set report_name [file join $vivado_dir "timing_clocked_only.rpt"]
  set clock_pins [all_registers -clock_pins]
  set data_pins [all_registers -data_pins]
  if {([llength $clock_pins] == 0) || ([llength $data_pins] == 0)} {
    write_report_error $report_name "missing clocked endpoints; clock_pins=[llength $clock_pins], data_pins=[llength $data_pins]"
    return
  }

  report_timing \
    -from $clock_pins \
    -to $data_pins \
    -max_paths 30 \
    -sort_by slack \
    -file $report_name
}

proc report_pc_update_path {vivado_dir {report_file "timing_pc_update_control.rpt"}} {
  set report_name [file join $vivado_dir $report_file]
  set pc_d_pins [get_pins -hier -quiet -regexp {.*uRv32iCore/uFetchStage/uPc/oPc_reg\[[0-9]+\]/D}]
  if {[llength $pc_d_pins] == 0} {
    write_report_error $report_name "missing PC D pins"
    return
  }

  report_timing \
    -to $pc_d_pins \
    -max_paths 20 \
    -sort_by slack \
    -file $report_name
}

proc report_reset_fanout_path {vivado_dir {report_file "timing_reset_fanout.rpt"}} {
  set report_name [file join $vivado_dir $report_file]
  set sysrst_cells [get_cells -hier -quiet -regexp {.*SysRst_reg.*}]
  set reset_pins [get_pins -hier -quiet -regexp {.*(/CLR|/R|/PRE)$}]
  if {([llength $sysrst_cells] == 0) || ([llength $reset_pins] == 0)} {
    write_report_error $report_name "missing reset endpoints; sysrst_cells=[llength $sysrst_cells], reset_pins=[llength $reset_pins]"
    return
  }

  report_timing \
    -from $sysrst_cells \
    -to $reset_pins \
    -max_paths 20 \
    -sort_by slack \
    -file $report_name
}

if {$argc < 1} {
  error "usage: vivado_sweep.tcl <case_manifest.json>"
}

set manifest_path [file normalize [lindex $argv 0]]
set manifest_text [read_file_text $manifest_path]
set project_root [file normalize [json_string $manifest_text "project_root" "."]]
set generated_dir [file normalize [json_string $manifest_text "generated_dir" "."]]
set vivado_dir [file normalize [json_string $manifest_text "vivado_dir" "."]]
set top_name [json_string $manifest_text "top" "TOP"]
set part_name [json_string $manifest_text "part" "xc7a35tcpg236-1"]
set vivado_level [json_string $manifest_text "vivado_level" "synth_only"]
set boot_addr_width [json_number $manifest_text "boot_addr_width" [json_number $manifest_text "addr_width" 10]]
set program_addr_width [json_number $manifest_text "program_addr_width" [json_number $manifest_text "addr_width" 10]]
set boot_depth_words [json_number $manifest_text "boot_depth_words" [json_number $manifest_text "depth_words" [expr {1 << int($boot_addr_width)}]]]
set program_depth_words [json_number $manifest_text "program_depth_words" [json_number $manifest_text "depth_words" [expr {1 << int($program_addr_width)}]]]
set init_file [file normalize [json_string $manifest_text "init_file" ""]]
set boot_init_file [file normalize [json_string $manifest_text "boot_init_file" $init_file]]
set program_init_file [file normalize [json_string $manifest_text "program_init_file" $init_file]]
set program_read_only_init [json_number $manifest_text "program_read_only_init" 0]
set mem_impl [json_number $manifest_text "mem_impl" 0]
set mem_latency [json_number $manifest_text "mem_latency" 0]
set prefetch_depth [json_number $manifest_text "prefetch_depth" 0]
set ifetch_build_mode [json_string $manifest_text "ifetch_build_mode" "legacy_unspecified"]
set clock_period_ns [json_number $manifest_text "clock_period_ns" 40.0]
set run_seed [json_number $manifest_text "run_seed" ""]
set placer_seed [json_number $manifest_text "placer_seed" ""]
set router_seed [json_number $manifest_text "router_seed" ""]

file mkdir $vivado_dir
cd $vivado_dir

set status_path [file join $vivado_dir "status.json"]
set vivado_version [version -short]
set status "pass"
set status_message "completed"

if {[catch {
  create_project instr_mem_sweep_case . -part $part_name -in_memory
  set_property target_language Verilog [current_project]
  set_property include_dirs [list $generated_dir] [current_fileset]
  note_seed_param $vivado_dir "placer_seed" $placer_seed "place.seed"
  note_seed_param $vivado_dir "router_seed" $router_seed "route.seed"

  set package_files [list]
  foreach package_name [list "rv32i_pkg.sv" "sort_demo_pkg.sv" "soc_addr_pkg.sv"] {
    set package_path [file join $project_root "src" $package_name]
    if {[file exists $package_path]} {
      lappend package_files [file normalize $package_path]
  }
}

  set variant_pkg [file join $generated_dir "instr_mem_variant_pkg.sv"]
  if {[file exists $variant_pkg]} {
    lappend package_files [file normalize $variant_pkg]
  }
  if {[llength $package_files] > 0} {
    read_verilog -sv $package_files
  }

  set sv_files [recursive_glob [file join $project_root "src"] "*.sv"]
  set v_files [recursive_glob [file join $project_root "src"] "*.v"]
  set rtl_files [list]
  foreach rtl_file [concat $sv_files $v_files] {
    if {[lsearch -exact $package_files [file normalize $rtl_file]] >= 0} {
      continue
    }
    lappend rtl_files $rtl_file
  }
  if {[llength $rtl_files] > 0} {
    read_verilog -sv $rtl_files
  }

  set xdc_path [file join $project_root "constrs" "basys3_top.xdc"]
  if {[file exists $xdc_path]} {
    read_xdc $xdc_path
  }

  set generics [list \
    P_BOOT_ADDR_WIDTH=$boot_addr_width \
    P_BOOT_DEPTH_WORDS=$boot_depth_words \
    P_BOOT_INIT_FILE=$boot_init_file \
    P_PROGRAM_ADDR_WIDTH=$program_addr_width \
    P_PROGRAM_DEPTH_WORDS=$program_depth_words \
    P_PROGRAM_INIT_FILE=$program_init_file \
    P_PROGRAM_READ_ONLY_INIT=$program_read_only_init \
    P_INSTR_MEM_IMPL=$mem_impl \
    P_INSTR_MEM_LATENCY=$mem_latency \
    P_PREFETCH_DEPTH=$prefetch_depth \
  ]
  synth_design -top $top_name -part $part_name -generic $generics
  if {[llength [get_clocks -quiet]] == 0} {
    create_clock -name iClk -period 10.000 [get_ports iClk]
  }

  if {$vivado_level eq "route"} {
    opt_design
    place_design
    route_design
  }

  safe_report {report_utilization -hierarchical -file [file join $vivado_dir "util_hier.rpt"]} [file join $vivado_dir "util_hier.rpt"]
  safe_report {report_utilization -file [file join $vivado_dir "util_flat.rpt"]} [file join $vivado_dir "util_flat.rpt"]
  safe_report {report_timing_summary -file [file join $vivado_dir "timing_summary.rpt"]} [file join $vivado_dir "timing_summary.rpt"]
  safe_report {report_timing -max_paths 30 -sort_by slack -file [file join $vivado_dir "timing_overall.rpt"]} [file join $vivado_dir "timing_overall.rpt"]
  safe_report {report_timing -max_paths 30 -sort_by slack -file [file join $vivado_dir "timing_paths.rpt"]} [file join $vivado_dir "timing_paths.rpt"]
  safe_report {report_clocked_only_path $vivado_dir} [file join $vivado_dir "timing_clocked_only.rpt"]
  safe_report {report_direct_fetch_path $vivado_dir $ifetch_build_mode "timing_direct_fetch.rpt"} [file join $vivado_dir "timing_direct_fetch.rpt"]
  safe_report {report_pc_to_ifid_path $vivado_dir "timing_lutrom_fetch.rpt" ""} [file join $vivado_dir "timing_lutrom_fetch.rpt"]
  safe_report {report_pc_to_ifid_path $vivado_dir "timing_bootrom_fetch.rpt" {.*(uInstrRom|BootRom|MemRom|gen_direct_rom).*}} [file join $vivado_dir "timing_bootrom_fetch.rpt"]
  safe_report {report_pc_to_ifid_path $vivado_dir "timing_programram_fetch.rpt" {.*(uProgramRam|ProgramRam|MemRam|gen_direct_ram).*}} [file join $vivado_dir "timing_programram_fetch.rpt"]
  safe_report {report_pc_to_ifid_path $vivado_dir "timing_ifetch_mux_to_ifid.rpt" {.*(uInstrBusMux|InstrBusMux).*}} [file join $vivado_dir "timing_ifetch_mux_to_ifid.rpt"]
  safe_report {report_pc_to_ifid_path $vivado_dir "timing_boot_fetch.rpt" {.*(uInstrRom|BootRom|MemRom|gen_direct_rom).*}} [file join $vivado_dir "timing_boot_fetch.rpt"]
  safe_report {report_pc_to_ifid_path $vivado_dir "timing_program_fetch.rpt" {.*(uProgramRam|ProgramRam|MemRam|gen_direct_ram).*}} [file join $vivado_dir "timing_program_fetch.rpt"]
  safe_report {report_pc_update_path $vivado_dir "timing_pc_update_control.rpt"} [file join $vivado_dir "timing_pc_update_control.rpt"]
  safe_report {report_pc_update_path $vivado_dir "timing_pc_update.rpt"} [file join $vivado_dir "timing_pc_update.rpt"]
  safe_report {report_reset_fanout_path $vivado_dir} [file join $vivado_dir "timing_reset_fanout.rpt"]
  safe_report {report_reset_fanout_path $vivado_dir "timing_async_reset.rpt"} [file join $vivado_dir "timing_async_reset.rpt"]
  safe_report {report_clock_utilization -file [file join $vivado_dir "clock_util.rpt"]} [file join $vivado_dir "clock_util.rpt"]
  safe_report {report_route_status -file [file join $vivado_dir "route_status.rpt"]} [file join $vivado_dir "route_status.rpt"]
  safe_report {report_methodology -file [file join $vivado_dir "methodology.rpt"]} [file join $vivado_dir "methodology.rpt"]
  safe_report {report_drc -file [file join $vivado_dir "drc.rpt"]} [file join $vivado_dir "drc.rpt"]
  safe_report {report_power -file [file join $vivado_dir "power.rpt"]} [file join $vivado_dir "power.rpt"]
} err]} {
  set status "vivado_fail"
  set status_message [string map {"\"" "'"} $err]
}

write_status $status_path $status $status_message $vivado_version $vivado_level
if {$status ne "pass"} {
  error $status_message
}
