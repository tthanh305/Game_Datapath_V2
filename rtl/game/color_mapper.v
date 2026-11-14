`timescale 1ns / 1ps
`include "game_params.vh"

// =============================================================================
// Galaxian Steredenn Shmup Color Mapper & Pixel Renderer (Enhanced 32-Tile Edition)
// Features:
//   - 11x4 Enemy Formation via O(1) Grid Bit-Shift Lookup + 2-Frame Wing Animation
//   - 4 Concurrent Diving Enemies (with Plasma Wake) + 3 Native 64x64 Cratered Asteroids
//   - Player Ship with 3D Banking (Tiles 0, 16, 20), Hex Shield (Tile 4) & 2 Wingmen
//   - Native 64x64 Dreadnought Mothership Boss with 2-Frame Reactor/Claw Animation
//   - Pulsing Helical Overdrive Laser & Boss Mega Death-Ray
//   - 16 Player Bullets (with dust trail), 8 Homing Missiles (with pink ion trail),
//     10 Multi-Style Enemy Bullets
//   - Distinct [P], [S], [R] Beveled Power-Up Capsules (Tile 6 sub-tiles)
//   - Bottom HUD with 5 Miniature Ship Silhouettes, 3D Power Bars & Cylindrical Laser Tube
// =============================================================================

(* keep_hierarchy = "yes" *)
module color_mapper (
    input wire clk,
    input wire rst,
    input wire frame_tick,
    input wire pixel_active,
    input wire [`GAME_COORD_WIDTH-1:0] pixel_x,
    input wire [`GAME_COORD_WIDTH-1:0] pixel_y,
    input wire [`GAME_COORD_WIDTH-1:0] ship_x,
    input wire [`GAME_COORD_WIDTH-1:0] ship_y,
    input wire [`GAME_COORD_WIDTH-1:0] projectile_x,
    input wire [`GAME_COORD_WIDTH-1:0] projectile_y,
    input wire projectile_active,
    input wire [`GAME_COORD_WIDTH-1:0] projectile2_x,
    input wire [`GAME_COORD_WIDTH-1:0] projectile2_y,
    input wire projectile2_active,
    input wire [`GAME_TARGET_COUNT-1:0] alive_flags,
    input wire [`GAME_TARGET_COUNT*`GAME_COORD_WIDTH-1:0] target_x_flat,
    input wire [`GAME_TARGET_COUNT*`GAME_COORD_WIDTH-1:0] target_y_flat,
    input wire [`GAME_SCORE_WIDTH-1:0] score,
    input wire win,
    input wire game_over,
    input wire [6:0] wave_num,

    // Legacy Galaxian specific state
    input wire [2:0]  player_lives,
    input wire        player_exploding,
    input wire [1:0]  player_exp_phase,
    input wire        bomb_active,
    input wire [10:0] bomb_x,
    input wire [10:0] bomb_y,
    input wire [1:0]  alien_anim_phase,
    input wire        alien_exploding,
    input wire [10:0] alien_explode_x,
    input wire [10:0] alien_explode_y,
    input wire [3:0]  alien_explode_timer,
    input wire        diving_active,
    input wire [3:0]  diving_id,
    input wire signed [1:0] diver_tilt,
    input wire [10:0] diving_x,
    input wire [10:0] diving_y,
    input wire signed [8:0] fleet_offset_x,

    input wire [2:0]  ship_tilt_frame,
    input wire [10:0] diver_ghost_x,
    input wire [10:0] diver_ghost_y,
    input wire [15:0] hit_flash_mask,
    input wire [1:0]  muzzle_flash_timer,
    input wire [2:0]  screen_shake_cnt,

    // VFX Signals
    input wire [1:0]         muzzle_timer,
    input wire [2:0]         enemy_flash_timer,
    input wire [5:0]         flash_alien_id,
    input wire [1:0]         freeze_timer,
    input wire [3:0]         shake_timer,
    input wire signed [4:0]  shake_dx,
    input wire signed [4:0]  shake_dy,
    input wire [4*11-1:0]    exp_x_flat,
    input wire [4*11-1:0]    exp_y_flat,
    input wire [4*4-1:0]     exp_timer_flat,
    input wire [3:0]         exp_active,
    input wire [8*11-1:0]    debris_x_flat,
    input wire [8*11-1:0]    debris_y_flat,
    input wire [8*5-1:0]     debris_life_flat,
    input wire [7:0]         debris_active,

    // --- 11x4 SHMUP INPUTS ---
    input wire [43:0]        form_alive,
    input wire [43:0]        form_diving_mask,
    input wire [2:0]         power_level,
    input wire [1:0]         wingmen_count,
    input wire [4:0]         rage_cnt,
    input wire [6:0]         laser_timer,
    input wire [6:0]         invuln_timer,
    input wire               respawn_invuln,

    input wire [15:0]        pbul_active,
    input wire [16*11-1:0]   pbul_x_flat,
    input wire [16*11-1:0]   pbul_y_flat,

    input wire [7:0]         hbul_active,
    input wire [8*11-1:0]    hbul_x_flat,
    input wire [8*11-1:0]    hbul_y_flat,

    input wire [9:0]         ebul_active,
    input wire [10*11-1:0]   ebul_x_flat,
    input wire [10*11-1:0]   ebul_y_flat,
    input wire [10*2-1:0]    ebul_type_flat,

    input wire [3:0]         div_active,
    input wire [4*6-1:0]     div_idx_flat,
    input wire [4*11-1:0]    div_x_flat,
    input wire [4*11-1:0]    div_y_flat,

    input wire [2:0]         ast_active,
    input wire [3*11-1:0]    ast_x_flat,
    input wire [3*11-1:0]    ast_y_flat,
    input wire [3*5-1:0]     ast_hp_flat,
    input wire [4:0]         ast_max_hp,

    input wire [1:0]         pu_active,
    input wire [2*11-1:0]    pu_x_flat,
    input wire [2*11-1:0]    pu_y_flat,
    input wire [2*2-1:0]     pu_type_flat,

    input wire [3:0]         imp_active,
    input wire [4*11-1:0]    imp_x_flat,
    input wire [4*11-1:0]    imp_y_flat,
    input wire [4*3-1:0]     imp_timer_flat,

    input wire [11*5-1:0]    row0_hp_flat,
    input wire [4:0]         row0_max_hp,

    input wire               boss_active,
    input wire [10:0]        boss_x,
    input wire [10:0]        boss_y,
    input wire [7:0]         boss_hp,
    input wire [7:0]         boss_max_hp,
    input wire [2:0]         boss_flash_timer,
    input wire [6:0]         boss_warn_timer,
    input wire [6:0]         boss_laser_timer,
    input wire               boss_enraged,
    input wire [7:0]         wave_entry_offset,

    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue
);

`include "palette_lut.vh"

// =============================================================================
// 1. HARDWARE SCREEN SHAKE COORDINATES
// =============================================================================
wire [10:0] eff_x = pixel_x + {{6{shake_dx[4]}}, shake_dx};
wire [10:0] eff_y = pixel_y + {{6{shake_dy[4]}}, shake_dy};

// =============================================================================
// 2. UNPACK FLAT BUSES
// =============================================================================
wire [10:0] exp_x [0:3];
wire [10:0] exp_y [0:3];
wire [3:0]  exp_timer [0:3];
assign exp_x[0] = exp_x_flat[10:0];   assign exp_y[0] = exp_y_flat[10:0];   assign exp_timer[0] = exp_timer_flat[3:0];
assign exp_x[1] = exp_x_flat[21:11];  assign exp_y[1] = exp_y_flat[21:11];  assign exp_timer[1] = exp_timer_flat[7:4];
assign exp_x[2] = exp_x_flat[32:22];  assign exp_y[2] = exp_y_flat[32:22];  assign exp_timer[2] = exp_timer_flat[11:8];
assign exp_x[3] = exp_x_flat[43:33];  assign exp_y[3] = exp_y_flat[43:33];  assign exp_timer[3] = exp_timer_flat[15:12];

wire [10:0] deb_x [0:7];
wire [10:0] deb_y [0:7];
wire [4:0]  deb_life [0:7];
genvar gi;
generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : UNPACK_DEB
        assign deb_x[gi]    = debris_x_flat[(gi+1)*11-1 : gi*11];
        assign deb_y[gi]    = debris_y_flat[(gi+1)*11-1 : gi*11];
        assign deb_life[gi] = debris_life_flat[(gi+1)*5-1 : gi*5];
    end
endgenerate

wire [10:0] pbul_x [0:15];
wire [10:0] pbul_y [0:15];
generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : UNPACK_PBUL
        assign pbul_x[gi] = pbul_x_flat[(gi+1)*11-1 : gi*11];
        assign pbul_y[gi] = pbul_y_flat[(gi+1)*11-1 : gi*11];
    end
endgenerate

wire [10:0] hbul_x [0:7];
wire [10:0] hbul_y [0:7];
generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : UNPACK_HBUL
        assign hbul_x[gi] = hbul_x_flat[(gi+1)*11-1 : gi*11];
        assign hbul_y[gi] = hbul_y_flat[(gi+1)*11-1 : gi*11];
    end
endgenerate

wire [10:0] ebul_x    [0:9];
wire [10:0] ebul_y    [0:9];
wire [1:0]  ebul_type [0:9];
generate
    for (gi = 0; gi < 10; gi = gi + 1) begin : UNPACK_EBUL
        assign ebul_x[gi]    = ebul_x_flat[(gi+1)*11-1 : gi*11];
        assign ebul_y[gi]    = ebul_y_flat[(gi+1)*11-1 : gi*11];
        assign ebul_type[gi] = ebul_type_flat[(gi+1)*2-1 : gi*2];
    end
endgenerate

wire [5:0]  div_idx [0:3];
wire [10:0] div_x   [0:3];
wire [10:0] div_y   [0:3];
generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : UNPACK_DIV
        assign div_idx[gi] = div_idx_flat[(gi+1)*6-1  : gi*6];
        assign div_x[gi]   = div_x_flat[(gi+1)*11-1 : gi*11];
        assign div_y[gi]   = div_y_flat[(gi+1)*11-1 : gi*11];
    end
endgenerate

wire [10:0] ast_x  [0:2];
wire [10:0] ast_y  [0:2];
wire [4:0]  ast_hp [0:2];
generate
    for (gi = 0; gi < 3; gi = gi + 1) begin : UNPACK_AST
        assign ast_x[gi]  = ast_x_flat[(gi+1)*11-1 : gi*11];
        assign ast_y[gi]  = ast_y_flat[(gi+1)*11-1 : gi*11];
        assign ast_hp[gi] = ast_hp_flat[(gi+1)*5-1  : gi*5];
    end
endgenerate

wire [10:0] pu_x    [0:1];
wire [10:0] pu_y    [0:1];
wire [1:0]  pu_type [0:1];
assign pu_x[0] = pu_x_flat[10:0];  assign pu_y[0] = pu_y_flat[10:0];  assign pu_type[0] = pu_type_flat[1:0];
assign pu_x[1] = pu_x_flat[21:11]; assign pu_y[1] = pu_y_flat[21:11]; assign pu_type[1] = pu_type_flat[3:2];

wire [10:0] imp_x     [0:3];
wire [10:0] imp_y     [0:3];
wire [2:0]  imp_timer [0:3];
generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : UNPACK_IMP
        assign imp_x[gi]     = imp_x_flat[(gi+1)*11-1 : gi*11];
        assign imp_y[gi]     = imp_y_flat[(gi+1)*11-1 : gi*11];
        assign imp_timer[gi] = imp_timer_flat[(gi+1)*3-1 : gi*3];
    end
endgenerate

wire [4:0] row0_hp [0:10];
generate
    for (gi = 0; gi < 11; gi = gi + 1) begin : UNPACK_ROW0_HP
        assign row0_hp[gi] = row0_hp_flat[(gi+1)*5-1 : gi*5];
    end
endgenerate

// =============================================================================
// 3. SLOW PARALLAX STARFIELD & NEBULA BACKGROUND + TOP HUD
// =============================================================================
wire bg_active;
wire [23:0] bg_color;
wire [3:0]  bg_idx;

space_bg_stereden space_bg_inst (
    .clk(clk),
    .rst(rst),
    .frame_tick(frame_tick),
    .pixel_active(pixel_active),
    .pixel_x(eff_x),
    .pixel_y(eff_y),
    .bg_active(bg_active),
    .bg_color(bg_color),
    .bg_idx(bg_idx)
);

wire hud_pixel;
wire [23:0] hud_color;

game_hud hud_inst (
    .pixel_x(pixel_x),
    .pixel_y(pixel_y),
    .score(score),
    .win(win),
    .game_over(game_over),
    .wave_num(wave_num),
    .scoreboard_active(1'b0),
    .high_score_2(20'd0),
    .high_score_3(20'd0),
    .laser_ready(rage_cnt >= `RAGE_MAX),
    .pixel_on(hud_pixel),
    .color(hud_color)
);

// =============================================================================
// 4. SPRITE BOUNDING BOXES & 11x4 FORMATION GRID LOOKUP (Cycle T0)
// =============================================================================
// A. Player Ship (32x32, Tiles 0 / 16 / 20 for Banking) & Hexagonal Shield (Tile 4)
wire ship_visible = !player_exploding && (player_lives > 3'd0) && (!respawn_invuln || alien_anim_phase[0]);
wire [10:0] ship_dx = pixel_x - ship_x;
wire [10:0] ship_dy = pixel_y - ship_y;
wire in_ship_box    = ship_visible && (ship_dx < 11'd32) && (ship_dy < 11'd32);
wire [4:0] ship_bank_tile = (ship_tilt_frame < 3'd2) ? 5'd16 :
                            (ship_tilt_frame > 3'd2) ? 5'd20 : 5'd0;

wire shield_blink_ok = (invuln_timer >= 7'd32) || !invuln_timer[1] || (laser_timer > 7'd0);
wire in_shield_box   = in_ship_box && ((invuln_timer > 7'd0) || (laser_timer > 7'd0)) && shield_blink_ok;

// B. 2 Wingmen (16x16 miniature fighters with banking lag & mini plasma thrusters)
wire signed [10:0] wing_lag_x = (ship_tilt_frame == 3'd0) ? 11'sd3 :
                                (ship_tilt_frame == 3'd1) ? 11'sd1 :
                                (ship_tilt_frame == 3'd3) ? -11'sd1 :
                                (ship_tilt_frame == 3'd4) ? -11'sd3 : 11'sd0;
wire [10:0] wing0_dx = pixel_x - (ship_x - 11'd28 + wing_lag_x);
wire [10:0] wing0_dy = pixel_y - (ship_y + 11'd8);
wire in_wing0 = ship_visible && (wingmen_count >= 2'd1) && (wing0_dx < 11'd16) && (wing0_dy < 11'd16);
wire in_wing0_thrust = ship_visible && (wingmen_count >= 2'd1) &&
                       (wing0_dx >= 11'd6 && wing0_dx <= 11'd9) &&
                       (wing0_dy >= 11'd15 && wing0_dy <= (alien_anim_phase[0] ? 11'd19 : 11'd17));

wire [10:0] wing1_dx = pixel_x - (ship_x + 11'd44 + wing_lag_x);
wire [10:0] wing1_dy = pixel_y - (ship_y + 11'd8);
wire in_wing1 = ship_visible && (wingmen_count >= 2'd2) && (wing1_dx < 11'd16) && (wing1_dy < 11'd16);
wire in_wing1_thrust = ship_visible && (wingmen_count >= 2'd2) &&
                       (wing1_dx >= 11'd6 && wing1_dx <= 11'd9) &&
                       (wing1_dy >= 11'd15 && wing1_dy <= (alien_anim_phase[0] ? 11'd19 : 11'd17));

wire in_wingman = in_wing0 | in_wing1;
wire [4:0] wing_rx = in_wing0 ? {wing0_dx[3:0], 1'b0} : {wing1_dx[3:0], 1'b0};
wire [4:0] wing_ry = in_wing0 ? {wing0_dy[3:0], 1'b0} : {wing1_dy[3:0], 1'b0};

// Animated Dual-Nozzle Plasma Thruster Flame underneath Player Ship + Wingmen
wire [10:0] thrust_max_y = alien_anim_phase[0] ? 11'd40 : 11'd36;
wire in_ship_thruster = ship_visible && (ship_dx >= 11'd11 && ship_dx <= 11'd20) &&
                        (ship_dy >= 11'd30 && ship_dy <= thrust_max_y) &&
                        !((ship_dx == 11'd15 || ship_dx == 11'd16) && (ship_dy >= 11'd35));
wire in_thruster      = in_ship_thruster | in_wing0_thrust | in_wing1_thrust;
wire in_thruster_core = (in_ship_thruster && (ship_dx >= 11'd13 && ship_dx <= 11'd18) && (ship_dy <= 11'd35)) ||
                        ((in_wing0_thrust | in_wing1_thrust) && !pixel_y[0]);

// C. Muzzle Flash (16x16 top-left of Tile 6) & Expanding Laser Shockwave (Tile 11)
wire [10:0] muzzle_x = ship_x + 11'd8;
wire [10:0] muzzle_y = ship_y - 11'd10;
wire [10:0] m_dx = pixel_x - muzzle_x;
wire [10:0] m_dy = pixel_y - muzzle_y;
wire in_muzzle_box = !player_exploding && (muzzle_timer > 2'd0) && (m_dx < 11'd16) && (m_dy < 11'd16);

wire [10:0] shock_dx = pixel_x - ship_x;
wire [10:0] shock_dy = pixel_y - (ship_y - 11'd20);
wire in_laser_shockwave = !player_exploding && (laser_timer >= 7'd104) &&
                          (shock_dx < 11'd32) && (shock_dy >= 11'd16 && shock_dy < 11'd32);

// D. 2 Power-Up Drops (Distinct [P], [S], [R] capsules in Tile 6 sub-tiles!)
wire [10:0] pu0_dx = eff_x - pu_x[0];
wire [10:0] pu0_dy = eff_y - pu_y[0];
wire in_pu0 = pu_active[0] && (pu0_dx < 11'd16) && (pu0_dy < 11'd16);

wire [10:0] pu1_dx = eff_x - pu_x[1];
wire [10:0] pu1_dy = eff_y - pu_y[1];
wire in_pu1 = pu_active[1] && (pu1_dx < 11'd16) && (pu1_dy < 11'd16);

wire in_pu_box = in_pu0 | in_pu1;
wire [3:0] pu_rx = in_pu0 ? pu0_dx[3:0] : pu1_dx[3:0];
wire [3:0] pu_ry = in_pu0 ? pu0_dy[3:0] : pu1_dy[3:0];
wire [1:0] sel_pu_type = in_pu0 ? pu_type[0] : pu_type[1];
// Map Item Type to Tile 6 quadrant: 0 (P) -> Top-Right (0,1), 1 (S) -> Bottom-Left (1,0), 2 (R) -> Bottom-Right (1,1)
wire pu_quad_y = (sel_pu_type != `ITEM_TYPE_POWER);
wire pu_quad_x = (sel_pu_type != `ITEM_TYPE_SHIELD);

// E. 4-Stage Explosions (Tiles 7..10, 32x32)
wire [3:0] in_exp;
wire [14:0] exp_addr [0:3];
generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : GEN_EXP_BOX
        wire [10:0] edx = eff_x - exp_x[gi];
        wire [10:0] edy = eff_y - exp_y[gi];
        assign in_exp[gi]   = exp_active[gi] && (edx < 11'd32) && (edy < 11'd32);
        wire [4:0] etile    = 5'd7 + {3'b000, exp_timer[gi][3:2]};
        assign exp_addr[gi] = {etile, edy[4:0], edx[4:0]};
    end
endgenerate
wire any_exp = |in_exp;
wire [14:0] sel_exp_addr = in_exp[0] ? exp_addr[0] :
                           in_exp[1] ? exp_addr[1] :
                           in_exp[2] ? exp_addr[2] : exp_addr[3];

// F. 3 Falling Asteroids (Native 64x64px across Tiles 12..15 = 5'b011_yx) + Mini HP Bar
wire [2:0] in_ast;
wire [5:0] ast_rx [0:2];
wire [5:0] ast_ry [0:2];
wire [2:0] in_ast_hp_bar;
wire [2:0] in_ast_hp_fill;
generate
    for (gi = 0; gi < 3; gi = gi + 1) begin : GEN_AST_BOX
        wire [10:0] adx = eff_x - ast_x[gi];
        wire [10:0] ady = eff_y - ast_y[gi];
        assign in_ast[gi] = ast_active[gi] && (adx < 11'd64) && (ady < 11'd64);
        assign ast_rx[gi] = adx[5:0];
        assign ast_ry[gi] = ady[5:0];
        assign in_ast_hp_bar[gi]  = ast_active[gi] && (ast_hp[gi] < ast_max_hp) &&
                                    (adx >= 11'd4 && adx < 11'd60) &&
                                    (eff_y + 11'd6 >= ast_y[gi]) && (eff_y + 11'd3 < ast_y[gi]);
        assign in_ast_hp_fill[gi] = in_ast_hp_bar[gi] && ((adx - 11'd4) < ({6'd0, ast_hp[gi]} << 2));
    end
endgenerate
wire any_ast = |in_ast;
wire [5:0] sel_ast_rx = in_ast[0] ? ast_rx[0] : in_ast[1] ? ast_rx[1] : ast_rx[2];
wire [5:0] sel_ast_ry = in_ast[0] ? ast_ry[0] : in_ast[1] ? ast_ry[1] : ast_ry[2];
// 16-step gentle rotation while falling: Slot 0 rotates CW, Slot 1 rotates CCW, Slot 2 alternates CW/CCW by wave
wire [3:0] sel_ast_rot = in_ast[0] ?  ast_y[0][7:4] :
                         in_ast[1] ? ~ast_y[1][7:4] :
                         (wave_num[0] ? ~ast_y[2][7:4] : ast_y[2][7:4]);
wire [5:0] ast_qx = (sel_ast_rot[3:2] == 2'd0) ?  sel_ast_rx :
                    (sel_ast_rot[3:2] == 2'd1) ?  sel_ast_ry :
                    (sel_ast_rot[3:2] == 2'd2) ? ~sel_ast_rx : ~sel_ast_ry;
wire [5:0] ast_qy = (sel_ast_rot[3:2] == 2'd0) ?  sel_ast_ry :
                    (sel_ast_rot[3:2] == 2'd1) ? ~sel_ast_rx :
                    (sel_ast_rot[3:2] == 2'd2) ? ~sel_ast_ry :  sel_ast_rx;
wire [5:0] ast_bx = (sel_ast_rot[1:0] == 2'd3) ?  ast_qy : ast_qx;
wire [5:0] ast_by = (sel_ast_rot[1:0] == 2'd3) ? ~ast_qx : ast_qy;
wire signed [6:0] ast_ox = (sel_ast_rot[1:0] == 2'd1) ? {{4{~ast_qy[5]}},  ast_qy[4:2]} :
                           (sel_ast_rot[1:0] == 2'd2) ? {{3{~ast_qy[5]}},  ast_qy[4:1]} :
                           (sel_ast_rot[1:0] == 2'd3) ? {{3{ ast_qx[5]}}, ~ast_qx[4:1]} : 7'sd0;
wire signed [6:0] ast_oy = (sel_ast_rot[1:0] == 2'd1) ? {{4{ ast_qx[5]}}, ~ast_qx[4:2]} :
                           (sel_ast_rot[1:0] == 2'd2) ? {{3{ ast_qx[5]}}, ~ast_qx[4:1]} :
                           (sel_ast_rot[1:0] == 2'd3) ? {{3{ ast_qy[5]}}, ~ast_qy[4:1]} : 7'sd0;
wire signed [6:0] ast_rx_s = $signed({1'b0, ast_bx}) + ast_ox;
wire signed [6:0] ast_ry_s = $signed({1'b0, ast_by}) + ast_oy;
wire [5:0] ast_rot_rx = ast_rx_s[6] ? {6{~ast_rx_s[5]}} : ast_rx_s[5:0];
wire [5:0] ast_rot_ry = ast_ry_s[6] ? {6{~ast_ry_s[5]}} : ast_ry_s[5:0];
// Tiles 12..15 = {3'b011, ry[5], rx[5]} -> native 64x64 rotated lookup!
wire [14:0] sel_ast_addr = {3'b011, ast_rot_ry[5], ast_rot_rx[5], ast_rot_ry[4:0], ast_rot_rx[4:0]};

// F2. Native 64x64 Dreadnought Mothership Boss (Tiles 24..27 = Frame 0, Tiles 28..31 = Frame 1)
wire [10:0] boss_dx = eff_x - boss_x;
wire [10:0] boss_dy = eff_y - boss_y;
wire in_boss_box    = boss_active && (boss_dx < 11'd64) && (boss_dy < 11'd64);
wire [14:0] boss_bram_addr = {2'b11, alien_anim_phase[0], boss_dy[5], boss_dx[5], boss_dy[4:0], boss_dx[4:0]};

// G. 4 Diving Attackers (Tiles 1..3 & 17..19, 32x32)
wire [3:0] in_div;
wire [5:0] div_id_arr [0:3];
wire [4:0] div_rx [0:3];
wire [4:0] div_ry [0:3];
generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : GEN_DIV_BOX
        wire [10:0] ddx = eff_x - div_x[gi];
        wire [10:0] ddy = eff_y - div_y[gi];
        assign in_div[gi]     = div_active[gi] && (ddx < 11'd32) && (ddy < 11'd32);
        assign div_id_arr[gi] = div_idx[gi];
        assign div_rx[gi]     = ddx[4:0];
        assign div_ry[gi]     = ddy[4:0];
    end
endgenerate
wire any_div = |in_div;
wire [5:0] sel_div_id = in_div[0] ? div_id_arr[0] :
                        in_div[1] ? div_id_arr[1] :
                        in_div[2] ? div_id_arr[2] : div_id_arr[3];
wire [4:0] sel_div_rx = in_div[0] ? div_rx[0] :
                        in_div[1] ? div_rx[1] :
                        in_div[2] ? div_rx[2] : div_rx[3];
wire [4:0] sel_div_ry = in_div[0] ? div_ry[0] :
                        in_div[1] ? div_ry[1] :
                        in_div[2] ? div_ry[2] : div_ry[3];

// H. 11x4 Formation Grid Lookup (O(1) Bit-Shift Math + Top-Down Wave Entry Offset)
wire signed [11:0] form_x0    = $signed(12'd288) + {{3{fleet_offset_x[8]}}, fleet_offset_x};
wire signed [11:0] f_rel_x    = $signed({1'b0, eff_x}) - form_x0;
wire [3:0]         f_col      = f_rel_x[9:6];
wire [4:0]         f_rx       = f_rel_x[4:0];
wire               in_f_col   = (f_rel_x >= 12'sd0) && (f_rel_x < 12'sd704) &&
                                (f_col < 4'd11) && (f_rel_x[5] == 1'b0);
wire [10:0]        form_eff_y = eff_y + {3'b000, wave_entry_offset};

reg [1:0] f_row;
reg [4:0] f_ry;
reg       in_f_row;
always @* begin
    f_row    = 2'd0;
    f_ry     = 5'd0;
    in_f_row = 1'b0;
    if (eff_y >= 11'd48) begin
        if (form_eff_y >= 11'd72 && form_eff_y < 11'd104) begin
            f_row = 2'd0; f_ry = form_eff_y - 11'd72;  in_f_row = 1'b1;
        end else if (form_eff_y >= 11'd120 && form_eff_y < 11'd152) begin
            f_row = 2'd1; f_ry = form_eff_y - 11'd120; in_f_row = 1'b1;
        end else if (form_eff_y >= 11'd168 && form_eff_y < 11'd200) begin
            f_row = 2'd2; f_ry = form_eff_y - 11'd168; in_f_row = 1'b1;
        end else if (form_eff_y >= 11'd216 && form_eff_y < 11'd248) begin
            f_row = 2'd3; f_ry = form_eff_y - 11'd216; in_f_row = 1'b1;
        end
    end
end

// Pre-mux formation visibility by X-column first (cuts Y -> BRAM address timing path in half!)
wire [43:0] form_vis = form_alive & ~form_diving_mask;
wire [3:0]  col_vis_rows = (f_col < 4'd11) ?
    {form_vis[6'd33 + {2'b00, f_col}],
     form_vis[6'd22 + {2'b00, f_col}],
     form_vis[6'd11 + {2'b00, f_col}],
     form_vis[{2'b00, f_col}]} : 4'b0000;

wire [5:0] f_alien_id = (f_row == 2'd0) ? {2'b00, f_col} :
                        (f_row == 2'd1) ? ({2'b00, f_col} + 6'd11) :
                        (f_row == 2'd2) ? ({2'b00, f_col} + 6'd22) :
                                          ({2'b00, f_col} + 6'd33);

wire in_form_alien = in_f_col && in_f_row && col_vis_rows[f_row];

// Mini HP Bar above damaged Row 0 Elite enemies (y = 66..68 in formation space, width = 24px)
wire [7:0] row0_fill_px = (row0_max_hp > 5'd8) ? ({3'b000, row0_hp[f_col]} << 1) : ({3'b000, row0_hp[f_col]} << 2);
wire in_row0_hp_bar  = in_f_col && (eff_y >= 11'd48) && (form_eff_y >= 11'd66 && form_eff_y < 11'd69) &&
                       col_vis_rows[0] && (row0_hp[f_col] < row0_max_hp) && (f_rx >= 5'd4 && f_rx < 5'd28);
wire in_row0_hp_fill = in_row0_hp_bar && ({3'b000, (f_rx - 5'd4)} < row0_fill_px);

// Combine Diver and Formation Alien selection + 2-Frame Wing Animation bit (MSB of tile_id)
wire any_alien_hit = any_div | in_form_alien;
wire [5:0] sel_alien_id = any_div ? sel_div_id : f_alien_id;
wire [4:0] sel_alien_rx = any_div ? sel_div_rx : f_rx;
wire [4:0] sel_alien_ry = any_div ? sel_div_ry : f_ry;

wire [3:0] div_tile       = (sel_div_id < 6'd11) ? 4'd1 : (sel_div_id < 6'd22) ? 4'd2 : 4'd3;
wire [3:0] form_tile      = (f_row == 2'd0)      ? 4'd1 : (f_row == 2'd1)      ? 4'd2 : 4'd3;
wire [3:0] sel_alien_tile = any_div ? div_tile : form_tile;
wire [1:0] sel_alien_anim = any_div ? alien_anim_phase : (alien_anim_phase ^ {1'b0, f_col[0]});
wire [4:0] alien_anim_offset = (sel_alien_anim == 2'd0) ? 5'd0 :
                               (sel_alien_anim == 2'd2) ? 5'd20 : 5'd16;
wire [4:0] final_alien_tile  = {1'b0, sel_alien_tile} + alien_anim_offset;

wire sel_alien_gold_tint = any_div ? (sel_div_id >= 6'd33) : (f_row == 2'd3);
wire sel_alien_flash     = (enemy_flash_timer > 3'd0) && (sel_alien_id == flash_alien_id);
wire [14:0] alien_bram_addr = {final_alien_tile, sel_alien_ry, sel_alien_rx};

// =============================================================================
// 5. DUAL-PORT BRAM ARBITRATION & INSTANCE
// =============================================================================
localparam ENT_NONE   = 3'd0;
localparam ENT_EXP    = 3'd1;
localparam ENT_ALIEN  = 3'd2;
localparam ENT_SHIP   = 3'd3;
localparam ENT_METEOR = 3'd4;
localparam ENT_WING   = 3'd5;
localparam ENT_BOSS   = 3'd6;

localparam OVL_NONE   = 3'd0;
localparam OVL_MUZZLE = 3'd1;
localparam OVL_SHIELD = 3'd2;
localparam OVL_PU     = 3'd3;
localparam OVL_SHOCK  = 3'd4;

reg [14:0] bram_addr_a;
reg [14:0] bram_addr_b;
reg [2:0]  sel_entity_a;
reg [2:0]  sel_entity_b;

always @* begin
    if (any_exp) begin
        bram_addr_a  = sel_exp_addr;
        sel_entity_a = ENT_EXP;
    end else if (in_ship_box) begin
        bram_addr_a  = {ship_bank_tile, ship_dy[4:0], ship_dx[4:0]};
        sel_entity_a = ENT_SHIP;
    end else if (in_wingman) begin
        bram_addr_a  = {ship_bank_tile, wing_ry, wing_rx};
        sel_entity_a = ENT_WING;
    end else if (in_boss_box) begin
        bram_addr_a  = boss_bram_addr;
        sel_entity_a = ENT_BOSS;
    end else if (any_alien_hit) begin
        bram_addr_a  = alien_bram_addr;
        sel_entity_a = ENT_ALIEN;
    end else if (any_ast) begin
        bram_addr_a  = sel_ast_addr;
        sel_entity_a = ENT_METEOR;
    end else begin
        bram_addr_a  = 15'd0;
        sel_entity_a = ENT_NONE;
    end
end

always @* begin
    if (in_laser_shockwave) begin
        // Tile 11 Bottom Half: Expanding Laser Shockwave Ring
        bram_addr_b  = {5'd11, shock_dy[4:0], shock_dx[4:0]};
        sel_entity_b = OVL_SHOCK;
    end else if (in_muzzle_box) begin
        // Tile 6 Top-Left 16x16: Starburst Muzzle Flash
        bram_addr_b  = {5'd6, 1'b0, m_dy[3:0], 1'b0, m_dx[3:0]};
        sel_entity_b = OVL_MUZZLE;
    end else if (in_shield_box) begin
        // Tile 4: Hexagonal Purple Energy Shield + Gun-pods
        bram_addr_b  = {5'd4, ship_dy[4:0], ship_dx[4:0]};
        sel_entity_b = OVL_SHIELD;
    end else if (in_pu_box) begin
        // Tile 6 Sub-tiles: Distinct [P] (0,1), [S] (1,0), [R] (1,1) Power-Up Capsules!
        bram_addr_b  = {5'd6, pu_quad_y, pu_ry, pu_quad_x, pu_rx};
        sel_entity_b = OVL_PU;
    end else begin
        bram_addr_b  = 15'd0;
        sel_entity_b = OVL_NONE;
    end
end

wire [3:0] bram_data_a;
wire [3:0] bram_data_b;

sprite_rom_32x32 sprite_rom_inst (
    .clk(clk),
    .addr_a(bram_addr_a),
    .data_a(bram_data_a),
    .addr_b(bram_addr_b),
    .data_b(bram_data_b)
);

// =============================================================================
// 6. PROJECTILES, IMPACT RINGS, HELICAL LASERS, DEBRIS & 3D HUD BARS (Cycle T0)
// =============================================================================
// A. Overdrive Laser Beam (Pulsing Core + Helical Energy Wave from y=48 to ship_y)
wire [10:0] beam_dx = pixel_x - (ship_x + 11'd4);
wire in_overdrive_beam = (laser_timer > 7'd0) && !player_exploding &&
                         (pixel_y >= 11'd48) && (pixel_y <= ship_y) && (beam_dx < 11'd24);
wire [2:0] beam_scroll = pixel_y[4:2] + laser_timer[2:0];
wire beam_core_wide    = laser_timer[0] ? (beam_dx >= 11'd6 && beam_dx <= 11'd17) :
                                          (beam_dx >= 11'd8 && beam_dx <= 11'd15);
wire beam_helix_hit    = (beam_scroll[1:0] == beam_dx[2:1]);
wire [3:0] beam_color_idx = beam_core_wide ? 4'h4 :                                   // Pulsing Pure White Core
                            (beam_dx >= 11'd3 && beam_dx <= 11'd20) ?
                            (beam_helix_hit ? 4'h4 : 4'h5) :                          // Cyan Neon + White Helix
                            ((pixel_y[2] ^ laser_timer[1]) ? 4'h6 : 4'h7);            // Electric Blue/Purple Corona

// A1B. Boss Telegraph Warning Sight & Boss Mega Death-Ray (36px wide column with Crimson Helix & Bottom Splash)
wire [10:0] boss_beam_dx = eff_x - (boss_x + 11'd14);
wire in_boss_charging = (boss_warn_timer <= 7'd20); // Last 0.33s energy surge before firing
wire in_boss_warn_sight = boss_active && (boss_warn_timer > 7'd0) &&
                          (eff_y >= boss_y + 11'd56) && (eff_y < 11'd688) && (boss_beam_dx < 11'd36) &&
                          // Outer borders (dx <= 1 or dx >= 34)
                          ((boss_beam_dx <= 11'd1 || boss_beam_dx >= 11'd34) ||
                           // Center targeting core
                           ((boss_beam_dx >= 11'd16 && boss_beam_dx <= 11'd19) && (eff_y[2] ^ boss_warn_timer[1])) ||
                           // Horizontal energy scanlines across whole 36px column
                           ((eff_y[3:0] == 4'd0 || eff_y[3:0] == 4'd8) && (eff_y[2] ^ boss_warn_timer[0])) ||
                           // Final surge phase: solid full-column strobe warning!
                           (in_boss_charging && (boss_warn_timer[1] || (eff_x[1] ^ eff_y[1]))));

wire [10:0] boss_splash_dx = eff_x - (boss_x + 11'd6);
wire in_boss_laser_splash  = boss_active && (boss_laser_timer > 7'd0) &&
                             (eff_y >= 11'd672) && (eff_y < 11'd688) && (boss_splash_dx < 11'd52) &&
                             (boss_splash_dx >= ((11'd687 - eff_y) >> 1)) &&
                             ((11'd51 - boss_splash_dx) >= ((11'd687 - eff_y) >> 1));

wire in_boss_death_ray  = boss_active && (boss_laser_timer > 7'd0) &&
                          (((eff_y >= boss_y + 11'd56) && (eff_y < 11'd688) && (boss_beam_dx < 11'd36)) ||
                           in_boss_laser_splash);
wire [2:0] boss_scroll  = eff_y[4:2] - boss_laser_timer[2:0];
wire boss_core_wide     = boss_laser_timer[0] ? (boss_beam_dx >= 11'd12 && boss_beam_dx <= 11'd23) :
                                                (boss_beam_dx >= 11'd14 && boss_beam_dx <= 11'd21);
wire boss_helix_hit     = (boss_scroll[1:0] == boss_beam_dx[2:1]);
wire boss_splash_core   = (boss_splash_dx >= 11'd18 && boss_splash_dx <= 11'd33) && (eff_y >= 11'd680);
wire [3:0] boss_ray_color_idx = in_boss_laser_splash ? (boss_splash_core ? 4'h4 : (eff_y[1] ^ boss_laser_timer[0]) ? 4'hB : 4'hA) :
                                boss_core_wide ? 4'h4 :                               // Pulsing White Core
                                (boss_beam_dx >= 11'd6 && boss_beam_dx <= 11'd29) ?
                                (boss_helix_hit ? 4'hB : 4'h9) :                      // Crimson + Gold Helix
                                ((eff_y[2] ^ boss_laser_timer[1]) ? 4'hA : 4'h7);     // Fiery Orange / Purple Edge

// A2. 4 Bullet Impact Effect Slots (16x16 Starburst Cross + Expanding Shockwave Ring)
wire [3:0] imp_core_hit;
wire [3:0] imp_ring_hit;
generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : GEN_IMPACT_RENDER
        wire [10:0] idx = eff_x - imp_x[gi];
        wire [10:0] idy = eff_y - imp_y[gi];
        wire in_ibox    = imp_active[gi] && (idx < 11'd16) && (idy < 11'd16);
        wire [3:0] dist_x = (idx[3:0] >= 4'd8) ? (idx[3:0] - 4'd8) : (4'd8 - idx[3:0]);
        wire [3:0] dist_y = (idy[3:0] >= 4'd8) ? (idy[3:0] - 4'd8) : (4'd8 - idy[3:0]);
        wire [4:0] manhattan_d = {1'b0, dist_x} + {1'b0, dist_y};
        wire [4:0] target_rad  = 5'd9 - {2'b00, imp_timer[gi]};
        assign imp_core_hit[gi] = in_ibox && (imp_timer[gi] >= 3'd4) &&
                                  ((dist_x == 4'd0 && dist_y <= 4'd5) || (dist_y == 4'd0 && dist_x <= 4'd5) || (manhattan_d <= 5'd2));
        assign imp_ring_hit[gi] = in_ibox && ((manhattan_d == target_rad) || (manhattan_d == target_rad + 5'd1));
    end
endgenerate
wire any_imp_core = |imp_core_hit;
wire any_imp_ring = |imp_ring_hit;

// A3. Mini HP Bars (Damaged 64x64 Asteroids, Damaged Row 0 Elite Enemies, and 3D Mothership Boss Bar)
wire any_mini_hp_bar  = (|in_ast_hp_bar) | in_row0_hp_bar;
wire any_mini_hp_fill = (|in_ast_hp_fill) | in_row0_hp_fill;

wire in_boss_hp_frame = boss_active && (pixel_y >= 11'd45 && pixel_y < 11'd55) &&
                        (pixel_x >= 11'd480 && pixel_x <= 11'd800);
wire [10:0] boss_bar_raw_w = (boss_max_hp <= 8'd80)  ? ({3'b000, boss_hp} << 2) :
                             (boss_max_hp <= 8'd110) ? (({3'b000, boss_hp} << 1) + {3'b000, boss_hp}) :
                             (boss_max_hp <= 8'd170) ? ({3'b000, boss_hp} << 1) :
                                                       ({3'b000, boss_hp} + ({3'b000, boss_hp} >> 2));
wire [10:0] boss_bar_fill_w = (boss_hp == 8'd0) ? 11'd0 :
                              (boss_bar_raw_w > 11'd318) ? 11'd318 : boss_bar_raw_w;
wire in_boss_hp_fill  = in_boss_hp_frame && (pixel_y >= 11'd47 && pixel_y < 11'd53) &&
                        (pixel_x >= 11'd481) && (pixel_x <= 11'd799) && ((pixel_x - 11'd481) < boss_bar_fill_w);

// B. 16 Player Main Bullets (White Core 4'h4, Cyan Border 4'h5, Dust Trail)
wire [15:0] pbul_head_hit;
wire [15:0] pbul_core_hit;
wire [15:0] pbul_trail_hit;
generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : GEN_PBUL_RENDER
        wire [10:0] pdx = eff_x - pbul_x[gi];
        wire [10:0] pdy = eff_y - pbul_y[gi];
        assign pbul_head_hit[gi]  = pbul_active[gi] && (pdx < 11'd6) && (pdy < 11'd14);
        assign pbul_core_hit[gi]  = pbul_head_hit[gi] && (pdx == 11'd2 || pdx == 11'd3);
        assign pbul_trail_hit[gi] = pbul_active[gi] && (pdx >= 11'd1 && pdx <= 11'd4) &&
                                    (pdy >= 11'd14 && pdy < 11'd26) && (eff_y[1:0] != 2'b00);
    end
endgenerate
wire any_pbul_head  = |pbul_head_hit;
wire any_pbul_core  = |pbul_core_hit;
wire any_pbul_trail = |pbul_trail_hit;

// C. 8 Wingman Homing Missiles (Pink/Purple Orb + Glowing Ion Exhaust Trail)
wire [7:0] hbul_hit;
wire [7:0] hbul_core;
wire [7:0] hbul_trail;
generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : GEN_HBUL_RENDER
        wire [10:0] hdx = eff_x - hbul_x[gi];
        wire [10:0] hdy = eff_y - hbul_y[gi];
        assign hbul_hit[gi]   = hbul_active[gi] && (hdx < 11'd6) && (hdy < 11'd12);
        assign hbul_core[gi]  = hbul_hit[gi] && (hdx >= 11'd2 && hdx <= 11'd3) && (hdy < 11'd6);
        assign hbul_trail[gi] = hbul_active[gi] && (hdx >= 11'd1 && hdx <= 11'd4) &&
                                (hdy >= 11'd12 && hdy < 11'd21) && (eff_y[0] ^ hdx[0]);
    end
endgenerate
wire any_hbul       = |hbul_hit;
wire any_hbul_core  = |hbul_core;
wire any_hbul_trail = |hbul_trail;

// D. 10 Enemy Bullets with 4 Distinct Visual Styles
wire [9:0] ebul_hit;
wire [3:0] hit_edx [0:9];
wire [3:0] hit_edy [0:9];
generate
    for (gi = 0; gi < 10; gi = gi + 1) begin : GEN_EBUL_RENDER
        wire [10:0] edx = eff_x - ebul_x[gi];
        wire [10:0] edy = eff_y - ebul_y[gi];
        wire [1:0]  et  = ebul_type[gi];

        wire hit_fireball = (et == `EBUL_TYPE_FIREBALL) && (edx < 11'd6)  && (edy < 11'd12);
        wire hit_wave     = (et == `EBUL_TYPE_WAVE)     && (edx < 11'd8)  && (edy < 11'd14) &&
                            !((edx == 11'd0 || edx == 11'd7) && (edy == 11'd4 || edy == 11'd11));
        wire hit_sniper   = (et == `EBUL_TYPE_SNIPER)   && (edx >= 11'd1 && edx <= 11'd4) && (edy < 11'd16);
        wire hit_seeker   = (et == `EBUL_TYPE_SEEKER)   && (edx < 11'd10) && (edy < 11'd10) &&
                            (((edx >= 11'd2 && edx <= 11'd7) && (edy >= 11'd2 && edy <= 11'd7)) ||
                             (edx == 11'd4 || edx == 11'd5 || edy == 11'd4 || edy == 11'd5));

        assign ebul_hit[gi] = ebul_active[gi] && (hit_fireball | hit_wave | hit_sniper | hit_seeker);
        assign hit_edx[gi]  = edx[3:0];
        assign hit_edy[gi]  = edy[3:0];
    end
endgenerate
wire any_ebul = |ebul_hit;

reg [3:0] sel_edx;
reg [3:0] sel_edy;
reg [1:0] sel_ebul_type;
integer eci;
always @* begin
    sel_edx       = 4'd0;
    sel_edy       = 4'd0;
    sel_ebul_type = `EBUL_TYPE_FIREBALL;
    for (eci = 0; eci < 10; eci = eci + 1) begin
        if (ebul_hit[eci]) begin
            sel_edx       = hit_edx[eci];
            sel_edy       = hit_edy[eci];
            sel_ebul_type = ebul_type[eci];
        end
    end
end

reg [3:0] sel_ebul_color;
always @* begin
    case (sel_ebul_type)
        `EBUL_TYPE_WAVE: begin
            // Trailing comet ion spark wake (edy < 4, trailing above the falling orb)
            if (sel_edy < 4'd4) begin
                if (sel_edx >= 4'd2 && sel_edx <= 4'd5 && (eff_y[0] ^ sel_edx[0]))
                    sel_ebul_color = 4'h8; // Pink radiant spark
                else
                    sel_ebul_color = 4'h7; // Purple ion halo
            end
            // Leading glowing plasma orb (edy = 4..11): Pure white core + Pink body + Purple border
            else if (sel_edx >= 4'd3 && sel_edx <= 4'd4 && sel_edy >= 4'd6 && sel_edy <= 4'd9)
                sel_ebul_color = 4'h4; // Pure white core
            else if (sel_edx >= 4'd2 && sel_edx <= 4'd5 && sel_edy >= 4'd5 && sel_edy <= 4'd10)
                sel_ebul_color = 4'h8; // Pink radiant orb
            else
                sel_ebul_color = 4'h7; // Purple border
        end
        `EBUL_TYPE_SNIPER: begin
            // Sharp needle bolt: Pure white central core + Yellow glow + Red edge
            if ((sel_edx == 4'd2 || sel_edx == 4'd3) && (sel_edy >= 4'd4 && sel_edy <= 4'd13))
                sel_ebul_color = 4'h4; // Pure white core
            else if (sel_edy >= 4'd2)
                sel_ebul_color = 4'hB; // Yellow Gold
            else
                sel_ebul_color = 4'h9; // Red Crimson tip
        end
        `EBUL_TYPE_SEEKER: begin
            // Pulsing diamond missile: Strobe white core + Red body + Dark border
            if (sel_edx >= 4'd4 && sel_edx <= 4'd5 && sel_edy >= 4'd4 && sel_edy <= 4'd5)
                sel_ebul_color = alien_anim_phase[0] ? 4'h4 : 4'hB; // Strobe White/Gold core
            else if (sel_edx >= 4'd3 && sel_edx <= 4'd6 && sel_edy >= 4'd3 && sel_edy <= 4'd6)
                sel_ebul_color = 4'h9; // Red Crimson
            else
                sel_ebul_color = 4'h2; // Dark Hull outline
        end
        default: begin // EBUL_TYPE_FIREBALL (6x12)
            // Fireball: Pure white core + Orange fire + Crimson border
            if (sel_edx >= 4'd2 && sel_edx <= 4'd3 && sel_edy >= 4'd4 && sel_edy <= 4'd8)
                sel_ebul_color = 4'h4; // Pure white core
            else if (sel_edx >= 4'd1 && sel_edx <= 4'd4 && sel_edy >= 4'd2 && sel_edy <= 4'd10)
                sel_ebul_color = 4'hA; // Orange Fire halo
            else
                sel_ebul_color = 4'h9; // Red Crimson border
        end
    endcase
end

// E. 8 Debris Particles
wire [7:0] in_debris_arr;
generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : GEN_DEB_RENDER
        wire [10:0] ddx = eff_x - deb_x[gi];
        wire [10:0] ddy = eff_y - deb_y[gi];
        assign in_debris_arr[gi] = debris_active[gi] && (ddx <= 11'd2) && (ddy <= 11'd2);
    end
endgenerate
wire in_debris = |in_debris_arr;

reg [4:0] sel_deb_life;
integer dbi;
always @* begin
    sel_deb_life = 5'd0;
    for (dbi = 0; dbi < 8; dbi = dbi + 1) begin
        if (in_debris_arr[dbi])
            sel_deb_life = deb_life[dbi];
    end
end
wire [3:0] debris_color_idx = (sel_deb_life >= 5'd10) ? 4'hB :
                              (sel_deb_life >= 5'd5)  ? 4'hA : 4'h9;

// F. Bottom Status Bar (pixel_y >= 688: Miniature Fighter Icons, 3D Power Bars, Cylindrical Laser Tube)
reg [4:0] hud_blink_cnt;
always @(posedge clk) begin
    if (rst) hud_blink_cnt <= 5'd0;
    else if (frame_tick) hud_blink_cnt <= hud_blink_cnt + 5'd1;
end
wire critical_life  = (player_lives == 3'd1);
wire critical_pulse = critical_life && hud_blink_cnt[3];

reg        bot_hud_on;
reg [23:0] bot_hud_rgb;
wire [10:0] rage_fill_width = ({6'd0, rage_cnt} << 3) + ({6'd0, rage_cnt} << 1); // 0..200 px (rage_cnt * 10)
wire [3:0]  hud_local_y     = pixel_y - 11'd696;

// Helper for 16x16 Miniature Ship Icon in Bottom HUD
reg [3:0] ship_icon_x;
reg       in_ship_slot;
always @* begin
    in_ship_slot = 1'b0;
    ship_icon_x  = 4'd0;
    if (player_lives >= 3'd1 && pixel_x >= 11'd96  && pixel_x < 11'd112) begin
        in_ship_slot = 1'b1; ship_icon_x = pixel_x - 11'd96;
    end else if (player_lives >= 3'd2 && pixel_x >= 11'd118 && pixel_x < 11'd134) begin
        in_ship_slot = 1'b1; ship_icon_x = pixel_x - 11'd118;
    end else if (player_lives >= 3'd3 && pixel_x >= 11'd140 && pixel_x < 11'd156) begin
        in_ship_slot = 1'b1; ship_icon_x = pixel_x - 11'd140;
    end else if (player_lives >= 3'd4 && pixel_x >= 11'd162 && pixel_x < 11'd178) begin
        in_ship_slot = 1'b1; ship_icon_x = pixel_x - 11'd162;
    end else if (player_lives >= 3'd5 && pixel_x >= 11'd184 && pixel_x < 11'd200) begin
        in_ship_slot = 1'b1; ship_icon_x = pixel_x - 11'd184;
    end
end
wire [3:0] icon_adx = (ship_icon_x >= 4'd8) ? (ship_icon_x - 4'd8) : (4'd7 - ship_icon_x);
wire icon_ship_body = (hud_local_y <= 4'd3  && icon_adx <= (hud_local_y >> 1)) ||
                      (hud_local_y >= 4'd4  && hud_local_y <= 4'd7  && icon_adx <= 4'd2) ||
                      (hud_local_y >= 4'd8  && hud_local_y <= 4'd12 && icon_adx <= (hud_local_y - 4'd5)) ||
                      (hud_local_y >= 4'd13 && hud_local_y <= 4'd14 && (icon_adx == 4'd1 || icon_adx == 4'd2));
wire icon_ship_cockpit = (hud_local_y >= 4'd4 && hud_local_y <= 4'd7 && icon_adx == 4'd0);
wire icon_ship_flame   = (hud_local_y == 4'd15 && icon_adx == 4'd1);

always @* begin
    bot_hud_on  = 1'b0;
    bot_hud_rgb = 24'h000000;

    if (pixel_y >= 11'd688) begin
        // Top double-bevel border line of bottom bar (pulses red on critical 1-life alert!)
        if (pixel_y == 11'd688) begin
            bot_hud_on  = 1'b1;
            bot_hud_rgb = critical_pulse ? 24'hFF2244 : 24'h225577;
        end else if (pixel_y == 11'd689) begin
            bot_hud_on  = 1'b1;
            bot_hud_rgb = critical_pulse ? 24'h770511 : 24'h0F172A;
        end
        // 1. SHIPS (5 Miniature Fighter Icons at X = 96..200, Y = 696..712)
        else if (pixel_y >= 11'd696 && pixel_y < 11'd712) begin
            if (in_ship_slot) begin
                if (icon_ship_flame) begin
                    bot_hud_on  = 1'b1;
                    bot_hud_rgb = 24'hFF9922;
                end else if (icon_ship_cockpit) begin
                    bot_hud_on  = 1'b1;
                    bot_hud_rgb = 24'hFFFFFF;
                end else if (icon_ship_body) begin
                    bot_hud_on  = 1'b1;
                    bot_hud_rgb = critical_pulse ? ((hud_local_y <= 4'd6) ? 24'hFFAA33 : 24'hFF2244) :
                                                   ((hud_local_y <= 4'd6) ? 24'h66FFFF : 24'h22B8EE);
                end
            end
            // 2. POWER LEVEL (5 3D-Shaded Energy Cells at X = 304..408 + 2 Wingman Badges at 424..458)
            else if ((power_level >= 3'd1 && pixel_x >= 11'd304 && pixel_x < 11'd320) ||
                     (power_level >= 3'd2 && pixel_x >= 11'd326 && pixel_x < 11'd342) ||
                     (power_level >= 3'd3 && pixel_x >= 11'd348 && pixel_x < 11'd364) ||
                     (power_level >= 3'd4 && pixel_x >= 11'd370 && pixel_x < 11'd386) ||
                     (power_level >= 3'd5 && pixel_x >= 11'd392 && pixel_x < 11'd408)) begin
                bot_hud_on  = 1'b1;
                bot_hud_rgb = (hud_local_y <= 4'd2)  ? 24'hCCFFEE :
                              (hud_local_y >= 4'd13) ? 24'h118866 : 24'h33FFBB;
            end
            else if ((wingmen_count >= 2'd1 && pixel_x >= 11'd424 && pixel_x < 11'd438) ||
                     (wingmen_count >= 2'd2 && pixel_x >= 11'd444 && pixel_x < 11'd458)) begin
                bot_hud_on  = 1'b1;
                bot_hud_rgb = (hud_local_y <= 4'd2)  ? 24'hFFBBEE :
                              (hud_local_y >= 4'd13) ? 24'h992266 : 24'hFF55AA;
            end
            // 3. OVERDRIVE LASER CYLINDRICAL RAGE TUBE (X = 1018..1222, width = 200px)
            else if (pixel_x >= 11'd1018 && pixel_x <= 11'd1222) begin
                if (pixel_x == 11'd1018 || pixel_x == 11'd1222 || pixel_y == 11'd696 || pixel_y == 11'd711) begin
                    bot_hud_on  = 1'b1;
                    bot_hud_rgb = (rage_cnt >= `RAGE_MAX) ? 24'hFFEE66 : 24'h6688AA;
                end else if (laser_timer > 7'd0 && pixel_x >= 11'd1020 && pixel_x < 11'd1220) begin
                    bot_hud_on  = 1'b1;
                    bot_hud_rgb = ((pixel_x[3] ^ laser_timer[1]) || (hud_local_y >= 4'd4 && hud_local_y <= 4'd7)) ?
                                  24'hFFFFFF : 24'h33EEFF;
                end else if (pixel_x >= 11'd1020 && (pixel_x - 11'd1020 < rage_fill_width)) begin
                    bot_hud_on  = 1'b1;
                    if (rage_cnt >= `RAGE_MAX) begin
                        bot_hud_rgb = (hud_local_y >= 4'd4 && hud_local_y <= 4'd6) ? 24'hFFFFFF :
                                      ((pixel_x[3] ^ alien_anim_phase[0]) ? 24'hFFEE66 : 24'hFF9922);
                    end else begin
                        bot_hud_rgb = (hud_local_y >= 4'd4 && hud_local_y <= 4'd6) ? 24'hBBFFFF :
                                      (hud_local_y >= 4'd12) ? 24'h116699 : 24'h33EEFF;
                    end
                end else begin
                    // Dark glass tube background when empty
                    bot_hud_on  = 1'b1;
                    bot_hud_rgb = (hud_local_y == 4'd4) ? 24'h1E293B : 24'h0B111E;
                end
            end
        end
    end
end

// =============================================================================
// 7. 1-CYCLE PIPELINE REGISTERS (Synchronized with BRAM read latency)
// =============================================================================
reg [2:0]  sel_entity_a_d;
reg [2:0]  sel_entity_b_d;
reg        hit_flash_d;
reg        gold_tint_d;

reg        in_overdrive_beam_d;
reg [3:0]  beam_color_idx_d;

reg        in_boss_warn_sight_d;
reg        in_boss_death_ray_d;
reg [3:0]  boss_ray_color_idx_d;

reg        any_imp_core_d;
reg        any_imp_ring_d;

reg        any_mini_hp_bar_d;
reg        any_mini_hp_fill_d;
reg        in_boss_hp_frame_d;
reg        in_boss_hp_fill_d;

reg        in_thruster_d;
reg        in_thruster_core_d;

reg        any_pbul_head_d;
reg        any_pbul_core_d;
reg        any_pbul_trail_d;

reg        any_hbul_d;
reg        any_hbul_core_d;
reg        any_hbul_trail_d;

reg        any_ebul_d;
reg [3:0]  sel_ebul_color_d;

reg        in_debris_d;
reg [3:0]  debris_color_idx_d;

reg        hud_pixel_d;
reg [23:0] hud_color_d;
reg        bot_hud_on_d;
reg [23:0] bot_hud_rgb_d;
reg [23:0] bg_color_d;
reg [10:0] pixel_y_d;
reg        pixel_active_d;

always @(posedge clk) begin
    sel_entity_a_d      <= sel_entity_a;
    sel_entity_b_d      <= sel_entity_b;
    hit_flash_d         <= ((sel_entity_a == ENT_ALIEN) && sel_alien_flash) ||
                           ((sel_entity_a == ENT_BOSS)  && (boss_flash_timer > 3'd0));
    gold_tint_d         <= ((sel_entity_a == ENT_ALIEN) && sel_alien_gold_tint) ||
                           ((sel_entity_a == ENT_BOSS)  && boss_enraged);

    in_overdrive_beam_d  <= in_overdrive_beam;
    beam_color_idx_d     <= beam_color_idx;

    in_boss_warn_sight_d <= in_boss_warn_sight;
    in_boss_death_ray_d  <= in_boss_death_ray;
    boss_ray_color_idx_d <= boss_ray_color_idx;

    any_imp_core_d      <= any_imp_core;
    any_imp_ring_d      <= any_imp_ring;

    any_mini_hp_bar_d   <= any_mini_hp_bar;
    any_mini_hp_fill_d  <= any_mini_hp_fill;
    in_boss_hp_frame_d  <= in_boss_hp_frame;
    in_boss_hp_fill_d   <= in_boss_hp_fill;

    in_thruster_d       <= in_thruster;
    in_thruster_core_d  <= in_thruster_core;

    any_pbul_head_d     <= any_pbul_head;
    any_pbul_core_d     <= any_pbul_core;
    any_pbul_trail_d    <= any_pbul_trail;

    any_hbul_d          <= any_hbul;
    any_hbul_core_d     <= any_hbul_core;
    any_hbul_trail_d    <= any_hbul_trail;

    any_ebul_d          <= any_ebul;
    sel_ebul_color_d    <= sel_ebul_color;

    in_debris_d         <= in_debris;
    debris_color_idx_d  <= debris_color_idx;

    hud_pixel_d         <= hud_pixel;
    hud_color_d         <= hud_color;
    bot_hud_on_d        <= bot_hud_on;
    bot_hud_rgb_d       <= bot_hud_rgb;
    bg_color_d          <= bg_color;
    pixel_y_d           <= pixel_y;
    pixel_active_d      <= pixel_active;
end

// =============================================================================
// 8. CYCLE T1 FINAL PIXEL COMPOSITOR (Centralized Single-Palette Lookup)
// =============================================================================
reg [3:0] mapped_entity_a_idx;
always @* begin
    if (gold_tint_d) begin
        case (bram_data_a)
            4'h5, 4'h6, 4'h8, 4'hC: mapped_entity_a_idx = 4'hB; // Cyan/Blue/Pink/Mint -> Yellow Gold
            4'h7:                   mapped_entity_a_idx = 4'hA; // Purple -> Orange Fire
            default:                mapped_entity_a_idx = bram_data_a;
        endcase
    end else begin
        mapped_entity_a_idx = bram_data_a;
    end
end

reg        use_raw_rgb;
reg [23:0] raw_rgb_val;
reg [3:0]  comp_idx;
reg        comp_flash;

always @* begin
    use_raw_rgb = 1'b1;
    raw_rgb_val = 24'h000000;
    comp_idx    = 4'h0;
    comp_flash  = 1'b0;

    if (pixel_active_d) begin
        // 1. Top HUD or Center Game Over / Win Banner
        if (hud_pixel_d) begin
            raw_rgb_val = hud_color_d;
        end
        // 1B. Top Mothership Boss Health Bar (with 3D cylindrical specular highlight)
        else if (in_boss_hp_frame_d) begin
            if (in_boss_hp_fill_d) begin
                raw_rgb_val = (pixel_y_d == 11'd48 || pixel_y_d == 11'd49) ? 24'hFF9988 :
                              (pixel_y_d >= 11'd52) ? 24'h991111 : 24'hFF3322;
            end else begin
                raw_rgb_val = (pixel_y_d == 11'd45 || pixel_y_d == 11'd54) ? 24'h64748B : 24'h1E293B;
            end
        end
        // 2. Bottom Status Bar (Miniature Ships, 3D Power Bars, Cylindrical Laser Bar)
        else if (bot_hud_on_d) begin
            raw_rgb_val = bot_hud_rgb_d;
        end
        // 3. Playfield Compositing
        else begin
            // 1. DANGER PRIORITY: Enemy Bullets (Never occluded by Laser, Shield, Impact Shockwaves, or Muzzle Flash!)
            if (any_ebul_d) begin
                use_raw_rgb = 1'b0;
                comp_idx    = sel_ebul_color_d;
            end
            // 2. Boss Mega Death-Ray (36px wide column)
            else if (in_boss_death_ray_d) begin
                use_raw_rgb = 1'b0;
                comp_idx    = boss_ray_color_idx_d;
            end
            // 3. Boss Telegraph Red Warning Laser Sight
            else if (in_boss_warn_sight_d) begin
                raw_rgb_val = 24'hFF2244;
            end
            // 4. Overdrive Laser Beam
            else if (in_overdrive_beam_d) begin
                use_raw_rgb = 1'b0;
                comp_idx    = beam_color_idx_d;
            end
            // 5. Bullet Impact Effect (Bright White Starburst + Expanding Cyan Shockwave Ring)
            else if (any_imp_core_d) begin
                raw_rgb_val = 24'hFFFFFF;
            end
            else if (any_imp_ring_d) begin
                raw_rgb_val = 24'h33EEFF;
            end
            // 6. Mini HP Bars above damaged 64x64 Asteroids & Row 0 Elite Enemies
            else if (any_mini_hp_bar_d) begin
                raw_rgb_val = any_mini_hp_fill_d ? 24'h44FFCC : 24'h1E293B;
            end
            // 7. Overlay Sprites (Laser Shockwave Ring, Muzzle Flash, Hex Shield, Power-Up [P]/[S]/[R])
            else if ((sel_entity_b_d != OVL_NONE) && (bram_data_b != 4'h0)) begin
                use_raw_rgb = 1'b0;
                comp_idx    = bram_data_b;
            end
            // 8. Main Entities (Explosions, Banking Ship, Wingmen, 64x64 Boss, 11x4 Aliens, 64x64 Asteroids)
            else if ((sel_entity_a_d != ENT_NONE) && (bram_data_a != 4'h0)) begin
                use_raw_rgb = 1'b0;
                comp_idx    = mapped_entity_a_idx;
                comp_flash  = hit_flash_d;
            end
            // Animated Player & Wingman Thruster Flame
            else if (in_thruster_d) begin
                raw_rgb_val = in_thruster_core_d ? 24'hFFEE66 : 24'hFF5522;
            end
            // Player Main Bullets (White Core + Cyan Border)
            else if (any_pbul_head_d) begin
                use_raw_rgb = 1'b0;
                comp_idx    = any_pbul_core_d ? 4'h4 : 4'h5;
            end
            // Wingman Homing Bullets (White Core + Pink Orb)
            else if (any_hbul_d) begin
                use_raw_rgb = 1'b0;
                comp_idx    = any_hbul_core_d ? 4'h4 : 4'h8;
            end
            // Wingman Homing Bullet Glowing Ion Trail
            else if (any_hbul_trail_d) begin
                use_raw_rgb = 1'b0;
                comp_idx    = 4'h7;
            end
            // Player Bullet Pixel Dust Trail
            else if (any_pbul_trail_d) begin
                use_raw_rgb = 1'b0;
                comp_idx    = 4'h5;
            end
            // Explosion Debris Sparks
            else if (in_debris_d) begin
                use_raw_rgb = 1'b0;
                comp_idx    = debris_color_idx_d;
            end
            // Slow Parallax Starfield & Cosmic Nebula Background
            else begin
                raw_rgb_val = bg_color_d;
            end
        end
    end
end

wire [23:0] final_rgb = use_raw_rgb ? raw_rgb_val : get_rgb888(comp_idx, comp_flash);

always @(posedge clk) begin
    if (rst) begin
        red   <= 8'h00;
        green <= 8'h00;
        blue  <= 8'h00;
    end else begin
        red   <= pixel_active_d ? final_rgb[23:16] : 8'h00;
        green <= pixel_active_d ? final_rgb[15:8]  : 8'h00;
        blue  <= pixel_active_d ? final_rgb[7:0]   : 8'h00;
    end
end

endmodule
