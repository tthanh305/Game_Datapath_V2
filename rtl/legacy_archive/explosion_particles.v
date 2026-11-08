`timescale 1ns / 1ps

// Galaxian Arcade 12-Spark Pixel Explosion Particle Generator
// Generates explosive outward-flying pixel sparks with velocity decay and color fading.
// Recreates authentic retro arcade destruction bursts with 0 DSP slices.
module explosion_particles (
    input  wire clk,
    input  wire rst,
    input  wire frame_tick,
    input  wire trigger,
    input  wire [10:0] origin_x,
    input  wire [10:0] origin_y,
    input  wire [10:0] pixel_x,
    input  wire [10:0] pixel_y,
    output reg  particle_on,
    output reg  [23:0] particle_color
);

reg [4:0]  life;
reg [10:0] p_x [0:11];
reg [10:0] p_y [0:11];

// Fixed radial directional velocity table (12 directions: Cardinals, Diagonals & Fast sparks)
wire signed [4:0] vel_x [0:11];
wire signed [4:0] vel_y [0:11];

assign vel_x[0]  =  5'sd3; assign vel_y[0]  =  5'sd0; // Right
assign vel_x[1]  =  5'sd2; assign vel_y[1]  =  5'sd2; // Down-Right
assign vel_x[2]  =  5'sd0; assign vel_y[2]  =  5'sd3; // Down
assign vel_x[3]  = -5'sd2; assign vel_y[3]  =  5'sd2; // Down-Left
assign vel_x[4]  = -5'sd3; assign vel_y[4]  =  5'sd0; // Left
assign vel_x[5]  = -5'sd2; assign vel_y[5]  = -5'sd2; // Up-Left
assign vel_x[6]  =  5'sd0; assign vel_y[6]  = -5'sd3; // Up
assign vel_x[7]  =  5'sd2; assign vel_y[7]  = -5'sd2; // Up-Right
assign vel_x[8]  =  5'sd5; assign vel_y[8]  =  5'sd1; // Fast East-Southeast
assign vel_x[9]  = -5'sd5; assign vel_y[9]  =  5'sd1; // Fast West-Southwest
assign vel_x[10] =  5'sd2; assign vel_y[10] = -5'sd5; // High North-Northeast
assign vel_x[11] = -5'sd2; assign vel_y[11] = -5'sd5; // High North-Northwest

integer k;
always @(posedge clk) begin
    if (rst) begin
        life <= 5'd0;
        for (k = 0; k < 12; k = k + 1) begin
            p_x[k] <= 11'd0;
            p_y[k] <= 11'd0;
        end
    end else if (trigger) begin
        life <= 5'd24; // 24 frames (~0.4 second burst)
        for (k = 0; k < 12; k = k + 1) begin
            p_x[k] <= origin_x + 11'd16; // Center of 32x32 target/sprite
            p_y[k] <= origin_y + 11'd16;
        end
    end else if (frame_tick && (life > 5'd0)) begin
        life <= life - 5'd1;
        for (k = 0; k < 12; k = k + 1) begin
            p_x[k] <= p_x[k] + {{6{vel_x[k][4]}}, vel_x[k]};
            p_y[k] <= p_y[k] + {{6{vel_y[k][4]}}, vel_y[k]};
        end
    end
end

// Particle pixel hit detection: 2x2 pixel cluster per particle
wire [11:0] hit;
genvar gi;
generate
    for (gi = 0; gi < 12; gi = gi + 1) begin : GEN_HIT
        wire [10:0] dx = pixel_x - p_x[gi];
        wire [10:0] dy = pixel_y - p_y[gi];
        assign hit[gi] = (dx <= 11'd1) && (dy <= 11'd1);
    end
endgenerate

wire any_hit = |hit;

// Chromatic heat-dissipation color palette
always @* begin
    if (life > 5'd0 && any_hit) begin
        particle_on = 1'b1;
        if (life >= 5'd18)
            // Initial flash: Pure White & Plasma Blue sparks
            particle_color = (hit[0] || hit[2] || hit[4] || hit[6]) ? 24'h00FFFF : 24'hFFFFFF;
        else if (life >= 5'd11)
            // Hot fire: Intense Golden Yellow
            particle_color = 24'hFFEE11;
        else if (life >= 5'd5)
            // Molten debris: Fiery Orange-Red
            particle_color = 24'hFF4400;
        else
            // Cooling embers: Fading Dark Crimson
            particle_color = 24'h881100;
    end else begin
        particle_on    = 1'b0;
        particle_color = 24'h000000;
    end
end

endmodule

