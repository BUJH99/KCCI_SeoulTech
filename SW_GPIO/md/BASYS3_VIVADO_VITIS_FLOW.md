# SW_GPIO Basys3 Vivado + Vitis Flow

## 1. Vivado XSA creation

From `Project/SW_GPIO`, run:

```bat
C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat -mode batch -source tools\create_sw_gpio_bd_xsa.tcl
```

Expected output:

- `output\xsa\SW_GPIO_Basys3.xsa`
- `output\vivado\sw_gpio_buttons_bd_project\`

The generated block design contains:

- MicroBlaze with 64KB local BRAM
- AXI GPIO `axi_gpio_ctrl`: 2-bit output to RTL
  - bit 0: run
  - bit 1: stop
- AXI GPIO `axi_gpio_buttons`: 2-bit input from Basys3 buttons
  - bit 0: BTNL stop
  - bit 1: BTNR run
- AXI GPIO `axi_gpio_status`: 32-bit input from RTL
  - bits 15:0: BCD counter value
  - bit 16: run state
  - bit 17: rollover pulse
  - bit 18: run command pulse monitor
  - bit 19: stop command pulse monitor
- RTL module reference `Top`
- Basys3 FND pins from `constrs/basys3_sw_gpio_bd.xdc`

## 2. Vitis platform

1. Open Vitis.
2. Create a workspace, for example `Project/SW_GPIO/output/vitis_workspace`.
3. Create a new platform from:

```text
Project/SW_GPIO/output/xsa/SW_GPIO_Basys3.xsa
```

4. Select the standalone domain for MicroBlaze.
5. Build the platform.

## 3. Vitis application

1. Create an application project using the generated platform.
2. Choose an Empty Application template.
3. Add `vitis/sw_gpio_app/src/main.c` to the app source folder.
4. Build the application.
5. Connect Basys3 over USB.
6. Program FPGA from Vitis with the bitstream included in the XSA.
7. Run the application on MicroBlaze.
8. Control the counter with Basys3 pushbuttons:

- BTNR: run counter
- BTNL: stop counter
- BTNC: reset and clear counter to 0000

The FND should display the 0000 to 9999 up-counter while run is active.
