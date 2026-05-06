# Build a Basys3 MicroBlaze block design for the SW_CLOCK project and export XSA.
#
# Run from Vivado Tcl shell or Windows command prompt:
#   C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat -mode batch -source tools/create_sw_clock_bd_xsa.tcl
#
# Outputs:
#   output/vivado/sw_clock_bd_project/
#   output/xsa/SW_CLOCK_Basys3.xsa

set script_dir [file normalize [file dirname [info script]]]
set project_dir [file normalize [file join $script_dir ".."]]
set build_dir [file normalize [file join $project_dir "output" "vivado" "sw_clock_bd_project"]]
set xsa_dir [file normalize [file join $project_dir "output" "xsa"]]
set xsa_file [file normalize [file join $xsa_dir "SW_CLOCK_Basys3.xsa"]]
set bd_name "sw_clock_bd"
set proj_name "SW_CLOCK_Basys3"
set part_name "xc7a35tcpg236-1"

file mkdir $build_dir
file mkdir $xsa_dir

create_project -force $proj_name $build_dir -part $part_name
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_files [concat \
  [glob -nocomplain [file join $project_dir "src" "*.sv"]] \
  [glob -nocomplain [file join $project_dir "src" "*.v"]] \
]
if {[llength $rtl_files] == 0} {
  error "No RTL files found under $project_dir/src"
}
add_files -fileset sources_1 $rtl_files
add_files -fileset constrs_1 [file join $project_dir "constrs" "basys3_sw_clock_bd.xdc"]
update_compile_order -fileset sources_1

create_bd_design $bd_name
current_bd_design $bd_name

create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze microblaze_0
set_property -dict [list \
  CONFIG.C_USE_BARREL {1} \
  CONFIG.C_USE_DIV {1} \
  CONFIG.C_USE_HW_MUL {1} \
  CONFIG.C_DEBUG_ENABLED {1} \
] [get_bd_cells microblaze_0]

apply_bd_automation -rule xilinx.com:bd_rule:microblaze \
  -config {local_mem "64KB" ecc "None" debug_module "Debug Only" axi_periph "1" axi_intc "0" clk "New External Port (100 MHz)" } \
  [get_bd_cells microblaze_0]

set clk_port [get_bd_ports -quiet clk_100MHz]
if {$clk_port eq ""} {
  set clk_port [get_bd_ports -quiet -filter {TYPE == clk}]
}
if {$clk_port eq ""} {
  error "MicroBlaze automation did not create an external clock port"
}
set clk_port [lindex $clk_port 0]
if {[get_property NAME $clk_port] ne "iClk100Mhz"} {
  set_property name iClk100Mhz $clk_port
}
set clk_port [get_bd_ports iClk100Mhz]
set_property CONFIG.FREQ_HZ 100000000 $clk_port

set reset_port [get_bd_ports -quiet reset]
if {$reset_port eq ""} {
  set reset_port [get_bd_ports -quiet reset_rtl]
}
if {$reset_port eq ""} {
  set reset_port [get_bd_ports -quiet ext_reset_in]
}
if {$reset_port ne ""} {
  set_property name iBtnC $reset_port
} else {
  create_bd_port -dir I -type rst iBtnC
  set rst_cell [lindex [get_bd_cells -hier -filter {VLNV =~ "xilinx.com:ip:proc_sys_reset:*"}] 0]
  connect_bd_net [get_bd_ports iBtnC] [get_bd_pins $rst_cell/ext_reset_in]
}
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports iBtnC]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_display
set_property -dict [list \
  CONFIG.C_GPIO_WIDTH {32} \
  CONFIG.C_ALL_OUTPUTS {1} \
  CONFIG.C_INTERRUPT_PRESENT {0} \
] [get_bd_cells axi_gpio_display]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_buttons
set_property -dict [list \
  CONFIG.C_GPIO_WIDTH {8} \
  CONFIG.C_ALL_INPUTS {1} \
  CONFIG.C_INTERRUPT_PRESENT {0} \
] [get_bd_cells axi_gpio_buttons]

foreach axi_slave [list \
  [get_bd_intf_pins axi_gpio_display/S_AXI] \
  [get_bd_intf_pins axi_gpio_buttons/S_AXI] \
] {
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config [list Master "/microblaze_0 (Periph)"] \
    $axi_slave
}

create_bd_cell -type module -reference SwClockCoreBd uSwClockCore
set_property -dict [list \
  CONFIG.P_CLK_HZ {100000000} \
  CONFIG.P_SCAN_HZ {1000} \
  CONFIG.P_DEBOUNCE_MS {20} \
] [get_bd_cells uSwClockCore]

set rst_cell [lindex [get_bd_cells -hier -filter {VLNV =~ "xilinx.com:ip:proc_sys_reset:*"}] 0]
set rstn_pin [get_bd_pins $rst_cell/peripheral_aresetn]

create_bd_port -dir I -from 3 -to 0 iBtn
create_bd_port -dir O -from 6 -to 0 oSeg
create_bd_port -dir O oDp
create_bd_port -dir O -from 3 -to 0 oDigitSel

connect_bd_net $clk_port [get_bd_pins uSwClockCore/iClk]
connect_bd_net $rstn_pin [get_bd_pins uSwClockCore/iRstn]
connect_bd_net [get_bd_ports iBtn] [get_bd_pins uSwClockCore/iBtnRaw]
connect_bd_net [get_bd_pins axi_gpio_display/gpio_io_o] [get_bd_pins uSwClockCore/iDisplayWord]
connect_bd_net [get_bd_pins uSwClockCore/oButtonStatus] [get_bd_pins axi_gpio_buttons/gpio_io_i]
connect_bd_net [get_bd_pins uSwClockCore/oSeg] [get_bd_ports oSeg]
connect_bd_net [get_bd_pins uSwClockCore/oDp] [get_bd_ports oDp]
connect_bd_net [get_bd_pins uSwClockCore/oDigitSel] [get_bd_ports oDigitSel]

set uartlite_cells [get_bd_cells -quiet -hier -filter {VLNV =~ "xilinx.com:ip:axi_uartlite:*"}]
if {[llength $uartlite_cells] != 0} {
  error "AXI UARTLite must not be present in SW_CLOCK block design"
}

assign_bd_address
validate_bd_design
save_bd_design

set bd_file [get_files [file join $build_dir "$proj_name.srcs" "sources_1" "bd" $bd_name "$bd_name.bd"]]
generate_target all $bd_file
make_wrapper -files $bd_file -top
add_files -norecurse [file join $build_dir "$proj_name.gen" "sources_1" "bd" $bd_name "hdl" "${bd_name}_wrapper.v"]
set_property top "${bd_name}_wrapper" [current_fileset]
update_compile_order -fileset sources_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
if {[string first "Complete" $impl_status] < 0} {
  error "Implementation did not complete successfully. impl_1 status: $impl_status"
}

open_run impl_1
write_hw_platform -fixed -include_bit -force -file $xsa_file
puts "INFO: Exported XSA: $xsa_file"
