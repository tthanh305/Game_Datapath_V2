`timescale 1ns / 1ps

// =============================================================================
// Module: space_bg_stereden
// Clean Deep-Space Slow Parallax Starfield (3 layers of slowly drifting stars,
// no nebula, no planet, pure dark cosmic background).
// =============================================================================

module space_bg_stereden (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_tick,
    input  wire        pixel_active,
    input  wire [10:0] pixel_x,
    input  wire [10:0] pixel_y,
    output reg         bg_active,
    output reg  [23:0] bg_color,
    output reg  [3:0]  bg_idx
);

`include "palette_lut.vh"

    // Sub-frame divider for slow, gentle scrolling
    reg [1:0] sub_cnt;
    reg [9:0] scroll_slow;
    reg [9:0] scroll_med;
    reg [9:0] scroll_fast;

    always @(posedge clk) begin
        if (rst) begin
            sub_cnt     <= 2'd0;
            scroll_slow <= 10'd0;
            scroll_med  <= 10'd0;
            scroll_fast <= 10'd0;
        end else if (frame_tick) begin
            sub_cnt     <= sub_cnt + 2'd1;
            // Layer 1 (Distant): 1 px every 4 frames (15 px/sec)
            if (sub_cnt == 2'b11)
                scroll_slow <= scroll_slow - 10'd1;
            // Layer 2 (Mid): 1 px every 2 frames (30 px/sec)
            if (sub_cnt[0] == 1'b1)
                scroll_med  <= scroll_med - 10'd1;
            // Layer 3 (Near): 1 px every frame (60 px/sec)
            scroll_fast <= scroll_fast - 10'd1;
        end
    end

    // Virtual Y coordinates (subtracting scroll makes stars drift downwards as y increases)
    wire [9:0] y_slow = pixel_y[9:0] + scroll_slow;
    wire [9:0] y_med  = pixel_y[9:0] + scroll_med;
    wire [9:0] y_fast = pixel_y[9:0] + scroll_fast;

    // XOR Pseudo-random hash permutations
    wire [9:0] h_slow = pixel_x[9:0] ^ {y_slow[4:0], y_slow[9:5]} ^ {y_slow[1:0], y_slow[9:2]};
    wire [9:0] h_med  = pixel_x[9:0] ^ {y_med[6:0],  y_med[9:7]}  ^ {y_med[3:0],  y_med[9:4]};
    wire [9:0] h_fast = pixel_x[9:0] ^ {y_fast[2:0], y_fast[9:3]} ^ {y_fast[5:0], y_fast[9:6]};

    wire star_slow_hit = (h_slow == 10'h15A);
    wire star_med_hit  = (h_med  == 10'h2B3);
    wire star_fast_hit = (h_fast == 10'h369);

    always @* begin
        bg_active = 1'b0;
        bg_color  = 24'h000000;
        bg_idx    = 4'h0;

        if (pixel_active) begin
            bg_active = 1'b1;

            if (star_fast_hit) begin
                bg_idx   = 4'h4;
                bg_color = h_fast[4] ? 24'hFFFFFF : get_rgb888(4'hB, 1'b0);
            end else if (star_med_hit) begin
                bg_idx   = 4'h5;
                bg_color = h_med[5] ? get_rgb888(4'h5, 1'b0) : 24'hFFAA44;
            end else if (star_slow_hit) begin
                bg_idx   = 4'h6;
                case (h_slow[3:2])
                    2'b00:   bg_color = 24'h3355AA;
                    2'b01:   bg_color = 24'h774488;
                    2'b10:   bg_color = 24'h338866;
                    default: bg_color = 24'h556688;
                endcase
            end else begin
                // Pure dark space background
                bg_idx   = 4'h1;
                bg_color = 24'h080810;
            end
        end
    end

endmodule
