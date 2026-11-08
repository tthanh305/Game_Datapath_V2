`ifndef GAME_PARAMS_VH
`define GAME_PARAMS_VH

// --- Screen & Timing Constants (720p @ 60Hz) ---
`define GAME_SCREEN_WIDTH    1280
`define GAME_SCREEN_HEIGHT   720
`define GAME_COORD_WIDTH     11
`define GAME_SCORE_WIDTH     20

// --- Player Ship Constants (4-Directional Movement) ---
`define GAME_SHIP_WIDTH      32
`define GAME_SHIP_HEIGHT     32
`define GAME_SHIP_Y          620
`define GAME_SHIP_INIT_X     624
`define GAME_SHIP_START_X    624
`define GAME_SHIP_MIN_X      32
`define GAME_SHIP_MAX_X      1216
`define GAME_SHIP_MIN_Y      360
`define GAME_SHIP_MAX_Y      648
`define SHIP_MIN_X           32
`define SHIP_MAX_X           1216
`define SHIP_MIN_Y           360
`define SHIP_MAX_Y           648
`define GAME_SHIP_SPEED      7

// --- 11x4 Enemy Formation Constants (44 Enemies) ---
`define FORM_COLS            11
`define FORM_ROWS            4
`define FORM_COUNT           44
`define FORM_X0              288
`define FORM_Y0              72
`define FORM_DX              64
`define FORM_DY              48
`define FORM_ENEMY_SIZE      32

// --- Legacy 16-target bus compatibility for top-level wrappers ---
`define GAME_TARGET_COLS     4
`define GAME_TARGET_ROWS     4
`define GAME_TARGET_COUNT    16
`define GAME_TARGET_ID_WIDTH 4
`define GAME_TARGET_WIDTH    32
`define GAME_TARGET_HEIGHT   32
`define GAME_TARGET_X0       240
`define GAME_TARGET_Y0       100
`define GAME_TARGET_DX       160
`define GAME_TARGET_DY       60

// --- Weapon, Projectiles, Wingmen, Laser & Pools ---
`define GAME_PROJECTILE_WIDTH      6
`define GAME_PROJECTILE_HEIGHT     16
`define GAME_PROJECTILE_INIT_X     638
`define GAME_PROJECTILE_INIT_Y     604
`define GAME_PROJECTILE_SPEED      19
`define GAME_HOMING_SPEED          12
`define GAME_EBUL_SPEED            6

`define PLAYER_INIT_LIVES          3'd5
`define PLAYER_MAX_LIVES           3'd5

`define MAX_PBUL             16
`define MAX_HBUL             8
`define MAX_EBUL             10
`define MAX_DIVERS           4
`define MAX_ASTEROIDS        3
`define MAX_POWERUPS         2
`define MAX_IMPACTS          4

`define AUTO_FIRE_PERIOD     11
`define AUTOFIRE_FRAMES      11
`define HOMING_FIRE_PERIOD   14
`define WINGMAN_FIRE_FRAMES  14
`define RAGE_MAX             20
`define LASER_DURATION       120
`define LASER_FRAMES         120
`define HOLD_MENU_FRAMES     120
`define EXIT_HOLD_FRAMES     120

// --- Larger Asteroid (64x64px = 2x scale) & Boss (64x64px) & Power-up Sizes ---
`define ASTEROID_SIZE        64
`define BOSS_SIZE            64
`define POWERUP_SIZE         16
`define IMPACT_SIZE          16

// --- Power-Up Item Types ---
`define ITEM_TYPE_POWER      2'd0
`define ITEM_TYPE_SHIELD     2'd1
`define ITEM_TYPE_RAGE       2'd2

// --- 4 Distinct Enemy Bullet Types ---
`define EBUL_TYPE_FIREBALL   2'd0
`define EBUL_TYPE_WAVE       2'd1
`define EBUL_TYPE_SNIPER     2'd2
`define EBUL_TYPE_SEEKER     2'd3

`define GAME_WIN_HOLD_FRAMES       180

`endif
