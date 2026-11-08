`timescale 1ns / 1ps
// =============================================================================
// Galaxian Arcade Parallax Scrolling Starfield & Deep Space Nebulae Generator
// Inspired by "Devil Blade Reboot" - Multi-layered depth and cosmic dust
// Generates 3 layers of multicolored twinkling stars + 1 layer of drift nebulae
// =============================================================================
module galaxian_starfield (
    input  wire clk,
    input  wire rst,
    input  wire frame_tick,
    input  wire warp_speed,
    input  wire pixel_active,
    input  wire [10:0] pixel_x,
    input  wire [10:0] pixel_y,
    output reg  star_active,
    output reg  [23:0] star_color
);

reg [9:0] scroll_slow;
reg [9:0] scroll_med;
reg [9:0] scroll_fast;
reg [9:0] scroll_nebula;

// Update starfield scrolling on frame tick
always @(posedge clk) begin
    if (rst) begin
        scroll_slow   <= 10'd0;
        scroll_med    <= 10'd0;
        scroll_fast   <= 10'd0;
        scroll_nebula <= 10'd0;
    end else if (frame_tick) begin
        if (warp_speed) begin
            scroll_slow   <= scroll_slow   + 10'd6;
            scroll_med    <= scroll_med    + 10'd12;
            scroll_fast   <= scroll_fast   + 10'd20;
            scroll_nebula <= scroll_nebula + 10'd4;
        end else begin
            scroll_slow   <= scroll_slow   + 10'd1;
            scroll_med    <= scroll_med    + 10'd2;
            scroll_fast   <= scroll_fast   + 10'd3;
            // Tinh vân trôi cực chậm tạo chiều sâu vô tận (1 pixel sau mỗi 4 frame)
            scroll_nebula <= scroll_nebula + 10'd1;
        end
    end
end

// Virtual Y coordinates with power-of-2 wrap-around
wire [9:0] y_slow   = pixel_y[9:0] + scroll_slow;
wire [9:0] y_med    = pixel_y[9:0] + scroll_med;
wire [9:0] y_fast   = pixel_y[9:0] + scroll_fast;
wire [9:0] y_nebula = pixel_y[9:0] + {2'b00, scroll_nebula[9:2]};

// Ultra-fast combinational XOR-permutation hash
wire [9:0] h_slow   = pixel_x[9:0] ^ {y_slow[4:0], y_slow[9:5]} ^ {y_slow[1:0], y_slow[9:2]};
wire [9:0] h_med    = pixel_x[9:0] ^ {y_med[6:0], y_med[9:7]}   ^ {y_med[3:0], y_med[9:4]};
wire [9:0] h_fast   = pixel_x[9:0] ^ {y_fast[2:0], y_fast[9:3]}  ^ {y_fast[5:0], y_fast[9:6]};
wire [9:0] h_nebula = {pixel_x[8:0], 1'b0} ^ {y_nebula[5:0], y_nebula[9:6]};

// Star detection logic
wire star_slow_hit = (h_slow == 10'h15A);
wire star_med_hit  = (h_med  == 10'h2B3);
wire star_fast_hit = (h_fast == 10'h369);

// Nebula cloud filter: vùng mây khí vũ trụ mờ ảo (h_nebula match pattern)
wire nebula_hit = (h_nebula[9:5] == 5'b10101) && ((pixel_x[2:0] ^ pixel_y[2:0]) == 3'b000);

always @* begin
    star_active = 1'b0;
    star_color  = 24'h000000;
    if (pixel_active) begin
        if (star_fast_hit) begin
            star_active = 1'b1;
            // Bright White or Yellow fast stars (Lõi sao gần sáng chói)
            star_color = h_fast[4] ? 24'hFFFFFF : 24'hFFEE44;
        end else if (star_med_hit) begin
            star_active = 1'b1;
            // Cyan or Red medium stars
            star_color = h_med[5] ? 24'h00E5FF : 24'hFF4444;
        end else if (star_slow_hit) begin
            star_active = 1'b1;
            // Deep Blue, Magenta, or Soft Green background stars
            case (h_slow[3:2])
                2'b00:   star_color = 24'h4477FF;
                2'b01:   star_color = 24'hFF44CC;
                2'b10:   star_color = 24'h44DD66;
                default: star_color = 24'h8888BB;
            endcase
        end else if (nebula_hit) begin
            // Devil Blade Deep Cosmic Nebulae: bụi khí màu xanh thẫm / tím mờ ảo hậu cảnh
            star_active = 1'b1;
            star_color  = h_nebula[4] ? 24'h0a1530 : 24'h1e0a2b; // Xanh đen và tím than
        end
    end
end

endmodule
