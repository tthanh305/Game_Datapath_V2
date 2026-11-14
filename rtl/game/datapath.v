`timescale 1ns / 1ps
`include "game_params.vh"

// =============================================================================
// Galaxian Steredenn Shmup Datapath
// Connects Physics Engine (11x4 formation, 4-way movement, auto-fire, Item P
// power-ups, 2 wingmen + homing bullets, falling asteroids, overdrive laser)
// with the Dual-Port BRAM Color Mapper & Slow Parallax Starfield Renderer.
// =============================================================================

(* keep_hierarchy = "yes" *)
module datapath (
    input wire clk,
    input wire rst,
    input wire game_reset,
    input wire frame_tick,
    input wire game_enable,
    input wire move_left,
    input wire move_right,
    input wire move_up,
    input wire move_down,
    input wire fire,
    input wire laser_trigger,
    input wire pixel_active,
    input wire [`GAME_COORD_WIDTH-1:0] pixel_x,
    input wire [`GAME_COORD_WIDTH-1:0] pixel_y,

    output wire hit_flag,
    output wire [`GAME_TARGET_ID_WIDTH-1:0] hit_target_id,
    output wire fire_ready,
    output wire fire_accepted,
    output wire [`GAME_SCORE_WIDTH-1:0] score,
    output wire win,
    output wire game_over,
    output wire [6:0] wave_num,
    output wire [`GAME_TARGET_COUNT-1:0] alive_flags,
    output wire [`GAME_COORD_WIDTH-1:0] ship_x,
    output wire [`GAME_COORD_WIDTH-1:0] ship_y,
    output wire [`GAME_COORD_WIDTH-1:0] projectile_x,
    output wire [`GAME_COORD_WIDTH-1:0] projectile_y,
    output wire projectile_active,
    output wire [`GAME_TARGET_COUNT*`GAME_COORD_WIDTH-1:0] target_x_flat,
    output wire [`GAME_TARGET_COUNT*`GAME_COORD_WIDTH-1:0] target_y_flat,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue,

    // Sound effect trigger outputs
    output wire sound_fire,
    output wire sound_hit,
    output wire sound_dive,
    output wire sound_player_die,
    output wire sound_win,
    output wire sound_game_over,
    output wire sound_powerup,
    output wire sound_laser
);

// Legacy Galaxian gameplay wires
wire [2:0]  player_lives;
wire [7:0]  wave_entry_offset;
wire        player_exploding;
wire [1:0]  player_exp_phase;
wire [10:0] diving_x, diving_y;
wire        diving_active;
wire [3:0]  diving_id;
wire        bomb_active;
wire [10:0] bomb_x, bomb_y;
wire [1:0]  alien_anim_phase;

wire [10:0] projectile2_x, projectile2_y;
wire        projectile2_active;

wire        alien_exploding;
wire [10:0] alien_explode_x, alien_explode_y;
wire [3:0]  alien_explode_timer;
wire signed [1:0] diver_tilt;
wire signed [8:0] fleet_offset_x;
wire [2:0]  ship_tilt_frame;
wire [10:0] diver_ghost_x, diver_ghost_y;
wire [15:0] hit_flash_mask;
wire [1:0]  muzzle_flash_timer;
wire [2:0]  screen_shake_cnt;

// VFX Wires
wire [1:0]        muzzle_timer;
wire [2:0]        enemy_flash_timer;
wire [5:0]        flash_alien_id;
wire [1:0]        freeze_timer;
wire [3:0]        shake_timer;
wire signed [4:0] shake_dx;
wire signed [4:0] shake_dy;

wire [4*11-1:0]   exp_x_flat;
wire [4*11-1:0]   exp_y_flat;
wire [4*4-1:0]    exp_timer_flat;
wire [3:0]        exp_active;

wire [8*11-1:0]   debris_x_flat;
wire [8*11-1:0]   debris_y_flat;
wire [8*5-1:0]    debris_life_flat;
wire [7:0]        debris_active;

// 11x4 Shmup Gameplay Buses
wire [43:0]       form_alive;
wire [43:0]       form_diving_mask;
wire [2:0]        power_level;
wire [1:0]        wingmen_count;
wire [4:0]        rage_cnt;
wire [6:0]        laser_timer;
wire [6:0]        invuln_timer;
wire              respawn_invuln;

wire [15:0]       pbul_active;
wire [16*11-1:0]  pbul_x_flat;
wire [16*11-1:0]  pbul_y_flat;

wire [7:0]        hbul_active;
wire [8*11-1:0]   hbul_x_flat;
wire [8*11-1:0]   hbul_y_flat;

wire [9:0]        ebul_active;
wire [10*11-1:0]  ebul_x_flat;
wire [10*11-1:0]  ebul_y_flat;
wire [10*2-1:0]   ebul_type_flat;

wire [3:0]        div_active;
wire [4*6-1:0]    div_idx_flat;
wire [4*11-1:0]   div_x_flat;
wire [4*11-1:0]   div_y_flat;

wire [2:0]        ast_active;
wire [3*11-1:0]   ast_x_flat;
wire [3*11-1:0]   ast_y_flat;
wire [3*5-1:0]    ast_hp_flat;
wire [4:0]        ast_max_hp;

wire [1:0]        pu_active;
wire [2*11-1:0]   pu_x_flat;
wire [2*11-1:0]   pu_y_flat;
wire [2*2-1:0]    pu_type_flat;

wire [3:0]        imp_active;
wire [4*11-1:0]   imp_x_flat;
wire [4*11-1:0]   imp_y_flat;
wire [4*3-1:0]    imp_timer_flat;

wire [11*5-1:0]   row0_hp_flat;
wire [4:0]        row0_max_hp;

wire              boss_active;
wire [10:0]       boss_x;
wire [10:0]       boss_y;
wire [7:0]        boss_hp;
wire [7:0]        boss_max_hp;
wire [2:0]        boss_flash_timer;
wire [6:0]        boss_warn_timer;
wire [6:0]        boss_laser_timer;
wire              boss_enraged;

physics_engine physics_inst (
    .clk(clk),
    .rst(rst),
    .game_reset(game_reset),
    .frame_tick(frame_tick),
    .game_enable(game_enable),
    .move_left(move_left),
    .move_right(move_right),
    .move_up(move_up),
    .move_down(move_down),
    .fire(fire),
    .laser_trigger(laser_trigger),
    .hit_flag(hit_flag),
    .hit_target_id(hit_target_id),
    .fire_ready(fire_ready),
    .fire_accepted(fire_accepted),
    .score(score),
    .win(win),
    .game_over(game_over),
    .wave_num(wave_num),
    .ship_x(ship_x),
    .ship_y(ship_y),
    .projectile_x(projectile_x),
    .projectile_y(projectile_y),
    .projectile_active(projectile_active),
    .projectile2_x(projectile2_x),
    .projectile2_y(projectile2_y),
    .projectile2_active(projectile2_active),
    .alive_flags(alive_flags),
    .target_x_flat(target_x_flat),
    .target_y_flat(target_y_flat),

    .player_lives(player_lives),
    .player_exploding(player_exploding),
    .player_exp_phase(player_exp_phase),
    .diving_x(diving_x),
    .diving_y(diving_y),
    .diving_active(diving_active),
    .diving_id(diving_id),
    .bomb_active(bomb_active),
    .bomb_x(bomb_x),
    .bomb_y(bomb_y),
    .alien_anim_phase(alien_anim_phase),

    .alien_exploding(alien_exploding),
    .alien_explode_x(alien_explode_x),
    .alien_explode_y(alien_explode_y),
    .alien_explode_timer(alien_explode_timer),
    .diver_tilt(diver_tilt),
    .ship_tilt_frame(ship_tilt_frame),
    .hit_stop_active(),
    .diver_ghost_x(diver_ghost_x),
    .diver_ghost_y(diver_ghost_y),
    .hit_flash_mask(hit_flash_mask),
    .muzzle_flash_timer(muzzle_flash_timer),
    .screen_shake_cnt(screen_shake_cnt),

    // VFX ports
    .muzzle_timer(muzzle_timer),
    .enemy_flash_timer(enemy_flash_timer),
    .flash_alien_id(flash_alien_id),
    .freeze_timer(freeze_timer),
    .shake_timer(shake_timer),
    .shake_dx(shake_dx),
    .shake_dy(shake_dy),
    .exp_x_flat(exp_x_flat),
    .exp_y_flat(exp_y_flat),
    .exp_timer_flat(exp_timer_flat),
    .exp_active(exp_active),
    .debris_x_flat(debris_x_flat),
    .debris_y_flat(debris_y_flat),
    .debris_life_flat(debris_life_flat),
    .debris_active(debris_active),

    // 11x4 Shmup ports
    .form_alive(form_alive),
    .form_diving_mask(form_diving_mask),
    .power_level(power_level),
    .wingmen_count(wingmen_count),
    .rage_cnt(rage_cnt),
    .laser_timer(laser_timer),
    .invuln_timer(invuln_timer),
    .respawn_invuln(respawn_invuln),

    .pbul_active_out(pbul_active),
    .pbul_x_flat(pbul_x_flat),
    .pbul_y_flat(pbul_y_flat),

    .hbul_active_out(hbul_active),
    .hbul_x_flat(hbul_x_flat),
    .hbul_y_flat(hbul_y_flat),

    .ebul_active_out(ebul_active),
    .ebul_x_flat(ebul_x_flat),
    .ebul_y_flat(ebul_y_flat),
    .ebul_type_flat(ebul_type_flat),

    .div_active_out(div_active),
    .div_idx_flat(div_idx_flat),
    .div_x_flat(div_x_flat),
    .div_y_flat(div_y_flat),

    .ast_active_out(ast_active),
    .ast_x_flat(ast_x_flat),
    .ast_y_flat(ast_y_flat),
    .ast_hp_flat(ast_hp_flat),
    .ast_max_hp_out(ast_max_hp),

    .pu_active_out(pu_active),
    .pu_x_flat(pu_x_flat),
    .pu_y_flat(pu_y_flat),
    .pu_type_flat(pu_type_flat),

    .imp_active_out(imp_active),
    .imp_x_flat(imp_x_flat),
    .imp_y_flat(imp_y_flat),
    .imp_timer_flat(imp_timer_flat),

    .row0_hp_flat(row0_hp_flat),
    .row0_max_hp_out(row0_max_hp),

    .boss_active(boss_active),
    .boss_x(boss_x),
    .boss_y(boss_y),
    .boss_hp(boss_hp),
    .boss_max_hp(boss_max_hp),
    .boss_flash_timer(boss_flash_timer),
    .boss_warn_timer(boss_warn_timer),
    .boss_laser_timer(boss_laser_timer),
    .boss_enraged(boss_enraged),

    .sound_fire(sound_fire),
    .sound_hit(sound_hit),
    .sound_dive(sound_dive),
    .sound_player_die(sound_player_die),
    .sound_win(sound_win),
    .sound_game_over(sound_game_over),
    .sound_powerup(sound_powerup),
    .sound_laser(sound_laser),
    .fleet_offset_x_out(fleet_offset_x),
    .wave_entry_offset(wave_entry_offset)
);

color_mapper color_mapper_inst (
    .clk(clk),
    .rst(rst),
    .frame_tick(frame_tick),
    .pixel_active(pixel_active && !rst && !game_reset),
    .pixel_x(pixel_x),
    .pixel_y(pixel_y),
    .ship_x(ship_x),
    .ship_y(ship_y),
    .projectile_x(projectile_x),
    .projectile_y(projectile_y),
    .projectile_active(projectile_active),
    .projectile2_x(projectile2_x),
    .projectile2_y(projectile2_y),
    .projectile2_active(projectile2_active),
    .alive_flags(alive_flags),
    .target_x_flat(target_x_flat),
    .target_y_flat(target_y_flat),
    .score(score),
    .win(win),
    .game_over(game_over),
    .wave_num(wave_num),

    .player_lives(player_lives),
    .player_exploding(player_exploding),
    .player_exp_phase(player_exp_phase),
    .bomb_active(bomb_active),
    .bomb_x(bomb_x),
    .bomb_y(bomb_y),
    .alien_anim_phase(alien_anim_phase),
    .alien_exploding(alien_exploding),
    .alien_explode_x(alien_explode_x),
    .alien_explode_y(alien_explode_y),
    .alien_explode_timer(alien_explode_timer),
    .diving_active(diving_active),
    .diving_id(diving_id),
    .diver_tilt(diver_tilt),
    .diving_x(diving_x),
    .diving_y(diving_y),
    .fleet_offset_x(fleet_offset_x),
    .ship_tilt_frame(ship_tilt_frame),
    .diver_ghost_x(diver_ghost_x),
    .diver_ghost_y(diver_ghost_y),
    .hit_flash_mask(hit_flash_mask),
    .muzzle_flash_timer(muzzle_flash_timer),
    .screen_shake_cnt(screen_shake_cnt),

    // VFX connections
    .muzzle_timer(muzzle_timer),
    .enemy_flash_timer(enemy_flash_timer),
    .flash_alien_id(flash_alien_id),
    .freeze_timer(freeze_timer),
    .shake_timer(shake_timer),
    .shake_dx(shake_dx),
    .shake_dy(shake_dy),
    .exp_x_flat(exp_x_flat),
    .exp_y_flat(exp_y_flat),
    .exp_timer_flat(exp_timer_flat),
    .exp_active(exp_active),
    .debris_x_flat(debris_x_flat),
    .debris_y_flat(debris_y_flat),
    .debris_life_flat(debris_life_flat),
    .debris_active(debris_active),

    // 11x4 Shmup connections
    .form_alive(form_alive),
    .form_diving_mask(form_diving_mask),
    .power_level(power_level),
    .wingmen_count(wingmen_count),
    .rage_cnt(rage_cnt),
    .laser_timer(laser_timer),
    .invuln_timer(invuln_timer),
    .respawn_invuln(respawn_invuln),

    .pbul_active(pbul_active),
    .pbul_x_flat(pbul_x_flat),
    .pbul_y_flat(pbul_y_flat),

    .hbul_active(hbul_active),
    .hbul_x_flat(hbul_x_flat),
    .hbul_y_flat(hbul_y_flat),

    .ebul_active(ebul_active),
    .ebul_x_flat(ebul_x_flat),
    .ebul_y_flat(ebul_y_flat),
    .ebul_type_flat(ebul_type_flat),

    .div_active(div_active),
    .div_idx_flat(div_idx_flat),
    .div_x_flat(div_x_flat),
    .div_y_flat(div_y_flat),

    .ast_active(ast_active),
    .ast_x_flat(ast_x_flat),
    .ast_y_flat(ast_y_flat),
    .ast_hp_flat(ast_hp_flat),
    .ast_max_hp(ast_max_hp),

    .pu_active(pu_active),
    .pu_x_flat(pu_x_flat),
    .pu_y_flat(pu_y_flat),
    .pu_type_flat(pu_type_flat),

    .imp_active(imp_active),
    .imp_x_flat(imp_x_flat),
    .imp_y_flat(imp_y_flat),
    .imp_timer_flat(imp_timer_flat),

    .row0_hp_flat(row0_hp_flat),
    .row0_max_hp(row0_max_hp),

    .boss_active(boss_active),
    .boss_x(boss_x),
    .boss_y(boss_y),
    .boss_hp(boss_hp),
    .boss_max_hp(boss_max_hp),
    .boss_flash_timer(boss_flash_timer),
    .boss_warn_timer(boss_warn_timer),
    .boss_laser_timer(boss_laser_timer),
    .boss_enraged(boss_enraged),
    .wave_entry_offset(wave_entry_offset),

    .red(red),
    .green(green),
    .blue(blue)
);

endmodule
