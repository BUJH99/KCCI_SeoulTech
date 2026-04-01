## Roguelike Candidate

Selected upstream reference: `kkgobkk/strogue`

Why this repo:
- Small C codebase with a very small `src/` tree
- Terminal-based and turn-based, which fits UART text rendering better than real-time action games
- MIT license

Current status:
- Upstream source has been vendored under `upstream/strogue`
- This code is not yet runnable on the RV32I bare-metal target
- It currently depends on `ncurses`, so a UART/ANSI terminal backend will be needed for porting

Recommended next step:
- Replace the `ncurses` drawing/input layer with the project's UART terminal input/output layer
- Keep map generation, player/entity movement, and turn sequencing logic
- Mirror HP, floor, or score on the FND if desired
