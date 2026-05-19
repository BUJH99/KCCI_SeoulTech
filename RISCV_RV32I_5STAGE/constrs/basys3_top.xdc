## Basys3 board constraints for RISCV_RV32I_5STAGE TOP
## Target part from fpga_auto.yml: xc7a35tcpg236-1
##
## Reset note:
## - iRst is active-high in RTL.
## - It is mapped to SW15 so switch high asserts reset and switch low releases reset.

set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports iClk]
create_clock -name iClk -period 10.000 [get_ports iClk]

set_property -dict { PACKAGE_PIN R2 IOSTANDARD LVCMOS33 } [get_ports iRst]

## MASTER GPIO command buttons.
set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports {iGpioIn[0]}] ;# BTNR start
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports {iGpioIn[1]}] ;# BTNL slave FND mode
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports {iGpioIn[2]}] ;# BTNU unused
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports {iGpioIn[3]}] ;# BTNC reset
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {iGpioIn[4]}] ;# SW4 unused
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {iGpioIn[5]}] ;# SW5 unused
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {iGpioIn[6]}] ;# SW6 unused
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports {iGpioIn[7]}] ;# SW7 unused

set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {oGpioOut[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {oGpioOut[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {oGpioOut[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {oGpioOut[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {oGpioOut[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {oGpioOut[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {oGpioOut[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {oGpioOut[7]}]

set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {oGpioOe[0]}]
set_property -dict { PACKAGE_PIN V3 IOSTANDARD LVCMOS33 } [get_ports {oGpioOe[1]}]
set_property -dict { PACKAGE_PIN W3 IOSTANDARD LVCMOS33 } [get_ports {oGpioOe[2]}]
set_property -dict { PACKAGE_PIN U3 IOSTANDARD LVCMOS33 } [get_ports {oGpioOe[3]}]
set_property -dict { PACKAGE_PIN P3 IOSTANDARD LVCMOS33 } [get_ports {oGpioOe[4]}]
set_property -dict { PACKAGE_PIN N3 IOSTANDARD LVCMOS33 } [get_ports {oGpioOe[5]}]
set_property -dict { PACKAGE_PIN P1 IOSTANDARD LVCMOS33 } [get_ports {oGpioOe[6]}]
set_property -dict { PACKAGE_PIN L1 IOSTANDARD LVCMOS33 } [get_ports {oGpioOe[7]}]

set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports iUartRx]
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports oUartTx]

## MASTER FND display.
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

## External SLAVE control/status and trace pins.
## Two-Basys3 wiring checklist:
## - Tie MASTER GND and SLAVE GND together before connecting signal wires.
## - Keep all bus wiring in the 3.3 V LVCMOS domain; do not connect to 5 V logic.
## - MASTER and SLAVE use their own iClk/iRst; these pins are only the board-to-board link.
##
## I2C control/status bus, open-drain:
## - Add pull-ups from SCL and SDA to 3V3 on one side of the bus, typically 4.7 kOhm to 10 kOhm.
## - MASTER JA2/L2 ioI2cScl <-> SLAVE JA2/L2 iI2cScl.
## - MASTER JA3/J2 ioI2cSda <-> SLAVE JA3/J2 ioI2cSda.
set_property -dict { PACKAGE_PIN L2 IOSTANDARD LVCMOS33 } [get_ports ioI2cScl]
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports ioI2cSda]
##
## SPI trace bus, MASTER drives and SLAVE samples:
## - MASTER JB1/A14 oSpiSclk -> SLAVE JB1/A14 iSpiSclk.
## - MASTER JB2/A16 oSpiMosi -> SLAVE JB2/A16 iSpiMosi.
## - MASTER JB4/B16 oSpiCsN  -> SLAVE JB4/B16 iSpiCsN, active-low chip select.
## - Current SortDisplaySlaveTop is one-way SPI and has no MISO output.
##   MASTER JB3/B15 iSpiMiso is reserved for a future SLAVE MISO; leave it unconnected or pull it low unless the SLAVE top exports oSpiMiso.
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports oSpiSclk]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports oSpiMosi]
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports iSpiMiso]
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports oSpiCsN]

## Timing probe exported on PMOD JA1.
set_property -dict { PACKAGE_PIN J1 IOSTANDARD LVCMOS33 } [get_ports oTimingProbe]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
