`timescale 1ns / 1ps
`include "game_params.vh"

// =============================================================================
// Menu & Gameplay Control Path (Steredenn Shmup Edition)
// Button mapping:
//   K4 (U19) = Left   -> BTN[3] (Move Left in play)
//   K1 (T19) = Right  -> BTN[0] (Move Right in play)
//   K2 (P19) = Up     -> BTN[1] (Move Up in play, Move UP in menu)
//   K5 (V20) = Down   -> BTN[4] (Move Down in play, Move DOWN in menu)
//   K3 (U20) = Center -> BTN[2] (Press = Overdrive Laser; Hold >= 2s = Return to Menu)
// =============================================================================
module game_control_path #(
    parameter integer BUTTON_ACTIVE_LOW = 1,
    parameter integer DEBOUNCE_FRAMES = 1
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       frame_tick,
    input  wire [4:0] buttons_raw,
    input  wire       game_win,
    input  wire       game_over,
    input  wire       fire_accepted,
    input  wire [`GAME_SCORE_WIDTH-1:0] score,
    output reg        game_reset,
    output wire       game_enable,
    output wire       move_left,
    output wire       move_right,
    output wire       move_up,
    output wire       move_down,
    output wire       fire,
    output reg        laser_trigger,
    output wire       menu_active,
    output wire       scoreboard_active,
    output reg  [1:0] selected_option,
    output reg  [`GAME_SCORE_WIDTH-1:0] high_score,
    output reg  [`GAME_SCORE_WIDTH-1:0] high_score_2,
    output reg  [`GAME_SCORE_WIDTH-1:0] high_score_3,
    output wire [2:0] state_debug
);

localparam [2:0] MENU       = 3'd0,
                 PLAYING    = 3'd1,
                 SCOREBOARD = 3'd3,
                 WIN_SCREEN = 3'd4,
                 GAME_OVER  = 3'd5;

reg [2:0] state, return_state;
reg       game_started;
reg       fire_pending;
reg       center_hold_lock;
reg [7:0] center_hold_cnt;

wire [4:0] buttons_pressed, buttons_press_pulse;

game_button_input #(
    .BUTTON_ACTIVE_LOW(BUTTON_ACTIVE_LOW),
    .DEBOUNCE_FRAMES(DEBOUNCE_FRAMES)
) button_input_inst (
    .clk(clk),
    .rst(rst),
    .frame_tick(frame_tick),
    .buttons_raw(buttons_raw),
    .buttons_pressed(buttons_pressed),
    .buttons_press_pulse(buttons_press_pulse)
);

wire btn_right_held   = buttons_pressed[0];     // K1_T19
wire btn_up_held      = buttons_pressed[1];     // K2_P19
wire btn_center_held  = buttons_pressed[2];     // K3_U20
wire btn_left_held    = buttons_pressed[3];     // K4_U19
wire btn_down_held    = buttons_pressed[4];     // K5_V20

wire btn_right_pulse  = buttons_press_pulse[0]; // K1_T19
wire btn_up_pulse     = buttons_press_pulse[1]; // K2_P19
wire btn_center_pulse = buttons_press_pulse[2]; // K3_U20
wire btn_left_pulse   = buttons_press_pulse[3]; // K4_U19
wire btn_down_pulse   = buttons_press_pulse[4]; // K5_V20

assign game_enable       = (state == PLAYING) && !game_win && !game_over;
assign move_left         = game_enable && btn_left_held  && !btn_right_held;
assign move_right        = game_enable && btn_right_held && !btn_left_held;
assign move_up           = game_enable && btn_up_held    && !btn_down_held;
assign move_down         = game_enable && btn_down_held  && !btn_up_held;
assign fire              = game_enable && (fire_pending || laser_trigger);
assign menu_active       = (state == MENU) || (state == SCOREBOARD);
assign scoreboard_active = (state == SCOREBOARD);
assign state_debug       = state;

wire record_score_now = ((state == PLAYING) && (game_win || game_over)) ||
                        ((state == MENU) && btn_center_pulse && (selected_option == 2'd0) && game_started);

always @(posedge clk) begin
    if (rst) begin
        state            <= MENU;
        return_state     <= MENU;
        game_started     <= 1'b0;
        game_reset       <= 1'b0;
        fire_pending     <= 1'b0;
        laser_trigger    <= 1'b0;
        center_hold_lock <= 1'b0;
        center_hold_cnt  <= 8'd0;
        selected_option  <= 2'd0;
        high_score       <= {`GAME_SCORE_WIDTH{1'b0}};
        high_score_2     <= {`GAME_SCORE_WIDTH{1'b0}};
        high_score_3     <= {`GAME_SCORE_WIDTH{1'b0}};
    end else begin
        game_reset    <= 1'b0;
        laser_trigger <= 1'b0;

        if (!game_enable || fire_accepted)
            fire_pending <= 1'b0;

        // In non-playing states, release center hold lock when button is let go
        if (state != PLAYING) begin
            if (!btn_center_held) begin
                center_hold_lock <= 1'b0;
                center_hold_cnt  <= 8'd0;
            end
        end

        // Record score only when a run finishes (win / game_over) or is abandoned for a new mission
        if (record_score_now) begin
            if (score > high_score) begin
                high_score_3 <= high_score_2;
                high_score_2 <= high_score;
                high_score   <= score;
            end else if (score > high_score_2) begin
                high_score_3 <= high_score_2;
                high_score_2 <= score;
            end else if (score > high_score_3) begin
                high_score_3 <= score;
            end
        end

        // Transitions from PLAYING: Win or Game Over
        if ((state == PLAYING) && game_win) begin
            state           <= WIN_SCREEN;
            game_started    <= 1'b0;
            fire_pending    <= 1'b0;
            center_hold_cnt <= 8'd0;
        end else if ((state == PLAYING) && game_over) begin
            state           <= GAME_OVER;
            game_started    <= 1'b0;
            fire_pending    <= 1'b0;
            center_hold_cnt <= 8'd0;
        end else begin
            case (state)
                MENU: begin
                    center_hold_cnt <= 8'd0;
                    // Up (K2_P19): Move selection UP
                    if (btn_up_pulse) begin
                        selected_option <= (selected_option == 2'd0) ? 2'd2 : selected_option - 1'b1;
                    // Down (K5_V20): Move selection DOWN
                    end else if (btn_down_pulse) begin
                        selected_option <= (selected_option >= 2'd2) ? 2'd0 : selected_option + 1'b1;
                    // Center (K3_U20): Select / Start Game
                    end else if (btn_center_pulse) begin
                        case (selected_option)
                            2'd0: begin
                                game_reset       <= 1'b1;
                                game_started     <= 1'b1;
                                center_hold_lock <= 1'b1;
                                state            <= PLAYING;
                            end
                            2'd1: begin
                                if (game_started) begin
                                    center_hold_lock <= 1'b1;
                                    state            <= PLAYING;
                                end else begin
                                    game_reset       <= 1'b1;
                                    game_started     <= 1'b1;
                                    center_hold_lock <= 1'b1;
                                    state            <= PLAYING;
                                end
                            end
                            2'd2: begin
                                return_state <= MENU;
                                state        <= SCOREBOARD;
                            end
                            default: selected_option <= 2'd0;
                        endcase
                    end
                end

                PLAYING: begin
                    // Tap Center (Press & Release < 60 frames ~ 1.0s) -> Fire Overdrive Laser on release!
                    // Hold Center >= 60 frames (~1.0s) -> Exit to Pause/Menu without wasting Laser!
                    if (btn_center_held && !center_hold_lock) begin
                        if (frame_tick) begin
                            if (center_hold_cnt >= 8'd60) begin
                                state            <= MENU;
                                selected_option  <= 2'd1; // Highlight "CONTINUE/RESUME"
                                center_hold_cnt  <= 8'd0;
                                center_hold_lock <= 1'b1;
                            end else begin
                                center_hold_cnt <= center_hold_cnt + 8'd1;
                            end
                        end
                    end else begin
                        if (!btn_center_held) begin
                            if (!center_hold_lock && (center_hold_cnt > 8'd0) && (center_hold_cnt < 8'd60)) begin
                                laser_trigger <= 1'b1;
                                fire_pending  <= 1'b1;
                            end
                            center_hold_lock <= 1'b0;
                            center_hold_cnt  <= 8'd0;
                        end
                    end
                end

                SCOREBOARD: begin
                    if (btn_center_pulse || btn_up_pulse || btn_down_pulse || btn_left_pulse || btn_right_pulse)
                        state <= return_state;
                end

                WIN_SCREEN: begin
                    if (btn_center_pulse || btn_down_pulse) begin
                        game_reset       <= 1'b1;
                        game_started     <= 1'b1;
                        center_hold_lock <= 1'b1;
                        state            <= PLAYING;
                    end else if (btn_up_pulse || btn_left_pulse) begin
                        state           <= MENU;
                        selected_option <= 2'd0;
                    end
                end

                GAME_OVER: begin
                    if (btn_center_pulse || btn_down_pulse) begin
                        game_reset       <= 1'b1;
                        game_started     <= 1'b1;
                        center_hold_lock <= 1'b1;
                        state            <= PLAYING;
                    end else if (btn_up_pulse || btn_left_pulse) begin
                        state           <= MENU;
                        selected_option <= 2'd0;
                    end
                end

                default: begin
                    state           <= MENU;
                    selected_option <= 2'd0;
                    game_started    <= 1'b0;
                    fire_pending    <= 1'b0;
                end
            endcase
        end
    end
end

endmodule
