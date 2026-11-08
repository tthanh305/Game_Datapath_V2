`timescale 1ns / 1ps
`include "game_params.vh"

// =============================================================================
// Galaxian Steredenn Shmup Color Mapper & Pixel Renderer
// Features:
//   - 11x4 Enemy Formation via O(1) Grid Bit-Shift Lookup (4 distinct row styles)
//   - 4 Concurrent Diving Enemies + 3 Falling Asteroids (Tile 5)
//   - Player Ship (Tile 0) + Shield Ring (Tile 4) + 2 Miniature Wingmen
//   - Overdrive Laser Full-Screen Beam + Rage Progress Bar
//   - 16 Player Bullets (with dust trail), 8 Homing Bullets (pink/purple),
//     10 Enemy Bullets (distinct bright red/orange)
//   - 2 Power-Up Drops (Item P: Tile 6 bottom-right 16x16 sub-tile)
//   - 4-Stage Explosions (Tiles 7..10) & 8 Debris Sparks
//   - Dual-Port BRAM with synchronized 1-Cycle Pipeline Stage
// =============================================================================

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
    input wire [3:0] wave_num,

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

    // --- NEW 11x4 SHMUP INPUTS ---
    input wire [43:0]        form_alive,
    input wire [43:0]        form_diving_mask,
    input wire [2:0]         power_level,
    input wire [1:0]         wingmen_count,
    input wire [4:0]         rage_cnt,
    input wire [6:0]         laser_timer,
    input wire [6:0]         invuln_timer,

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

// Helper palette lookup with optional gold-orange tint for Row 3 enemies
function automatic [23:0] get_rgb888_tinted(input [3:0] idx, input hit_flash, input gold_tint);
    reg [3:0] mapped_idx;
    begin
        if (gold_tint) begin
            case (idx)
                4'h5, 4'h6, 4'h8: mapped_idx = 4'hB; // Cyan/Blue/Pink -> Yellow Gold
                4'h7:             mapped_idx = 4'hA; // Purple -> Orange Fire
                default:          mapped_idx = idx;
            endcase
        end else begin
            mapped_idx = idx;
        end
        get_rgb888_tinted = get_rgb888(mapped_idx, hit_flash);
    end
endfunction

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
// 3. SLOW PARALLAX STARFIELD BACKGROUND & TOP HUD
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
    .pixel_on(hud_pixel),
    .color(hud_color)
);

// =============================================================================
// 4. SPRITE BOUNDING BOXES & 11x4 FORMATION GRID LOOKUP (Cycle T0)
// =============================================================================
// A. Player Ship (32x32, Tile 0) & Temporary/Breakable Purple Energy Shield (Tile 4)
//    Anchored to un-shaken pixel_x/pixel_y so player character never blurs during screen shake!
wire ship_visible = !player_exploding && (player_lives > 3'd0);
wire [10:0] ship_dx = pixel_x - ship_x;
wire [10:0] ship_dy = pixel_y - ship_y;
wire in_ship_box    = ship_visible && (ship_dx < 11'd32) && (ship_dy < 11'd32);
// Shield is only visible while active (invuln_timer > 0 or laser_timer > 0) and blinks when < 32 frames left
wire shield_blink_ok = (invuln_timer >= 7'd32) || !invuln_timer[1] || (laser_timer > 7'd0);
wire in_shield_box   = in_ship_box && ((invuln_timer > 7'd0) || (laser_timer > 7'd0)) && shield_blink_ok;

// B. 2 Wingmen (16x16 miniature fighters with banking lag & thruster flame)
wire signed [10:0] wing_lag_x = (ship_tilt_frame == 3'd0) ? 11'sd3 :
                                (ship_tilt_frame == 3'd1) ? 11'sd1 :
                                (ship_tilt_frame == 3'd3) ? -11'sd1 :
                                (ship_tilt_frame == 3'd4) ? -11'sd3 : 11'sd0;
wire [10:0] wing0_dx = pixel_x - (ship_x - 11'd28 + wing_lag_x);
wire [10:0] wing0_dy = pixel_y - (ship_y + 11'd8);
wire in_wing0 = ship_visible && (wingmen_count >= 2'd1) && (wing0_dx < 11'd16) && (wing0_dy < 11'd16);

wire [10:0] wing1_dx = pixel_x - (ship_x + 11'd44 + wing_lag_x);
wire [10:0] wing1_dy = pixel_y - (ship_y + 11'd8);
wire in_wing1 = ship_visible && (wingmen_count >= 2'd2) && (wing1_dx < 11'd16) && (wing1_dy < 11'd16);

wire in_wingman = in_wing0 | in_wing1;
wire [4:0] wing_rx = in_wing0 ? {wing0_dx[3:0], 1'b0} : {wing1_dx[3:0], 1'b0};
wire [4:0] wing_ry = in_wing0 ? {wing0_dy[3:0], 1'b0} : {wing1_dy[3:0], 1'b0};

// Animated Thruster Flame underneath Player Ship
wire in_thruster = ship_visible && (ship_dx >= 11'd12 && ship_dx <= 11'd19) &&
                   (ship_dy >= 11'd31 && ship_dy <= (alien_anim_phase[0] ? 11'd39 : 11'd36));
wire in_thruster_core = in_thruster && (ship_dx >= 11'd14 && ship_dx <= 11'd17);

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

// D. 2 Power-Up Drops (Item P / S / R: 16x16 bottom-right of Tile 6)
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

// E. 4-Stage Explosions (Tiles 7..10, 32x32)
wire [3:0] in_exp;
wire [13:0] exp_addr [0:3];
generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : GEN_EXP_BOX
        wire [10:0] edx = eff_x - exp_x[gi];
        wire [10:0] edy = eff_y - exp_y[gi];
        assign in_exp[gi]   = exp_active[gi] && (edx < 11'd32) && (edy < 11'd32);
        wire [3:0] etile    = 4'd7 + exp_timer[gi][3:2];
        assign exp_addr[gi] = {etile, edy[4:0], edx[4:0]};
    end
endgenerate
wire any_exp = |in_exp;
wire [13:0] sel_exp_addr = in_exp[0] ? exp_addr[0] :
                           in_exp[1] ? exp_addr[1] :
                           in_exp[2] ? exp_addr[2] : exp_addr[3];

// F. 3 Falling Asteroids (Tile 5 scaled 2x -> 64x64px) + Mini HP Bar above damaged asteroids
wire [2:0] in_ast;
wire [4:0] ast_rx [0:2];
wire [4:0] ast_ry [0:2];
wire [2:0] in_ast_hp_bar;
wire [2:0] in_ast_hp_fill;
generate
    for (gi = 0; gi < 3; gi = gi + 1) begin : GEN_AST_BOX
        wire [10:0] adx = eff_x - ast_x[gi];
        wire [10:0] ady = eff_y - ast_y[gi];
        assign in_ast[gi] = ast_active[gi] && (adx < 11'd64) && (ady < 11'd64);
        assign ast_rx[gi] = adx[5:1]; // 2x scale (64x64 -> 32x32 ROM)
        assign ast_ry[gi] = ady[5:1];
        assign in_ast_hp_bar[gi]  = ast_active[gi] && (ast_hp[gi] < ast_max_hp) &&
                                    (adx >= 11'd4 && adx < 11'd60) &&
                                    (eff_y + 11'd6 >= ast_y[gi]) && (eff_y + 11'd3 < ast_y[gi]);
        assign in_ast_hp_fill[gi] = in_ast_hp_bar[gi] && ((adx - 11'd4) < ({6'd0, ast_hp[gi]} << 2));
    end
endgenerate
wire any_ast = |in_ast;
wire [13:0] sel_ast_addr = in_ast[0] ? {4'd5, ast_ry[0], ast_rx[0]} :
                           in_ast[1] ? {4'd5, ast_ry[1], ast_rx[1]} :
                                       {4'd5, ast_ry[2], ast_rx[2]};

// F2. 64x64 Mothership Boss (Tile 1 scaled 2x -> 64x64px)
wire [10:0] boss_dx = eff_x - boss_x;
wire [10:0] boss_dy = eff_y - boss_y;
wire in_boss_box    = boss_active && (boss_dx < 11'd64) && (boss_dy < 11'd64);
wire [13:0] boss_bram_addr = {4'd1, boss_dy[5:1], boss_dx[5:1]};

// G. 4 Diving Attackers (Tiles 1..3, 32x32)
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

// Combine Diver and Formation Alien selection (direct row-based tile selection avoids 6-bit comparator chain)
wire any_alien_hit = any_div | in_form_alien;
wire [5:0] sel_alien_id = any_div ? sel_div_id : f_alien_id;
wire [4:0] sel_alien_rx = any_div ? sel_div_rx : f_rx;
wire [4:0] sel_alien_ry = any_div ? sel_div_ry : f_ry;

wire [3:0] div_tile       = (sel_div_id < 6'd11) ? 4'd1 : (sel_div_id < 6'd22) ? 4'd2 : 4'd3;
wire [3:0] form_tile      = (f_row == 2'd0)      ? 4'd1 : (f_row == 2'd1)      ? 4'd2 : 4'd3;
wire [3:0] sel_alien_tile = any_div ? div_tile : form_tile;

wire sel_alien_gold_tint = any_div ? (sel_div_id >= 6'd33) : (f_row == 2'd3); // Row 3 gets golden palette tint
wire sel_alien_flash     = (enemy_flash_timer > 3'd0) && (sel_alien_id == flash_alien_id);
wire [13:0] alien_bram_addr = {sel_alien_tile, sel_alien_ry, sel_alien_rx};

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

reg [13:0] bram_addr_a;
reg [13:0] bram_addr_b;
reg [2:0]  sel_entity_a;
reg [2:0]  sel_entity_b;

always @* begin
    if (any_exp) begin
        bram_addr_a  = sel_exp_addr;
        sel_entity_a = ENT_EXP;
    end else if (in_ship_box) begin
        bram_addr_a  = {4'd0, ship_dy[4:0], ship_dx[4:0]};
        sel_entity_a = ENT_SHIP;
    end else if (in_wingman) begin
        bram_addr_a  = {4'd0, wing_ry, wing_rx};
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
        bram_addr_a  = 14'd0;
        sel_entity_a = ENT_NONE;
    end
end

always @* begin
    if (in_laser_shockwave) begin
        // Tile 11 Bottom Half: Expanding Laser Shockwave Ring
        bram_addr_b  = {4'd11, shock_dy[4:0], shock_dx[4:0]};
        sel_entity_b = OVL_SHOCK;
    end else if (in_muzzle_box) begin
        // Tile 6 Top-Left 16x16: Muzzle Flash
        bram_addr_b  = {4'd6, 1'b0, m_dy[3:0], 1'b0, m_dx[3:0]};
        sel_entity_b = OVL_MUZZLE;
    end else if (in_shield_box) begin
        // Tile 4: Purple Energy Shield + Gun-pods
        bram_addr_b  = {4'd4, ship_dy[4:0], ship_dx[4:0]};
        sel_entity_b = OVL_SHIELD;
    end else if (in_pu_box) begin
        // Tile 6 Bottom-Right 16x16: Power-Up Item P / S / R
        bram_addr_b  = {4'd6, 1'b1, pu_ry, 1'b1, pu_rx};
        sel_entity_b = OVL_PU;
    end else begin
        bram_addr_b  = 14'd0;
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
// 6. PROJECTILES, IMPACT RINGS, OVERDRIVE LASER BEAM, DEBRIS & HUD BARS (Cycle T0)
// =============================================================================
// A. Overdrive Laser Beam (Full-height column from y=48 to ship_y, anchored to ship_x)
wire [10:0] beam_dx = pixel_x - (ship_x + 11'd4);
wire in_overdrive_beam = (laser_timer > 7'd0) && !player_exploding &&
                         (pixel_y >= 11'd48) && (pixel_y <= ship_y) && (beam_dx < 11'd24);
wire [3:0] beam_color_idx = (beam_dx >= 11'd7 && beam_dx <= 11'd16) ? 4'h4 : // Pure White Core
                            (beam_dx >= 11'd3 && beam_dx <= 11'd20) ? 4'h5 : // Cyan Neon Mid
                            ((pixel_y[2] ^ laser_timer[1]) ? 4'h6 : 4'h7);   // Pulsing Blue/Purple Edge

// A1B. Boss Telegraph Warning Sight & Boss Mega Death-Ray (36px wide column)
wire [10:0] boss_beam_dx = eff_x - (boss_x + 11'd14);
wire in_boss_warn_sight = boss_active && (boss_warn_timer > 7'd0) &&
                          (eff_y >= boss_y + 11'd56) && (eff_y < 11'd688) &&
                          (((eff_x >= boss_x + 11'd31) && (eff_x <= boss_x + 11'd33) && (eff_y[2] ^ boss_warn_timer[1])) ||
                           ((eff_y < boss_y + 11'd68) && (eff_x >= boss_x + 11'd24) && (eff_x <= boss_x + 11'd40)));

wire in_boss_death_ray  = boss_active && (boss_laser_timer > 7'd0) &&
                          (eff_y >= boss_y + 11'd56) && (eff_y < 11'd688) && (boss_beam_dx < 11'd36);
wire [3:0] boss_ray_color_idx = (boss_beam_dx >= 11'd13 && boss_beam_dx <= 11'd22) ? 4'h4 : // White Core
                                (boss_beam_dx >= 11'd6  && boss_beam_dx <= 11'd29) ? 4'h9 : // Crimson Mid
                                ((eff_y[2] ^ boss_laser_timer[1]) ? 4'hA : 4'h7);           // Fiery Orange / Purple Edge

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
        wire [4:0] target_rad  = 5'd9 - {2'b00, imp_timer[gi]}; // expands 3 -> 8 as timer counts 6 -> 1
        // Inner white starburst cross on first 3 frames
        assign imp_core_hit[gi] = in_ibox && (imp_timer[gi] >= 3'd4) &&
                                  ((dist_x == 4'd0 && dist_y <= 4'd5) || (dist_y == 4'd0 && dist_x <= 4'd5) || (manhattan_d <= 5'd2));
        // Expanding cyan/gold shockwave ring
        assign imp_ring_hit[gi] = in_ibox && ((manhattan_d == target_rad) || (manhattan_d == target_rad + 5'd1));
    end
endgenerate
wire any_imp_core = |imp_core_hit;
wire any_imp_ring = |imp_ring_hit;

// A3. Mini HP Bars (Damaged 64x64 Asteroids, Damaged Row 0 Elite Enemies, and Mothership Boss Bar)
wire any_mini_hp_bar  = (|in_ast_hp_bar) | in_row0_hp_bar;
wire any_mini_hp_fill = (|in_ast_hp_fill) | in_row0_hp_fill;

wire in_boss_hp_frame = boss_active && (pixel_y >= 11'd46 && pixel_y < 11'd54) &&
                        (pixel_x >= 11'd480 && pixel_x <= 11'd800);
wire [10:0] boss_bar_fill_w = (boss_max_hp > 8'd80) ? ({3'b000, boss_hp} * 11'd3) : ({3'b000, boss_hp} << 2);
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

// C. 8 Wingman Homing Bullets (Pink/Purple Orb 4'h8 / 4'h7)
wire [7:0] hbul_hit;
wire [7:0] hbul_core;
generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : GEN_HBUL_RENDER
        wire [10:0] hdx = eff_x - hbul_x[gi];
        wire [10:0] hdy = eff_y - hbul_y[gi];
        assign hbul_hit[gi]  = hbul_active[gi] && (hdx < 11'd6) && (hdy < 11'd12);
        assign hbul_core[gi] = hbul_hit[gi] && (hdx >= 11'd2 && hdx <= 11'd3) && (hdy < 11'd6);
    end
endgenerate
wire any_hbul      = |hbul_hit;
wire any_hbul_core = |hbul_core;

// D. 10 Enemy Bullets with 4 Distinct Visual Styles:
//    2'd0 (FIREBALL): 6x12px Fiery Red/Orange (4'h9) + Gold Core (4'hB)
//    2'd1 (WAVE):     8x8px  Purple/Pink Neon Diamond Orb (4'h7/4'h8) + White Core (4'h4)
//    2'd2 (SNIPER):   4x16px High-Speed Yellow-Gold Needle Bolt (4'hB/4'hA) + White Core (4'h4)
//    2'd3 (SEEKER):   10x10px Heavy Spiked Mine (Teal Spikes 4'hC, Crimson Body 4'h9, Pulsing Core)
wire [9:0] ebul_hit;
wire [3:0] ebul_color_arr [0:9];
generate
    for (gi = 0; gi < 10; gi = gi + 1) begin : GEN_EBUL_RENDER
        wire [10:0] edx = eff_x - ebul_x[gi];
        wire [10:0] edy = eff_y - ebul_y[gi];
        wire [1:0]  et  = ebul_type[gi];

        wire hit_fireball = (et == `EBUL_TYPE_FIREBALL) && (edx < 11'd6)  && (edy < 11'd12);
        wire hit_wave     = (et == `EBUL_TYPE_WAVE)     && (edx < 11'd8)  && (edy < 11'd8) &&
                            !((edx == 11'd0 || edx == 11'd7) && (edy == 11'd0 || edy == 11'd7));
        wire hit_sniper   = (et == `EBUL_TYPE_SNIPER)   && (edx >= 11'd1 && edx <= 11'd4) && (edy < 11'd16);
        wire hit_seeker   = (et == `EBUL_TYPE_SEEKER)   && (edx < 11'd10) && (edy < 11'd10) &&
                            (((edx >= 11'd2 && edx <= 11'd7) && (edy >= 11'd2 && edy <= 11'd7)) ||
                             (edx == 11'd4 || edx == 11'd5 || edy == 11'd4 || edy == 11'd5));

        assign ebul_hit[gi] = ebul_active[gi] && (hit_fireball | hit_wave | hit_sniper | hit_seeker);

        assign ebul_color_arr[gi] =
            (et == `EBUL_TYPE_WAVE) ?
                ((edx >= 11'd3 && edx <= 11'd4 && edy >= 11'd3 && edy <= 11'd4) ? 4'h4 :
                 (edx >= 11'd2 && edx <= 11'd5 && edy >= 11'd2 && edy <= 11'd5) ? 4'h8 : 4'h7) :
            (et == `EBUL_TYPE_SNIPER) ?
                ((edx == 11'd2 || edx == 11'd3) && (edy >= 11'd6) ? 4'h4 :
                 (edy >= 11'd4) ? 4'hB : 4'hA) :
            (et == `EBUL_TYPE_SEEKER) ?
                ((edx >= 11'd4 && edx <= 11'd5 && edy >= 11'd4 && edy <= 11'd5) ? (alien_anim_phase[0] ? 4'h4 : 4'hB) :
                 (edx >= 11'd2 && edx <= 11'd7 && edy >= 11'd2 && edy <= 11'd7) ? 4'h9 : 4'hC) :
            // Default: FIREBALL
                ((edx >= 11'd2 && edx <= 11'd3 && edy >= 11'd4) ? 4'hB :
                 (edy < 11'd3) ? 4'hA : 4'h9);
    end
endgenerate
wire any_ebul = |ebul_hit;
reg [3:0] sel_ebul_color;
integer eci;
always @* begin
    sel_ebul_color = 4'h9;
    for (eci = 0; eci < 10; eci = eci + 1) begin
        if (ebul_hit[eci])
            sel_ebul_color = ebul_color_arr[eci];
    end
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
wire [3:0] debris_color_idx = in_debris_arr[0] ? ((deb_life[0] >= 5'd10) ? 4'hB : 4'hA) : 4'h9;

// F. Bottom Status Bar (pixel_y >= 688: Lives, Power Level, Overdrive Rage Bar)
reg        bot_hud_on;
reg [23:0] bot_hud_rgb;
wire [10:0] rage_fill_width = rage_cnt * 11'd10; // 0..200 px

always @* begin
    bot_hud_on  = 1'b0;
    bot_hud_rgb = 24'h000000;

    if (pixel_y >= 11'd688) begin
        // Top border line of bottom bar
        if (pixel_y == 11'd688) begin
            bot_hud_on  = 1'b1;
            bot_hud_rgb = 24'h1E293B;
        end
        // 1. SHIPS (5 Lives icons at X = 96..200, Y = 696..712)
        else if (pixel_y >= 11'd696 && pixel_y < 11'd712) begin
            if ((player_lives >= 3'd1 && pixel_x >= 11'd96  && pixel_x < 11'd112) ||
                (player_lives >= 3'd2 && pixel_x >= 11'd118 && pixel_x < 11'd134) ||
                (player_lives >= 3'd3 && pixel_x >= 11'd140 && pixel_x < 11'd156) ||
                (player_lives >= 3'd4 && pixel_x >= 11'd162 && pixel_x < 11'd178) ||
                (player_lives >= 3'd5 && pixel_x >= 11'd184 && pixel_x < 11'd200)) begin
                bot_hud_on  = 1'b1;
                bot_hud_rgb = 24'h33EEFF; // Cyan Ship Badge
            end
            // 2. POWER LEVEL (5 bars at X = 272..376 + 2 Wingman badges at 392..426)
            else if ((power_level >= 3'd1 && pixel_x >= 11'd272 && pixel_x < 11'd288) ||
                     (power_level >= 3'd2 && pixel_x >= 11'd294 && pixel_x < 11'd310) ||
                     (power_level >= 3'd3 && pixel_x >= 11'd316 && pixel_x < 11'd332) ||
                     (power_level >= 3'd4 && pixel_x >= 11'd338 && pixel_x < 11'd354) ||
                     (power_level >= 3'd5 && pixel_x >= 11'd360 && pixel_x < 11'd376)) begin
                bot_hud_on  = 1'b1;
                bot_hud_rgb = 24'h44FFCC; // Teal Mint Power Bar
            end
            else if ((wingmen_count >= 2'd1 && pixel_x >= 11'd392 && pixel_x < 11'd406) ||
                     (wingmen_count >= 2'd2 && pixel_x >= 11'd412 && pixel_x < 11'd426)) begin
                bot_hud_on  = 1'b1;
                bot_hud_rgb = 24'hFF55AA; // Pink Wingman Badge
            end
            // 3. OVERDRIVE LASER RAGE BAR (X = 1020..1220, width = 200px)
            else if (pixel_x >= 11'd1018 && pixel_x <= 11'd1222) begin
                if (pixel_x == 11'd1018 || pixel_x == 11'd1222 || pixel_y == 11'd696 || pixel_y == 11'd711) begin
                    bot_hud_on  = 1'b1;
                    bot_hud_rgb = 24'h667788; // Bar Frame
                end else if (pixel_x >= 11'd1020 && (pixel_x - 11'd1020 < rage_fill_width)) begin
                    bot_hud_on  = 1'b1;
                    bot_hud_rgb = (rage_cnt >= `RAGE_MAX) ? 24'hFFEE66 : 24'h33EEFF;
                end else if (laser_timer > 7'd0 && pixel_x >= 11'd1020 && pixel_x < 11'd1220) begin
                    bot_hud_on  = 1'b1;
                    bot_hud_rgb = 24'hFFFFFF;
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
reg [1:0]  sel_pu_type_d;
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
    sel_pu_type_d       <= sel_pu_type;
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
// 8. CYCLE T1 FINAL PIXEL COMPOSITOR
// =============================================================================
wire [23:0] rgb_entity_a = get_rgb888_tinted(bram_data_a, hit_flash_d, gold_tint_d);

// Color-code Item Drops: 0=Gold P (4'hB), 1=Emerald S (4'hC), 2=Cyan-Blue R (4'h5)
wire [3:0] pu_mapped_idx = (sel_entity_b_d == OVL_PU && bram_data_b == 4'hB) ?
                           ((sel_pu_type_d == `ITEM_TYPE_SHIELD) ? 4'hC :
                            (sel_pu_type_d == `ITEM_TYPE_RAGE)   ? 4'h5 : 4'hB) : bram_data_b;
wire [23:0] rgb_entity_b = get_rgb888(pu_mapped_idx, 1'b0);

reg [23:0] final_rgb;

always @* begin
    final_rgb = 24'h000000;

    if (pixel_active_d) begin
        // 1. Top HUD or Center Game Over / Win Banner
        if (hud_pixel_d) begin
            final_rgb = hud_color_d;
        end
        // 1B. Top Mothership Boss Health Bar
        else if (in_boss_hp_frame_d) begin
            final_rgb = in_boss_hp_fill_d ? 24'hFF3322 : 24'h334155;
        end
        // 2. Bottom Status Bar (Ships, Power, Overdrive Laser Bar)
        else if (bot_hud_on_d) begin
            final_rgb = bot_hud_rgb_d;
        end
        // 3. Playfield Compositing
        else begin
            // Bullet Impact Effect (Bright White Starburst + Expanding Cyan/Gold Shockwave Ring)
            if (any_imp_core_d) begin
                final_rgb = 24'hFFFFFF;
            end
            else if (any_imp_ring_d) begin
                final_rgb = 24'h33EEFF;
            end
            // Mini HP Bars above damaged 64x64 Asteroids & Row 0 Elite Enemies
            else if (any_mini_hp_bar_d) begin
                final_rgb = any_mini_hp_fill_d ? 24'h44FFCC : 24'h1E293B;
            end
            // Overdrive Laser Beam
            else if (in_overdrive_beam_d) begin
                final_rgb = get_rgb888(beam_color_idx_d, 1'b0);
            end
            // Boss Mega Death-Ray (36px wide column)
            else if (in_boss_death_ray_d) begin
                final_rgb = get_rgb888(boss_ray_color_idx_d, 1'b0);
            end
            // Boss Telegraph Red Warning Laser Sight
            else if (in_boss_warn_sight_d) begin
                final_rgb = 24'hFF2244;
            end
            // Overlay Sprites (Laser Shockwave Ring, Muzzle Flash, Purple Shield, Power-Up Item P/S/R)
            else if ((sel_entity_b_d != OVL_NONE) && (bram_data_b != 4'h0)) begin
                final_rgb = rgb_entity_b;
            end
            // Main Entities (Explosions, Player Ship, Wingmen, Mothership Boss, 11x4 Aliens, 64x64 Asteroids)
            else if ((sel_entity_a_d != ENT_NONE) && (bram_data_a != 4'h0)) begin
                final_rgb = rgb_entity_a;
            end
            // Animated Player Thruster Flame
            else if (in_thruster_d) begin
                final_rgb = in_thruster_core_d ? 24'hFFEE66 : 24'hFF5522;
            end
            // 4-Type Enemy Bullets (Fireball, Sine-Wave Orb, High-Speed Sniper Bolt, Spiked Seeker Mine)
            else if (any_ebul_d) begin
                final_rgb = get_rgb888(sel_ebul_color_d, 1'b0);
            end
            // Player Main Bullets (White Core + Cyan Border)
            else if (any_pbul_head_d) begin
                final_rgb = any_pbul_core_d ? get_rgb888(4'h4, 1'b0) : get_rgb888(4'h5, 1'b0);
            end
            // Wingman Homing Bullets (White Core + Pink Orb)
            else if (any_hbul_d) begin
                final_rgb = any_hbul_core_d ? get_rgb888(4'h4, 1'b0) : get_rgb888(4'h8, 1'b0);
            end
            // Player Bullet Pixel Dust Trail
            else if (any_pbul_trail_d) begin
                final_rgb = get_rgb888(4'h5, 1'b0);
            end
            // Explosion Debris Sparks
            else if (in_debris_d) begin
                final_rgb = get_rgb888(debris_color_idx_d, 1'b0);
            end
            // Slow Parallax Starfield Background
            else begin
                final_rgb = bg_color_d;
            end
        end
    end
end

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
