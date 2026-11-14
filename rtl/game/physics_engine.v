`timescale 1ns / 1ps
`include "game_params.vh"

// =============================================================================
// Galaxian Steredenn Shmup Physics & Gameplay Engine
// Features:
//   1. 11x4 Enemy Formation (44 enemies) with per-enemy HP scaling per wave
//   2. Up to 4 Concurrent Galaxian Diving Attackers + Active Enemy Shooting
//   3. 4-Directional Player Movement + Automatic Firing (1..5 streams)
//   4. Power-Up Drops (Item P): Upgrades 1->5 shots, then up to 2 Wingmen
//   5. Wingmen firing Homing Projectiles (lower damage, auto-steering)
//   6. Overdrive Laser (Rage Bar: 20 kills -> 2s full-height beam on Center button)
//   7. 3 Falling Destructible Asteroids
//   8. Sequential Multi-Cycle Collision FSM (runs in ~70 clocks after frame_tick
//      for minimal LUT usage and high 720p Fmax margin)
// =============================================================================

(* keep_hierarchy = "yes" *)
module physics_engine #(
    parameter integer SHIP_STEP = `GAME_SHIP_SPEED,
    parameter integer PROJECTILE_STEP = `GAME_PROJECTILE_SPEED
)(
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

    output reg hit_flag,
    output reg [`GAME_TARGET_ID_WIDTH-1:0] hit_target_id,
    output wire fire_ready,
    output reg fire_accepted,
    output reg [`GAME_SCORE_WIDTH-1:0] score,
    output reg win,
    output reg game_over,
    output reg [6:0] wave_num,

    output reg [`GAME_COORD_WIDTH-1:0] ship_x,
    output reg [`GAME_COORD_WIDTH-1:0] ship_y,
    output reg [`GAME_COORD_WIDTH-1:0] projectile_x,
    output reg [`GAME_COORD_WIDTH-1:0] projectile_y,
    output reg projectile_active,
    output reg [`GAME_COORD_WIDTH-1:0] projectile2_x,
    output reg [`GAME_COORD_WIDTH-1:0] projectile2_y,
    output reg projectile2_active,
    output reg [`GAME_TARGET_COUNT-1:0] alive_flags,
    output wire [`GAME_TARGET_COUNT*`GAME_COORD_WIDTH-1:0] target_x_flat,
    output wire [`GAME_TARGET_COUNT*`GAME_COORD_WIDTH-1:0] target_y_flat,

    // Legacy Galaxian specific gameplay state (5 lives: 3-bit 0..5)
    output reg [2:0] player_lives,
    output reg player_exploding,
    output wire [1:0] player_exp_phase,
    output wire [10:0] diving_x,
    output wire [10:0] diving_y,
    output wire diving_active,
    output wire [3:0] diving_id,
    output wire bomb_active,
    output wire [10:0] bomb_x,
    output wire [10:0] bomb_y,
    output reg [1:0] alien_anim_phase,

    output reg alien_exploding,
    output reg [`GAME_COORD_WIDTH-1:0] alien_explode_x,
    output reg [`GAME_COORD_WIDTH-1:0] alien_explode_y,
    output reg [3:0] alien_explode_timer,
    output wire signed [1:0] diver_tilt,

    output reg  [2:0]  ship_tilt_frame,
    output wire        hit_stop_active,
    output reg  [10:0] diver_ghost_x,
    output reg  [10:0] diver_ghost_y,

    // VFX Registers & Signals (shake_dx/shake_dy registered once per frame to prevent sprite blur)
    output reg  [1:0]          muzzle_timer,
    output reg  [2:0]          enemy_flash_timer,
    output reg  [5:0]          flash_alien_id,
    output reg  [1:0]          freeze_timer,
    output reg  [3:0]          shake_timer,
    output reg  signed [4:0]   shake_dx,
    output reg  signed [4:0]   shake_dy,

    // 4 Explosion Slots
    output wire [4*11-1:0] exp_x_flat,
    output wire [4*11-1:0] exp_y_flat,
    output wire [4*4-1:0]  exp_timer_flat,
    output wire [3:0]      exp_active,

    // 8 Debris Particles
    output wire [8*11-1:0] debris_x_flat,
    output wire [8*11-1:0] debris_y_flat,
    output wire [8*5-1:0]  debris_life_flat,
    output wire [7:0]      debris_active,

    // --- NEW 11x4 SHMUP EXPORTS ---
    output reg  [43:0]         form_alive,
    output wire [43:0]         form_diving_mask,
    output reg  [2:0]          power_level,      // 1..5 streams
    output reg  [1:0]          wingmen_count,    // 0..2 wingmen
    output reg  [4:0]          rage_cnt,         // 0..20 kills
    output reg  [6:0]          laser_timer,      // 0..120 frames (2s beam)
    output reg  [6:0]          invuln_timer,     // 0..120 frames item shield
    output wire                respawn_invuln,   // 1 while true respawn god mode is active

    // 16 Player Main Bullets
    output wire [15:0]         pbul_active_out,
    output wire [16*11-1:0]    pbul_x_flat,
    output wire [16*11-1:0]    pbul_y_flat,

    // 8 Wingman Homing Bullets
    output wire [7:0]          hbul_active_out,
    output wire [8*11-1:0]     hbul_x_flat,
    output wire [8*11-1:0]     hbul_y_flat,

    // 10 Enemy Bullets (4 distinct types: Fireball, Sine-Wave, Sniper, Seeker)
    output wire [9:0]          ebul_active_out,
    output wire [10*11-1:0]    ebul_x_flat,
    output wire [10*11-1:0]    ebul_y_flat,
    output wire [10*2-1:0]     ebul_type_flat,

    // 4 Diving Aliens
    output wire [3:0]          div_active_out,
    output wire [4*6-1:0]      div_idx_flat,
    output wire [4*11-1:0]     div_x_flat,
    output wire [4*11-1:0]     div_y_flat,

    // 3 Falling Asteroids (64x64px) + HP for Mini HP Bar
    output wire [2:0]          ast_active_out,
    output wire [3*11-1:0]     ast_x_flat,
    output wire [3*11-1:0]     ast_y_flat,
    output wire [3*5-1:0]      ast_hp_flat,
    output wire [4:0]          ast_max_hp_out,

    // 2 Power-Up Drops (Item P / S / R)
    output wire [1:0]          pu_active_out,
    output wire [2*11-1:0]     pu_x_flat,
    output wire [2*11-1:0]     pu_y_flat,
    output wire [2*2-1:0]      pu_type_flat,

    // 4 Bullet Impact Effect Slots (Spark / Shockwave Ring on every bullet hit)
    output wire [3:0]          imp_active_out,
    output wire [4*11-1:0]     imp_x_flat,
    output wire [4*11-1:0]     imp_y_flat,
    output wire [4*3-1:0]      imp_timer_flat,

    // Row 0 Elite Enemy HP for Mini HP Bars
    output wire [11*5-1:0]     row0_hp_flat,
    output wire [4:0]          row0_max_hp_out,

    // Mothership Boss State (Every 5th Wave) + Special Moves & Enrage
    output reg                 boss_active,
    output reg  [10:0]         boss_x,
    output reg  [10:0]         boss_y,
    output reg  [7:0]          boss_hp,
    output reg  [7:0]          boss_max_hp,
    output reg  [2:0]          boss_flash_timer,
    output reg  [6:0]          boss_warn_timer,
    output reg  [6:0]          boss_laser_timer,
    output wire                boss_enraged,

    // Backward-compatibility aliases
    output wire [15:0] hit_flash_mask,
    output wire [1:0]  muzzle_flash_timer,
    output wire [2:0]  screen_shake_cnt,

    // Sound triggers
    output reg sound_fire,
    output reg sound_hit,
    output reg sound_dive,
    output reg sound_player_die,
    output reg sound_win,
    output reg sound_game_over,
    output reg sound_powerup,
    output wire sound_laser,

    output wire signed [8:0] fleet_offset_x_out,
    output reg  [7:0]        wave_entry_offset
);

// =============================================================================
// 1. Hardware 16-bit LFSR & Replicated Local Reset
// =============================================================================
(* max_fanout = 64 *) reg rst_q = 1'b1;
always @(posedge clk) begin
    rst_q <= rst | game_reset;
end

reg [15:0] lfsr;
always @(posedge clk) begin
    if (rst_q)
        lfsr <= 16'hACE1;
    else
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
end

// =============================================================================
// 2. 11x4 Formation Coordinates & Per-Enemy HP Memory
// =============================================================================
reg signed [8:0] fleet_offset_x;
assign fleet_offset_x_out = fleet_offset_x;
reg fleet_dir;
reg sway_div;
wire signed [11:0] fleet_offset_12 = {{3{fleet_offset_x[8]}}, fleet_offset_x};

reg [4:0] enemy_hp [0:43];

// Helper function to get formation X and Y from enemy ID (0..43)
function [3:0] get_col(input [5:0] id);
    case (id)
        6'd0,  6'd11, 6'd22, 6'd33: get_col = 4'd0;
        6'd1,  6'd12, 6'd23, 6'd34: get_col = 4'd1;
        6'd2,  6'd13, 6'd24, 6'd35: get_col = 4'd2;
        6'd3,  6'd14, 6'd25, 6'd36: get_col = 4'd3;
        6'd4,  6'd15, 6'd26, 6'd37: get_col = 4'd4;
        6'd5,  6'd16, 6'd27, 6'd38: get_col = 4'd5;
        6'd6,  6'd17, 6'd28, 6'd39: get_col = 4'd6;
        6'd7,  6'd18, 6'd29, 6'd40: get_col = 4'd7;
        6'd8,  6'd19, 6'd30, 6'd41: get_col = 4'd8;
        6'd9,  6'd20, 6'd31, 6'd42: get_col = 4'd9;
        6'd10, 6'd21, 6'd32, 6'd43: get_col = 4'd10;
        default:                    get_col = 4'd0;
    endcase
endfunction

function [1:0] get_row(input [5:0] id);
    begin
        if (id < 6'd11)      get_row = 2'd0;
        else if (id < 6'd22) get_row = 2'd1;
        else if (id < 6'd33) get_row = 2'd2;
        else                 get_row = 2'd3;
    end
endfunction

function [10:0] get_form_x(input [5:0] id, input signed [8:0] f_off);
    reg [3:0] c;
    reg signed [11:0] bx;
    begin
        c  = get_col(id);
        bx = $signed(12'd288) + $signed({1'b0, c, 6'b000000}) + {{3{f_off[8]}}, f_off};
        get_form_x = bx[10:0];
    end
endfunction

function [10:0] get_form_y(input [5:0] id);
    reg [1:0] r;
    reg [10:0] base_y;
    begin
        r = get_row(id);
        case (r)
            2'd0: base_y = 11'd72;
            2'd1: base_y = 11'd120;
            2'd2: base_y = 11'd168;
            default: base_y = 11'd216;
        endcase
        get_form_y = (base_y > {3'b000, wave_entry_offset} + 11'd16) ?
                     (base_y - {3'b000, wave_entry_offset}) : 11'd16;
    end
endfunction

function [4:0] calc_init_hp(input [1:0] r, input [6:0] w);
    reg [6:0] raw_hp;
    reg [6:0] w_minus_1;
    begin
        w_minus_1 = (w > 7'd0) ? (w - 7'd1) : 7'd0;
        case (r)
            2'd0: raw_hp = 7'd6 + (w_minus_1 << 1) + w_minus_1; // Boss
            2'd1: raw_hp = 7'd4 + (w_minus_1 << 1);             // Escort
            default: raw_hp = 7'd2 + (w_minus_1 << 1);          // Drone
        endcase
        calc_init_hp = (raw_hp > 7'd31) ? 5'd31 : raw_hp[4:0];
    end
endfunction

// Legacy 16-target flat exports (maps first 16 enemies for debug/compatibility)
genvar g;
generate
    for (g = 0; g < 16; g = g + 1) begin : GEN_LEGACY_TARGETS
        assign target_x_flat[(g+1)*11-1 : g*11] = get_form_x(g[5:0], fleet_offset_x);
        assign target_y_flat[(g+1)*11-1 : g*11] = get_form_y(g[5:0]);
    end
endgenerate

// =============================================================================
// 3. Entity Pools (Bullets, Divers, Asteroids, Power-Ups, Explosions, Debris)
// =============================================================================
// A. 16 Player Main Bullets
reg [15:0]        pbul_active;
reg [10:0]        pbul_x  [0:15];
reg [10:0]        pbul_y  [0:15];
reg signed [2:0]  pbul_vx [0:15];
assign pbul_active_out = pbul_active;

genvar pbi;
generate
    for (pbi = 0; pbi < 16; pbi = pbi + 1) begin : GEN_PBUL_FLAT
        assign pbul_x_flat[(pbi+1)*11-1 : pbi*11] = pbul_x[pbi];
        assign pbul_y_flat[(pbi+1)*11-1 : pbi*11] = pbul_y[pbi];
    end
endgenerate

// B. 8 Wingman Homing Bullets
reg [7:0]         hbul_active;
reg [10:0]        hbul_x  [0:7];
reg [10:0]        hbul_y  [0:7];
reg signed [3:0]  hbul_vx [0:7];
assign hbul_active_out = hbul_active;

genvar hbi;
generate
    for (hbi = 0; hbi < 8; hbi = hbi + 1) begin : GEN_HBUL_FLAT
        assign hbul_x_flat[(hbi+1)*11-1 : hbi*11] = hbul_x[hbi];
        assign hbul_y_flat[(hbi+1)*11-1 : hbi*11] = hbul_y[hbi];
    end
endgenerate

// C. 10 Enemy Bullets (with 2-bit type: 0=Fireball, 1=Wave, 2=Sniper, 3=Seeker)
reg [9:0]         ebul_active;
reg [10:0]        ebul_x    [0:9];
reg [10:0]        ebul_y    [0:9];
reg signed [3:0]  ebul_vx   [0:9];
reg [1:0]         ebul_type [0:9];
assign ebul_active_out = ebul_active;
assign boss_enraged    = boss_active && (boss_hp < {1'b0, boss_max_hp[7:1]});

genvar ebi;
generate
    for (ebi = 0; ebi < 10; ebi = ebi + 1) begin : GEN_EBUL_FLAT
        assign ebul_x_flat[(ebi+1)*11-1 : ebi*11]   = ebul_x[ebi];
        assign ebul_y_flat[(ebi+1)*11-1 : ebi*11]   = ebul_y[ebi];
        assign ebul_type_flat[(ebi+1)*2-1 : ebi*2]  = ebul_type[ebi];
    end
endgenerate

// D. 4 Diving Enemies
reg [3:0]         div_active;
reg [3:0]         div_returning;
reg [5:0]         div_idx [0:3];
reg [10:0]        div_x   [0:3];
reg [10:0]        div_y   [0:3];
reg [10:0]        div_base_x[0:3];
reg [10:0]        div_base_y[0:3];
reg signed [4:0]  div_vx  [0:3];
reg [5:0]         div_step[0:3];
assign div_active_out = div_active;

genvar dvi;
generate
    for (dvi = 0; dvi < 4; dvi = dvi + 1) begin : GEN_DIV_FLAT
        assign div_idx_flat[(dvi+1)*6-1  : dvi*6]  = div_idx[dvi];
        assign div_x_flat[(dvi+1)*11-1 : dvi*11] = div_x[dvi];
        assign div_y_flat[(dvi+1)*11-1 : dvi*11] = div_y[dvi];
    end
endgenerate

// Compute 44-bit mask of which formation aliens are currently diving
reg [43:0] r_form_diving_mask;
assign form_diving_mask = r_form_diving_mask;

// E. 3 Falling Asteroids (64x64px = 2x scale)
reg [2:0]         ast_active;
reg [10:0]        ast_x  [0:2];
reg [10:0]        ast_y  [0:2];
reg signed [2:0]  ast_vx [0:2];
reg [2:0]         ast_vy [0:2];
reg [4:0]         ast_hp [0:2];
assign ast_active_out = ast_active;
assign ast_max_hp_out = (wave_num >= 4'd4) ? 5'd14 : 5'd10;

genvar asi;
generate
    for (asi = 0; asi < 3; asi = asi + 1) begin : GEN_AST_FLAT
        assign ast_x_flat[(asi+1)*11-1 : asi*11] = ast_x[asi];
        assign ast_y_flat[(asi+1)*11-1 : asi*11] = ast_y[asi];
        assign ast_hp_flat[(asi+1)*5-1  : asi*5]  = ast_hp[asi];
    end
endgenerate

// Row 0 Elite Enemy HP export for Mini HP Bars
assign row0_max_hp_out = calc_init_hp(2'd0, wave_num);
genvar r0i;
generate
    for (r0i = 0; r0i < 11; r0i = r0i + 1) begin : GEN_ROW0_HP
        assign row0_hp_flat[(r0i+1)*5-1 : r0i*5] = enemy_hp[r0i];
    end
endgenerate

// F. 2 Power-Up Drops (Item P=0, S=1, R=2)
reg [1:0]         pu_active;
reg [10:0]        pu_x    [0:1];
reg [10:0]        pu_y    [0:1];
reg [1:0]         pu_type [0:1];
assign pu_active_out = pu_active;
assign pu_x_flat     = {pu_x[1], pu_x[0]};
assign pu_y_flat     = {pu_y[1], pu_y[0]};
assign pu_type_flat  = {pu_type[1], pu_type[0]};

// F2. 4 Bullet Impact Effect Slots (Spark / Shockwave Ring on every bullet hit)
reg [3:0]         r_imp_active;
reg [10:0]        r_imp_x     [0:3];
reg [10:0]        r_imp_y     [0:3];
reg [2:0]         r_imp_timer [0:3];
reg [1:0]         imp_alloc_ptr;
assign imp_active_out = r_imp_active;
assign imp_x_flat     = {r_imp_x[3], r_imp_x[2], r_imp_x[1], r_imp_x[0]};
assign imp_y_flat     = {r_imp_y[3], r_imp_y[2], r_imp_y[1], r_imp_y[0]};
assign imp_timer_flat = {r_imp_timer[3], r_imp_timer[2], r_imp_timer[1], r_imp_timer[0]};

assign sound_laser = (laser_timer > 7'd0) || (boss_laser_timer > 7'd0);

// G. 4 Explosion Slots & 8 Debris Particles
reg [10:0] r_exp_x [0:3];
reg [10:0] r_exp_y [0:3];
reg [3:0]  r_exp_timer [0:3];
reg [3:0]  r_exp_active;
reg [1:0]  exp_alloc_ptr;

assign exp_active     = r_exp_active;
assign exp_x_flat     = {r_exp_x[3], r_exp_x[2], r_exp_x[1], r_exp_x[0]};
assign exp_y_flat     = {r_exp_y[3], r_exp_y[2], r_exp_y[1], r_exp_y[0]};
assign exp_timer_flat = {r_exp_timer[3], r_exp_timer[2], r_exp_timer[1], r_exp_timer[0]};

reg [10:0]        r_debris_x [0:7];
reg [10:0]        r_debris_y [0:7];
reg signed [4:0]  r_debris_vx [0:7];
reg signed [4:0]  r_debris_vy [0:7];
reg [4:0]         r_debris_life [0:7];
reg [7:0]         r_debris_active;
assign debris_active = r_debris_active;

genvar gi;
generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : GEN_DEBRIS_FLAT
        assign debris_x_flat[(gi+1)*11-1 : gi*11]    = r_debris_x[gi];
        assign debris_y_flat[(gi+1)*11-1 : gi*11]    = r_debris_y[gi];
        assign debris_life_flat[(gi+1)*5-1 : gi*5] = r_debris_life[gi];
    end
endgenerate

wire signed [4:0] deb_init_vx [0:7];
wire signed [4:0] deb_init_vy [0:7];
assign deb_init_vx[0] =  5'sd3; assign deb_init_vy[0] =  5'sd0;
assign deb_init_vx[1] =  5'sd2; assign deb_init_vy[1] =  5'sd2;
assign deb_init_vx[2] =  5'sd0; assign deb_init_vy[2] =  5'sd3;
assign deb_init_vx[3] = -5'sd2; assign deb_init_vy[3] =  5'sd2;
assign deb_init_vx[4] = -5'sd3; assign deb_init_vy[4] =  5'sd0;
assign deb_init_vx[5] = -5'sd2; assign deb_init_vy[5] = -5'sd2;
assign deb_init_vx[6] =  5'sd0; assign deb_init_vy[6] = -5'sd3;
assign deb_init_vx[7] =  5'sd2; assign deb_init_vy[7] = -5'sd2;

// Legacy single-wire aliases
assign diving_active      = div_active[0];
assign diving_x           = div_x[0];
assign diving_y           = div_y[0];
assign diving_id          = div_idx[0][3:0];
assign bomb_active        = ebul_active[0];
assign bomb_x             = ebul_x[0];
assign bomb_y             = ebul_y[0];
assign diver_tilt         = (div_vx[0] > 5'sd1) ? 2'sd1 : (div_vx[0] < -5'sd1 ? -2'sd1 : 2'sd0);
assign hit_stop_active    = (freeze_timer > 2'd0);
assign muzzle_flash_timer = muzzle_timer;
assign screen_shake_cnt   = shake_timer[2:0];
assign hit_flash_mask     = (enemy_flash_timer > 3'd0) ? (16'b1 << flash_alien_id[3:0]) : 16'h0000;
assign fire_ready         = 1'b1;

reg [5:0] player_respawn_timer;
reg [6:0] respawn_invuln_timer;
assign player_exp_phase = player_respawn_timer[4:3];
assign respawn_invuln   = (respawn_invuln_timer > 7'd0);

// Fast nibble-wise BCD Adder for arcade scores
function [19:0] bcd_add;
    input [19:0] a;
    input [11:0] b;
    reg [4:0] d0, d1, d2, d3, d4;
    reg       c0, c1, c2, c3;
    begin
        d0 = {1'b0, a[3:0]} + {1'b0, b[3:0]};
        c0 = (d0 >= 5'd10);
        if (c0) d0 = d0 + 5'd6;

        d1 = {1'b0, a[7:4]} + {1'b0, b[7:4]} + {4'd0, c0};
        c1 = (d1 >= 5'd10);
        if (c1) d1 = d1 + 5'd6;

        d2 = {1'b0, a[11:8]} + {1'b0, b[11:8]} + {4'd0, c1};
        c2 = (d2 >= 5'd10);
        if (c2) d2 = d2 + 5'd6;

        d3 = {1'b0, a[15:12]} + {4'd0, c2};
        c3 = (d3 >= 5'd10);
        if (c3) d3 = d3 + 5'd6;

        d4 = {1'b0, a[19:16]} + {4'd0, c3};
        if (d4 >= 5'd10)
            bcd_add = 20'h99999;
        else
            bcd_add = {d4[3:0], d3[3:0], d2[3:0], d1[3:0], d0[3:0]};
    end
endfunction

// =============================================================================
// 4. Timers & Sequential Collision FSM State
// =============================================================================
reg [3:0] autofire_cnt;
reg [4:0] wing_fire_cnt;
reg [7:0] dive_cooldown;
reg [6:0] shoot_cooldown;
reg [6:0] ast_cooldown;
reg [5:0] diver_scan_ptr;
reg [5:0] shoot_scan_ptr;
reg [1:0] pbul_slot_idx;
reg [2:0] hbul_alloc_ptr;
reg [3:0] ebul_alloc_ptr;
reg [1:0] ast_alloc_ptr;
reg       pu_alloc_ptr;
reg [11:0] pending_pts;

reg [5:0] anim_timer;
reg [6:0] wave_timer;
reg       wave_transition;

localparam [2:0] C_IDLE   = 3'd0,
                 C_PBUL   = 3'd1,
                 C_HBUL   = 3'd2,
                 C_LASER  = 3'd3,
                 C_PLAYER = 3'd4;

reg [2:0]  c_state;
reg [5:0]  c_idx;
reg [1:0]  c_phase;
reg [1:0]  hit_kind_q;
reg [5:0]  hit_eid_q;
reg [10:0] kill_x_q;
reg [10:0] kill_y_q;
reg [10:0] cur_bul_x_q;
reg [10:0] cur_bul_y_q;
reg        cur_bul_en_q;
reg [4:0]  cur_bul_dmg_q;
reg        laser_hits_q;
reg        r_player_hit_q;

// Player Ship Hitbox and Center point shortcuts for collision and tracking (10x12 tight core)
wire [10:0] ship_hb_l     = ship_x + 11'd11;
wire [10:0] ship_hb_r     = ship_x + 11'd21;
wire [10:0] ship_hb_t     = ship_y + 11'd10;
wire [10:0] ship_hb_b     = ship_y + 11'd22;
wire [10:0] ship_center_x = ship_x + 11'd16;

// Shared combinational grid lookup for current bullet in Collision FSM (driven from registered cur_bul_*_q)
wire [10:0] cur_bul_x   = cur_bul_x_q;
wire [10:0] cur_bul_y   = cur_bul_y_q;
wire        cur_bul_en  = cur_bul_en_q;
wire [4:0]  cur_bul_dmg = cur_bul_dmg_q;

wire signed [11:0] form_start_x   = $signed(12'd288) + fleet_offset_12;
wire signed [11:0] bul_rel_fx     = $signed({1'b0, cur_bul_x}) + 12'sd3 - form_start_x;
wire [3:0]         bul_grid_col   = bul_rel_fx[9:6];
wire               bul_in_col     = (bul_rel_fx >= 12'sd0) && (bul_rel_fx < 12'sd704) && (bul_rel_fx[5:0] <= 6'd34);
wire [10:0]        cur_bul_form_y = cur_bul_y + {3'b000, wave_entry_offset};

reg [1:0] bul_grid_row;
reg       bul_in_row;
always @* begin
    bul_grid_row = 2'd0;
    bul_in_row   = 1'b0;
    if (cur_bul_y >= 11'd20) begin
        if (cur_bul_form_y >= 11'd64 && cur_bul_form_y <= 11'd104) begin
            bul_grid_row = 2'd0; bul_in_row = 1'b1;
        end else if (cur_bul_form_y >= 11'd112 && cur_bul_form_y <= 11'd152) begin
            bul_grid_row = 2'd1; bul_in_row = 1'b1;
        end else if (cur_bul_form_y >= 11'd160 && cur_bul_form_y <= 11'd200) begin
            bul_grid_row = 2'd2; bul_in_row = 1'b1;
        end else if (cur_bul_form_y >= 11'd208 && cur_bul_form_y <= 11'd248) begin
            bul_grid_row = 2'd3; bul_in_row = 1'b1;
        end
    end
end

wire [5:0] bul_form_id = (bul_grid_row == 2'd0) ? {2'b00, bul_grid_col} :
                         (bul_grid_row == 2'd1) ? ({2'b00, bul_grid_col} + 6'd11) :
                         (bul_grid_row == 2'd2) ? ({2'b00, bul_grid_col} + 6'd22) :
                                                  ({2'b00, bul_grid_col} + 6'd33);

// Pre-mux formation visibility by column (X-only) in parallel with Y row decode
wire [43:0] form_hit_vis = form_alive & ~r_form_diving_mask;
wire [3:0]  bul_col_vis_rows = (bul_grid_col < 4'd11) ?
    {form_hit_vis[6'd33 + {2'b00, bul_grid_col}],
     form_hit_vis[6'd22 + {2'b00, bul_grid_col}],
     form_hit_vis[6'd11 + {2'b00, bul_grid_col}],
     form_hit_vis[{2'b00, bul_grid_col}]} : 4'b0000;

wire bul_hits_form = cur_bul_en && bul_in_col && bul_in_row && bul_col_vis_rows[bul_grid_row];

wire signed [11:0] bul_form_hit_bx = $signed(12'd288) + $signed({1'b0, bul_grid_col, 6'b000000}) + fleet_offset_12;
wire [10:0]        bul_form_hit_x  = bul_form_hit_bx[10:0];
wire [10:0]        bul_form_base_y = (bul_grid_row == 2'd0) ? 11'd72 :
                                     (bul_grid_row == 2'd1) ? 11'd120 :
                                     (bul_grid_row == 2'd2) ? 11'd168 : 11'd216;
wire [10:0]        bul_form_hit_y  = (bul_form_base_y > {3'b000, wave_entry_offset} + 11'd16) ?
                                     (bul_form_base_y - {3'b000, wave_entry_offset}) : 11'd16;

// Check current bullet vs 4 divers
wire [3:0] bul_hits_div;
genvar bd;
generate
    for (bd = 0; bd < 4; bd = bd + 1) begin : GEN_BUL_DIV_HIT
        assign bul_hits_div[bd] = cur_bul_en && div_active[bd] &&
            (cur_bul_x + 11'd6 >= div_x[bd]) && (cur_bul_x <= div_x[bd] + 11'd32) &&
            (cur_bul_y <= div_y[bd] + 11'd30) && (cur_bul_y + 11'd16 >= div_y[bd]);
    end
endgenerate

// Check current bullet vs 3 asteroids (64x64px)
wire [2:0] bul_hits_ast;
genvar ba;
generate
    for (ba = 0; ba < 3; ba = ba + 1) begin : GEN_BUL_AST_HIT
        assign bul_hits_ast[ba] = cur_bul_en && ast_active[ba] &&
            (cur_bul_x + 11'd6 >= ast_x[ba]) && (cur_bul_x <= ast_x[ba] + 11'd64) &&
            (cur_bul_y <= ast_y[ba] + 11'd62) && (cur_bul_y + 11'd16 >= ast_y[ba]);
    end
endgenerate

// Check current bullet vs 64x64 Mothership Boss
wire bul_hits_boss = cur_bul_en && boss_active &&
    (cur_bul_x + 11'd6 >= boss_x) && (cur_bul_x <= boss_x + 11'd64) &&
    (cur_bul_y <= boss_y + 11'd62) && (cur_bul_y + 11'd16 >= boss_y);

// Homing target X selection (steers toward Boss center, else first active diver, else swaying formation center)
wire [10:0] homing_target_x = boss_active   ? (boss_x + 11'd32) :
                              div_active[0] ? div_x[0] :
                              div_active[1] ? div_x[1] :
                              div_active[2] ? div_x[2] :
                              div_active[3] ? div_x[3] :
                              (11'd624 + {{2{fleet_offset_x[8]}}, fleet_offset_x});

// =============================================================================
// 5. Main Synchronous Gameplay & Collision FSM
// =============================================================================
integer i, s_k;
reg [5:0] cand_id;
reg       found_cand;
reg [1:0] free_div_slot;
reg       has_free_div;
reg [5:0] hit_eid;
reg [10:0] kill_x, kill_y;
reg [10:0] ret_fx, ret_fy;
reg [11:0] add_pts;
reg        player_hit;
reg        boss_dir;
reg [5:0]  boss_shoot_cnt;
reg [1:0]  boss_skill_idx;
reg [6:0]  next_wave_calc;
reg        ebul_spawn_en;
reg [10:0] ebul_spawn_x;
reg [10:0] ebul_spawn_y;
reg signed [3:0] ebul_spawn_vx;
reg [1:0]  ebul_spawn_type;
reg signed [4:0] ebul_step_dx;
reg [3:0]        ebul_step_dy;

reg        ebul_spawn_en_q;
reg [10:0] ebul_spawn_x_q;
reg [10:0] ebul_spawn_y_q;
reg signed [3:0] ebul_spawn_vx_q;
reg [1:0]  ebul_spawn_type_q;

always @(posedge clk) begin
    if (rst_q) begin
        ship_x               <= `GAME_SHIP_START_X;
        ship_y               <= `GAME_SHIP_Y;
        projectile_x         <= 11'd0;
        projectile_y         <= 11'd0;
        projectile_active    <= 1'b0;
        projectile2_x        <= 11'd0;
        projectile2_y        <= 11'd0;
        projectile2_active   <= 1'b0;

        form_alive           <= {44{1'b1}};
        alive_flags          <= 16'hFFFF;
        for (i = 0; i < 44; i = i + 1) begin
            if (i < 11)      enemy_hp[i] <= 5'd6; // Row 0 Boss
            else if (i < 22) enemy_hp[i] <= 5'd4; // Row 1 Escort
            else             enemy_hp[i] <= 5'd2; // Row 2..3 Drone
        end

        score                <= 20'h00000;
        pending_pts          <= 12'h000;
        win                  <= 1'b0;
        game_over            <= 1'b0;
        wave_num             <= 7'd1;
        wave_transition      <= 1'b0;
        wave_timer           <= 7'd0;
        wave_entry_offset    <= 8'd192;
        hit_flag             <= 1'b0;
        hit_target_id        <= 4'd0;
        fire_accepted        <= 1'b0;

        player_lives         <= `PLAYER_INIT_LIVES;
        player_exploding     <= 1'b0;
        player_respawn_timer <= 6'd0;
        respawn_invuln_timer <= 7'd120; // 2s true god mode at start
        invuln_timer         <= 7'd0;   // Item shield only
        power_level          <= 3'd1;
        wingmen_count        <= 2'd0;
        rage_cnt             <= 5'd0;
        laser_timer          <= 7'd0;

        fleet_offset_x       <= 9'sd0;
        fleet_dir            <= 1'b1;
        sway_div             <= 1'b0;

        autofire_cnt         <= 4'd0;
        wing_fire_cnt        <= 5'd0;
        dive_cooldown        <= 8'd70;
        shoot_cooldown       <= 7'd50;
        ast_cooldown         <= 7'd80;
        diver_scan_ptr       <= 6'd0;
        shoot_scan_ptr       <= 6'd7;
        pbul_slot_idx        <= 2'd0;
        hbul_alloc_ptr       <= 3'd0;
        ebul_alloc_ptr       <= 4'd0;
        ast_alloc_ptr        <= 2'd0;
        pu_alloc_ptr         <= 1'b0;
        ebul_spawn_en_q      <= 1'b0;
        ebul_spawn_x_q       <= 11'd0;
        ebul_spawn_y_q       <= 11'd0;
        ebul_spawn_vx_q      <= 4'sd0;
        ebul_spawn_type_q    <= 2'd0;

        pbul_active          <= 16'h0000;
        hbul_active          <= 8'h00;
        ebul_active          <= 10'h000;
        div_active           <= 4'h0;
        div_returning        <= 4'h0;
        r_form_diving_mask   <= 44'd0;
        ast_active           <= 3'h0;
        pu_active            <= 2'h0;

        for (i = 0; i < 16; i = i + 1) begin
            pbul_x[i] <= 11'd0; pbul_y[i] <= 11'd0; pbul_vx[i] <= 3'sd0;
        end
        for (i = 0; i < 8; i = i + 1) begin
            hbul_x[i] <= 11'd0; hbul_y[i] <= 11'd0; hbul_vx[i] <= 4'sd0;
        end
        for (i = 0; i < 10; i = i + 1) begin
            ebul_x[i] <= 11'd0; ebul_y[i] <= 11'd0; ebul_vx[i] <= 4'sd0; ebul_type[i] <= 2'd0;
        end
        for (i = 0; i < 4; i = i + 1) begin
            div_idx[i] <= 6'd0; div_x[i] <= 11'd0; div_y[i] <= 11'd0;
            div_base_x[i] <= 11'd0; div_base_y[i] <= 11'd0;
            div_vx[i]  <= 5'sd0; div_step[i] <= 6'd0;
        end
        for (i = 0; i < 3; i = i + 1) begin
            ast_x[i] <= 11'd0; ast_y[i] <= 11'd0; ast_vx[i] <= 3'sd0;
            ast_vy[i] <= 3'd1; ast_hp[i] <= 5'd10;
        end
        for (i = 0; i < 2; i = i + 1) begin
            pu_x[i] <= 11'd0; pu_y[i] <= 11'd0; pu_type[i] <= 2'd0;
        end
        for (i = 0; i < 4; i = i + 1) begin
            r_imp_x[i] <= 11'd0; r_imp_y[i] <= 11'd0; r_imp_timer[i] <= 3'd0;
        end
        r_imp_active         <= 4'b0000;
        imp_alloc_ptr        <= 2'd0;

        boss_active          <= 1'b0;
        boss_x               <= 11'd608;
        boss_y               <= 11'd64;
        boss_hp              <= 8'd0;
        boss_max_hp          <= 8'd80;
        boss_flash_timer     <= 3'd0;
        boss_warn_timer      <= 7'd0;
        boss_laser_timer     <= 7'd0;
        boss_dir             <= 1'b1;
        boss_shoot_cnt       <= 6'd0;
        boss_skill_idx       <= 2'd0;

        alien_exploding      <= 1'b0;
        alien_explode_x      <= 11'd0;
        alien_explode_y      <= 11'd0;
        alien_explode_timer  <= 4'd0;
        ship_tilt_frame      <= 3'd2;
        diver_ghost_x        <= 11'd0;
        diver_ghost_y        <= 11'd0;

        muzzle_timer         <= 2'd0;
        enemy_flash_timer    <= 3'd0;
        flash_alien_id       <= 6'd0;
        freeze_timer         <= 2'd0;
        shake_timer          <= 4'd0;
        shake_dx             <= 5'sd0;
        shake_dy             <= 5'sd0;
        exp_alloc_ptr        <= 2'd0;
        r_exp_active         <= 4'b0000;
        r_debris_active      <= 8'h00;

        for (i = 0; i < 4; i = i + 1) begin
            r_exp_x[i] <= 11'd0; r_exp_y[i] <= 11'd0; r_exp_timer[i] <= 4'd0;
        end
        for (i = 0; i < 8; i = i + 1) begin
            r_debris_x[i] <= 11'd0; r_debris_y[i] <= 11'd0;
            r_debris_vx[i] <= 5'sd0; r_debris_vy[i] <= 5'sd0; r_debris_life[i] <= 5'd0;
        end

        alien_anim_phase     <= 2'd0;
        anim_timer           <= 6'd0;
        c_state              <= C_IDLE;
        c_idx                <= 6'd0;
        c_phase              <= 2'd0;
        hit_kind_q           <= 2'd0;
        hit_eid_q            <= 6'd0;
        kill_x_q             <= 11'd0;
        kill_y_q             <= 11'd0;
        cur_bul_x_q          <= 11'd0;
        cur_bul_y_q          <= 11'd0;
        cur_bul_en_q         <= 1'b0;
        cur_bul_dmg_q        <= 5'd2;
        laser_hits_q         <= 1'b0;
        r_player_hit_q       <= 1'b0;

        sound_fire           <= 1'b0;
        sound_hit            <= 1'b0;
        sound_dive           <= 1'b0;
        sound_player_die     <= 1'b0;
        sound_win            <= 1'b0;
        sound_game_over      <= 1'b0;
        sound_powerup        <= 1'b0;
    end else begin
        // Single-cycle pulse resets
        hit_flag         <= 1'b0;
        fire_accepted    <= 1'b0;
        sound_fire       <= 1'b0;
        sound_hit        <= 1'b0;
        sound_dive       <= 1'b0;
        sound_player_die <= 1'b0;
        sound_win        <= 1'b0;
        sound_game_over  <= 1'b0;
        sound_powerup    <= 1'b0;

        // Pipelined BCD Score Accumulator (breaks 24-level collision -> score path)
        if (pending_pts != 12'd0) begin
            score       <= bcd_add(score, pending_pts);
            pending_pts <= 12'd0;
        end

        // Keep legacy outputs mirrored
        alive_flags        <= form_alive[15:0] | {15'b0, (|form_alive[43:16]) | boss_active};
        projectile_active  <= pbul_active[0];
        projectile_x       <= pbul_x[0];
        projectile_y       <= pbul_y[0];
        projectile2_active <= pbul_active[3];
        projectile2_x      <= pbul_x[3];
        projectile2_y      <= pbul_y[3];

        // Trigger Overdrive Laser ONLY when Center button is tapped (laser_trigger) and Rage is full
        if (game_enable && !game_over && laser_trigger) begin
            fire_accepted <= 1'b1;
            if ((rage_cnt >= `RAGE_MAX) && (laser_timer == 7'd0)) begin
                laser_timer <= `LASER_FRAMES;
                rage_cnt    <= 5'd0;
                shake_timer <= 4'd10;
                sound_dive  <= 1'b1;
            end
        end

        // Background O(1) scan pointer advance & pipelined enemy bullet commit between frames
        if (!frame_tick) begin
            if (!form_alive[diver_scan_ptr] || r_form_diving_mask[diver_scan_ptr] ||
                (!div_active[0] && (div_step[0] > 6'd0) && (div_idx[0] == diver_scan_ptr)) ||
                (!div_active[1] && (div_step[1] > 6'd0) && (div_idx[1] == diver_scan_ptr)) ||
                (!div_active[2] && (div_step[2] > 6'd0) && (div_idx[2] == diver_scan_ptr)) ||
                (!div_active[3] && (div_step[3] > 6'd0) && (div_idx[3] == diver_scan_ptr)))
                diver_scan_ptr <= (diver_scan_ptr >= 6'd43) ? 6'd0 : (diver_scan_ptr + 6'd1);
            if (!form_alive[shoot_scan_ptr] || r_form_diving_mask[shoot_scan_ptr])
                shoot_scan_ptr <= (shoot_scan_ptr >= 6'd43) ? 6'd0 : (shoot_scan_ptr + 6'd1);
            if (ebul_active[ebul_alloc_ptr] && !ebul_spawn_en_q)
                ebul_alloc_ptr <= (ebul_alloc_ptr >= 4'd9) ? 4'd0 : (ebul_alloc_ptr + 4'd1);

            if (ebul_spawn_en_q) begin
                ebul_spawn_en_q             <= 1'b0;
                ebul_active[ebul_alloc_ptr] <= 1'b1;
                ebul_x[ebul_alloc_ptr]      <= ebul_spawn_x_q;
                ebul_y[ebul_alloc_ptr]      <= ebul_spawn_y_q;
                ebul_vx[ebul_alloc_ptr]     <= ebul_spawn_vx_q;
                ebul_type[ebul_alloc_ptr]   <= ebul_spawn_type_q;
                ebul_alloc_ptr              <= (ebul_alloc_ptr >= 4'd9) ? 4'd0 : (ebul_alloc_ptr + 4'd1);
            end
        end

        // =====================================================================
        // PHASE A: 60Hz Frame Update (Movement, Spawning, Timers)
        // =====================================================================
        if (frame_tick && game_enable && !game_over) begin
            if (muzzle_timer > 2'd0)      muzzle_timer      <= muzzle_timer - 2'd1;
            if (enemy_flash_timer > 3'd0)    enemy_flash_timer    <= enemy_flash_timer - 3'd1;
            if (boss_flash_timer > 3'd0)     boss_flash_timer     <= boss_flash_timer - 3'd1;
            if (invuln_timer > 7'd0)         invuln_timer         <= invuln_timer - 7'd1;
            if (respawn_invuln_timer > 7'd0) respawn_invuln_timer <= respawn_invuln_timer - 7'd1;

            // Update screen shake once per frame (prevents per-pixel LFSR jitter/blurring!)
            if (shake_timer > 4'd0) begin
                shake_timer <= shake_timer - 4'd1;
                shake_dx    <= lfsr[0] ? (shake_timer[3] ? 5'sd5 : 5'sd2) : (shake_timer[3] ? -5'sd5 : -5'sd2);
                shake_dy    <= lfsr[1] ? (shake_timer[3] ? 5'sd4 : 5'sd2) : (shake_timer[3] ? -5'sd4 : -5'sd2);
            end else begin
                shake_dx    <= 5'sd0;
                shake_dy    <= 5'sd0;
            end

            if (laser_timer > 7'd0) begin
                laser_timer <= laser_timer - 7'd1;
                if (shake_timer < 4'd3)
                    shake_timer <= 4'd3;
            end

            // Bullet Impact Effect slots progression
            for (i = 0; i < 4; i = i + 1) begin
                if (r_imp_active[i]) begin
                    if (r_imp_timer[i] <= 3'd1)
                        r_imp_active[i] <= 1'b0;
                    else
                        r_imp_timer[i] <= r_imp_timer[i] - 3'd1;
                end
            end

            // Explosion slots progression
            for (i = 0; i < 4; i = i + 1) begin
                if (r_exp_active[i]) begin
                    if (r_exp_timer[i] == 4'd15)
                        r_exp_active[i] <= 1'b0;
                    else
                        r_exp_timer[i] <= r_exp_timer[i] + 4'd1;
                end
            end

            // Debris particles progression
            for (i = 0; i < 8; i = i + 1) begin
                if (r_debris_active[i]) begin
                    if (r_debris_life[i] == 5'd0) begin
                        r_debris_active[i] <= 1'b0;
                    end else begin
                        r_debris_life[i] <= r_debris_life[i] - 5'd1;
                        r_debris_x[i]    <= r_debris_x[i] + {{6{r_debris_vx[i][4]}}, r_debris_vx[i]};
                        r_debris_y[i]    <= r_debris_y[i] + {{6{r_debris_vy[i][4]}}, r_debris_vy[i]};
                    end
                end
            end

            // Hit-Stop Freeze Check
            if (freeze_timer > 2'd0) begin
                freeze_timer <= freeze_timer - 2'd1;
            end else begin
                // 1. Animation Timer
                if (anim_timer >= 6'd15) begin
                    anim_timer       <= 6'd0;
                    alien_anim_phase <= alien_anim_phase + 2'd1;
                end else begin
                    anim_timer <= anim_timer + 6'd1;
                end

                // Smooth Top-Down Wave Entry Descent for Formation Aliens (3 px/frame)
                if (!wave_transition && (wave_entry_offset > 8'd0)) begin
                    if (wave_entry_offset > 8'd3)
                        wave_entry_offset <= wave_entry_offset - 8'd3;
                    else
                        wave_entry_offset <= 8'd0;
                end

                // 2. Gentle Formation Sway (1 px every 2 frames, +/- 48 px)
                sway_div <= ~sway_div;
                if (sway_div) begin
                    if (fleet_dir) begin
                        if (fleet_offset_x >= 9'sd48) fleet_dir <= 1'b0;
                        else fleet_offset_x <= fleet_offset_x + 9'sd1;
                    end else begin
                        if (fleet_offset_x <= -9'sd48) fleet_dir <= 1'b1;
                        else fleet_offset_x <= fleet_offset_x - 9'sd1;
                    end
                end

                // 3. 4-Way Player Movement & Respawn
                diver_ghost_x <= div_x[0];
                diver_ghost_y <= div_y[0];

                if (player_exploding) begin
                    ship_tilt_frame <= 3'd2;
                    if (player_respawn_timer >= 6'd40) begin
                        player_exploding     <= 1'b0;
                        player_respawn_timer <= 6'd0;
                        if (player_lives == 3'd0) begin
                            game_over       <= 1'b1;
                            sound_game_over <= 1'b1;
                        end else begin
                            ship_x               <= `GAME_SHIP_START_X;
                            ship_y               <= `GAME_SHIP_Y;
                            respawn_invuln_timer <= 7'd120; // 2s true respawn god mode!
                            invuln_timer         <= 7'd0;
                        end
                    end else begin
                        player_respawn_timer <= player_respawn_timer + 6'd1;
                    end
                end else if (player_lives > 3'd0) begin
                    // Horizontal movement
                    if (move_left && !move_right) begin
                        if (ship_tilt_frame > 3'd0) ship_tilt_frame <= ship_tilt_frame - 3'd1;
                        if (ship_x > `SHIP_MIN_X + SHIP_STEP) ship_x <= ship_x - SHIP_STEP;
                        else ship_x <= `SHIP_MIN_X;
                    end else if (move_right && !move_left) begin
                        if (ship_tilt_frame < 3'd4) ship_tilt_frame <= ship_tilt_frame + 3'd1;
                        if (ship_x + SHIP_STEP < `SHIP_MAX_X) ship_x <= ship_x + SHIP_STEP;
                        else ship_x <= `SHIP_MAX_X;
                    end else begin
                        if (ship_tilt_frame < 3'd2) ship_tilt_frame <= ship_tilt_frame + 3'd1;
                        else if (ship_tilt_frame > 3'd2) ship_tilt_frame <= ship_tilt_frame - 3'd1;
                    end

                    // Vertical movement (Up / Down)
                    if (move_up && !move_down) begin
                        if (ship_y > `SHIP_MIN_Y + SHIP_STEP) ship_y <= ship_y - SHIP_STEP;
                        else ship_y <= `SHIP_MIN_Y;
                    end else if (move_down && !move_up) begin
                        if (ship_y + SHIP_STEP < `SHIP_MAX_Y) ship_y <= ship_y + SHIP_STEP;
                        else ship_y <= `SHIP_MAX_Y;
                    end
                end

                // 4. Move Existing Player Main Bullets (full-screen travel up to Y=20 at 19 px/frame)
                for (i = 0; i < 16; i = i + 1) begin
                    if (pbul_active[i]) begin
                        if (pbul_y[i] <= 11'd20 || pbul_x[i] <= 11'd16 || pbul_x[i] >= 11'd1264) begin
                            pbul_active[i] <= 1'b0;
                        end else begin
                            pbul_y[i] <= pbul_y[i] - `GAME_PROJECTILE_SPEED;
                            pbul_x[i] <= pbul_x[i] + {{8{pbul_vx[i][2]}}, pbul_vx[i]};
                        end
                    end
                end

                // 5. Player Auto-Fire (5 streams x 3 dedicated slots per stream -> never overwrites in-flight bullets!)
                if (!player_exploding && player_lives > 3'd0) begin
                    if (autofire_cnt >= `AUTOFIRE_FRAMES - 1) begin
                        autofire_cnt  <= 4'd0;
                        muzzle_timer  <= 2'd2;
                        pbul_slot_idx <= (pbul_slot_idx >= 2'd2) ? 2'd0 : (pbul_slot_idx + 2'd1);

                        // Stream 0 -> slots 0..2 (active for all power_level 1..5)
                        pbul_active[{2'b00, pbul_slot_idx}] <= 1'b1;
                        pbul_x[{2'b00, pbul_slot_idx}]      <= ship_x + ((power_level == 3'd2) ? 11'd5 :
                                                                         (power_level == 3'd4) ? 11'd7 : 11'd13);
                        pbul_y[{2'b00, pbul_slot_idx}]      <= ship_y - 11'd10;
                        pbul_vx[{2'b00, pbul_slot_idx}]     <= 3'sd0;

                        // Stream 1 -> slots 3..5 (active for power_level >= 2)
                        if (power_level >= 3'd2) begin
                            pbul_active[4'd3 + {2'b00, pbul_slot_idx}] <= 1'b1;
                            pbul_x[4'd3 + {2'b00, pbul_slot_idx}]      <= ship_x + ((power_level == 3'd2) ? 11'd21 :
                                                                                    (power_level == 3'd3) ? 11'd3  :
                                                                                    (power_level == 3'd4) ? 11'd19 : 11'd5);
                            pbul_y[4'd3 + {2'b00, pbul_slot_idx}]      <= ship_y - 11'd8;
                            pbul_vx[4'd3 + {2'b00, pbul_slot_idx}]     <= (power_level == 3'd3 || power_level == 3'd5) ? -3'sd1 : 3'sd0;
                        end

                        // Stream 2 -> slots 6..8 (active for power_level >= 3)
                        if (power_level >= 3'd3) begin
                            pbul_active[4'd6 + {2'b00, pbul_slot_idx}] <= 1'b1;
                            pbul_x[4'd6 + {2'b00, pbul_slot_idx}]      <= ship_x + ((power_level == 3'd3) ? 11'd23 :
                                                                                    (power_level == 3'd4) ? 11'd1  : 11'd21);
                            pbul_y[4'd6 + {2'b00, pbul_slot_idx}]      <= ship_y - 11'd6;
                            pbul_vx[4'd6 + {2'b00, pbul_slot_idx}]     <= (power_level == 3'd4) ? -3'sd2 : 3'sd1;
                        end

                        // Stream 3 -> slots 9..11 (active for power_level >= 4)
                        if (power_level >= 3'd4) begin
                            pbul_active[4'd9 + {2'b00, pbul_slot_idx}] <= 1'b1;
                            pbul_x[4'd9 + {2'b00, pbul_slot_idx}]      <= ship_x + ((power_level == 3'd4) ? 11'd25 : 11'd0);
                            pbul_y[4'd9 + {2'b00, pbul_slot_idx}]      <= ship_y - 11'd4;
                            pbul_vx[4'd9 + {2'b00, pbul_slot_idx}]     <= (power_level == 3'd4) ? 3'sd2 : -3'sd2;
                        end

                        // Stream 4 -> slots 12..14 (active for power_level == 5)
                        if (power_level >= 3'd5) begin
                            pbul_active[4'd12 + {2'b00, pbul_slot_idx}] <= 1'b1;
                            pbul_x[4'd12 + {2'b00, pbul_slot_idx}]      <= ship_x + 11'd26;
                            pbul_y[4'd12 + {2'b00, pbul_slot_idx}]      <= ship_y - 11'd4;
                            pbul_vx[4'd12 + {2'b00, pbul_slot_idx}]     <= 3'sd2;
                        end
                    end else begin
                        autofire_cnt <= autofire_cnt + 4'd1;
                    end
                end

                // 6. Wingman Homing Bullets Movement & Spawning
                for (i = 0; i < 8; i = i + 1) begin
                    if (hbul_active[i]) begin
                        if (hbul_y[i] <= 11'd20 || hbul_x[i] <= 11'd16 || hbul_x[i] >= 11'd1264) begin
                            hbul_active[i] <= 1'b0;
                        end else begin
                            hbul_y[i] <= hbul_y[i] - `GAME_HOMING_SPEED;
                            hbul_x[i] <= hbul_x[i] + {{7{hbul_vx[i][3]}}, hbul_vx[i]};
                            if (hbul_x[i] + 11'd48 < homing_target_x && hbul_vx[i] < 4'sd6)
                                hbul_vx[i] <= hbul_vx[i] + 4'sd2;
                            else if (hbul_x[i] + 11'd8 < homing_target_x && hbul_vx[i] < 4'sd6)
                                hbul_vx[i] <= hbul_vx[i] + 4'sd1;
                            else if (hbul_x[i] > homing_target_x + 11'd48 && hbul_vx[i] > -4'sd6)
                                hbul_vx[i] <= hbul_vx[i] - 4'sd2;
                            else if (hbul_x[i] > homing_target_x + 11'd8 && hbul_vx[i] > -4'sd6)
                                hbul_vx[i] <= hbul_vx[i] - 4'sd1;
                        end
                    end
                end

                if (!player_exploding && player_lives > 3'd0 && wingmen_count > 2'd0) begin
                    if (wing_fire_cnt >= `WINGMAN_FIRE_FRAMES - 1) begin
                        wing_fire_cnt  <= 5'd0;
                        hbul_alloc_ptr <= hbul_alloc_ptr + 3'd1;
                        // Left Wingman shot -> slots 0..3
                        hbul_active[{1'b0, hbul_alloc_ptr[1:0]}] <= 1'b1;
                        hbul_x[{1'b0, hbul_alloc_ptr[1:0]}]      <= ship_x - 11'd22;
                        hbul_y[{1'b0, hbul_alloc_ptr[1:0]}]      <= ship_y + 11'd4;
                        hbul_vx[{1'b0, hbul_alloc_ptr[1:0]}]     <= -4'sd1;
                        if (wingmen_count >= 2'd2) begin
                            // Right Wingman shot -> slots 4..7
                            hbul_active[{1'b1, hbul_alloc_ptr[1:0]}] <= 1'b1;
                            hbul_x[{1'b1, hbul_alloc_ptr[1:0]}]      <= ship_x + 11'd48;
                            hbul_y[{1'b1, hbul_alloc_ptr[1:0]}]      <= ship_y + 11'd4;
                            hbul_vx[{1'b1, hbul_alloc_ptr[1:0]}]     <= 4'sd1;
                        end
                    end else begin
                        wing_fire_cnt <= wing_fire_cnt + 5'd1;
                    end
                end

                // 7. Endless Wave Progression & Mothership Boss Wave (every 5th Wave)
                if (wave_transition) begin
                    if (wave_timer <= 7'd1) begin
                        wave_transition   <= 1'b0;
                        next_wave_calc     = (wave_num >= 7'd99) ? 7'd1 : (wave_num + 7'd1);
                        wave_num          <= next_wave_calc;
                        wave_entry_offset <= 8'd192; // Descend from top of screen on every new wave!
                        div_active        <= 4'h0;
                        div_returning     <= 4'h0;
                        for (i = 0; i < 4; i = i + 1)
                            div_step[i] <= 6'd0;
                        r_form_diving_mask <= 44'd0;
                        fleet_offset_x    <= 9'sd0;
                        fleet_dir         <= 1'b1;
                        dive_cooldown     <= (next_wave_calc >= 7'd4) ? 8'd26 : (next_wave_calc >= 7'd2 ? 8'd36 : 8'd50);
                        if (next_wave_calc == 7'd5  || next_wave_calc == 7'd10 || next_wave_calc == 7'd15 ||
                            next_wave_calc == 7'd20 || next_wave_calc == 7'd25 || next_wave_calc == 7'd30 ||
                            next_wave_calc == 7'd35 || next_wave_calc == 7'd40 || next_wave_calc == 7'd45 ||
                            next_wave_calc == 7'd50 || next_wave_calc == 7'd55 || next_wave_calc == 7'd60 ||
                            next_wave_calc == 7'd65 || next_wave_calc == 7'd70 || next_wave_calc == 7'd75 ||
                            next_wave_calc == 7'd80 || next_wave_calc == 7'd85 || next_wave_calc == 7'd90 ||
                            next_wave_calc == 7'd95) begin
                            boss_active      <= 1'b1;
                            boss_x           <= 11'd608;
                            boss_y           <= 11'd16; // Boss also descends from top of screen!
                            boss_hp          <= (next_wave_calc > 7'd48) ? 8'd250 : (8'd60 + {next_wave_calc[5:0], 2'b00});
                            boss_max_hp      <= (next_wave_calc > 7'd48) ? 8'd250 : (8'd60 + {next_wave_calc[5:0], 2'b00});
                            boss_warn_timer  <= 7'd0;
                            boss_laser_timer <= 7'd0;
                            boss_dir         <= 1'b1;
                            boss_shoot_cnt   <= 6'd0;
                            boss_skill_idx   <= 2'd0;
                            // Top 2 rows cleared to make room for 64x64 Mothership Boss; bottom 2 rows act as escorts
                            form_alive       <= {22'h3FFFFF, 22'h000000};
                        end else begin
                            boss_active      <= 1'b0;
                            boss_warn_timer  <= 7'd0;
                            boss_laser_timer <= 7'd0;
                            form_alive       <= {44{1'b1}};
                        end
                        for (i = 0; i < 44; i = i + 1) begin
                            if (i < 11)      enemy_hp[i] <= calc_init_hp(2'd0, next_wave_calc);
                            else if (i < 22) enemy_hp[i] <= calc_init_hp(2'd1, next_wave_calc);
                            else             enemy_hp[i] <= calc_init_hp(2'd2, next_wave_calc);
                        end
                    end else begin
                        wave_timer <= wave_timer - 7'd1;
                    end
                end else if ((|form_alive == 1'b0) && !boss_active) begin
                    wave_transition <= 1'b1;
                    wave_timer      <= 7'd75;
                    sound_win       <= 1'b1;
                    ebul_active     <= 10'h000;
                end

                // 7B. Mothership Boss Movement & 4 Special Moves + Enrage Mode
                if (boss_active && !wave_transition) begin
                    if (boss_y < 11'd64) begin
                        boss_y <= (boss_y + 11'd2 >= 11'd64) ? 11'd64 : (boss_y + 11'd2);
                    end
                    // When charging Death-Ray telegraph or firing Mega Laser, Boss holds horizontal position steady
                    if (boss_warn_timer > 7'd0) begin
                        boss_warn_timer <= boss_warn_timer - 7'd1;
                        if (boss_warn_timer == 7'd1) begin
                            boss_laser_timer <= 7'd80; // 1.33s Mega Death-Ray
                            shake_timer      <= 4'd12;
                            sound_dive       <= 1'b1;
                        end
                    end else if (boss_laser_timer > 7'd0) begin
                        boss_laser_timer <= boss_laser_timer - 7'd1;
                        if (shake_timer < 4'd3)
                            shake_timer <= 4'd3;
                    end else begin
                        // Normal / Enraged Horizontal Sway
                        if (boss_dir) begin
                            if (boss_x >= 11'd920) boss_dir <= 1'b0;
                            else boss_x <= boss_x + (boss_enraged ? 11'd5 : 11'd3);
                        end else begin
                            if (boss_x <= 11'd296) boss_dir <= 1'b1;
                            else boss_x <= boss_x - (boss_enraged ? 11'd5 : 11'd3);
                        end

                        if (boss_shoot_cnt >= (boss_enraged ? 6'd38 : 6'd56)) begin
                            boss_shoot_cnt <= 6'd0;
                            boss_skill_idx <= boss_skill_idx + 2'd1;

                            case (boss_skill_idx)
                                // Move 0: 5-Way Curtain Spread (Fireballs + Wave Orbs -> fixed slots 0..4)
                                2'd0: begin
                                    for (s_k = 0; s_k < 5; s_k = s_k + 1) begin
                                        ebul_active[s_k] <= 1'b1;
                                        ebul_x[s_k]      <= boss_x + 11'd12 + (({7'd0, s_k[3:0]} << 3) + ({7'd0, s_k[3:0]} << 1));
                                        ebul_y[s_k]      <= boss_y + 11'd56;
                                        ebul_vx[s_k]     <= (s_k == 0) ? -4'sd4 :
                                                            (s_k == 1) ? -4'sd2 :
                                                            (s_k == 2) ?  4'sd0 :
                                                            (s_k == 3) ?  4'sd2 : 4'sd4;
                                        ebul_type[s_k]   <= (s_k[0]) ? `EBUL_TYPE_WAVE : `EBUL_TYPE_FIREBALL;
                                    end
                                end

                                // Move 1: Twin Viper Sine-Wave + Center Heavy Seeker Salvo (fixed slots 5..7)
                                2'd1: begin
                                    ebul_active[5] <= 1'b1;
                                    ebul_x[5]      <= boss_x + 11'd8;
                                    ebul_y[5]      <= boss_y + 11'd54;
                                    ebul_vx[5]     <= -4'sd1;
                                    ebul_type[5]   <= `EBUL_TYPE_WAVE;

                                    ebul_active[6] <= 1'b1;
                                    ebul_x[6]      <= boss_x + 11'd28;
                                    ebul_y[6]      <= boss_y + 11'd60;
                                    ebul_vx[6]     <= 4'sd0;
                                    ebul_type[6]   <= `EBUL_TYPE_SEEKER;

                                    ebul_active[7] <= 1'b1;
                                    ebul_x[7]      <= boss_x + 11'd50;
                                    ebul_y[7]      <= boss_y + 11'd54;
                                    ebul_vx[7]     <= 4'sd1;
                                    ebul_type[7]   <= `EBUL_TYPE_WAVE;
                                end

                                // Move 2: Boss Mega Death-Ray (Telegraph Warning Sight -> Full Column Beam)
                                2'd2: begin
                                    boss_warn_timer <= 7'd60; // 1.0s Red Laser Sight Telegraph with charging phase
                                    sound_dive      <= 1'b1;
                                end

                                // Move 3: High-Speed Sniper Twin Bolt + Enrage Meteor Call (fixed slots 8..9)
                                default: begin
                                    ebul_active[8] <= 1'b1;
                                    ebul_x[8]      <= boss_x + 11'd14;
                                    ebul_y[8]      <= boss_y + 11'd56;
                                    ebul_vx[8]     <= (ship_x > boss_x + 11'd32) ? 4'sd2 : -4'sd2;
                                    ebul_type[8]   <= `EBUL_TYPE_SNIPER;

                                    ebul_active[9] <= 1'b1;
                                    ebul_x[9]      <= boss_x + 11'd46;
                                    ebul_y[9]      <= boss_y + 11'd56;
                                    ebul_vx[9]     <= (ship_x > boss_x + 11'd32) ? 4'sd2 : -4'sd2;
                                    ebul_type[9]   <= `EBUL_TYPE_SNIPER;

                                    // If Boss is Enraged (<50% HP), summon an extra 64x64 Meteor!
                                    if (boss_enraged && !ast_active[ast_alloc_ptr]) begin
                                        ast_active[ast_alloc_ptr] <= 1'b1;
                                        ast_x[ast_alloc_ptr]      <= boss_x;
                                        ast_y[ast_alloc_ptr]      <= boss_y + 11'd32;
                                        ast_vx[ast_alloc_ptr]     <= (ship_x > boss_x) ? 3'sd1 : -3'sd1;
                                        ast_vy[ast_alloc_ptr]     <= 3'd3;
                                        ast_hp[ast_alloc_ptr]     <= 5'd12;
                                        ast_alloc_ptr             <= (ast_alloc_ptr >= 2'd2) ? 2'd0 : (ast_alloc_ptr + 2'd1);
                                    end
                                end
                            endcase
                        end else begin
                            boss_shoot_cnt <= boss_shoot_cnt + 6'd1;
                        end
                    end
                end

                // 8. Galaxian Diving Attackers (4 Concurrent Divers - O(1) pre-scanned pointer)
                has_free_div  = 1'b0;
                free_div_slot = 2'd0;
                for (i = 0; i < 4; i = i + 1) begin
                    if (!has_free_div && !div_active[i] && (!form_alive[div_idx[i]] || (div_step[i] == 6'd0))) begin
                        has_free_div  = 1'b1;
                        free_div_slot = i[1:0];
                    end
                end

                if (!wave_transition) begin
                    if (dive_cooldown > 8'd0) begin
                        dive_cooldown <= dive_cooldown - 8'd1;
                    end else if ((wave_entry_offset == 8'd0) && has_free_div &&
                                 form_alive[diver_scan_ptr] && !r_form_diving_mask[diver_scan_ptr] &&
                                 !((!div_active[0] && (div_step[0] > 6'd0) && (div_idx[0] == diver_scan_ptr)) ||
                                   (!div_active[1] && (div_step[1] > 6'd0) && (div_idx[1] == diver_scan_ptr)) ||
                                   (!div_active[2] && (div_step[2] > 6'd0) && (div_idx[2] == diver_scan_ptr)) ||
                                   (!div_active[3] && (div_step[3] > 6'd0) && (div_idx[3] == diver_scan_ptr)))) begin
                        ret_fx = get_form_x(diver_scan_ptr, fleet_offset_x);
                        ret_fy = get_form_y(diver_scan_ptr);
                        div_active[free_div_slot]    <= 1'b1;
                        div_returning[free_div_slot] <= 1'b0;
                        div_idx[free_div_slot]       <= diver_scan_ptr;
                        r_form_diving_mask[diver_scan_ptr] <= 1'b1;
                        div_x[free_div_slot]         <= ret_fx;
                        div_y[free_div_slot]         <= ret_fy;
                        div_base_x[free_div_slot]    <= 11'd288 + {1'b0, get_col(diver_scan_ptr), 6'b000000};
                        div_base_y[free_div_slot]    <= ret_fy;
                        div_vx[free_div_slot]        <= (ship_x > ret_fx) ? 5'sd2 : -5'sd2;
                        div_step[free_div_slot]      <= 6'd0;
                        dive_cooldown                <= (wave_num >= 4'd4) ? 8'd28 : (wave_num >= 4'd2 ? 8'd38 : 8'd75);
                        sound_dive                   <= 1'b1;
                        diver_scan_ptr               <= (diver_scan_ptr >= 6'd37) ? (diver_scan_ptr - 6'd37) : (diver_scan_ptr + 6'd7);
                    end
                end

                // Shared single-port Enemy Bullet Spawner for Divers & Formation
                ebul_spawn_en   = 1'b0;
                ebul_spawn_x    = 11'd0;
                ebul_spawn_y    = 11'd0;
                ebul_spawn_vx   = 4'sd0;
                ebul_spawn_type = `EBUL_TYPE_FIREBALL;

                // Update active divers & fire enemy bullets during swoop
                for (i = 0; i < 4; i = i + 1) begin
                    if (div_active[i]) begin
                        if (!div_returning[i]) begin
                            div_y[i]    <= div_y[i] + 11'd5;
                            div_step[i] <= div_step[i] + 6'd1;
                            if (div_step[i][2:0] == 3'b000) begin
                                if (div_x[i] < ship_x && div_vx[i] < 5'sd4)
                                    div_vx[i] <= div_vx[i] + 5'sd1;
                                else if (div_x[i] > ship_x && div_vx[i] > -5'sd4)
                                    div_vx[i] <= div_vx[i] - 5'sd1;
                            end
                            if (div_vx[i][4] && (div_x[i] <= 11'd16))
                                div_x[i] <= 11'd16;
                            else if (!div_vx[i][4] && (div_x[i] >= 11'd1232))
                                div_x[i] <= 11'd1232;
                            else
                                div_x[i] <= div_x[i] + {{6{div_vx[i][4]}}, div_vx[i]};

                            // Diver fires high-speed Sniper Bolt (at Y=190) or Sine-Wave Orb (at Y=310)
                            if ((div_y[i] == 11'd190) || (div_y[i] == 11'd310)) begin
                                ebul_spawn_en   = 1'b1;
                                ebul_spawn_x    = div_x[i] + 11'd12;
                                ebul_spawn_y    = div_y[i] + 11'd24;
                                if (wave_num == 7'd1) begin
                                    // Wave 1: Only basic fireball, no fast snipers
                                    ebul_spawn_type = `EBUL_TYPE_FIREBALL;
                                    ebul_spawn_vx   = 4'sd0;
                                end else if (div_y[i] == 11'd190) begin
                                    ebul_spawn_type = `EBUL_TYPE_SNIPER;
                                    if (ship_x > div_x[i] + 11'd120)
                                        ebul_spawn_vx = 4'sd3;
                                    else if (ship_x > div_x[i] + 11'd40)
                                        ebul_spawn_vx = 4'sd2;
                                    else if (ship_x + 11'd120 < div_x[i])
                                        ebul_spawn_vx = -4'sd3;
                                    else if (ship_x + 11'd40 < div_x[i])
                                        ebul_spawn_vx = -4'sd2;
                                    else
                                        ebul_spawn_vx = 4'sd0;
                                end else begin
                                    ebul_spawn_type = `EBUL_TYPE_WAVE;
                                    ebul_spawn_vx   = (div_x[i] < ship_x) ? 4'sd1 : -4'sd1;
                                end
                            end

                            if (div_y[i] >= 11'd700) begin
                                div_returning[i] <= 1'b1;
                                div_y[i]         <= 11'd16; // Re-enter from top of screen
                            end
                        end else begin
                            // Smoothly fly down from top of screen and steer horizontally back into formation slot
                            ret_fx = div_base_x[i] + {{2{fleet_offset_x[8]}}, fleet_offset_x};
                            ret_fy = div_base_y[i];
                            if (div_y[i] + 11'd4 < ret_fy)
                                div_y[i] <= div_y[i] + 11'd4;
                            else
                                div_y[i] <= ret_fy;

                            if (div_x[i] + 11'd5 < ret_fx)
                                div_x[i] <= div_x[i] + 11'd5;
                            else if (div_x[i] > ret_fx + 11'd5)
                                div_x[i] <= div_x[i] - 11'd5;
                            else
                                div_x[i] <= ret_fx;

                            if ((div_y[i] + 11'd4 >= ret_fy) &&
                                (div_x[i] + 11'd6 >= ret_fx) &&
                                (div_x[i] <= ret_fx + 11'd6)) begin
                                div_active[i]                  <= 1'b0;
                                div_returning[i]               <= 1'b0;
                                div_step[i]                    <= 6'd63; // ~2.1s post-return rest (126 frames)
                                r_form_diving_mask[div_idx[i]] <= 1'b0;
                                if (dive_cooldown < 8'd50)
                                    dive_cooldown <= 8'd50;              // ~0.83s breather after diver returns
                            end
                        end
                    end else if (div_step[i] > 6'd0) begin
                        if (!form_alive[div_idx[i]])
                            div_step[i] <= 6'd0;
                        else if (autofire_cnt[0])
                            div_step[i] <= div_step[i] - 6'd1;
                    end
                end

                // 9. Formation Alien Shooting (O(1) pre-scanned pointer)
                if (!wave_transition) begin
                    if (shoot_cooldown > 7'd0) begin
                        shoot_cooldown <= shoot_cooldown - 7'd1;
                    end else if ((wave_entry_offset <= 8'd36) && !ebul_spawn_en && form_alive[shoot_scan_ptr] && !r_form_diving_mask[shoot_scan_ptr]) begin
                        ret_fx          = get_form_x(shoot_scan_ptr, fleet_offset_x);
                        ret_fy          = get_form_y(shoot_scan_ptr);
                        ebul_spawn_en   = 1'b1;
                        ebul_spawn_x    = ret_fx + 11'd12;
                        ebul_spawn_y    = ret_fy + 11'd24;
                        if (wave_num == 7'd1) begin
                            // Wave 1: Purely basic Fireballs to introduce moving & dodging safely
                            ebul_spawn_type = `EBUL_TYPE_FIREBALL;
                            ebul_spawn_vx   = (ship_x > ret_fx + 11'd80) ? 4'sd1 :
                                              (ship_x + 11'd80 < ret_fx) ? -4'sd1 : 4'sd0;
                        end else if (shoot_scan_ptr < 6'd11) begin
                            ebul_spawn_type = (wave_num == 7'd2) ? `EBUL_TYPE_WAVE : (lfsr[0] ? `EBUL_TYPE_SEEKER : `EBUL_TYPE_SNIPER);
                            if (ebul_spawn_type == `EBUL_TYPE_SNIPER) begin // SNIPER aimed trajectory
                                if (ship_x > ret_fx + 11'd180)
                                    ebul_spawn_vx = 4'sd3;
                                else if (ship_x > ret_fx + 11'd70)
                                    ebul_spawn_vx = 4'sd2;
                                else if (ship_x > ret_fx + 11'd20)
                                    ebul_spawn_vx = 4'sd1;
                                else if (ship_x + 11'd180 < ret_fx)
                                    ebul_spawn_vx = -4'sd3;
                                else if (ship_x + 11'd70 < ret_fx)
                                    ebul_spawn_vx = -4'sd2;
                                else if (ship_x + 11'd20 < ret_fx)
                                    ebul_spawn_vx = -4'sd1;
                                else
                                    ebul_spawn_vx = 4'sd0;
                            end else begin
                                ebul_spawn_vx = (ship_x > ret_fx + 11'd60) ? 4'sd1 :
                                                (ship_x + 11'd60 < ret_fx) ? -4'sd1 : 4'sd0;
                            end
                        end else if (shoot_scan_ptr < 6'd22) begin
                            ebul_spawn_type = `EBUL_TYPE_WAVE;
                            ebul_spawn_vx   = (shoot_scan_ptr[0]) ? 4'sd1 : -4'sd1;
                        end else begin
                            ebul_spawn_type = `EBUL_TYPE_FIREBALL;
                            ebul_spawn_vx   = (ship_x > ret_fx + 11'd60) ? 4'sd1 :
                                              (ship_x + 11'd60 < ret_fx) ? -4'sd1 : 4'sd0;
                        end

                        shoot_cooldown <= (wave_num >= 4'd4) ? 7'd22 : (wave_num >= 4'd2 ? 7'd30 : 7'd45);
                        shoot_scan_ptr <= (shoot_scan_ptr >= 6'd35) ? (shoot_scan_ptr - 6'd35) : (shoot_scan_ptr + 6'd9);
                    end
                end

                // Move Enemy Bullets according to their 4 distinct types (Single adder per bullet)
                for (i = 0; i < 10; i = i + 1) begin
                    if (ebul_active[i]) begin
                        if (ebul_y[i] >= 11'd695 || ebul_x[i] <= 11'd16 || ebul_x[i] >= 11'd1264) begin
                            ebul_active[i] <= 1'b0;
                        end else begin
                            case (ebul_type[i])
                                `EBUL_TYPE_WAVE: begin
                                    ebul_step_dy = 4'd4;
                                    case (ebul_y[i][6:4])
                                        3'd0: ebul_step_dx = ebul_vx[i][3] ? -5'sd3 : 5'sd3;
                                        3'd1: ebul_step_dx = ebul_vx[i][3] ? -5'sd5 : 5'sd5;
                                        3'd2: ebul_step_dx = ebul_vx[i][3] ? -5'sd5 : 5'sd5;
                                        3'd3: ebul_step_dx = ebul_vx[i][3] ? -5'sd3 : 5'sd3;
                                        3'd4: ebul_step_dx = ebul_vx[i][3] ? 5'sd3 : -5'sd3;
                                        3'd5: ebul_step_dx = ebul_vx[i][3] ? 5'sd5 : -5'sd5;
                                        3'd6: ebul_step_dx = ebul_vx[i][3] ? 5'sd5 : -5'sd5;
                                        default: ebul_step_dx = ebul_vx[i][3] ? 5'sd3 : -5'sd3;
                                    endcase
                                end
                                `EBUL_TYPE_SNIPER: begin
                                    ebul_step_dy = 4'd8;
                                    ebul_step_dx = {{1{ebul_vx[i][3]}}, ebul_vx[i]};
                                end
                                `EBUL_TYPE_SEEKER: begin
                                    ebul_step_dy = 4'd4;
                                    if (ebul_x[i] + 11'd72 < ship_center_x)
                                        ebul_step_dx = 5'sd3;
                                    else if (ebul_x[i] + 11'd24 < ship_center_x)
                                        ebul_step_dx = 5'sd2;
                                    else if (ebul_x[i] + 11'd8 < ship_center_x)
                                        ebul_step_dx = 5'sd1;
                                    else if (ebul_x[i] > ship_center_x + 11'd64)
                                        ebul_step_dx = -5'sd3;
                                    else if (ebul_x[i] > ship_center_x + 11'd16)
                                        ebul_step_dx = -5'sd2;
                                    else if (ebul_x[i] > ship_center_x)
                                        ebul_step_dx = -5'sd1;
                                    else
                                        ebul_step_dx = 5'sd0;
                                end
                                default: begin // EBUL_TYPE_FIREBALL
                                    ebul_step_dy = 4'd5;
                                    ebul_step_dx = {{1{ebul_vx[i][3]}}, ebul_vx[i]};
                                end
                            endcase
                            ebul_y[i] <= ebul_y[i] + {7'd0, ebul_step_dy};
                            ebul_x[i] <= ebul_x[i] + {{6{ebul_step_dx[4]}}, ebul_step_dx};
                        end
                    end
                end

                // Latch newly spawned Diver/Formation bullet to commit on next cycle
                ebul_spawn_en_q   <= ebul_spawn_en;
                ebul_spawn_x_q    <= ebul_spawn_x;
                ebul_spawn_y_q    <= ebul_spawn_y;
                ebul_spawn_vx_q   <= ebul_spawn_vx;
                ebul_spawn_type_q <= ebul_spawn_type;

                // 10. Falling Destructible 64x64 Asteroids (3 Slots)
                if (ast_cooldown > 7'd0) begin
                    ast_cooldown <= ast_cooldown - 7'd1;
                end else begin
                    if (!ast_active[ast_alloc_ptr]) begin
                        ast_active[ast_alloc_ptr] <= 1'b1;
                        ast_x[ast_alloc_ptr]      <= 11'd120 + {1'b0, lfsr[9:0]};
                        ast_y[ast_alloc_ptr]      <= 11'd44;
                        ast_vx[ast_alloc_ptr]     <= lfsr[11] ? (lfsr[10] ? 3'sd1 : -3'sd1) : 3'sd0;
                        ast_vy[ast_alloc_ptr]     <= lfsr[12] ? 3'd2 : 3'd3;
                        ast_hp[ast_alloc_ptr]     <= (wave_num >= 4'd4) ? 5'd14 : 5'd10;
                        ast_alloc_ptr             <= (ast_alloc_ptr >= 2'd2) ? 2'd0 : (ast_alloc_ptr + 2'd1);
                    end
                    ast_cooldown <= 7'd75;
                end

                for (i = 0; i < 3; i = i + 1) begin
                    if (ast_active[i]) begin
                        if (ast_y[i] >= 11'd695 || ast_x[i] <= 11'd16 || ast_x[i] >= 11'd1216) begin
                            ast_active[i] <= 1'b0;
                        end else begin
                            ast_y[i] <= ast_y[i] + {8'd0, ast_vy[i]};
                            ast_x[i] <= ast_x[i] + {{8{ast_vx[i][2]}}, ast_vx[i]};
                        end
                    end
                end

                // 11. Falling Power-Up Items (2 Slots)
                for (i = 0; i < 2; i = i + 1) begin
                    if (pu_active[i]) begin
                        if (pu_y[i] >= 11'd695)
                            pu_active[i] <= 1'b0;
                        else
                            pu_y[i] <= pu_y[i] + 11'd2;
                    end
                end

                // Launch Sequential Collision FSM for this frame!
                c_state <= C_PBUL;
                c_idx   <= 6'd0;
                c_phase <= 2'd0;
            end
        end

        // =====================================================================
        // PHASE B: Multi-Cycle Sequential Collision FSM (Pipelined 3-Phase Hit Processing)
        // =====================================================================
        else if (c_state != C_IDLE) begin
            case (c_state)
                // -------------------------------------------------------------
                // Step 1 & 2: Player Main Bullets (0..15) & Homing Bullets (0..7)
                // -------------------------------------------------------------
                C_PBUL, C_HBUL: begin
                    if (c_phase == 2'd0) begin
                        // PHASE 0: Fetch bullet coordinates & active state into pipeline registers
                        cur_bul_x_q   <= (c_state == C_PBUL) ? pbul_x[c_idx[3:0]]      : hbul_x[c_idx[2:0]];
                        cur_bul_y_q   <= (c_state == C_PBUL) ? pbul_y[c_idx[3:0]]      : hbul_y[c_idx[2:0]];
                        cur_bul_en_q  <= (c_state == C_PBUL) ? pbul_active[c_idx[3:0]] : hbul_active[c_idx[2:0]];
                        cur_bul_dmg_q <= (c_state == C_PBUL) ? 5'd2                    : 5'd1;

                        if ((c_state == C_PBUL) ? pbul_active[c_idx[3:0]] : hbul_active[c_idx[2:0]]) begin
                            c_phase <= 2'd1;
                        end else begin
                            // Inactive bullet: skip straight to next bullet in 1 cycle
                            if (c_state == C_PBUL) begin
                                if (c_idx >= 6'd15) begin
                                    c_state <= C_HBUL;
                                    c_idx   <= 6'd0;
                                end else begin
                                    c_idx <= c_idx + 6'd1;
                                end
                            end else begin
                                if (c_idx >= 6'd7) begin
                                    if (laser_timer > 7'd0 && (laser_timer[1:0] == 2'b00)) begin
                                        c_state <= C_LASER;
                                        c_idx   <= 6'd0;
                                    end else begin
                                        c_state <= C_PLAYER;
                                        c_idx   <= 6'd0;
                                    end
                                end else begin
                                    c_idx <= c_idx + 6'd1;
                                end
                            end
                        end
                    end else if (c_phase == 2'd1) begin
                        // PHASE 1: Detect Hit from Registered Bullet & Latch Target Coordinates/ID
                        if ((|bul_hits_ast) || bul_hits_boss || (|bul_hits_div) || bul_hits_form) begin
                            if (c_state == C_PBUL) pbul_active[c_idx[3:0]] <= 1'b0;
                            else                   hbul_active[c_idx[2:0]] <= 1'b0;

                            c_phase <= 2'd2;

                            if (|bul_hits_ast) begin
                                hit_kind_q <= 2'd1;
                                hit_eid_q  <= bul_hits_ast[0] ? 6'd0 : (bul_hits_ast[1] ? 6'd1 : 6'd2);
                                kill_x_q   <= bul_hits_ast[0] ? ast_x[0] : (bul_hits_ast[1] ? ast_x[1] : ast_x[2]);
                                kill_y_q   <= bul_hits_ast[0] ? ast_y[0] : (bul_hits_ast[1] ? ast_y[1] : ast_y[2]);
                            end else if (bul_hits_boss) begin
                                hit_kind_q <= 2'd2;
                                hit_eid_q  <= 6'd0;
                                kill_x_q   <= boss_x;
                                kill_y_q   <= boss_y;
                            end else begin
                                hit_kind_q <= 2'd3;
                                if (bul_hits_div[0]) begin
                                    hit_eid_q <= div_idx[0]; kill_x_q <= div_x[0]; kill_y_q <= div_y[0];
                                end else if (bul_hits_div[1]) begin
                                    hit_eid_q <= div_idx[1]; kill_x_q <= div_x[1]; kill_y_q <= div_y[1];
                                end else if (bul_hits_div[2]) begin
                                    hit_eid_q <= div_idx[2]; kill_x_q <= div_x[2]; kill_y_q <= div_y[2];
                                end else if (bul_hits_div[3]) begin
                                    hit_eid_q <= div_idx[3]; kill_x_q <= div_x[3]; kill_y_q <= div_y[3];
                                end else begin
                                    hit_eid_q <= bul_form_id;
                                    kill_x_q  <= bul_form_hit_x;
                                    kill_y_q  <= bul_form_hit_y;
                                end
                            end
                        end else begin
                            // No hit: advance bullet index and return to Phase 0
                            c_phase <= 2'd0;
                            if (c_state == C_PBUL) begin
                                if (c_idx >= 6'd15) begin
                                    c_state <= C_HBUL;
                                    c_idx   <= 6'd0;
                                end else begin
                                    c_idx <= c_idx + 6'd1;
                                end
                            end else begin
                                if (c_idx >= 6'd7) begin
                                    if (laser_timer > 7'd0 && (laser_timer[1:0] == 2'b00)) begin
                                        c_state <= C_LASER;
                                        c_idx   <= 6'd0;
                                    end else begin
                                        c_state <= C_PLAYER;
                                        c_idx   <= 6'd0;
                                    end
                                end else begin
                                    c_idx <= c_idx + 6'd1;
                                end
                            end
                        end
                    end else begin
                        // PHASE 2: Spawn Impact Ring & Apply Damage, Explosions, Debris & Queued Score
                        c_phase <= 2'd0;

                        // Spawn Bullet Impact Ring right at registered contact point!
                        r_imp_active[imp_alloc_ptr] <= 1'b1;
                        r_imp_x[imp_alloc_ptr]      <= (cur_bul_x_q > 11'd6) ? (cur_bul_x_q - 11'd6) : 11'd0;
                        r_imp_y[imp_alloc_ptr]      <= (cur_bul_y_q > 11'd6) ? (cur_bul_y_q - 11'd6) : 11'd0;
                        r_imp_timer[imp_alloc_ptr]  <= 3'd6;
                        imp_alloc_ptr               <= imp_alloc_ptr + 2'd1;

                        if (hit_kind_q == 2'd1) begin
                            // 1. Asteroid Hit Resolution
                            if (ast_hp[hit_eid_q[1:0]] <= cur_bul_dmg_q) begin
                                ast_active[hit_eid_q[1:0]]  <= 1'b0;
                                r_exp_active[exp_alloc_ptr] <= 1'b1;
                                r_exp_x[exp_alloc_ptr]      <= kill_x_q + 11'd16;
                                r_exp_y[exp_alloc_ptr]      <= kill_y_q + 11'd16;
                                r_exp_timer[exp_alloc_ptr]  <= 4'd0;
                                exp_alloc_ptr               <= exp_alloc_ptr + 2'd1;
                                pending_pts                 <= 12'h150;
                                shake_timer                 <= 4'd8;
                                sound_hit                   <= 1'b1;
                                if (lfsr[0] && !pu_active[pu_alloc_ptr]) begin
                                    pu_active[pu_alloc_ptr] <= 1'b1;
                                    pu_x[pu_alloc_ptr]      <= kill_x_q + 11'd24;
                                    pu_y[pu_alloc_ptr]      <= kill_y_q + 11'd24;
                                    pu_type[pu_alloc_ptr]   <= lfsr[1] ? `ITEM_TYPE_RAGE : `ITEM_TYPE_SHIELD;
                                    pu_alloc_ptr            <= ~pu_alloc_ptr;
                                end
                            end else begin
                                ast_hp[hit_eid_q[1:0]]      <= ast_hp[hit_eid_q[1:0]] - cur_bul_dmg_q;
                                sound_hit                   <= 1'b1;
                                r_debris_active[c_idx[2:0]] <= 1'b1;
                                r_debris_x[c_idx[2:0]]      <= cur_bul_x_q;
                                r_debris_y[c_idx[2:0]]      <= cur_bul_y_q;
                                r_debris_vx[c_idx[2:0]]     <= lfsr[0] ? 5'sd3 : -5'sd3;
                                r_debris_vy[c_idx[2:0]]     <= 5'sd2;
                                r_debris_life[c_idx[2:0]]   <= 5'd8;
                            end
                        end else if (hit_kind_q == 2'd2) begin
                            // 2. Mothership Boss Hit Resolution
                            boss_flash_timer <= 3'd5;
                            sound_hit        <= 1'b1;
                            hit_flag         <= 1'b1;

                            if (boss_hp <= {3'b000, cur_bul_dmg_q}) begin
                                boss_active      <= 1'b0;
                                boss_warn_timer  <= 7'd0;
                                boss_laser_timer <= 7'd0;
                                boss_hp          <= 8'd0;
                                shake_timer      <= 4'd15;
                                freeze_timer     <= 2'd2;
                                pending_pts      <= 12'h900;
                                r_exp_active[0]  <= 1'b1; r_exp_x[0] <= kill_x_q + 11'd4;  r_exp_y[0] <= kill_y_q + 11'd12; r_exp_timer[0] <= 4'd0;
                                r_exp_active[1]  <= 1'b1; r_exp_x[1] <= kill_x_q + 11'd28; r_exp_y[1] <= kill_y_q + 11'd20; r_exp_timer[1] <= 4'd0;
                                pu_active[0]     <= 1'b1; pu_x[0]    <= kill_x_q + 11'd12; pu_y[0]    <= kill_y_q + 11'd24; pu_type[0]    <= `ITEM_TYPE_POWER;
                                pu_active[1]     <= 1'b1; pu_x[1]    <= kill_x_q + 11'd40; pu_y[1]    <= kill_y_q + 11'd24; pu_type[1]    <= `ITEM_TYPE_SHIELD;
                            end else begin
                                boss_hp <= boss_hp - {3'b000, cur_bul_dmg_q};
                            end
                        end else begin
                            // 3. Diver or Formation Alien Hit Resolution
                            enemy_flash_timer <= 3'd5;
                            flash_alien_id    <= hit_eid_q;
                            sound_hit         <= 1'b1;
                            hit_flag          <= 1'b1;
                            hit_target_id     <= hit_eid_q[3:0];

                            if (enemy_hp[hit_eid_q] <= cur_bul_dmg_q) begin
                                form_alive[hit_eid_q] <= 1'b0;
                                r_form_diving_mask[hit_eid_q] <= 1'b0;
                                for (i = 0; i < 4; i = i + 1) begin
                                    if (div_active[i] && (div_idx[i] == hit_eid_q))
                                        div_active[i] <= 1'b0;
                                end

                                freeze_timer <= 2'd1;
                                shake_timer  <= (hit_eid_q < 6'd11) ? 4'd10 : 4'd6;

                                r_exp_active[exp_alloc_ptr] <= 1'b1;
                                r_exp_x[exp_alloc_ptr]      <= kill_x_q;
                                r_exp_y[exp_alloc_ptr]      <= kill_y_q;
                                r_exp_timer[exp_alloc_ptr]  <= 4'd0;
                                exp_alloc_ptr               <= exp_alloc_ptr + 2'd1;

                                for (i = 0; i < 8; i = i + 1) begin
                                    r_debris_active[i] <= 1'b1;
                                    r_debris_x[i]      <= kill_x_q + 11'd14;
                                    r_debris_y[i]      <= kill_y_q + 11'd14;
                                    r_debris_vx[i]     <= deb_init_vx[i];
                                    r_debris_vy[i]     <= deb_init_vy[i];
                                    r_debris_life[i]   <= 5'd16;
                                end

                                if (laser_timer == 7'd0 && rage_cnt < `RAGE_MAX)
                                    rage_cnt <= rage_cnt + 5'd1;

                                if ((hit_eid_q < 6'd11) ? (lfsr[1:0] == 2'b00) : (lfsr[2:0] == 3'b000)) begin
                                    if (!pu_active[pu_alloc_ptr]) begin
                                        pu_active[pu_alloc_ptr] <= 1'b1;
                                        pu_x[pu_alloc_ptr]      <= kill_x_q + 11'd8;
                                        pu_y[pu_alloc_ptr]      <= kill_y_q + 11'd8;
                                        pu_type[pu_alloc_ptr]   <= (lfsr[4:3] == 2'b11) ? `ITEM_TYPE_SHIELD :
                                                                   (lfsr[4:3] == 2'b10) ? `ITEM_TYPE_RAGE   : `ITEM_TYPE_POWER;
                                        pu_alloc_ptr            <= ~pu_alloc_ptr;
                                    end
                                end

                                pending_pts <= (hit_eid_q < 6'd11) ? 12'h100 :
                                               (hit_eid_q < 6'd22) ? 12'h050 : 12'h030;
                            end else begin
                                enemy_hp[hit_eid_q]         <= enemy_hp[hit_eid_q] - cur_bul_dmg_q;
                                r_debris_active[c_idx[2:0]] <= 1'b1;
                                r_debris_x[c_idx[2:0]]      <= cur_bul_x_q;
                                r_debris_y[c_idx[2:0]]      <= cur_bul_y_q;
                                r_debris_vx[c_idx[2:0]]     <= lfsr[0] ? 5'sd3 : -5'sd3;
                                r_debris_vy[c_idx[2:0]]     <= 5'sd2;
                                r_debris_life[c_idx[2:0]]   <= 5'd7;
                            end
                        end

                        // Advance FSM index after hit resolution
                        if (c_state == C_PBUL) begin
                            if (c_idx >= 6'd15) begin
                                c_state <= C_HBUL;
                                c_idx   <= 6'd0;
                            end else begin
                                c_idx <= c_idx + 6'd1;
                            end
                        end else begin
                            if (c_idx >= 6'd7) begin
                                if (laser_timer > 7'd0 && (laser_timer[1:0] == 2'b00)) begin
                                    c_state <= C_LASER;
                                    c_idx   <= 6'd0;
                                end else begin
                                    c_state <= C_PLAYER;
                                    c_idx   <= 6'd0;
                                end
                            end else begin
                                c_idx <= c_idx + 6'd1;
                            end
                        end
                    end
                end

                // -------------------------------------------------------------
                // Step 3: Overdrive Laser Column Sweep (0..43: Aliens, 44: Boss & Bullets, 45..47: Asteroids 0..2)
                // -------------------------------------------------------------
                C_LASER: begin
                    if (c_phase == 2'd0) begin
                        if (c_idx < 6'd44) begin
                            hit_eid = c_idx;
                            kill_x  = get_form_x(hit_eid, fleet_offset_x);
                            kill_y  = get_form_y(hit_eid);
                            if (r_form_diving_mask[hit_eid]) begin
                                for (i = 0; i < 4; i = i + 1) begin
                                    if (div_active[i] && (div_idx[i] == hit_eid)) begin
                                        kill_x = div_x[i];
                                        kill_y = div_y[i];
                                    end
                                end
                            end
                            kill_x_q     <= kill_x;
                            kill_y_q     <= kill_y;
                            laser_hits_q <= form_alive[hit_eid] &&
                                            (kill_x + 11'd28 >= ship_x + 11'd4) &&
                                            (kill_x <= ship_x + 11'd28) &&
                                            (kill_y <= ship_y);
                        end else if (c_idx == 6'd44) begin
                            // Check Boss in laser beam
                            laser_hits_q <= boss_active &&
                                            (boss_x + 11'd60 >= ship_x + 11'd4) &&
                                            (boss_x <= ship_x + 11'd28);
                        end else begin
                            // Check Asteroid (c_idx - 45) in laser beam
                            hit_eid = c_idx - 6'd45; // 0, 1, 2
                            laser_hits_q <= ast_active[hit_eid[1:0]] &&
                                            (ast_x[hit_eid[1:0]] + 11'd60 >= ship_x + 11'd4) &&
                                            (ast_x[hit_eid[1:0]] <= ship_x + 11'd28);
                        end
                        c_phase <= 2'd1;
                    end else begin
                        c_phase <= 2'd0;
                        if (c_idx < 6'd44) begin
                            if (laser_hits_q) begin
                                enemy_flash_timer <= 3'd3;
                                flash_alien_id    <= c_idx;
                                if (enemy_hp[c_idx] <= 5'd1) begin
                                    form_alive[c_idx] <= 1'b0;
                                    r_form_diving_mask[c_idx] <= 1'b0;
                                    for (i = 0; i < 4; i = i + 1) begin
                                        if (div_active[i] && (div_idx[i] == c_idx))
                                            div_active[i] <= 1'b0;
                                    end
                                    r_exp_active[exp_alloc_ptr] <= 1'b1;
                                    r_exp_x[exp_alloc_ptr]      <= kill_x_q;
                                    r_exp_y[exp_alloc_ptr]      <= kill_y_q;
                                    r_exp_timer[exp_alloc_ptr]  <= 4'd0;
                                    exp_alloc_ptr               <= exp_alloc_ptr + 2'd1;
                                    pending_pts                 <= 12'h050;
                                    sound_hit                   <= 1'b1;
                                end else begin
                                    enemy_hp[c_idx] <= enemy_hp[c_idx] - 5'd1;
                                end
                            end
                            c_idx <= c_idx + 6'd1;
                        end else if (c_idx == 6'd44) begin
                            // Vaporize Enemy Bullets in laser beam
                            for (i = 0; i < 10; i = i + 1) begin
                                if (ebul_active[i] &&
                                    (ebul_x[i] + 11'd8 >= ship_x + 11'd4) && (ebul_x[i] <= ship_x + 11'd28) &&
                                    (ebul_y[i] <= ship_y)) begin
                                    ebul_active[i] <= 1'b0;
                                end
                            end
                            // Damage or destroy Boss
                            if (laser_hits_q) begin
                                boss_flash_timer <= 3'd3;
                                if (boss_hp <= 8'd2) begin
                                    boss_active      <= 1'b0;
                                    boss_warn_timer  <= 7'd0;
                                    boss_laser_timer <= 7'd0;
                                    boss_hp          <= 8'd0;
                                    shake_timer      <= 4'd15;
                                    freeze_timer     <= 2'd2;
                                    pending_pts      <= 12'h900;
                                    r_exp_active[0]  <= 1'b1; r_exp_x[0] <= boss_x + 11'd8;  r_exp_y[0] <= boss_y + 11'd16; r_exp_timer[0] <= 4'd0;
                                    r_exp_active[1]  <= 1'b1; r_exp_x[1] <= boss_x + 11'd36; r_exp_y[1] <= boss_y + 11'd24; r_exp_timer[1] <= 4'd0;
                                    pu_active[0]     <= 1'b1; pu_x[0]    <= boss_x + 11'd16; pu_y[0]    <= boss_y + 11'd24; pu_type[0]    <= `ITEM_TYPE_POWER;
                                    pu_active[1]     <= 1'b1; pu_x[1]    <= boss_x + 11'd44; pu_y[1]    <= boss_y + 11'd24; pu_type[1]    <= `ITEM_TYPE_SHIELD;
                                end else begin
                                    boss_hp <= boss_hp - 8'd2;
                                end
                            end
                            c_idx <= 6'd45;
                        end else begin
                            // Damage or destroy Asteroid (c_idx - 45)
                            hit_eid = c_idx - 6'd45;
                            if (laser_hits_q) begin
                                if (ast_hp[hit_eid[1:0]] <= 5'd2) begin
                                    ast_active[hit_eid[1:0]] <= 1'b0;
                                    pending_pts              <= 12'h150;
                                end else begin
                                    ast_hp[hit_eid[1:0]] <= ast_hp[hit_eid[1:0]] - 5'd2;
                                end
                            end
                            if (c_idx >= 6'd47) begin
                                c_state <= C_PLAYER;
                                c_idx   <= 6'd0;
                            end else begin
                                c_idx <= c_idx + 6'd1;
                            end
                        end
                    end
                end

                // -------------------------------------------------------------
                // Step 4: Two serial pickups, then player collision resolution.
                // -------------------------------------------------------------
                C_PLAYER: begin
                    if ((c_phase == 2'd0) || (c_phase == 2'd3)) begin
                        // Phase 0A: Multi-Type Power-Up Pickup (P = Weapon, S = +1 Life/Shield up to 5, R = +6 Rage)
                        // One slot per clock lets slot 1 see slot 0's updated
                        // resources and lets pending_pts drain between rewards.
                        begin
                            i = (c_phase == 2'd0) ? 0 : 1;
                            if (pu_active[i] && !player_exploding &&
                                (pu_x[i] + 11'd16 >= ship_x) && (pu_x[i] <= ship_x + 11'd32) &&
                                (pu_y[i] + 11'd16 >= ship_y) && (pu_y[i] <= ship_y + 11'd32)) begin
                                pu_active[i]  <= 1'b0;
                                sound_powerup <= 1'b1;
                                case (pu_type[i])
                                    `ITEM_TYPE_SHIELD: begin
                                        if (player_lives < `PLAYER_MAX_LIVES)
                                            player_lives <= player_lives + 3'd1;
                                        invuln_timer <= 7'd120; // 2s Shield Ring
                                        pending_pts  <= 12'h200;
                                    end
                                    `ITEM_TYPE_RAGE: begin
                                        if (rage_cnt + 5'd6 >= `RAGE_MAX)
                                            rage_cnt <= `RAGE_MAX;
                                        else
                                            rage_cnt <= rage_cnt + 5'd6;
                                        pending_pts <= 12'h200;
                                    end
                                    default: begin // ITEM_TYPE_POWER (Gold P)
                                        if (power_level < 3'd5)
                                            power_level <= power_level + 3'd1;
                                        else if (wingmen_count < 2'd2)
                                            wingmen_count <= wingmen_count + 2'd1;
                                        else
                                            pending_pts <= 12'h500;
                                    end
                                endcase
                            end
                        end

                        if (c_phase == 2'd0) begin
                            c_phase <= 2'd3;
                        end else begin
                            // After both pickups: Enemy Bullets vs Player
                            player_hit = 1'b0;
                            if (!player_exploding && player_lives > 3'd0 && (laser_timer == 7'd0)) begin
                                for (i = 0; i < 10; i = i + 1) begin
                                    if (ebul_active[i] &&
                                        (ebul_x[i] + ((ebul_type[i] == `EBUL_TYPE_SEEKER) ? 11'd10 : 11'd6) >= ship_hb_l) &&
                                        (ebul_x[i] <= ship_hb_r) &&
                                        (ebul_y[i] + ((ebul_type[i] == `EBUL_TYPE_SNIPER) ? 11'd16 : 11'd10) >= ship_hb_t) &&
                                        (ebul_y[i] <= ship_hb_b)) begin
                                        ebul_active[i] <= 1'b0;
                                        if (respawn_invuln_timer == 7'd0)
                                            player_hit = 1'b1;
                                    end
                                end
                            end
                            r_player_hit_q <= player_hit;
                            c_phase        <= 2'd1;
                        end
                    end else if (c_phase == 2'd1) begin
                        // Phase 1: Divers / 64x64 Asteroids / Boss vs Player Ship
                        player_hit = r_player_hit_q;
                        if (!player_exploding && player_lives > 3'd0 && (laser_timer == 7'd0) && (respawn_invuln_timer == 7'd0)) begin
                            for (i = 0; i < 4; i = i + 1) begin
                                if (div_active[i] &&
                                    (div_x[i] + 11'd26 >= ship_hb_l) && (div_x[i] <= ship_hb_r) &&
                                    (div_y[i] + 11'd26 >= ship_hb_t) && (div_y[i] <= ship_hb_b)) begin
                                    div_active[i]                  <= 1'b0;
                                    form_alive[div_idx[i]]         <= 1'b0;
                                    r_form_diving_mask[div_idx[i]] <= 1'b0;
                                    player_hit = 1'b1;
                                end
                            end

                            for (i = 0; i < 3; i = i + 1) begin
                                if (ast_active[i] &&
                                    (ast_x[i] + 11'd56 >= ship_hb_l) && (ast_x[i] + 11'd8 <= ship_hb_r) &&
                                    (ast_y[i] + 11'd56 >= ship_hb_t) && (ast_y[i] + 11'd8 <= ship_hb_b)) begin
                                    ast_active[i] <= 1'b0;
                                    player_hit = 1'b1;
                                end
                            end

                            // Boss Body or Boss Mega Death-Ray vs Player Ship
                            if (boss_active &&
                                (((boss_laser_timer > 7'd0) &&
                                  (ship_hb_r >= boss_x + 11'd14) && (ship_hb_l <= boss_x + 11'd50) &&
                                  (ship_y >= boss_y + 11'd56)) ||
                                 ((ship_hb_r >= boss_x + 11'd4) && (ship_hb_l <= boss_x + 11'd60) &&
                                  (ship_hb_b >= boss_y + 11'd4) && (ship_hb_t <= boss_y + 11'd60)))) begin
                                player_hit = 1'b1;
                            end
                        end
                        r_player_hit_q <= player_hit;
                        c_phase        <= 2'd2;
                    end else begin
                        // Phase 2: Resolve Player Hit (Shield absorbs or Player explodes)
                        if (r_player_hit_q && (respawn_invuln_timer == 7'd0)) begin
                            // If Purple Shield (invuln_timer > 0) is active, Shield absorbs the hit and breaks!
                            if (invuln_timer > 7'd0) begin
                                invuln_timer         <= 7'd0; // Shield breaks immediately!
                                respawn_invuln_timer <= 7'd30; // 0.5s mercy invulnerability to prevent unfair multi-hits!
                                shake_timer          <= 4'd10; // Medium shake for feedback
                                sound_hit            <= 1'b1;
                                r_imp_active[imp_alloc_ptr] <= 1'b1;
                                r_imp_x[imp_alloc_ptr]      <= ship_x + 11'd8;
                                r_imp_y[imp_alloc_ptr]      <= ship_y + 11'd8;
                                r_imp_timer[imp_alloc_ptr]  <= 3'd6;
                                imp_alloc_ptr               <= imp_alloc_ptr + 2'd1;
                            end else begin
                                player_exploding <= 1'b1;
                                player_lives     <= player_lives - 3'd1;
                                sound_player_die <= 1'b1;
                                shake_timer      <= 4'd14;

                                // Downgrade 1 wingman or 1 power level on death AND eject a Gold P item so player can recover it!
                                if (wingmen_count > 2'd0 || power_level > 3'd1) begin
                                    if (wingmen_count > 2'd0)
                                        wingmen_count <= wingmen_count - 2'd1;
                                    else
                                        power_level <= power_level - 3'd1;

                                    if (player_lives > 3'd1) begin
                                        pu_active[pu_alloc_ptr] <= 1'b1;
                                        pu_x[pu_alloc_ptr]      <= ship_x + 11'd8;
                                        pu_y[pu_alloc_ptr]      <= (ship_y > 11'd60) ? (ship_y - 11'd30) : 11'd60;
                                        pu_type[pu_alloc_ptr]   <= `ITEM_TYPE_POWER;
                                        pu_alloc_ptr            <= ~pu_alloc_ptr;
                                    end
                                end

                                r_exp_active[exp_alloc_ptr] <= 1'b1;
                                r_exp_x[exp_alloc_ptr]      <= ship_x;
                                r_exp_y[exp_alloc_ptr]      <= ship_y;
                                r_exp_timer[exp_alloc_ptr]  <= 4'd0;
                                exp_alloc_ptr               <= exp_alloc_ptr + 2'd1;

                                for (i = 0; i < 8; i = i + 1) begin
                                    r_debris_active[i] <= 1'b1;
                                    r_debris_x[i]      <= ship_x + 11'd14;
                                    r_debris_y[i]      <= ship_y + 11'd14;
                                    r_debris_vx[i]     <= deb_init_vx[i];
                                    r_debris_vy[i]     <= deb_init_vy[i];
                                    r_debris_life[i]   <= 5'd22;
                                end
                            end
                        end

                        r_player_hit_q <= 1'b0;
                        c_phase        <= 2'd0;
                        c_state        <= C_IDLE;
                    end
                end

                default: c_state <= C_IDLE;
            endcase
        end
    end
end

endmodule
