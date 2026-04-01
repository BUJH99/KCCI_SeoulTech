typedef unsigned char u8;
typedef unsigned int u32;
typedef int s32;

#define UART_STATUS (*(volatile u32 *)0x40000004u)
#define UART_TXDATA (*(volatile u32 *)0x40000008u)
#define UART_RXDATA (*(volatile u32 *)0x4000000cu)
#define FND_DIGITS  (*(volatile u32 *)0x40002000u)
#define FND_CTRL    (*(volatile u32 *)0x4000200cu)

#define MAP_W 30u
#define MAP_H 14u
#define MAP_CELLS (MAP_W * MAP_H)
#define ROOM_COUNT 5u
#define ROOM_SLOTS 6u
#define CELL_W (MAP_W / 3u)
#define CELL_H (MAP_H / 2u)
#define MAX_ENEMIES 12u
#define MAX_GOLD 8u
#define PLAYER_MAX_HP 9u
#define GOAL_FLOOR 5u
#define INVALID_INDEX 0xffffffffu

#define TILE_WALL 0u
#define TILE_FLOOR 1u
#define TILE_STAIRS 2u

#define MSG_WELCOME 0u
#define MSG_GOLD 1u
#define MSG_ENEMY_HIT 2u
#define MSG_ENEMY_SLAIN 3u
#define MSG_PLAYER_HURT 4u
#define MSG_STAIRS 5u
#define MSG_NEW_FLOOR 6u
#define MSG_BLOCKED 7u
#define MSG_WAIT 8u
#define MSG_CANT_DESCEND 9u
#define MSG_WIN 10u
#define MSG_DEAD 11u
#define MSG_RESTART 12u

typedef struct {
    u8 x;
    u8 y;
    u8 w;
    u8 h;
} Room;

typedef struct {
    u8 x;
    u8 y;
    u8 hp;
} Enemy;

typedef struct {
    u8 x;
    u8 y;
    u8 value;
} Gold;

static u8   gMap[MAP_CELLS];
static Room gRooms[ROOM_COUNT];
static Enemy gEnemies[MAX_ENEMIES];
static Gold  gGold[MAX_GOLD];

static u8  gEnemyCount;
static u8  gGoldCount;
static u8  gPlayerX;
static u8  gPlayerY;
static u8  gPlayerHp;
static u8  gFloor;
static u8  gStairsX;
static u8  gStairsY;
static u8  gGameOver;
static u8  gGameWon;
static u32 gGoldTotal;
static u32 gTurnCount;
static u32 gRngState;
static u8  gMessageId;
static u32 gMessageValue;

void *memcpy(void *dst, const void *src, unsigned int len)
{
    u8 *dst_bytes = (u8 *)dst;
    const u8 *src_bytes = (const u8 *)src;

    while (len != 0u) {
        *dst_bytes = *src_bytes;
        ++dst_bytes;
        ++src_bytes;
        --len;
    }

    return dst;
}

static u32 map_index(u32 x, u32 y)
{
    return (y * MAP_W) + x;
}

static u8 map_get(u32 x, u32 y)
{
    return gMap[map_index(x, y)];
}

static void map_set(u32 x, u32 y, u8 tile)
{
    gMap[map_index(x, y)] = tile;
}

static void rng_mix(u32 seed)
{
    gRngState ^= seed + 0x9e3779b9u;
    if (gRngState == 0u) {
        gRngState = 0x13579bdfu;
    }
}

static u32 rng_next(void)
{
    if (gRngState == 0u) {
        gRngState = 0x13579bdfu;
    }

    gRngState ^= gRngState << 13;
    gRngState ^= gRngState >> 17;
    gRngState ^= gRngState << 5;
    return gRngState;
}

static u32 rng_range(u32 max_value)
{
    if (max_value == 0u) {
        return 0u;
    }

    return rng_next() % max_value;
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

static s32 uart_wait_key(void)
{
    s32 key;

    do {
        key = uart_getc_nonblock();
    } while (key < 0);

    return key;
}

static void emit_str(const char *str)
{
    while (*str != '\0') {
        uart_putc((u32)(unsigned char)(*str));
        ++str;
    }
}

static void emit_crlf(void)
{
    uart_putc('\r');
    uart_putc('\n');
}

static void emit_dec_u32(u32 value)
{
    char digits[10];
    u32 idx = 0u;

    if (value == 0u) {
        uart_putc('0');
        return;
    }

    while (value != 0u && idx < 10u) {
        digits[idx] = (char)('0' + (value % 10u));
        value /= 10u;
        ++idx;
    }

    while (idx != 0u) {
        --idx;
        uart_putc((u32)(unsigned char)digits[idx]);
    }
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

static void fnd_write_gold(void)
{
    u32 value = gGoldTotal;
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

static void set_message(u8 id, u32 value)
{
    gMessageId = id;
    gMessageValue = value;
}

static u32 coord_in_bounds(s32 x, s32 y)
{
    if (x < 0 || y < 0) {
        return 0u;
    }

    if ((u32)x >= MAP_W || (u32)y >= MAP_H) {
        return 0u;
    }

    return 1u;
}

static s32 abs_s32(s32 value)
{
    return (value < 0) ? -value : value;
}

static s32 step_dir(s32 delta)
{
    if (delta < 0) {
        return -1;
    }
    if (delta > 0) {
        return 1;
    }
    return 0;
}

static void fill_map(u8 tile)
{
    u32 idx;

    for (idx = 0u; idx < MAP_CELLS; ++idx) {
        gMap[idx] = tile;
    }
}

static void carve_room(const Room *room)
{
    u32 y;
    u32 x;

    for (y = 0u; y < room->h; ++y) {
        for (x = 0u; x < room->w; ++x) {
            map_set((u32)room->x + x, (u32)room->y + y, TILE_FLOOR);
        }
    }
}

static void carve_hline(u32 y, u32 x0, u32 x1)
{
    u32 x;
    u32 begin = x0;
    u32 end = x1;

    if (begin > end) {
        begin = x1;
        end = x0;
    }

    for (x = begin; x <= end; ++x) {
        map_set(x, y, TILE_FLOOR);
    }
}

static void carve_vline(u32 x, u32 y0, u32 y1)
{
    u32 y;
    u32 begin = y0;
    u32 end = y1;

    if (begin > end) {
        begin = y1;
        end = y0;
    }

    for (y = begin; y <= end; ++y) {
        map_set(x, y, TILE_FLOOR);
    }
}

static u32 room_center_x(const Room *room)
{
    return (u32)room->x + ((u32)room->w / 2u);
}

static u32 room_center_y(const Room *room)
{
    return (u32)room->y + ((u32)room->h / 2u);
}

static void build_rooms(void)
{
    u32 slot;
    u32 room_idx = 0u;
    u32 skip_slot = rng_range(ROOM_SLOTS);

    for (slot = 0u; slot < ROOM_SLOTS; ++slot) {
        Room room;
        u32 cell_col;
        u32 cell_row;
        u32 room_w;
        u32 room_h;
        u32 off_x;
        u32 off_y;

        if (slot == skip_slot) {
            continue;
        }

        cell_col = slot % 3u;
        cell_row = slot / 3u;
        room_w = 4u + rng_range(5u);
        room_h = 3u + rng_range(3u);
        off_x = CELL_W - room_w - 1u;
        off_y = CELL_H - room_h - 1u;

        room.x = (u8)((cell_col * CELL_W) + 1u + rng_range(off_x));
        room.y = (u8)((cell_row * CELL_H) + 1u + rng_range(off_y));
        room.w = (u8)room_w;
        room.h = (u8)room_h;

        gRooms[room_idx] = room;
        carve_room(&room);
        ++room_idx;
    }
}

static void connect_rooms(void)
{
    u32 idx;

    for (idx = 1u; idx < ROOM_COUNT; ++idx) {
        u32 x0 = room_center_x(&gRooms[idx - 1u]);
        u32 y0 = room_center_y(&gRooms[idx - 1u]);
        u32 x1 = room_center_x(&gRooms[idx]);
        u32 y1 = room_center_y(&gRooms[idx]);

        if ((rng_next() & 1u) == 0u) {
            carve_hline(y0, x0, x1);
            carve_vline(x1, y0, y1);
        } else {
            carve_vline(x0, y0, y1);
            carve_hline(y1, x0, x1);
        }
    }
}

static u32 enemy_at(u32 x, u32 y)
{
    u32 idx;

    for (idx = 0u; idx < (u32)gEnemyCount; ++idx) {
        if ((u32)gEnemies[idx].x == x && (u32)gEnemies[idx].y == y) {
            return idx;
        }
    }

    return INVALID_INDEX;
}

static u32 gold_at(u32 x, u32 y)
{
    u32 idx;

    for (idx = 0u; idx < (u32)gGoldCount; ++idx) {
        if ((u32)gGold[idx].x == x && (u32)gGold[idx].y == y) {
            return idx;
        }
    }

    return INVALID_INDEX;
}

static u32 spawn_blocked(u32 x, u32 y)
{
    if ((u32)gPlayerX == x && (u32)gPlayerY == y) {
        return 1u;
    }

    if ((u32)gStairsX == x && (u32)gStairsY == y) {
        return 1u;
    }

    if (enemy_at(x, y) != INVALID_INDEX) {
        return 1u;
    }

    if (gold_at(x, y) != INVALID_INDEX) {
        return 1u;
    }

    return 0u;
}

static void room_random_floor(const Room *room, u8 *x, u8 *y)
{
    *x = (u8)((u32)room->x + rng_range((u32)room->w));
    *y = (u8)((u32)room->y + rng_range((u32)room->h));
}

static void remove_enemy(u32 idx)
{
    while (idx + 1u < (u32)gEnemyCount) {
        gEnemies[idx] = gEnemies[idx + 1u];
        ++idx;
    }

    if (gEnemyCount != 0u) {
        --gEnemyCount;
    }
}

static void remove_gold(u32 idx)
{
    while (idx + 1u < (u32)gGoldCount) {
        gGold[idx] = gGold[idx + 1u];
        ++idx;
    }

    if (gGoldCount != 0u) {
        --gGoldCount;
    }
}

static void spawn_floor_objects(u32 start_room_idx)
{
    u32 room_idx;
    u32 enemy_hp = 1u + ((u32)gFloor > 2u ? 1u : 0u) + ((u32)gFloor > 4u ? 1u : 0u);

    gEnemyCount = 0u;
    gGoldCount = 0u;

    for (room_idx = 0u; room_idx < ROOM_COUNT; ++room_idx) {
        u32 attempt;

        if (room_idx != start_room_idx) {
            u32 spawns = 1u;
            if ((u32)gFloor > 1u && (rng_next() & 1u) == 0u) {
                ++spawns;
            }

            for (attempt = 0u; attempt < spawns && gEnemyCount < MAX_ENEMIES; ++attempt) {
                u32 tries;

                for (tries = 0u; tries < 10u; ++tries) {
                    u8 ex;
                    u8 ey;

                    room_random_floor(&gRooms[room_idx], &ex, &ey);
                    if (spawn_blocked((u32)ex, (u32)ey)) {
                        continue;
                    }

                    gEnemies[gEnemyCount].x = ex;
                    gEnemies[gEnemyCount].y = ey;
                    gEnemies[gEnemyCount].hp = (u8)enemy_hp;
                    ++gEnemyCount;
                    break;
                }
            }
        }

        if (room_idx != start_room_idx && gGoldCount < MAX_GOLD && (rng_range(100u) < 75u)) {
            for (attempt = 0u; attempt < 10u; ++attempt) {
                u8 gx;
                u8 gy;

                room_random_floor(&gRooms[room_idx], &gx, &gy);
                if (spawn_blocked((u32)gx, (u32)gy)) {
                    continue;
                }

                gGold[gGoldCount].x = gx;
                gGold[gGoldCount].y = gy;
                gGold[gGoldCount].value = (u8)(5u + rng_range(8u) + ((u32)gFloor * 2u));
                ++gGoldCount;
                break;
            }
        }
    }
}

static void build_floor(void)
{
    u32 start_room_idx;
    u32 exit_room_idx;

    fill_map(TILE_WALL);
    build_rooms();
    connect_rooms();

    start_room_idx = rng_range(ROOM_COUNT);
    exit_room_idx = rng_range(ROOM_COUNT - 1u);
    if (exit_room_idx >= start_room_idx) {
        ++exit_room_idx;
    }

    gPlayerX = (u8)room_center_x(&gRooms[start_room_idx]);
    gPlayerY = (u8)room_center_y(&gRooms[start_room_idx]);
    gStairsX = (u8)room_center_x(&gRooms[exit_room_idx]);
    gStairsY = (u8)room_center_y(&gRooms[exit_room_idx]);
    map_set((u32)gStairsX, (u32)gStairsY, TILE_STAIRS);

    spawn_floor_objects(start_room_idx);
}

static void game_reset(void)
{
    rng_mix(gTurnCount + gGoldTotal + (u32)gFloor);
    gPlayerHp = PLAYER_MAX_HP;
    gFloor = 1u;
    gGoldTotal = 0u;
    gTurnCount = 0u;
    gGameOver = 0u;
    gGameWon = 0u;
    build_floor();
    fnd_write_gold();
    set_message(MSG_RESTART, 0u);
}

static void collect_gold_if_present(void)
{
    u32 idx = gold_at((u32)gPlayerX, (u32)gPlayerY);

    if (idx != INVALID_INDEX) {
        u32 value = (u32)gGold[idx].value;
        gGoldTotal += value;
        if (gGoldTotal > 9999u) {
            gGoldTotal = 9999u;
        }
        remove_gold(idx);
        fnd_write_gold();
        set_message(MSG_GOLD, value);
    } else if (map_get((u32)gPlayerX, (u32)gPlayerY) == TILE_STAIRS) {
        set_message(MSG_STAIRS, (u32)gFloor);
    }
}

static u32 attack_enemy(u32 idx)
{
    if (gEnemies[idx].hp > 1u) {
        --gEnemies[idx].hp;
        set_message(MSG_ENEMY_HIT, (u32)gEnemies[idx].hp);
    } else {
        remove_enemy(idx);
        set_message(MSG_ENEMY_SLAIN, 0u);
    }

    return 1u;
}

static u32 attempt_move_player(s32 dx, s32 dy)
{
    s32 next_x = (s32)gPlayerX + dx;
    s32 next_y = (s32)gPlayerY + dy;
    u32 enemy_idx;

    if (!coord_in_bounds(next_x, next_y)) {
        set_message(MSG_BLOCKED, 0u);
        return 0u;
    }

    if (map_get((u32)next_x, (u32)next_y) == TILE_WALL) {
        set_message(MSG_BLOCKED, 0u);
        return 0u;
    }

    enemy_idx = enemy_at((u32)next_x, (u32)next_y);
    if (enemy_idx != INVALID_INDEX) {
        return attack_enemy(enemy_idx);
    }

    gPlayerX = (u8)next_x;
    gPlayerY = (u8)next_y;
    collect_gold_if_present();
    return 1u;
}

static u32 enemy_move_target_blocked(u32 idx, s32 next_x, s32 next_y)
{
    if (!coord_in_bounds(next_x, next_y)) {
        return 1u;
    }

    if (map_get((u32)next_x, (u32)next_y) == TILE_WALL) {
        return 1u;
    }

    if (enemy_at((u32)next_x, (u32)next_y) != INVALID_INDEX) {
        return 1u;
    }

    if ((u32)gStairsX == (u32)next_x && (u32)gStairsY == (u32)next_y) {
        return 0u;
    }

    (void)idx;
    return 0u;
}

static u32 enemy_try_step(u32 idx, s32 dx, s32 dy, u32 *damage)
{
    s32 next_x = (s32)gEnemies[idx].x + dx;
    s32 next_y = (s32)gEnemies[idx].y + dy;

    if (dx == 0 && dy == 0) {
        return 0u;
    }

    if (!coord_in_bounds(next_x, next_y)) {
        return 0u;
    }

    if ((u32)next_x == (u32)gPlayerX && (u32)next_y == (u32)gPlayerY) {
        *damage += 1u;
        return 1u;
    }

    if (enemy_move_target_blocked(idx, next_x, next_y)) {
        return 0u;
    }

    gEnemies[idx].x = (u8)next_x;
    gEnemies[idx].y = (u8)next_y;
    return 1u;
}

static void enemy_turn(void)
{
    u32 idx;
    u32 total_damage = 0u;

    for (idx = 0u; idx < (u32)gEnemyCount; ++idx) {
        s32 dx = (s32)gPlayerX - (s32)gEnemies[idx].x;
        s32 dy = (s32)gPlayerY - (s32)gEnemies[idx].y;
        s32 sx = step_dir(dx);
        s32 sy = step_dir(dy);

        if (abs_s32(dx) <= 1 && abs_s32(dy) <= 1) {
            total_damage += 1u;
            continue;
        }

        if (sx != 0 && sy != 0) {
            if (enemy_try_step(idx, sx, sy, &total_damage)) {
                continue;
            }
        }

        if (abs_s32(dx) >= abs_s32(dy)) {
            if (enemy_try_step(idx, sx, 0, &total_damage)) {
                continue;
            }
            (void)enemy_try_step(idx, 0, sy, &total_damage);
        } else {
            if (enemy_try_step(idx, 0, sy, &total_damage)) {
                continue;
            }
            (void)enemy_try_step(idx, sx, 0, &total_damage);
        }
    }

    if (total_damage != 0u) {
        if (total_damage >= (u32)gPlayerHp) {
            gPlayerHp = 0u;
            gGameOver = 1u;
            set_message(MSG_DEAD, gGoldTotal);
        } else {
            gPlayerHp = (u8)((u32)gPlayerHp - total_damage);
            set_message(MSG_PLAYER_HURT, total_damage);
        }
    }
}

static u32 descend_floor(void)
{
    if ((u32)gPlayerX != (u32)gStairsX || (u32)gPlayerY != (u32)gStairsY) {
        set_message(MSG_CANT_DESCEND, 0u);
        return 0u;
    }

    if ((u32)gFloor >= GOAL_FLOOR) {
        gGameWon = 1u;
        set_message(MSG_WIN, gGoldTotal);
        return 1u;
    }

    ++gFloor;
    if (gPlayerHp < PLAYER_MAX_HP) {
        ++gPlayerHp;
    }
    build_floor();
    set_message(MSG_NEW_FLOOR, (u32)gFloor);
    return 1u;
}

static void emit_title(void)
{
    emit_str("RV32I MICRO ROGUELIKE");
    emit_crlf();
    emit_str("HP ");
    emit_dec_u32((u32)gPlayerHp);
    emit_str("/");
    emit_dec_u32(PLAYER_MAX_HP);
    emit_str("  FLOOR ");
    emit_dec_u32((u32)gFloor);
    emit_str("  GOLD ");
    emit_dec_u32(gGoldTotal);
    emit_str("  TURN ");
    emit_dec_u32(gTurnCount);
    emit_crlf();
}

static void emit_border(void)
{
    u32 idx;

    uart_putc('+');
    for (idx = 0u; idx < MAP_W; ++idx) {
        uart_putc('-');
    }
    uart_putc('+');
    emit_crlf();
}

static u32 enemy_symbol_hp(u32 hp)
{
    if (hp >= 3u) {
        return 'O';
    }
    if (hp == 2u) {
        return 'G';
    }
    return 'g';
}

static u32 tile_glyph(u32 x, u32 y)
{
    u32 enemy_idx;
    u32 gold_idx;
    u8 tile;

    if ((u32)gPlayerX == x && (u32)gPlayerY == y) {
        return '@';
    }

    enemy_idx = enemy_at(x, y);
    if (enemy_idx != INVALID_INDEX) {
        return enemy_symbol_hp((u32)gEnemies[enemy_idx].hp);
    }

    gold_idx = gold_at(x, y);
    if (gold_idx != INVALID_INDEX) {
        return '$';
    }

    tile = map_get(x, y);
    if (tile == TILE_WALL) {
        return '#';
    }
    if (tile == TILE_STAIRS) {
        return '>';
    }
    return '.';
}

static void emit_message_line(void)
{
    switch (gMessageId) {
        case MSG_GOLD:
            emit_str("You collect ");
            emit_dec_u32(gMessageValue);
            emit_str(" gold.");
            break;
        case MSG_ENEMY_HIT:
            emit_str("You wound the goblin.");
            break;
        case MSG_ENEMY_SLAIN:
            emit_str("You slay the goblin.");
            break;
        case MSG_PLAYER_HURT:
            emit_str("The dungeon bites back. Damage ");
            emit_dec_u32(gMessageValue);
            emit_str(".");
            break;
        case MSG_STAIRS:
            emit_str("Stairs found. Press X to descend.");
            break;
        case MSG_NEW_FLOOR:
            emit_str("You descend to floor ");
            emit_dec_u32(gMessageValue);
            emit_str(".");
            break;
        case MSG_BLOCKED:
            emit_str("A wall blocks your path.");
            break;
        case MSG_WAIT:
            emit_str("You wait and listen.");
            break;
        case MSG_CANT_DESCEND:
            emit_str("No stairs here.");
            break;
        case MSG_WIN:
            emit_str("You escape rich. Gold ");
            emit_dec_u32(gMessageValue);
            emit_str(". Press R.");
            break;
        case MSG_DEAD:
            emit_str("You died. Gold ");
            emit_dec_u32(gMessageValue);
            emit_str(". Press R.");
            break;
        case MSG_RESTART:
            emit_str("New run begins.");
            break;
        case MSG_WELCOME:
        default:
            emit_str("Reach floor ");
            emit_dec_u32(GOAL_FLOOR);
            emit_str(" and escape alive.");
            break;
    }
    emit_crlf();
}

static void emit_help_line(void)
{
    if (gGameOver) {
        emit_str("GAME OVER  R restart");
    } else if (gGameWon) {
        emit_str("VICTORY  R restart");
    } else {
        emit_str("WASD move  QEZC diag  X stairs  . or SPACE wait  R reset");
    }
    emit_crlf();
}

static void draw_game(void)
{
    u32 y;
    u32 x;

    term_home();
    emit_title();
    emit_border();
    for (y = 0u; y < MAP_H; ++y) {
        uart_putc('|');
        for (x = 0u; x < MAP_W; ++x) {
            uart_putc(tile_glyph(x, y));
        }
        uart_putc('|');
        emit_crlf();
    }
    emit_border();
    emit_message_line();
    emit_help_line();
}

static u32 handle_key(s32 key)
{
    if (key == 'r' || key == 'R') {
        game_reset();
        return 0u;
    }

    if (gGameOver || gGameWon) {
        return 0u;
    }

    if (key == 'x' || key == 'X' || key == '>' || key == '\r' || key == '\n') {
        return descend_floor();
    }

    if (key == '.' || key == ' ') {
        set_message(MSG_WAIT, 0u);
        return 1u;
    }

    if (key == 'w' || key == 'W' || key == 'k' || key == 'K') {
        return attempt_move_player(0, -1);
    }
    if (key == 's' || key == 'S' || key == 'j' || key == 'J') {
        return attempt_move_player(0, 1);
    }
    if (key == 'a' || key == 'A' || key == 'h' || key == 'H') {
        return attempt_move_player(-1, 0);
    }
    if (key == 'd' || key == 'D' || key == 'l' || key == 'L') {
        return attempt_move_player(1, 0);
    }
    if (key == 'q' || key == 'Q' || key == 'y' || key == 'Y') {
        return attempt_move_player(-1, -1);
    }
    if (key == 'e' || key == 'E' || key == 'u' || key == 'U') {
        return attempt_move_player(1, -1);
    }
    if (key == 'z' || key == 'Z' || key == 'b' || key == 'B') {
        return attempt_move_player(-1, 1);
    }
    if (key == 'c' || key == 'C' || key == 'n' || key == 'N') {
        return attempt_move_player(1, 1);
    }

    return 0u;
}

int main(void)
{
    FND_CTRL = 1u;
    rng_mix(0x2468ace1u);
    term_clear();
    term_hide_cursor();
    gMessageId = MSG_WELCOME;
    game_reset();

    while (1) {
        u32 consumed;
        s32 key;

        draw_game();
        key = uart_wait_key();
        consumed = handle_key(key);

        if (consumed != 0u && !gGameOver && !gGameWon && gMessageId != MSG_NEW_FLOOR) {
            ++gTurnCount;
            enemy_turn();
        }
    }
}
