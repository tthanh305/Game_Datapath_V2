`timescale 1ns / 1ps
`include "game_params.vh"

// Temporary, deterministic controller. Everything belongs to clk/PCK.
// Clock-by-clock handshake bookkeeping is independent of frame_tick.
module auto_game_controller #(
    parameter integer WIN_HOLD_FRAMES = 180,
    parameter integer ALIGN_TOLERANCE = `GAME_SHIP_SPEED / 2
)(
    input wire clk,
    input wire rst,
    input wire frame_tick,
    input wire demo_enable,
    input wire [`GAME_COORD_WIDTH-1:0] ship_x,
    input wire [`GAME_TARGET_COUNT-1:0] alive_flags,
    input wire [`GAME_TARGET_COUNT*`GAME_COORD_WIDTH-1:0] target_x_flat,
    input wire fire_ready,
    input wire fire_accepted,
    input wire projectile_active,
    input wire win,

    output reg game_reset,
    output reg game_enable,
    output reg move_left,
    output reg move_right,
    output reg fire,
    output wire [2:0] state_debug,
    output reg [`GAME_TARGET_ID_WIDTH-1:0] target_id_debug,
    output reg [`GAME_COORD_WIDTH-1:0] aim_x_debug
);

localparam [2:0] RESET_GAME = 3'd0;
localparam [2:0] WAIT_RESET = 3'd1;
localparam [2:0] SEEK_TARGET = 3'd2;
localparam [2:0] WAIT_ACCEPT = 3'd3;
localparam [2:0] WAIT_RESULT = 3'd4;
localparam [2:0] HOLD_WIN = 3'd5;
localparam integer HOLD_FRAMES = WIN_HOLD_FRAMES > 0 ? WIN_HOLD_FRAMES : 1;
localparam integer HOLD_WIDTH = HOLD_FRAMES > 1 ? $clog2(HOLD_FRAMES) : 1;
localparam integer SHIP_MAX_X = `GAME_SCREEN_WIDTH - `GAME_SHIP_WIDTH;

reg [2:0] state;
reg [HOLD_WIDTH-1:0] hold_count;
reg target_found, aligned;
integer column_index, row_index, object_index;
integer selected_x, desired_x;
assign state_debug = state;

always @* begin
    target_found = 1'b0;
    target_id_debug = 0;
    aim_x_debug = 0;
    selected_x = 0;
    desired_x = 0;
    object_index = 0;
    aligned = 1'b0;

    // First live column, bottom live row first. Target coordinates come from
    // the Datapath bus, rather than a second hard-coded placement table.
    for (column_index = 0; column_index < `GAME_TARGET_COLS;
         column_index = column_index + 1) begin
        for (row_index = `GAME_TARGET_ROWS - 1; row_index >= 0;
             row_index = row_index - 1) begin
            object_index = row_index*`GAME_TARGET_COLS + column_index;
            if (!target_found && alive_flags[object_index]) begin
                target_found = 1'b1;
                target_id_debug = object_index;
                selected_x = target_x_flat[object_index*`GAME_COORD_WIDTH +: `GAME_COORD_WIDTH];
            end
        end
    end

    desired_x = selected_x + (`GAME_TARGET_WIDTH / 2) - (`GAME_SHIP_WIDTH / 2);
    if (desired_x < 0) desired_x = 0;
    if (desired_x > SHIP_MAX_X) desired_x = SHIP_MAX_X;
    if (target_found) begin
        aim_x_debug = desired_x;
        aligned = ship_x + ALIGN_TOLERANCE >= desired_x &&
                  ship_x <= desired_x + ALIGN_TOLERANCE;
    end

    game_reset = 1'b0;
    game_enable = 1'b0;
    move_left = 1'b0;
    move_right = 1'b0;
    fire = 1'b0;

    if (!rst && demo_enable) begin
        case (state)
            RESET_GAME: game_reset = 1'b1;
            SEEK_TARGET, WAIT_ACCEPT, WAIT_RESULT: begin
                game_enable = !win;
                if (!win) begin
                    if (state == SEEK_TARGET && target_found && !projectile_active) begin
                        if (!aligned) begin
                            move_left = ship_x > desired_x;
                            move_right = ship_x < desired_x;
                        end else begin
                            fire = fire_ready;
                        end
                    end else if (state == WAIT_ACCEPT) begin
                        // Keep the request until an ACK/active feedback is seen.
                        fire = 1'b1;
                    end
                end
            end
            default: begin end
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        state <= RESET_GAME;
        hold_count <= 0;
    end else begin
        case (state)
            RESET_GAME: begin
                hold_count <= 0;
                if (demo_enable) state <= WAIT_RESET;
            end
            WAIT_RESET: begin
                hold_count <= 0;
                if (demo_enable) state <= SEEK_TARGET;
            end
            HOLD_WIN: begin
                // Only display frames count towards the win dwell time.
                // Pausing the demo also pauses the dwell counter.
                if (demo_enable && frame_tick) begin
                    if (hold_count == HOLD_FRAMES - 1) begin
                        hold_count <= 0;
                        state <= RESET_GAME;
                    end else begin
                        hold_count <= hold_count + 1'b1;
                    end
                end
            end
            SEEK_TARGET, WAIT_ACCEPT, WAIT_RESULT: begin
                hold_count <= 0;
                if (win) begin
                    state <= HOLD_WIN;
                end else begin
                    case (state)
                        SEEK_TARGET: begin
                            if (projectile_active)
                                state <= WAIT_RESULT;
                            else if (demo_enable && frame_tick && target_found &&
                                     aligned && fire_ready)
                                state <= WAIT_ACCEPT;
                        end
                        WAIT_ACCEPT: begin
                            // Consume the one-clock event even between frames,
                            // including a pause immediately after acceptance.
                            if (fire_accepted || projectile_active)
                                state <= WAIT_RESULT;
                        end
                        WAIT_RESULT: begin
                            if (!projectile_active && !fire_accepted)
                                state <= SEEK_TARGET;
                        end
                        default: begin end
                    endcase
                end
            end
            default: begin
                state <= RESET_GAME;
                hold_count <= 0;
            end
        endcase
    end
end

endmodule
