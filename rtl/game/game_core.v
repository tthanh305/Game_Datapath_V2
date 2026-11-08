`timescale 1ns / 1ps
`include "game_params.vh"

// Top-level game wrapper connecting datapath and optional auto controller.
module game_core #(
    parameter integer AUTO_DEMO = 0
)(
    input wire clk,
    input wire rst,
    input wire frame_tick,
    input wire pixel_active,
    input wire [`GAME_COORD_WIDTH-1:0] pixel_x,
    input wire [`GAME_COORD_WIDTH-1:0] pixel_y,
    input wire auto_enable,

    input wire control_game_reset,
    input wire control_game_enable,
    input wire control_move_left,
    input wire control_move_right,
    input wire control_move_up,
    input wire control_move_down,
    input wire control_fire,
    input wire control_laser_trigger,

    output wire hit_flag,
    output wire [`GAME_TARGET_ID_WIDTH-1:0] hit_target_id,
    output wire fire_ready,
    output wire fire_accepted,
    output wire [`GAME_SCORE_WIDTH-1:0] score,
    output wire win,
    output wire game_over,
    output wire [3:0] wave_num,
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
    output wire game_reset_debug,
    output wire game_enable_debug,
    output wire move_left_debug,
    output wire move_right_debug,
    output wire fire_debug,
    output wire [2:0] auto_state_debug,
    output wire [`GAME_TARGET_ID_WIDTH-1:0] target_id_debug,
    output wire [`GAME_COORD_WIDTH-1:0] aim_x_debug,

    // Sound effect triggers
    output wire sound_fire,
    output wire sound_hit,
    output wire sound_dive,
    output wire sound_player_die,
    output wire sound_win,
    output wire sound_game_over,
    output wire sound_powerup,
    output wire sound_laser
);

wire auto_game_reset, auto_game_enable, auto_move_left, auto_move_right, auto_fire;

wire effective_game_reset    = auto_enable ? auto_game_reset  : control_game_reset;
wire effective_game_enable   = auto_enable ? auto_game_enable : control_game_enable;
wire effective_move_left     = auto_enable ? auto_move_left   : control_move_left;
wire effective_move_right    = auto_enable ? auto_move_right  : control_move_right;
wire effective_move_up       = auto_enable ? 1'b0             : control_move_up;
wire effective_move_down     = auto_enable ? 1'b0             : control_move_down;
wire effective_fire          = auto_enable ? auto_fire        : control_fire;
wire effective_laser_trigger = auto_enable ? 1'b0             : control_laser_trigger;

datapath datapath_inst (
    .clk(clk), .rst(rst), .game_reset(effective_game_reset), .frame_tick(frame_tick),
    .game_enable(effective_game_enable),
    .move_left(effective_move_left),
    .move_right(effective_move_right),
    .move_up(effective_move_up),
    .move_down(effective_move_down),
    .fire(effective_fire),
    .laser_trigger(effective_laser_trigger),
    .pixel_active(pixel_active), .pixel_x(pixel_x), .pixel_y(pixel_y),
    .hit_flag(hit_flag), .hit_target_id(hit_target_id), .fire_ready(fire_ready),
    .fire_accepted(fire_accepted), .score(score), .win(win),
    .game_over(game_over), .wave_num(wave_num),
    .alive_flags(alive_flags), .ship_x(ship_x), .ship_y(ship_y),
    .projectile_x(projectile_x), .projectile_y(projectile_y),
    .projectile_active(projectile_active), .target_x_flat(target_x_flat),
    .target_y_flat(target_y_flat), .red(red), .green(green), .blue(blue),
    .sound_fire(sound_fire), .sound_hit(sound_hit), .sound_dive(sound_dive),
    .sound_player_die(sound_player_die), .sound_win(sound_win),
    .sound_game_over(sound_game_over),
    .sound_powerup(sound_powerup), .sound_laser(sound_laser)
);

generate
    if (AUTO_DEMO) begin : AUTO_BLOCK
        auto_game_controller auto_controller_inst (
            .clk(clk), .rst(rst), .frame_tick(frame_tick), .enable(auto_enable),
            .win(win), .fire_ready(fire_ready), .fire_accepted(fire_accepted),
            .ship_x(ship_x), .ship_y(ship_y), .target_x_flat(target_x_flat),
            .target_y_flat(target_y_flat), .alive_flags(alive_flags),
            .game_reset(auto_game_reset), .game_enable(auto_game_enable),
            .move_left(auto_move_left), .move_right(auto_move_right), .fire(auto_fire),
            .state_debug(auto_state_debug), .target_id_debug(target_id_debug), .aim_x_debug(aim_x_debug)
        );
    end else begin : NO_AUTO_BLOCK
        assign auto_game_reset   = 1'b0;
        assign auto_game_enable  = 1'b0;
        assign auto_move_left    = 1'b0;
        assign auto_move_right   = 1'b0;
        assign auto_fire         = 1'b0;
        assign auto_state_debug  = 3'd0;
        assign target_id_debug   = 4'd0;
        assign aim_x_debug       = 11'd0;
    end
endgenerate

assign game_reset_debug  = effective_game_reset;
assign game_enable_debug = effective_game_enable;
assign move_left_debug   = effective_move_left;
assign move_right_debug  = effective_move_right;
assign fire_debug        = effective_fire;

endmodule
