# Tetris Program Slot

This directory is the project-local landing zone for the `troglobit/tetris`
port that will eventually run on the `RISCV_32I_5STAGE_SW` core.

What is already wired:

- `tools/activate_program_image.bat`
  Copies a selected `.mem` file into the active ROM slot
  [`src/InstructionFORTIMING.mem`](/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_5STAGE_SW/src/InstructionFORTIMING.mem)
- `tools/build_tetris_bitstream.bat`
  Activates `Tetris.mem` and launches the normal Vivado build flow
- `tools/build_and_program_tetris.bat`
  Activates `Tetris.mem` and launches the normal build+program flow

Expected files:

- `Tetris.mem`
  Final playable RV32I program image for FPGA download
- `Tetris.s`
  Generated compiler assembly mirror of the current bare-metal port
- `tetris_port.c`
  Bare-metal UART terminal implementation used to produce the final ROM image
- `start.S`, `linker.ld`
  Minimal RV32I freestanding runtime for the split instruction/data memories

Reference sources:

- Upstream reference is vendored under
  [`src/programs/tetris/upstream/troglobit_tetris`](/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_5STAGE_SW/src/programs/tetris/upstream/troglobit_tetris)
- Porting notes live in
  [`src/programs/tetris/PORTING_NOTES.md`](/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_5STAGE_SW/src/programs/tetris/PORTING_NOTES.md)

Quick use:

1. Run `tools/build_tetris_program.sh`
2. Activate the generated image or use `tools\\build_and_program_tetris.bat`
3. Open Tera Term at `115200 8N1`
