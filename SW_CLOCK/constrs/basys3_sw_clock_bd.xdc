## Basys3 constraints for the SW_CLOCK MicroBlaze block-design wrapper
##
## Board target:
## - Digilent Basys3
## - Artix-7 xc7a35tcpg236-1
## - 100MHz oscillator on W5
##
## Expected block-design wrapper ports:
## - iClk100Mhz: board clock
## - iBtnC: active-high board reset into proc_sys_reset
## - iBtn[0]: BTNU mode select into RTL debounce core
## - iBtn[1]: BTNL stop/pause into RTL debounce core
## - iBtn[2]: BTNR run/start into RTL debounce core
## - iBtn[3]: BTND reset selected software service into RTL debounce core
## - oSeg/oDp/oDigitSel: active-low FND outputs from RTL display core

set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports iClk100Mhz]
create_clock -name Clk100Mhz -period 10.000 [get_ports iClk100Mhz]

set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports iBtnC]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports {iBtn[0]}]
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports {iBtn[1]}]
set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports {iBtn[2]}]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports {iBtn[3]}]

set_property -dict { PACKAGE_PIN W7 IOSTANDARD LVCMOS33 } [get_ports {oSeg[0]}]
set_property -dict { PACKAGE_PIN W6 IOSTANDARD LVCMOS33 } [get_ports {oSeg[1]}]
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS33 } [get_ports {oSeg[2]}]
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 } [get_ports {oSeg[3]}]
set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } [get_ports {oSeg[4]}]
set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 } [get_ports {oSeg[5]}]
set_property -dict { PACKAGE_PIN U7 IOSTANDARD LVCMOS33 } [get_ports {oSeg[6]}]
set_property -dict { PACKAGE_PIN V7 IOSTANDARD LVCMOS33 } [get_ports oDp]

set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS33 } [get_ports {oDigitSel[0]}]
set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS33 } [get_ports {oDigitSel[1]}]
set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS33 } [get_ports {oDigitSel[2]}]
set_property -dict { PACKAGE_PIN W4 IOSTANDARD LVCMOS33 } [get_ports {oDigitSel[3]}]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
