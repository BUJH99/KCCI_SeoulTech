# Troglobit Tetris Porting Notes

Target reference:

- Upstream repo: [troglobit/tetris](https://github.com/troglobit/tetris)
- Reference source:
  [`upstream/troglobit_tetris/tetris.c`](/mnt/c/Users/tbdk5/Desktop/MAIN/0_Working/git/FPGA_Auto_Project/Project/RISCV_32I_5STAGE_SW/src/programs/tetris/upstream/troglobit_tetris/tetris.c)

Why it is a good fit:

- Small single-file codebase
- ANSI escape based rendering, which matches the UART terminal plan
- Minimal external dependencies on desktop Linux

Why it cannot be dropped into the current FPGA image as-is:

- It uses POSIX terminal APIs such as `termios`, `ioctl`, `poll`, `sigaction`,
  and `setitimer`
- The current project does not have a RISC-V C runtime or cross-compiler in the
  checked environment
- The project ROM image flow consumes a `$readmemh` program image, not a native
  ELF binary

Recommended port split:

1. Keep upstream as the behavioral reference for board rules, rotation, line
   clearing, and scoring
2. Replace desktop terminal setup with fixed ANSI screen writes over UART TX
3. Replace `stdin` key handling with UART RX polling
4. Replace timer/signal based gravity with a software tick loop
5. Mirror score to the APB FND block while the board is rendered on UART

Project-side prep already completed:

- ROM/RAM defaults increased from 256 words to 2048 words
- ROM/RAM inference switched to block memory to make larger software images
  practical on Basys3
- Basys3 default UART baud raised to `115200`
- Dedicated Tetris activation/build/program wrappers added under `tools/`

Expected runtime shape for the final port:

- UART terminal: board, next piece, status text
- FND: score or cleared-line count
- Input keys: `a` left, `d` right, `s` soft drop, `w` rotate, `q` quit/reset
