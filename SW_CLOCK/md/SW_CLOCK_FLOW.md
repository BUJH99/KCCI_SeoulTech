# SW_CLOCK Basys3 Vivado + Vitis Flow

## Hardware

Run from `Project/SW_CLOCK`:

```bat
C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat -mode batch -source tools\create_sw_clock_bd_xsa.tcl
```

The block design contains MicroBlaze, local BRAM, reset/clock logic, `axi_gpio_display`, `axi_gpio_buttons`, and the custom RTL module reference `SwClockCoreBd`. It intentionally does not instantiate AXI UARTLite.

The custom RTL core receives a 32-bit display frame from software, scans the FND pins in hardware, and debounces the four physical buttons before software reads them through AXI GPIO.

Display frame map:

| Bits | Meaning |
|---|---|
| `[15:0]` | Four BCD digits, digit 0 in `[3:0]` |
| `[19:16]` | Decimal-point enable mask |
| `[23:20]` | Digit blank mask |
| `[31:24]` | Reserved |

Button status map:

| Bits | Meaning |
|---|---|
| `[3:0]` | Debounced button state |
| `[7:4]` | Synchronized raw button state |

## Software

Run after XSA export:

```bat
C:\AMDDesignTools\2025.2\Vitis\bin\vitis.bat -s tools\create_vitis_sw_clock_app.py
```

The Vitis workspace is generated at `C:\tmp\swclock_vitis`.

## Program And Run

Connect the Basys3 board, then run:

```bat
C:\AMDDesignTools\2025.2\Vitis\bin\vitis.bat -s tools\run_sw_clock_app.py
```

Button mapping:

| Button | Function |
|---|---|
| BTNU | Toggle UpCounter / Clock mode |
| BTNR | Run selected service |
| BTNL | Stop selected service |
| BTND | Reset selected service |
| BTNC | Hardware system reset |
