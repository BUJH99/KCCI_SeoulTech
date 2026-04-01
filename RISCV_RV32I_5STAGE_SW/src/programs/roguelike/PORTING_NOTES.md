## Porting Notes for `strogue`

Target environment:
- RV32I bare-metal
- UART terminal display via Tera Term
- FND available for compact status output

Good fit:
- Turn-based gameplay keeps UART bandwidth demands low
- Small upstream codebase is practical to rework into one freestanding program image

Main blockers to direct reuse:
- Uses `ncurses`
- Uses desktop-oriented build flow and terminal handling

Expected port strategy:
1. Preserve dungeon generation and entity/player turn logic
2. Replace `ncurses` draw calls with ANSI cursor and text rendering over UART
3. Replace keyboard polling with UART RX polling
4. Remove libc and host dependencies not available on the RV32I target
5. Map compact stats to FND

Suggested controls on this board:
- `W/A/S/D` move
- `Q/E/Z/C` diagonals if needed
- `R` restart
- Space or `Enter` interact
