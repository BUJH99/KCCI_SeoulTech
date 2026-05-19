## Basys3 board constraints for SortDisplaySlaveTop
## Target part from fpga_auto.yml: xc7a35tcpg236-1
##
## Build note:
## - This XDC is kept beside the SLAVE RTL so the current MASTER manifest
##   does not pick it up through constrs/**/*.xdc.
## - Use this with a SLAVE-specific build target whose top is SortDisplaySlaveTop.
##
## Reset note:
## - iRst is active-high in RTL.
## - It is mapped to SW15 so switch high asserts reset and switch low releases reset.
##
## I2C note:
## - SCL is input-only for this SLAVE top.
## - SDA is a single open-drain bidirectional PMOD pin with external pull-up.

set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports iClk]
create_clock -name iClk -period 10.000 [get_ports iClk]

set_property -dict { PACKAGE_PIN R2 IOSTANDARD LVCMOS33 } [get_ports iRst]

## Local SLAVE FND display.
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

## MASTER-to-SLAVE control/status pins.
## Pin footprint follows constrs/basys3_top.xdc for easier two-board wiring.
set_property -dict { PACKAGE_PIN L2 IOSTANDARD LVCMOS33 } [get_ports iI2cScl]
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports ioI2cSda]

## MASTER-to-SLAVE SPI trace pins.
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports iSpiSclk]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports iSpiMosi]
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports iSpiCsN]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
