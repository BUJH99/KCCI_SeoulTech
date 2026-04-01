if {![info exists repo_root]} {
  set repo_root [file normalize [file join [file dirname [info script]] ".." ".." ".."]]
}

source [file join $repo_root "templates" "contexts" "timing_verification" "adapters" "tcl" "common.tcl"]
source [file join $repo_root "templates" "contexts" "timing_verification" "adapters" "tcl" "single_cycle_collect_core.tcl"]

riscv_timing_analysis::single_cycle::run
