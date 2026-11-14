`timescale 1ns / 1ps
`include "game_params.vh"

// PCK-domain adapter between the unchanged 720p counters, menu, and game.
// The game/Control Path interface remains available at game_core.
module game_video #(
    parameter integer BUTTON_ACTIVE_LOW = 1,
    parameter integer DEBOUNCE_FRAMES = 1,
    parameter integer CRT_SCANLINE_EN = 0
)(
    input wire pck,
    input wire system_reset,
    input wire clock_locked,
    input wire [1:0] timing_active,
    input wire [1:0] timing_requested,
    input wire [4:0] buttons_raw,
    input wire [10:0] hcount,
    input wire [10:0] vcount,
    input wire pixel_active,
    input wire [10:0] pixel_x,
    input wire [10:0] pixel_y,
    output reg [7:0] red = 8'h00,
    output reg [7:0] green = 8'h00,
    output reg [7:0] blue = 8'h00,
    output reg data_enable = 1'b0,

    output wire frame_tick_debug,
    output wire game_reset_debug,
    output wire round_reset_debug,
    output wire [10:0] ship_x_debug,
    output wire [10:0] projectile_y_debug,
    output wire projectile_active_debug,
    output wire [`GAME_SCORE_WIDTH-1:0] score_debug,
    output wire win_debug,
    output wire [2:0] auto_state_debug,
    output wire buzzer_out
);

wire video_reset_pck, game_reset_pck, requested_720p_sync, game_frame_tick;
wire [7:0] game_red, game_green, game_blue;
wire [7:0] menu_red, menu_green, menu_blue;
reg menu_active_d, scoreboard_active_d;
// Game rendering is only enabled in 720p. Derive pixel coordinates directly
// from scan counters to remove timing_sel from the game color critical path.
wire game_pixel_active_720p = (timing_active == 2'd2) && pixel_active;
// Scanline coordinate registers: captures hcount - 368 and vcount - 30 to isolate
// scan counter routing from pixel-clock color decoding logic and meet 720p timing.
reg [10:0] game_pixel_x_720p = 11'd0;
reg [10:0] game_pixel_y_720p = 11'd0;
always @(posedge pck) begin
    if (video_reset_pck) begin
        game_pixel_x_720p <= 11'd0;
        game_pixel_y_720p <= 11'd0;
    end else begin
        game_pixel_x_720p <= hcount - 11'd368;
        game_pixel_y_720p <= vcount - 11'd30;
    end
end
wire [7:0] hud_red, hud_green, hud_blue;
wire hud_pixel_on;
wire game_enable, move_left, move_right, move_up, move_down, fire, laser_trigger;
wire menu_active, scoreboard_active;
wire [1:0] selected_option;
wire [`GAME_SCORE_WIDTH-1:0] high_score;
wire [`GAME_SCORE_WIDTH-1:0] current_score;
wire current_win, fire_accepted;
wire [2:0] control_state;
wire [23:0] hud_color;
wire [`GAME_SCORE_WIDTH-1:0] hud_score = scoreboard_active ? high_score : current_score;
wire hud_win = current_win && !scoreboard_active;

game_clock_reset #(.REQUESTED_720P_IS_SYNCED(1)) reset_inst (
    .pck(pck), .system_reset(system_reset), .clock_locked(clock_locked),
    .requested_720p(timing_requested == 2'd2),
    .active_720p(timing_active == 2'd2), .video_reset(video_reset_pck),
    .game_reset(game_reset_pck),
    .requested_720p_sync(requested_720p_sync)
);

frame_tick frame_tick_inst (
    .clk(pck), .rst(video_reset_pck), .enable(!game_reset_pck),
    .hcount(hcount), .vcount(vcount), .tick(game_frame_tick)
);

wire sound_fire, sound_hit, sound_dive, sound_player_die, sound_win, sound_game_over;
wire sound_powerup, sound_laser;
wire game_over;
wire [6:0] wave_num;
wire [`GAME_SCORE_WIDTH-1:0] high_score_2;
wire [`GAME_SCORE_WIDTH-1:0] high_score_3;

game_core #(.AUTO_DEMO(0)) game_core_inst (
    .clk(pck), .rst(game_reset_pck), .frame_tick(game_frame_tick),
    .pixel_active(game_pixel_active_720p), .pixel_x(game_pixel_x_720p), .pixel_y(game_pixel_y_720p),
    .auto_enable(1'b0),
    .control_game_reset(round_reset_debug), .control_game_enable(game_enable),
    .control_move_left(move_left), .control_move_right(move_right),
    .control_move_up(move_up), .control_move_down(move_down),
    .control_fire(fire), .control_laser_trigger(laser_trigger),
    .hit_flag(), .hit_target_id(), .fire_ready(), .fire_accepted(fire_accepted),
    .score(current_score), .win(current_win), .game_over(game_over), .wave_num(wave_num),
    .alive_flags(), .ship_x(ship_x_debug),
    .ship_y(), .projectile_x(), .projectile_y(projectile_y_debug),
    .projectile_active(projectile_active_debug), .target_x_flat(), .target_y_flat(),
    .red(game_red), .green(game_green), .blue(game_blue),
    .game_reset_debug(), .game_enable_debug(), .move_left_debug(), .move_right_debug(),
    .fire_debug(), .auto_state_debug(), .target_id_debug(), .aim_x_debug(),
    .sound_fire(sound_fire), .sound_hit(sound_hit), .sound_dive(sound_dive),
    .sound_player_die(sound_player_die), .sound_win(sound_win),
    .sound_game_over(sound_game_over),
    .sound_powerup(sound_powerup), .sound_laser(sound_laser)
);

game_buzzer buzzer_inst (
    .clk(pck),
    .rst(video_reset_pck),
    .frame_tick(game_frame_tick),
    .sound_fire(sound_fire),
    .sound_hit(sound_hit),
    .sound_dive(sound_dive),
    .sound_player_die(sound_player_die),
    .sound_win(sound_win),
    .sound_game_over(sound_game_over),
    .sound_powerup(sound_powerup),
    .sound_laser(sound_laser),
    .buzzer_out(buzzer_out)
);

game_control_path #(
    .BUTTON_ACTIVE_LOW(BUTTON_ACTIVE_LOW), .DEBOUNCE_FRAMES(DEBOUNCE_FRAMES)
) control_path_inst (
    .clk(pck), .rst(game_reset_pck), .frame_tick(game_frame_tick),
    .buttons_raw(buttons_raw), .game_win(current_win), .game_over(game_over),
    .fire_accepted(fire_accepted),
    .score(current_score), .game_reset(round_reset_debug), .game_enable(game_enable),
    .move_left(move_left), .move_right(move_right),
    .move_up(move_up), .move_down(move_down),
    .fire(fire), .laser_trigger(laser_trigger),
    .menu_active(menu_active), .scoreboard_active(scoreboard_active),
    .selected_option(selected_option), .high_score(high_score),
    .high_score_2(high_score_2), .high_score_3(high_score_3),
    .state_debug(control_state)
);

always @(posedge pck) begin
    if (video_reset_pck) begin
        menu_active_d <= 1'b0;
        scoreboard_active_d <= 1'b0;
    end else begin
        menu_active_d <= menu_active;
        scoreboard_active_d <= scoreboard_active;
    end
end

game_menu_renderer_timed menu_renderer_inst (
    .clk(pck), .rst(video_reset_pck),
    .active(menu_active), .selected_option(selected_option),
    .x(game_pixel_x_720p), .y(game_pixel_y_720p), .red(menu_red), .green(menu_green), .blue(menu_blue)
);

game_hud hud_inst (
    .pixel_x(game_pixel_x_720p), .pixel_y(game_pixel_y_720p), .score(hud_score), .win(1'b0),
    .game_over(1'b0), .wave_num(wave_num),
    .scoreboard_active(scoreboard_active), .high_score_2(high_score_2), .high_score_3(high_score_3),
    .laser_ready(1'b0),
    .pixel_on(hud_pixel_on), .color(hud_color)
);

// The original RGB/DE output latency remains aligned. HS/VS and the
// AXI/MMCM/TMDS path remain untouched. Other timings display black.
always @(posedge pck) begin
    if (video_reset_pck) begin
        red <= 0;
        green <= 0;
        blue <= 0;
        data_enable <= 1'b0;
    end else begin
        data_enable <= pixel_active;
        if (game_pixel_active_720p && !game_reset_pck) begin
            if (menu_active_d) begin
                if (scoreboard_active_d && hud_pixel_on) begin
                    red <= hud_color[23:16];
                    green <= hud_color[15:8];
                    blue <= hud_color[7:0];
                end else begin
                    red <= menu_red;
                    green <= menu_green;
                    blue <= menu_blue;
                end
            end else begin
                red   <= game_red;
                green <= game_green;
                blue  <= game_blue;
            end
        end else begin
            red <= 0;
            green <= 0;
            blue <= 0;
        end
    end
end

assign frame_tick_debug = game_frame_tick;
assign game_reset_debug = game_reset_pck;
assign score_debug = current_score;
assign win_debug = current_win;
assign auto_state_debug = control_state;
endmodule
