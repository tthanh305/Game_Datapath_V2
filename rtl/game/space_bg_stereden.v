`timescale 1ns / 1ps

// =============================================================================
// Module: space_bg_stereden
// Enhanced Deep-Space Parallax Starfield with:
//   - 3 layers of drifting stars (Slow, Medium, Fast) using nonlinear GF(2)
//     quadratic mixing (eliminates all linear/diagonal/curtain streaks)
//   - Twinkling 3x3 Cross Stars on the near layer
//   - Seamless Triangle-Wave Bayer-Dithered Cosmic Nebula ribbons
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

    reg [2:0] sub_cnt;
    reg [9:0] scroll_slow;
    reg [9:0] scroll_med;
    reg [9:0] scroll_fast;

    always @(posedge clk) begin
        if (rst) begin
            sub_cnt     <= 3'd0;
            scroll_slow <= 10'd0;
            scroll_med  <= 10'd0;
            scroll_fast <= 10'd0;
        end else if (frame_tick) begin
            sub_cnt     <= sub_cnt + 3'd1;
            // Layer 1 (Distant): 1 px every 4 frames (15 px/sec)
            if (sub_cnt[1:0] == 2'b11)
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

    // Nonlinear 10-bit hash function (combines shift-add prime multiples + AND-gate cross terms)
    function automatic [9:0] star_hash10(input [10:0] x, input [9:0] y, input [9:0] seed);
        reg [9:0] mx, my, nl;
        begin
            mx = x[9:0] ^ {x[6:0], x[9:7]} ^ {x[2:0], x[9:3]} ^ {9'd0, x[10]};
            my = y      ^ {y[4:0], y[9:5]} ^ {y[1:0], y[9:2]};
            nl = ({mx[4:0], mx[9:5]} & {my[6:0], my[9:7]}) ^
                 ({mx[7:0], mx[9:8]} & {my[2:0], my[9:3]});
            star_hash10 = mx ^ my ^ nl ^ seed;
        end
    endfunction

    wire [9:0] h_slow = star_hash10(pixel_x, y_slow, 10'h15A);
    wire [9:0] h_med  = star_hash10(pixel_x, y_med,  10'h2B3);
    wire [9:0] h_fast = star_hash10(pixel_x, y_fast, 10'h369);

    wire star_slow_hit = (h_slow == 10'h000);
    wire star_med_hit  = (h_med  == 10'h000);
    wire star_fast_hit = (h_fast == 10'h000);

    // Bright Twinkling Cross Star (sparse 4x4 cell grid on near layer)
    wire [7:0] cell_hash = (pixel_x[9:2] ^ {pixel_x[5:2], pixel_x[9:6]}) ^
                           (y_fast[9:2]  ^ {y_fast[4:2],  y_fast[9:5]}) ^
                           ({pixel_x[6:2], pixel_x[9:7]} & {y_fast[8:2], y_fast[9]});
    wire in_cross_cell = (cell_hash == 8'hA7) && (pixel_x[10] ^ y_fast[6]);
    wire [1:0] cx_sub  = pixel_x[1:0];
    wire [1:0] cy_sub  = y_fast[1:0];
    wire cross_core    = in_cross_cell && (cx_sub == 2'd1) && (cy_sub == 2'd1);
    wire cross_arm     = in_cross_cell && !sub_cnt[2] &&
                         (((cx_sub == 2'd1) && (cy_sub != 2'd3)) ||
                          ((cy_sub == 2'd1) && (cx_sub != 2'd3)));

    // Seamless Triangle-Wave Cosmic Nebula Ribbon (zero vertical discontinuity across 0..1279)
    wire [6:0] x_tri    = pixel_x[9] ? ~pixel_x[8:2] : pixel_x[8:2];
    wire [7:0] neb_wave = y_slow[9:2] + {2'b00, x_tri[6:1]};
    wire bayer_on       = (pixel_x[0] ^ y_slow[0]) && (pixel_x[1] ^ y_slow[1]);
    wire in_neb_band1   = (neb_wave >= 8'd64  && neb_wave < 8'd96)  && bayer_on;
    wire in_neb_band2   = (neb_wave >= 8'd180 && neb_wave < 8'd212) && bayer_on;

    always @* begin
        bg_active = 1'b0;
        bg_color  = 24'h000000;
        bg_idx    = 4'h0;

        if (pixel_active) begin
            bg_active = 1'b1;

            // Combat dodge zone (y >= 420): Dim/soften background stars so they never compete with small enemy bullets!
            if (pixel_y >= 11'd420) begin
                if (star_fast_hit) begin
                    bg_idx   = 4'h6;
                    bg_color = 24'h335577; // Gentle soft blue, zero pure white glare
                end else if (star_med_hit) begin
                    bg_idx   = 4'h2;
                    bg_color = 24'h223344;
                end else if (star_slow_hit) begin
                    bg_idx   = 4'h1;
                    bg_color = 24'h152233;
                end else if (in_neb_band1) begin
                    bg_idx   = 4'hD;
                    bg_color = 24'h100E24;
                end else if (in_neb_band2) begin
                    bg_idx   = 4'hE;
                    bg_color = 24'h0D1526;
                end else begin
                    bg_idx   = 4'h1;
                    bg_color = 24'h070812;
                end
            end else begin
                // Upper cosmic background: Full stellar brilliance
                if (cross_core) begin
                    bg_idx   = 4'h4;
                    bg_color = 24'hFFFFFF;
                end else if (cross_arm) begin
                    bg_idx   = 4'h5;
                    bg_color = pixel_x[4] ? 24'h55EEFF : 24'hFF99DD;
                end else if (star_fast_hit) begin
                    bg_idx   = 4'h4;
                    bg_color = pixel_x[3] ? 24'hFFFFFF : get_rgb888(4'hB, 1'b0);
                end else if (star_med_hit) begin
                    bg_idx   = 4'h5;
                    bg_color = pixel_x[4] ? get_rgb888(4'h5, 1'b0) : 24'hFFAA44;
                end else if (star_slow_hit) begin
                    bg_idx   = 4'h6;
                    case ({pixel_x[2], y_slow[2]})
                        2'b00:   bg_color = 24'h3366BB;
                        2'b01:   bg_color = 24'h8844AA;
                        2'b10:   bg_color = 24'h339977;
                        default: bg_color = 24'h557799;
                    endcase
                end else if (in_neb_band1) begin
                    bg_idx   = 4'hD;
                    bg_color = 24'h100E24;
                end else if (in_neb_band2) begin
                    bg_idx   = 4'hE;
                    bg_color = 24'h0D1526;
                end else begin
                    bg_idx   = 4'h1;
                    bg_color = 24'h070812;
                end
            end
        end
    end

endmodule
