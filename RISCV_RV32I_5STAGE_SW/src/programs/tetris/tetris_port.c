typedef unsigned char u8;
typedef unsigned int u32;
typedef int s32;

#define UART_STATUS (*(volatile u32 *)0x40000004u)
#define UART_TXDATA (*(volatile u32 *)0x40000008u)
#define UART_RXDATA (*(volatile u32 *)0x4000000cu)
#define FND_DIGITS  (*(volatile u32 *)0x40002000u)
#define FND_CTRL    (*(volatile u32 *)0x4000200cu)

#define BOARD_W 10u
#define BOARD_H 16u
#define BOARD_CELLS (BOARD_W * BOARD_H)

static u8  gBoard[BOARD_CELLS];
static u32 gRngState;
static s32 gPieceX;
static s32 gPieceY;
static u32 gPieceType;
static u32 gPieceRot;
static u32 gScore;
static u32 gLines;
static u32 gGameOver;
static u32 gNeedRedraw;
static u32 gGravityCounter;

static u32 board_index(u32 x, u32 y)
{
    return (y << 3) + (y << 1) + x;
}

static void busy_delay(u32 cycles)
{
    volatile u32 idx;

    for (idx = 0; idx < cycles; ++idx) {
        __asm__ volatile ("" ::: "memory");
    }
}

static void uart_putc(u32 ch)
{
    while ((UART_STATUS & 0x2u) == 0u) {
    }

    UART_TXDATA = ch & 0xffu;
}

static s32 uart_getc_nonblock(void)
{
    if ((UART_STATUS & 0x1u) == 0u) {
        return -1;
    }

    return (s32)(UART_RXDATA & 0xffu);
}

static void term_crlf(void)
{
    uart_putc('\r');
    uart_putc('\n');
}

static void term_home(void)
{
    uart_putc(27u);
    uart_putc('[');
    uart_putc('H');
}

static void term_clear(void)
{
    uart_putc(27u);
    uart_putc('[');
    uart_putc('2');
    uart_putc('J');
    term_home();
}

static void term_hide_cursor(void)
{
    uart_putc(27u);
    uart_putc('[');
    uart_putc('?');
    uart_putc('2');
    uart_putc('5');
    uart_putc('l');
}

static void emit_title(void)
{
    uart_putc('R');
    uart_putc('V');
    uart_putc('3');
    uart_putc('2');
    uart_putc('I');
    uart_putc(' ');
    uart_putc('T');
    uart_putc('E');
    uart_putc('T');
    uart_putc('R');
    uart_putc('I');
    uart_putc('S');
    term_crlf();
}

static void emit_running_help(void)
{
    uart_putc('A');
    uart_putc(' ');
    uart_putc('L');
    uart_putc(' ');
    uart_putc('D');
    uart_putc(' ');
    uart_putc('R');
    uart_putc(' ');
    uart_putc('W');
    uart_putc(' ');
    uart_putc('T');
    uart_putc(' ');
    uart_putc('S');
    uart_putc(' ');
    uart_putc('D');
    uart_putc(' ');
    uart_putc('R');
    uart_putc(' ');
    uart_putc('R');
    uart_putc(' ');
    uart_putc('E');
    uart_putc(' ');
    uart_putc('S');
    uart_putc(' ');
    uart_putc('P');
    uart_putc(' ');
    uart_putc('H');
    uart_putc(' ');
    uart_putc('D');
    term_crlf();
    uart_putc('S');
    uart_putc('C');
    uart_putc('O');
    uart_putc('R');
    uart_putc('E');
    uart_putc(' ');
    uart_putc('O');
    uart_putc('N');
    uart_putc(' ');
    uart_putc('F');
    uart_putc('N');
    uart_putc('D');
    term_crlf();
}

static void emit_game_over_help(void)
{
    uart_putc('G');
    uart_putc('A');
    uart_putc('M');
    uart_putc('E');
    uart_putc(' ');
    uart_putc('O');
    uart_putc('V');
    uart_putc('E');
    uart_putc('R');
    uart_putc(' ');
    uart_putc('R');
    uart_putc(' ');
    uart_putc('R');
    uart_putc('E');
    uart_putc('S');
    uart_putc('E');
    uart_putc('T');
    term_crlf();
}

static void board_clear(void)
{
    u32 idx;

    for (idx = 0; idx < BOARD_CELLS; ++idx) {
        gBoard[idx] = 0u;
    }
}

static u32 piece_mask(u32 type, u32 rot)
{
    u32 r = rot & 3u;

    if (type == 0u) {
        if ((r & 1u) == 0u) return (1u << 4) | (1u << 5) | (1u << 6) | (1u << 7);
        return (1u << 1) | (1u << 5) | (1u << 9) | (1u << 13);
    }

    if (type == 1u) {
        return (1u << 1) | (1u << 2) | (1u << 5) | (1u << 6);
    }

    if (type == 2u) {
        if (r == 0u) return (1u << 1) | (1u << 4) | (1u << 5) | (1u << 6);
        if (r == 1u) return (1u << 1) | (1u << 5) | (1u << 6) | (1u << 9);
        if (r == 2u) return (1u << 4) | (1u << 5) | (1u << 6) | (1u << 9);
        return (1u << 1) | (1u << 4) | (1u << 5) | (1u << 9);
    }

    if (type == 3u) {
        if ((r & 1u) == 0u) return (1u << 1) | (1u << 2) | (1u << 4) | (1u << 5);
        return (1u << 1) | (1u << 5) | (1u << 6) | (1u << 10);
    }

    if (type == 4u) {
        if ((r & 1u) == 0u) return (1u << 0) | (1u << 1) | (1u << 5) | (1u << 6);
        return (1u << 2) | (1u << 5) | (1u << 6) | (1u << 9);
    }

    if (type == 5u) {
        if (r == 0u) return (1u << 0) | (1u << 4) | (1u << 5) | (1u << 6);
        if (r == 1u) return (1u << 1) | (1u << 2) | (1u << 5) | (1u << 9);
        if (r == 2u) return (1u << 4) | (1u << 5) | (1u << 6) | (1u << 10);
        return (1u << 1) | (1u << 5) | (1u << 8) | (1u << 9);
    }

    if (r == 0u) return (1u << 2) | (1u << 4) | (1u << 5) | (1u << 6);
    if (r == 1u) return (1u << 1) | (1u << 5) | (1u << 9) | (1u << 10);
    if (r == 2u) return (1u << 4) | (1u << 5) | (1u << 6) | (1u << 8);
    return (1u << 0) | (1u << 1) | (1u << 5) | (1u << 9);
}

static u32 piece_has_block(u32 type, u32 rot, s32 dx, s32 dy)
{
    u32 mask;
    u32 bit;

    if (dx < 0 || dx > 3 || dy < 0 || dy > 3) {
        return 0u;
    }

    mask = piece_mask(type, rot);
    bit  = 1u << (((u32)dy << 2) + (u32)dx);
    return (mask & bit) != 0u;
}

static u32 piece_fits(s32 px, s32 py, u32 type, u32 rot)
{
    s32 row;
    s32 col;

    for (row = 0; row < 4; ++row) {
        for (col = 0; col < 4; ++col) {
            s32 board_x;
            s32 board_y;

            if (!piece_has_block(type, rot, col, row)) {
                continue;
            }

            board_x = px + col;
            board_y = py + row;

            if (board_x < 0 || board_x >= (s32)BOARD_W) {
                return 0u;
            }

            if (board_y >= (s32)BOARD_H) {
                return 0u;
            }

            if (board_y >= 0 && gBoard[board_index((u32)board_x, (u32)board_y)] != 0u) {
                return 0u;
            }
        }
    }

    return 1u;
}

static void score_to_fnd(void)
{
    u32 value = gScore;
    u32 d3 = 0u;
    u32 d2 = 0u;
    u32 d1 = 0u;
    u32 d0 = 0u;

    if (value > 9999u) {
        value = 9999u;
    }

    while (value >= 1000u) {
        value -= 1000u;
        ++d3;
    }

    while (value >= 100u) {
        value -= 100u;
        ++d2;
    }

    while (value >= 10u) {
        value -= 10u;
        ++d1;
    }

    d0 = value;
    FND_CTRL = 1u;
    FND_DIGITS = (d3 << 12) | (d2 << 8) | (d1 << 4) | d0;
}

static void score_add(u32 addend)
{
    gScore += addend;
    if (gScore > 9999u) {
        gScore = 9999u;
    }
    score_to_fnd();
}

static u32 next_piece_type(void)
{
    u32 value;

    if (gRngState == 0u) {
        gRngState = 0x13579bdfu;
    }

    gRngState ^= gRngState << 13;
    gRngState ^= gRngState >> 17;
    gRngState ^= gRngState << 5;

    value = gRngState & 7u;
    if (value == 7u) {
        value = 3u;
    }

    return value;
}

static u32 gravity_reload(void)
{
    if (gLines < 4u)  return 120u;
    if (gLines < 8u)  return 95u;
    if (gLines < 12u) return 75u;
    if (gLines < 16u) return 60u;
    if (gLines < 20u) return 48u;
    return 36u;
}

static void spawn_piece(void)
{
    gPieceType = next_piece_type();
    gPieceRot  = 0u;
    gPieceX    = 3;
    gPieceY    = 0;

    if (!piece_fits(gPieceX, gPieceY, gPieceType, gPieceRot)) {
        gGameOver = 1u;
    }
}

static void lock_piece(void)
{
    s32 row;
    s32 col;

    for (row = 0; row < 4; ++row) {
        for (col = 0; col < 4; ++col) {
            s32 board_x;
            s32 board_y;

            if (!piece_has_block(gPieceType, gPieceRot, col, row)) {
                continue;
            }

            board_x = gPieceX + col;
            board_y = gPieceY + row;

            if (board_x >= 0 && board_x < (s32)BOARD_W &&
                board_y >= 0 && board_y < (s32)BOARD_H) {
                gBoard[board_index((u32)board_x, (u32)board_y)] = 1u;
            }
        }
    }
}

static void clear_lines(void)
{
    s32 row;
    u32 cleared = 0u;

    for (row = (s32)BOARD_H - 1; row >= 0; --row) {
        u32 full = 1u;
        u32 col;

        for (col = 0u; col < BOARD_W; ++col) {
            if (gBoard[board_index(col, (u32)row)] == 0u) {
                full = 0u;
                break;
            }
        }

        if (full) {
            s32 move_row;

            ++cleared;
            for (move_row = row; move_row > 0; --move_row) {
                u32 move_col;
                for (move_col = 0u; move_col < BOARD_W; ++move_col) {
                    gBoard[board_index(move_col, (u32)move_row)] =
                        gBoard[board_index(move_col, (u32)(move_row - 1))];
                }
            }

            for (col = 0u; col < BOARD_W; ++col) {
                gBoard[board_index(col, 0u)] = 0u;
            }

            ++row;
        }
    }

    if (cleared != 0u) {
        gLines += cleared;
        if (cleared == 1u) score_add(100u);
        else if (cleared == 2u) score_add(300u);
        else if (cleared == 3u) score_add(500u);
        else score_add(800u);
    }
}

static void advance_game(void)
{
    if (piece_fits(gPieceX, gPieceY + 1, gPieceType, gPieceRot)) {
        ++gPieceY;
        return;
    }

    lock_piece();
    clear_lines();
    spawn_piece();
}

static void game_reset(void)
{
    board_clear();
    gScore = 0u;
    gLines = 0u;
    gGameOver = 0u;
    gNeedRedraw = 1u;
    gRngState ^= 0x9e3779b9u;
    if (gRngState == 0u) {
        gRngState = 0x2468ace1u;
    }
    score_to_fnd();
    gGravityCounter = gravity_reload();
    spawn_piece();
}

static void draw_cell(u32 col, u32 row)
{
    s32 rel_x = (s32)col - gPieceX;
    s32 rel_y = (s32)row - gPieceY;

    if (!gGameOver && piece_has_block(gPieceType, gPieceRot, rel_x, rel_y)) {
        uart_putc('@');
    } else if (gBoard[board_index(col, row)] != 0u) {
        uart_putc('#');
    } else {
        uart_putc(' ');
    }
}

static void draw_border(void)
{
    u32 col;

    uart_putc('+');
    for (col = 0u; col < BOARD_W; ++col) {
        uart_putc('-');
    }
    uart_putc('+');
    term_crlf();
}

static void draw_board(void)
{
    u32 row;
    u32 col;

    term_home();
    emit_title();
    draw_border();
    for (row = 0u; row < BOARD_H; ++row) {
        uart_putc('|');
        for (col = 0u; col < BOARD_W; ++col) {
            draw_cell(col, row);
        }
        uart_putc('|');
        term_crlf();
    }
    draw_border();
    if (gGameOver) emit_game_over_help();
    else emit_running_help();
}

static void handle_soft_drop(void)
{
    if (!piece_fits(gPieceX, gPieceY + 1, gPieceType, gPieceRot)) {
        advance_game();
    } else {
        ++gPieceY;
    }
    gGravityCounter = gravity_reload();
    gNeedRedraw = 1u;
}

static void handle_hard_drop(void)
{
    while (piece_fits(gPieceX, gPieceY + 1, gPieceType, gPieceRot)) {
        ++gPieceY;
        score_add(2u);
    }

    advance_game();
    gGravityCounter = gravity_reload();
    gNeedRedraw = 1u;
}

static void handle_key(s32 key)
{
    if (key == 'r' || key == 'R') {
        game_reset();
        return;
    }

    if (gGameOver) {
        return;
    }

    if (key == 'a' || key == 'A') {
        if (piece_fits(gPieceX - 1, gPieceY, gPieceType, gPieceRot)) {
            --gPieceX;
            gNeedRedraw = 1u;
        }
        return;
    }

    if (key == 'd' || key == 'D') {
        if (piece_fits(gPieceX + 1, gPieceY, gPieceType, gPieceRot)) {
            ++gPieceX;
            gNeedRedraw = 1u;
        }
        return;
    }

    if (key == 'w' || key == 'W') {
        u32 next_rot = (gPieceRot + 1u) & 3u;
        if (piece_fits(gPieceX, gPieceY, gPieceType, next_rot)) {
            gPieceRot = next_rot;
            gNeedRedraw = 1u;
        }
        return;
    }

    if (key == 's' || key == 'S') {
        handle_soft_drop();
        return;
    }

    if (key == ' ') {
        handle_hard_drop();
    }
}

int main(void)
{
    FND_CTRL = 1u;
    term_clear();
    term_hide_cursor();
    game_reset();

    while (1) {
        s32 key = uart_getc_nonblock();
        if (key >= 0) {
            handle_key(key);
        }

        if (!gGameOver) {
            if (gGravityCounter == 0u) {
                advance_game();
                gGravityCounter = gravity_reload();
                gNeedRedraw = 1u;
            } else {
                --gGravityCounter;
            }
        }

        if (gNeedRedraw) {
            draw_board();
            gNeedRedraw = 0u;
        }

        busy_delay(50000u);
    }
}
