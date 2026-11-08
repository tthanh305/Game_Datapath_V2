`timescale 1ns / 1ps
`include "game_params.vh"

// =============================================================================
// Galaxian Arcade Physics & Gameplay Engine (Steredenn Edition)
// Handles:
//   1. Dual Laser Cannons (Rapid fire) + Muzzle Flash Timer
//   2. Formation Swaying Left & Right
//   3. Rotating/Random Diver Selection & S-Curve Attacks
//   4. Wave & Level Progression
//   5. Hit/Collision Detection with Hit Flash & Hit Stop (Freeze Timer)
//   6. 4-Stage Explosion Slots & 8-Direction Radial Debris System
//   7. Hardware Screen Shake with 16-bit LFSR
// =============================================================================

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
    input wire fire,

    output reg hit_flag,
    output reg [`GAME_TARGET_ID_WIDTH-1:0] hit_target_id,
    output wire fire_ready,
    output reg fire_accepted,
    output reg [`GAME_SCORE_WIDTH-1:0] score,
    output reg win,
    output reg game_over,
    output reg [3:0] wave_num,

    output reg [`GAME_COORD_WIDTH-1:0] ship_x,
    output wire [`GAME_COORD_WIDTH-1:0] ship_y,
    output reg [`GAME_COORD_WIDTH-1:0] projectile_x,
    output reg [`GAME_COORD_WIDTH-1:0] projectile_y,
    output reg projectile_active,
    output reg [`GAME_COORD_WIDTH-1:0] projectile2_x,
    output reg [`GAME_COORD_WIDTH-1:0] projectile2_y,
    output reg projectile2_active,
    output reg [`GAME_TARGET_COUNT-1:0] alive_flags,
    output wire [`GAME_TARGET_COUNT*`GAME_COORD_WIDTH-1:0] target_x_flat,
    output wire [`GAME_TARGET_COUNT*`GAME_COORD_WIDTH-1:0] target_y_flat,

    // Galaxian specific gameplay state
    output reg [1:0] player_lives,
    output reg player_exploding,
    output wire [1:0] player_exp_phase,
    output reg [10:0] diving_x,
    output reg [10:0] diving_y,
    output reg diving_active,
    output reg [3:0] diving_id,
    output reg bomb_active,
    output reg [10:0] bomb_x,
    output reg [10:0] bomb_y,
    output reg [1:0] alien_anim_phase,

    // Legacy explosion & tilt outputs
    output reg alien_exploding,
    output reg [`GAME_COORD_WIDTH-1:0] alien_explode_x,
    output reg [`GAME_COORD_WIDTH-1:0] alien_explode_y,
    output reg [3:0] alien_explode_timer,
    output wire signed [1:0] diver_tilt,

    // Steredenn Kinematics & Ghost Trail
    output reg  [2:0]  ship_tilt_frame, // 0..4 (2: straight)
    output wire        hit_stop_active, // 1 during freeze frames
    output reg  [10:0] diver_ghost_x,
    output reg  [10:0] diver_ghost_y,

    // --- NEW VFX REGISTERS & SIGNALS (Requirements 3, 4, 5) ---
    output reg  [1:0]  muzzle_timer,
    output reg  [2:0]  enemy_flash_timer,
    output reg  [1:0]  freeze_timer,
    output reg  [3:0]  shake_timer,
    output wire signed [4:0] shake_dx,
    output wire signed [4:0] shake_dy,

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

    output wire signed [8:0] fleet_offset_x_out
);

localparam integer SHIP_MAX_X = `GAME_SCREEN_WIDTH - 64;
assign ship_y = `GAME_SHIP_Y;

// =============================================================================
// 1. Formation Base Coordinates
// =============================================================================
reg signed [8:0] fleet_offset_x;
assign fleet_offset_x_out = fleet_offset_x;
reg fleet_dir;
wire [10:0] fleet_offset_11 = {{2{fleet_offset_x[8]}}, fleet_offset_x};

wire [10:0] base_x [0:15];
wire [10:0] base_y [0:15];

assign base_x[0]  = 11'd340; assign base_y[0]  = 11'd100; // Bosses (Row 0)
assign base_x[1]  = 11'd500; assign base_y[1]  = 11'd100;
assign base_x[2]  = 11'd660; assign base_y[2]  = 11'd100;
assign base_x[3]  = 11'd820; assign base_y[3]  = 11'd100;

assign base_x[4]  = 11'd340; assign base_y[4]  = 11'd160; // Escorts (Row 1)
assign base_x[5]  = 11'd500; assign base_y[5]  = 11'd160;
assign base_x[6]  = 11'd660; assign base_y[6]  = 11'd160;
assign base_x[7]  = 11'd820; assign base_y[7]  = 11'd160;

assign base_x[8]  = 11'd340; assign base_y[8]  = 11'd220; // Drones (Row 2)
assign base_x[9]  = 11'd500; assign base_y[9]  = 11'd220;
assign base_x[10] = 11'd660; assign base_y[10] = 11'd220;
assign base_x[11] = 11'd820; assign base_y[11] = 11'd220;

assign base_x[12] = 11'd340; assign base_y[12] = 11'd280; // Drones (Row 3)
assign base_x[13] = 11'd500; assign base_y[13] = 11'd280;
assign base_x[14] = 11'd660; assign base_y[14] = 11'd280;
assign base_x[15] = 11'd820; assign base_y[15] = 11'd280;

wire [10:0] current_target_x [0:15];
wire [10:0] current_target_y [0:15];

genvar g;
generate
    for (g = 0; g < 16; g = g + 1) begin : GEN_TARGET_COORDS
        assign current_target_x[g] = (diving_active && (diving_id == g[3:0])) ? diving_x : (base_x[g] + fleet_offset_11);
        assign current_target_y[g] = (diving_active && (diving_id == g[3:0])) ? diving_y : base_y[g];
        assign target_x_flat[(g+1)*`GAME_COORD_WIDTH-1 : g*`GAME_COORD_WIDTH] = current_target_x[g];
        assign target_y_flat[(g+1)*`GAME_COORD_WIDTH-1 : g*`GAME_COORD_WIDTH] = current_target_y[g];
    end
endgenerate

// =============================================================================
// 2. Hardware 16-bit LFSR & Screen Shake Generator (Requirement 5)
// =============================================================================
reg [15:0] lfsr;
always @(posedge clk) begin
    if (rst) begin
        lfsr <= 16'hACE1;
    end else begin
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end
end

assign shake_dx = (shake_timer >= 4'd7) ? (lfsr[1] ? 5'sd5 : -5'sd5) :
                  (shake_timer >= 4'd4) ? (lfsr[2] ? 5'sd3 : -5'sd3) :
                  (shake_timer >  4'd0) ? (lfsr[3] ? 5'sd2 : -5'sd2) : 5'sd0;

assign shake_dy = (shake_timer >= 4'd7) ? (lfsr[4] ? 5'sd4 : -5'sd4) :
                  (shake_timer >= 4'd4) ? (lfsr[5] ? 5'sd2 : -5'sd2) :
                  (shake_timer >  4'd0) ? (lfsr[6] ? 5'sd1 : -5'sd1) : 5'sd0;

// =============================================================================
// 3. 4-Stage Explosion Slots & 8 Debris Particles (Requirement 4)
// =============================================================================
reg [10:0] r_exp_x [0:3];
reg [10:0] r_exp_y [0:3];
reg [3:0]  r_exp_timer [0:3];
reg [3:0]  r_exp_active;
reg [1:0]  exp_alloc_ptr;

assign exp_active = r_exp_active;

assign exp_x_flat = {r_exp_x[3], r_exp_x[2], r_exp_x[1], r_exp_x[0]};
assign exp_y_flat = {r_exp_y[3], r_exp_y[2], r_exp_y[1], r_exp_y[0]};
assign exp_timer_flat = {r_exp_timer[3], r_exp_timer[2], r_exp_timer[1], r_exp_timer[0]};

// 8 Debris particles
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
        assign debris_x_flat[(gi+1)*11-1 : gi*11] = r_debris_x[gi];
        assign debris_y_flat[(gi+1)*11-1 : gi*11] = r_debris_y[gi];
        assign debris_life_flat[(gi+1)*5-1 : gi*5] = r_debris_life[gi];
    end
endgenerate

// Radial velocity vectors for 8 directions
wire signed [4:0] deb_init_vx [0:7];
wire signed [4:0] deb_init_vy [0:7];
assign deb_init_vx[0] =  5'sd3; assign deb_init_vy[0] =  5'sd0; // East
assign deb_init_vx[1] =  5'sd2; assign deb_init_vy[1] =  5'sd2; // South-East
assign deb_init_vx[2] =  5'sd0; assign deb_init_vy[2] =  5'sd3; // South
assign deb_init_vx[3] = -5'sd2; assign deb_init_vy[3] =  5'sd2; // South-West
assign deb_init_vx[4] = -5'sd3; assign deb_init_vy[4] =  5'sd0; // West
assign deb_init_vx[5] = -5'sd2; assign deb_init_vy[5] = -5'sd2; // North-West
assign deb_init_vx[6] =  5'sd0; assign deb_init_vy[6] = -5'sd3; // North
assign deb_init_vx[7] =  5'sd2; assign deb_init_vy[7] = -5'sd2; // North-East

// Backward compatibility signals
assign hit_stop_active    = (freeze_timer > 2'd0);
assign muzzle_flash_timer = muzzle_timer;
assign screen_shake_cnt   = shake_timer[2:0];
assign hit_flash_mask     = (enemy_flash_timer > 3'd0) ? (16'b1 << hit_target_id) : 16'h0000;

// =============================================================================
// 4. Diver and Cannon Mechanics
// =============================================================================
reg signed [5:0] dive_vx;
reg [5:0]        dive_step;
reg [7:0]        dive_cooldown;
reg              diving_returning;
reg [3:0]        diver_select_ptr;

assign diver_tilt = (dive_vx > 6'sd1) ? 2'sd1 : (dive_vx < -6'sd1 ? -2'sd1 : 2'sd0);

reg signed [5:0] bomb_vx;
reg [5:0] player_respawn_timer;
assign player_exp_phase = player_respawn_timer[4:3];

assign fire_ready = (!projectile_active || !projectile2_active);

reg [5:0] anim_timer;
reg [6:0] wave_timer;
reg       wave_transition;

// BCD Adder for arcade scores
function [19:0] bcd_add;
    input [19:0] a;
    input [11:0] b;
    reg [23:0] sum;
    begin
        sum = a + b;
        if (sum[3:0] >= 4'd10)   sum = sum + 24'd6;
        if (sum[7:4] >= 4'd10)   sum = sum + 24'd96;
        if (sum[11:8] >= 4'd10)  sum = sum + 24'd1536;
        if (sum[15:12] >= 4'd10) sum = sum + 24'd24576;
        bcd_add = sum[19:0];
    end
endfunction

// =============================================================================
// 5. Parallel Collision Checks
// =============================================================================
wire [15:0] laser1_hit_alien;
wire [15:0] laser2_hit_alien;
wire [15:0] any_laser_hit;

genvar k;
generate
    for (k = 0; k < 16; k = k + 1) begin : GEN_HIT_DETECT
        assign laser1_hit_alien[k] = projectile_active && alive_flags[k] &&
            (projectile_x + 11'd8 >= current_target_x[k]) &&
            (projectile_x <= current_target_x[k] + 11'd32) &&
            (projectile_y <= current_target_y[k] + 11'd28) &&
            (projectile_y + 11'd16 >= current_target_y[k]);

        assign laser2_hit_alien[k] = projectile2_active && alive_flags[k] &&
            (projectile2_x + 11'd8 >= current_target_x[k]) &&
            (projectile2_x <= current_target_x[k] + 11'd32) &&
            (projectile2_y <= current_target_y[k] + 11'd28) &&
            (projectile2_y + 11'd16 >= current_target_y[k]);

        assign any_laser_hit[k] = laser1_hit_alien[k] | laser2_hit_alien[k];
    end
endgenerate

wire hit_occurred = |any_laser_hit;
reg [3:0] hit_alien_id;
wire hit_by_laser1 = laser1_hit_alien[hit_alien_id];
wire hit_by_laser2 = laser2_hit_alien[hit_alien_id];

always @* begin
    hit_alien_id = 4'd0;
    if (any_laser_hit[0])       hit_alien_id = 4'd0;
    else if (any_laser_hit[1])  hit_alien_id = 4'd1;
    else if (any_laser_hit[2])  hit_alien_id = 4'd2;
    else if (any_laser_hit[3])  hit_alien_id = 4'd3;
    else if (any_laser_hit[4])  hit_alien_id = 4'd4;
    else if (any_laser_hit[5])  hit_alien_id = 4'd5;
    else if (any_laser_hit[6])  hit_alien_id = 4'd6;
    else if (any_laser_hit[7])  hit_alien_id = 4'd7;
    else if (any_laser_hit[8])  hit_alien_id = 4'd8;
    else if (any_laser_hit[9])  hit_alien_id = 4'd9;
    else if (any_laser_hit[10]) hit_alien_id = 4'd10;
    else if (any_laser_hit[11]) hit_alien_id = 4'd11;
    else if (any_laser_hit[12]) hit_alien_id = 4'd12;
    else if (any_laser_hit[13]) hit_alien_id = 4'd13;
    else if (any_laser_hit[14]) hit_alien_id = 4'd14;
    else if (any_laser_hit[15]) hit_alien_id = 4'd15;
end

// =============================================================================
// 6. Main State Machine & Feedback Timers
// =============================================================================
integer si, di;
reg hit_by_bomb;
reg hit_by_diver;
reg [11:0] hit_pts;
reg found_diver;
integer scan_k;
reg [3:0] candidate_id;

always @(posedge clk) begin
    if (rst || game_reset) begin
        ship_x             <= 11'd608;
        projectile_x       <= 11'd0;
        projectile_y       <= 11'd0;
        projectile_active  <= 1'b0;
        projectile2_x      <= 11'd0;
        projectile2_y      <= 11'd0;
        projectile2_active <= 1'b0;
        alive_flags        <= 16'hFFFF;
        score              <= 20'h00000;
        win                <= 1'b0;
        game_over          <= 1'b0;
        wave_num           <= 4'd1;
        wave_transition    <= 1'b0;
        wave_timer         <= 7'd0;
        hit_flag           <= 1'b0;
        hit_target_id      <= 4'd0;
        fire_accepted      <= 1'b0;

        player_lives       <= 2'd3;
        player_exploding   <= 1'b0;
        player_respawn_timer <= 6'd0;

        fleet_offset_x     <= 9'sd0;
        fleet_dir          <= 1'b1;

        diving_active      <= 1'b0;
        diving_returning   <= 1'b0;
        diving_id          <= 4'd0;
        diving_x           <= 11'd0;
        diving_y           <= 11'd0;
        dive_vx            <= 6'sd0;
        dive_step          <= 6'd0;
        dive_cooldown      <= 8'd90;

        alien_exploding     <= 1'b0;
        alien_explode_x     <= 11'd0;
        alien_explode_y     <= 11'd0;
        alien_explode_timer <= 4'd0;
        diver_select_ptr   <= 4'd0;
        ship_tilt_frame    <= 3'd2;
        diver_ghost_x      <= 11'd0;
        diver_ghost_y      <= 11'd0;

        // VFX Reset
        muzzle_timer       <= 2'd0;
        enemy_flash_timer  <= 3'd0;
        freeze_timer       <= 2'd0;
        shake_timer        <= 4'd0;
        exp_alloc_ptr      <= 2'd0;
        r_exp_active       <= 4'b0000;
        r_debris_active    <= 8'h00;

        for (si = 0; si < 4; si = si + 1) begin
            r_exp_x[si]     <= 11'd0;
            r_exp_y[si]     <= 11'd0;
            r_exp_timer[si] <= 4'd0;
        end
        for (di = 0; di < 8; di = di + 1) begin
            r_debris_x[di]    <= 11'd0;
            r_debris_y[di]    <= 11'd0;
            r_debris_vx[di]   <= 5'sd0;
            r_debris_vy[di]   <= 5'sd0;
            r_debris_life[di] <= 5'd0;
        end

        bomb_active        <= 1'b0;
        bomb_x             <= 11'd0;
        bomb_y             <= 11'd0;
        bomb_vx            <= 6'sd0;

        alien_anim_phase   <= 2'd0;
        anim_timer         <= 6'd0;

        sound_fire         <= 1'b0;
        sound_hit          <= 1'b0;
        sound_dive         <= 1'b0;
        sound_player_die   <= 1'b0;
        sound_win          <= 1'b0;
        sound_game_over    <= 1'b0;
    end else begin
        // Reset single-clock pulses
        hit_flag         <= 1'b0;
        fire_accepted    <= 1'b0;
        sound_fire       <= 1'b0;
        sound_hit        <= 1'b0;
        sound_dive       <= 1'b0;
        sound_player_die <= 1'b0;
        sound_win        <= 1'b0;
        sound_game_over  <= 1'b0;

        if (frame_tick && game_enable && !win && !game_over) begin
            // -------------------------------------------------------------
            // VFX Timers Countdown
            // -------------------------------------------------------------
            if (muzzle_timer > 2'd0)      muzzle_timer      <= muzzle_timer - 2'd1;
            if (enemy_flash_timer > 3'd0) enemy_flash_timer <= enemy_flash_timer - 3'd1;
            if (shake_timer > 4'd0)       shake_timer       <= shake_timer - 4'd1;

            // 4 Explosion Slots Progression
            for (si = 0; si < 4; si = si + 1) begin
                if (r_exp_active[si]) begin
                    if (r_exp_timer[si] == 4'd15)
                        r_exp_active[si] <= 1'b0;
                    else
                        r_exp_timer[si] <= r_exp_timer[si] + 4'd1;
                end
            end

            // 8 Debris Progression
            for (di = 0; di < 8; di = di + 1) begin
                if (r_debris_active[di]) begin
                    if (r_debris_life[di] == 5'd0) begin
                        r_debris_active[di] <= 1'b0;
                    end else begin
                        r_debris_life[di] <= r_debris_life[di] - 5'd1;
                        r_debris_x[di]    <= r_debris_x[di] + {{6{r_debris_vx[di][4]}}, r_debris_vx[di]};
                        r_debris_y[di]    <= r_debris_y[di] + {{6{r_debris_vy[di][4]}}, r_debris_vy[di]};
                    end
                end
            end

            // -------------------------------------------------------------
            // HIT STOP (Freeze Timer): Pause entity updates for 2 frames
            // -------------------------------------------------------------
            if (freeze_timer > 2'd0) begin
                freeze_timer <= freeze_timer - 2'd1;
            end else begin
                // Update position & movement of all game entities below
                diver_select_ptr <= diver_select_ptr + 4'd3;

                // 1. Alien wing flapping animation timer
                if (anim_timer >= 6'd15) begin
                    anim_timer <= 6'd0;
                    alien_anim_phase <= alien_anim_phase + 2'd1;
                end else begin
                    anim_timer <= anim_timer + 6'd1;
                end

                // 2. Formation Swaying Left & Right
                if (fleet_dir) begin
                    if (fleet_offset_x >= 9'sd90)
                        fleet_dir <= 1'b0;
                    else
                        fleet_offset_x <= fleet_offset_x + 9'sd2;
                end else begin
                    if (fleet_offset_x <= -9'sd90)
                        fleet_dir <= 1'b1;
                    else
                        fleet_offset_x <= fleet_offset_x - 9'sd2;
                end

                // 3. Player Movement & Banking
                diver_ghost_x <= diving_x;
                diver_ghost_y <= diving_y;

                if (player_exploding) begin
                    ship_tilt_frame <= 3'd2;
                    if (player_respawn_timer >= 6'd35) begin
                        player_exploding <= 1'b0;
                        player_respawn_timer <= 6'd0;
                        if (player_lives == 2'd0) begin
                            game_over <= 1'b1;
                            sound_game_over <= 1'b1;
                        end else begin
                            ship_x <= 11'd608;
                        end
                    end else begin
                        player_respawn_timer <= player_respawn_timer + 6'd1;
                    end
                end else if (player_lives > 0) begin
                    if (move_left && !move_right) begin
                        if (ship_tilt_frame > 3'd0) ship_tilt_frame <= ship_tilt_frame - 3'd1;
                        if (ship_x > SHIP_STEP + 11'd40)
                            ship_x <= ship_x - SHIP_STEP;
                        else
                            ship_x <= 11'd40;
                    end else if (move_right && !move_left) begin
                        if (ship_tilt_frame < 3'd4) ship_tilt_frame <= ship_tilt_frame + 3'd1;
                        if (ship_x + SHIP_STEP < SHIP_MAX_X)
                            ship_x <= ship_x + SHIP_STEP;
                        else
                            ship_x <= SHIP_MAX_X;
                    end else begin
                        if (ship_tilt_frame < 3'd2) ship_tilt_frame <= ship_tilt_frame + 3'd1;
                        else if (ship_tilt_frame > 3'd2) ship_tilt_frame <= ship_tilt_frame - 3'd1;
                    end
                end

                // 4. Dual Laser Cannons (Rapid Fire) + Muzzle Flash
                if (fire && fire_ready) begin
                    muzzle_timer <= 2'd2; // Requirement 3: 2 frames Muzzle Flash!
                    if (!projectile_active) begin
                        projectile_active <= 1'b1;
                        projectile_x      <= ship_x + 11'd8; // Left cannon
                        projectile_y      <= ship_y - 11'd10;
                        fire_accepted     <= 1'b1;
                        sound_fire        <= 1'b1;
                    end else if (!projectile2_active) begin
                        projectile2_active <= 1'b1;
                        projectile2_x      <= ship_x + 11'd20; // Right cannon
                        projectile2_y      <= ship_y - 11'd10;
                        fire_accepted      <= 1'b1;
                        sound_fire         <= 1'b1;
                    end
                end

                if (projectile_active) begin
                    if (projectile_y <= PROJECTILE_STEP + 11'd40)
                        projectile_active <= 1'b0;
                    else
                        projectile_y <= projectile_y - PROJECTILE_STEP;
                end

                if (projectile2_active) begin
                    if (projectile2_y <= PROJECTILE_STEP + 11'd40)
                        projectile2_active <= 1'b0;
                    else
                        projectile2_y <= projectile2_y - PROJECTILE_STEP;
                end

                // 5. Wave Progression
                if (wave_transition) begin
                    if (wave_timer <= 7'd1) begin
                        wave_transition <= 1'b0;
                        if (wave_num >= 4'd5) begin
                            win <= 1'b1;
                        end else begin
                            wave_num       <= wave_num + 4'd1;
                            alive_flags    <= 16'hFFFF;
                            fleet_offset_x <= 9'sd0;
                            fleet_dir      <= 1'b1;
                            dive_cooldown  <= 8'd70;
                        end
                    end else begin
                        wave_timer <= wave_timer - 7'd1;
                    end
                end else if (|alive_flags == 1'b0) begin
                    wave_transition <= 1'b1;
                    wave_timer      <= 7'd90;
                    sound_win       <= 1'b1;
                    bomb_active     <= 1'b0;
                end

                // 6. Diving Attack Logic
                if (!diving_active && !wave_transition) begin
                    diving_returning <= 1'b0;
                    if (dive_cooldown > 8'd0) begin
                        dive_cooldown <= dive_cooldown - 8'd1;
                    end else if (|alive_flags) begin
                        found_diver = 1'b0;
                        for (scan_k = 0; scan_k < 16; scan_k = scan_k + 1) begin
                            candidate_id = (diver_select_ptr + scan_k[3:0]) & 4'hF;
                            if (!found_diver && alive_flags[candidate_id]) begin
                                diving_id        <= candidate_id;
                                diving_x         <= base_x[candidate_id] + fleet_offset_11;
                                diving_y         <= base_y[candidate_id];
                                dive_vx          <= (ship_x > base_x[candidate_id] + fleet_offset_11) ? 6'sd2 : -6'sd2;
                                diving_active    <= 1'b1;
                                diving_returning <= 1'b0;
                                dive_step        <= 6'd0;
                                dive_cooldown    <= (wave_num >= 4'd3) ? 8'd80 : (wave_num >= 4'd2 ? 8'd100 : 8'd130);
                                sound_dive       <= 1'b1;
                                found_diver      = 1'b1;
                            end
                        end
                    end
                end else if (diving_active) begin
                    if (!diving_returning) begin
                        diving_y  <= diving_y + 11'd6;
                        dive_step <= dive_step + 6'd1;

                        if (diving_x < ship_x && dive_vx < 6'sd5)
                            dive_vx <= dive_vx + 6'sd1;
                        else if (diving_x > ship_x && dive_vx > -6'sd5)
                            dive_vx <= dive_vx - 6'sd1;

                        diving_x <= diving_x + {{5{dive_vx[5]}}, dive_vx} + (dive_step[4] ? 11'd1 : -11'd1);

                        if (diving_y >= 11'd250 && diving_y <= 11'd256 && !bomb_active) begin
                            bomb_active <= 1'b1;
                            bomb_x      <= diving_x + 11'd14;
                            bomb_y      <= diving_y + 11'd24;
                            bomb_vx     <= ($signed({1'b0, ship_x + 11'd16}) - $signed({1'b0, diving_x + 11'd14})) >>> 6;
                        end

                        if (diving_y >= 11'd704) begin
                            diving_returning <= 1'b1;
                            diving_y         <= 11'd0;
                            diving_x         <= base_x[diving_id] + fleet_offset_11;
                            dive_vx          <= 6'sd0;
                        end
                    end else begin
                        diving_y <= diving_y + 11'd4;
                        diving_x <= base_x[diving_id] + fleet_offset_11;

                        if (diving_y >= base_y[diving_id]) begin
                            diving_active    <= 1'b0;
                            diving_returning <= 1'b0;
                        end
                    end
                end

                // 7. Enemy Bomb
                if (bomb_active) begin
                    if (bomb_y >= 11'd680 || bomb_x < 11'd20 || bomb_x > 11'd1260) begin
                        bomb_active <= 1'b0;
                    end else begin
                        bomb_y <= bomb_y + 11'd6;
                        bomb_x <= bomb_x + {{5{bomb_vx[5]}}, bomb_vx};
                    end
                end

                // 8. Collision Detection: Lasers vs Living Aliens
                if (hit_occurred) begin
                    alive_flags[hit_alien_id] <= 1'b0;
                    if (hit_by_laser1) projectile_active  <= 1'b0;
                    if (hit_by_laser2) projectile2_active <= 1'b0;
                    hit_flag            <= 1'b1;
                    hit_target_id       <= hit_alien_id;
                    sound_hit           <= 1'b1;

                    // Requirement 3: Hit Flash (5 frames) & Hit Stop (2 frames)
                    enemy_flash_timer   <= 3'd5;
                    freeze_timer        <= 2'd2;

                    // Requirement 5: Screen Shake
                    shake_timer         <= (hit_alien_id < 4) ? 4'd12 : 4'd8;

                    // Requirement 4: Spawn 4-Stage Explosion
                    r_exp_active[exp_alloc_ptr] <= 1'b1;
                    r_exp_x[exp_alloc_ptr]      <= current_target_x[hit_alien_id];
                    r_exp_y[exp_alloc_ptr]      <= current_target_y[hit_alien_id];
                    r_exp_timer[exp_alloc_ptr]  <= 4'd0;
                    exp_alloc_ptr               <= exp_alloc_ptr + 2'd1;

                    // Requirement 4: Spawn 8 Debris Particles
                    for (di = 0; di < 8; di = di + 1) begin
                        r_debris_active[di] <= 1'b1;
                        r_debris_x[di]      <= current_target_x[hit_alien_id] + 11'd14;
                        r_debris_y[di]      <= current_target_y[hit_alien_id] + 11'd14;
                        r_debris_vx[di]     <= deb_init_vx[di];
                        r_debris_vy[di]     <= deb_init_vy[di];
                        r_debris_life[di]   <= 5'd18;
                    end

                    if (diving_active && (diving_id == hit_alien_id)) begin
                        diving_active    <= 1'b0;
                        diving_returning <= 1'b0;
                        if (hit_alien_id < 4)      hit_pts = 12'h200;
                        else if (hit_alien_id < 8) hit_pts = 12'h100;
                        else                       hit_pts = 12'h060;
                    end else begin
                        if (hit_alien_id < 4)      hit_pts = 12'h100;
                        else if (hit_alien_id < 8) hit_pts = 12'h050;
                        else                       hit_pts = 12'h030;
                    end
                    score <= bcd_add(score, hit_pts);
                end

                // 9. Player Collision Detection
                if (!player_exploding && player_lives > 0) begin
                    hit_by_bomb = bomb_active &&
                        (bomb_x + 11'd4 >= ship_x + 11'd4) && (bomb_x <= ship_x + 11'd28) &&
                        (bomb_y + 11'd8 >= ship_y) && (bomb_y <= ship_y + 11'd24);

                    hit_by_diver = diving_active && !diving_returning &&
                        (diving_x + 11'd28 >= ship_x) && (diving_x <= ship_x + 11'd28) &&
                        (diving_y + 11'd20 >= ship_y) && (diving_y <= ship_y + 11'd24);

                    if (hit_by_bomb || hit_by_diver) begin
                        player_exploding <= 1'b1;
                        player_lives     <= player_lives - 2'd1;
                        sound_player_die <= 1'b1;
                        shake_timer      <= 4'd14; // Massive shake!

                        // Explosion & debris at ship position
                        r_exp_active[exp_alloc_ptr] <= 1'b1;
                        r_exp_x[exp_alloc_ptr]      <= ship_x;
                        r_exp_y[exp_alloc_ptr]      <= ship_y;
                        r_exp_timer[exp_alloc_ptr]  <= 4'd0;
                        exp_alloc_ptr               <= exp_alloc_ptr + 2'd1;

                        for (di = 0; di < 8; di = di + 1) begin
                            r_debris_active[di] <= 1'b1;
                            r_debris_x[di]      <= ship_x + 11'd14;
                            r_debris_y[di]      <= ship_y + 11'd14;
                            r_debris_vx[di]     <= deb_init_vx[di];
                            r_debris_vy[di]     <= deb_init_vy[di];
                            r_debris_life[di]   <= 5'd22;
                        end

                        if (hit_by_bomb)
                            bomb_active <= 1'b0;
                        if (hit_by_diver) begin
                            diving_active       <= 1'b0;
                            diving_returning    <= 1'b0;
                            alive_flags[diving_id] <= 1'b0;
                        end
                    end
                end
            end
        end
    end
end

endmodule
