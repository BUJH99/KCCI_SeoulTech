#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

mkdir -p output/vcs

vcs_opts=(
    -full64
    -sverilog
    -ntb_opts uvm-1.2
    -timescale=1ns/1ps
    -debug_access+all
    -kdb
    -top TbTop
    -l output/vcs/compile.log
    -f tb/vcs_filelist.f
    -o output/vcs/simv
)

if [[ "${ENABLE_FSDB:-0}" == "1" ]]; then
    vcs_opts+=(+define+FSDB)
fi

# shellcheck disable=SC2206
extra_vcs_opts=(${EXTRA_VCS_OPTS:-})
# shellcheck disable=SC2206
extra_sim_opts=(${EXTRA_SIM_OPTS:-})

vcs "${vcs_opts[@]}" "${extra_vcs_opts[@]}"

./output/vcs/simv \
    +UVM_TESTNAME="${UVM_TESTNAME:-FifoTest}" \
    +UVM_VERBOSITY="${UVM_VERBOSITY:-UVM_MEDIUM}" \
    "${extra_sim_opts[@]}" \
    -l output/vcs/sim.log
