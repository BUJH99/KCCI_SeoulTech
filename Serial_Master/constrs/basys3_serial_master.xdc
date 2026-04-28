## Basys 3 constraints for Serial_Master TOP
## Clock/reset inputs for the 100MHz Basys 3 top-level wrapper
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports iClk100Mhz]
create_clock -name Clk100Mhz -period 10.000 [get_ports iClk100Mhz]

set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports iRst]

## User switches.
## SW[15] selects the active protocol: 0 = SPI over JA, 1 = I2C over JB.
## SW[6:0] provide the master write payload; SW[14:7] are currently unused in logic.
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {iSw[0]}]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {iSw[1]}]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {iSw[2]}]
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {iSw[3]}]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {iSw[4]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {iSw[5]}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {iSw[6]}]
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports {iSw[7]}]
set_property -dict { PACKAGE_PIN V2 IOSTANDARD LVCMOS33 } [get_ports {iSw[8]}]
set_property -dict { PACKAGE_PIN T3 IOSTANDARD LVCMOS33 } [get_ports {iSw[9]}]
set_property -dict { PACKAGE_PIN T2 IOSTANDARD LVCMOS33 } [get_ports {iSw[10]}]
set_property -dict { PACKAGE_PIN R3 IOSTANDARD LVCMOS33 } [get_ports {iSw[11]}]
set_property -dict { PACKAGE_PIN W2 IOSTANDARD LVCMOS33 } [get_ports {iSw[12]}]
set_property -dict { PACKAGE_PIN U1 IOSTANDARD LVCMOS33 } [get_ports {iSw[13]}]
set_property -dict { PACKAGE_PIN T1 IOSTANDARD LVCMOS33 } [get_ports {iSw[14]}]
set_property -dict { PACKAGE_PIN R2 IOSTANDARD LVCMOS33 } [get_ports {iSw[15]}]

## User LEDs.
## LED[14:8] mirror the remote Serial_Slave readback data; the remaining LEDs stay off in the current TOP.
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {oLed[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {oLed[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {oLed[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {oLed[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {oLed[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {oLed[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {oLed[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {oLed[7]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {oLed[8]}]
set_property -dict { PACKAGE_PIN V3 IOSTANDARD LVCMOS33 } [get_ports {oLed[9]}]
set_property -dict { PACKAGE_PIN W3 IOSTANDARD LVCMOS33 } [get_ports {oLed[10]}]
set_property -dict { PACKAGE_PIN U3 IOSTANDARD LVCMOS33 } [get_ports {oLed[11]}]
set_property -dict { PACKAGE_PIN P3 IOSTANDARD LVCMOS33 } [get_ports {oLed[12]}]
set_property -dict { PACKAGE_PIN N3 IOSTANDARD LVCMOS33 } [get_ports {oLed[13]}]
set_property -dict { PACKAGE_PIN P1 IOSTANDARD LVCMOS33 } [get_ports {oLed[14]}]
set_property -dict { PACKAGE_PIN L1 IOSTANDARD LVCMOS33 } [get_ports {oLed[15]}]

## PMOD JA carries the SPI master interface toward the Serial_Slave board.
## oJaCs   -> JA1
## oJaMosi -> JA2
## iJaMiso -> JA3
## oJaSclk -> JA4
set_property -dict { PACKAGE_PIN J1 IOSTANDARD LVCMOS33 } [get_ports oJaCs]
set_property -dict { PACKAGE_PIN L2 IOSTANDARD LVCMOS33 } [get_ports oJaMosi]
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports iJaMiso]
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 } [get_ports oJaSclk]

## PMOD JB carries the I2C master interface.
## ioJbScl -> JB1
## ioJbSda -> JB2
## SCL and SDA keep pull-ups enabled because both lines are released high by open-drain drivers.
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 PULLUP true } [get_ports ioJbScl]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 PULLUP true } [get_ports ioJbSda]

## Basys 3 configuration properties
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
