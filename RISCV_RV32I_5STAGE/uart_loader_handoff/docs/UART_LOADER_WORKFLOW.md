# UART Loader Workflow

## One-time board image

Program this bitstream once:

`HW/bitstreams/risc_axi_uart_loader.bit`

The ROM loader waits for a UART packet. Keep `SW8=0` to use the Basys3 USB UART pins.

## Build only

```powershell
cd ..
.\SW\build_scripts\build_ram_app.ps1 -Name ram_led_app -Source firmware_sources\ram_led_main.c
.\SW\build_scripts\build_ram_uart_echo_app.ps1
```

Outputs are written under `SW\build_outputs`:

- `<name>.elf`
- `<name>.bin`
- `<name>.dump`
- `<name>_loader_packet.bin`
- `<name>_loader_packet.hex`

## Build and download

```bat
SW\build_scripts\download_ram_led_app.bat COM7
SW\build_scripts\download_ram_uart_echo_app.bat COM7
```

Use the COM port shown by Windows Device Manager.

## GUI launcher

```bat
SW\build_scripts\run_loader_gui.bat
```

The GUI is a thin wrapper around the same PowerShell build/download scripts.

## Packet format

All integer fields are little-endian:

```text
magic       4 bytes  "RAXI"
load_addr   4 bytes
byte_count  4 bytes
entry_addr  4 bytes
checksum    4 bytes  additive byte checksum over payload
payload     N bytes  word-padded raw binary
```

Default RAM app address is `0x20001000`; default stack top is `0x20004000`.
