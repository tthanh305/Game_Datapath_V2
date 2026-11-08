`timescale 1ns / 1ps

// ============================================================================
// Galaxian Authentic Sprite & Explosion Generator (32x32 Pixel Matrix)
// Re-engineered 100% faithful to the authentic NES / Arcade Galaxian video:
//   1. Galaxip (Player Ship): Red dome nose, Cyan central columns with red divider,
//      twin vertical white engine pods with Cyan cores, and dynamic thruster flame.
//   2. Boss Galaxian (Commander): Red crown/spike, Orange/Yellow chest, Blue wings.
//   3. Red Escort Alien (Guard): Red body, Orange glowing eyes, Blue wings.
//   4. Green Drone Alien: Green body with twin horns & brow bar, Orange eyes, Blue wings.
//   5. Banking Tilt Animation: Authentic roll tilt (left wing up/right wing down).
//   6. Rotating Pinwheel Cross Explosion: Authentic 4-phase shard & lightning burst.
//   7. Alien Flash Explosion: 4-stage starburst to dissipating particle ring.
//
// High-Speed Timing Closure (720p 60Hz):
//   Zero adders or carry-chains on the critical pixel evaluation path.
//   Pure constant bounds and bitwise equality for maximum positive timing slack.
// ============================================================================
module galaxian_sprites (
    input  wire [2:0]         sprite_type,  // 0:none, 1:ship, 2:boss, 3:escort, 4:drone, 5:explosion, 6:bomb
    input  wire [1:0]         anim_phase,   // 0..3 wing flap / explosion phase
    input  wire signed [1:0]  tilt_dir,     // -1: left tilt, 0: upright, +1: right tilt
    input  wire [5:0]         rel_x,        // 0..31
    input  wire [5:0]         rel_y,        // 0..31
    output reg                sprite_on,
    output reg  [23:0]        sprite_color
);

// Sprite Type Constants
localparam [2:0] TYPE_NONE      = 3'd0;
localparam [2:0] TYPE_SHIP      = 3'd1;
localparam [2:0] TYPE_BOSS      = 3'd2; // Flagship (Red Crown, Yellow/Orange, Blue wings)
localparam [2:0] TYPE_ESCORT    = 3'd3; // Red Alien (Red, Orange eyes, Blue wings)
localparam [2:0] TYPE_DRONE     = 3'd4; // Green Drone (Green body, Orange eyes, Blue wings)
localparam [2:0] TYPE_EXPLOSION = 3'd5; // Pinwheel Cross / Starburst
localparam [2:0] TYPE_BOMB      = 3'd6; // White Vertical Bomb

// Authentic NES Galaxian Color Palette
localparam [23:0] C_BLACK   = 24'h000000;
localparam [23:0] C_WHITE   = 24'hFFFFFF;
localparam [23:0] C_RED     = 24'hFF1A1A;
localparam [23:0] C_ORANGE  = 24'hFF8800;
localparam [23:0] C_YELLOW  = 24'hFFE600;
localparam [23:0] C_GREEN   = 24'h00E500;
localparam [23:0] C_CYAN    = 24'h00E5FF;
localparam [23:0] C_BLUE    = 24'h0066FF;

// Symmetrical Coordinates around Center (15.5, 15.5) -> dx = 0..15, dy = 0..31, abs_dy = 0..15
wire is_right_half = rel_x[4];
wire [4:0] dx      = {1'b0, is_right_half ? rel_x[3:0] : ~rel_x[3:0]};
wire [4:0] dy      = rel_y[4:0];
wire [4:0] abs_dy  = {1'b0, rel_y[4] ? rel_y[3:0] : ~rel_y[3:0]};

// Pre-computed wing flap limits (Zero adders on critical path)
wire [4:0] wing_max_boss   = anim_phase[0] ? 5'd11 : 5'd9;
wire [4:0] wing_max_escort = anim_phase[0] ? 5'd11 : 5'd9;
wire [4:0] wing_max_drone  = anim_phase[0] ? 5'd11 : 5'd9;

// Banking wing Y-bounds (pure constant selection, 0 adders)
// When banking right (+1): left wing shifts UP, right wing shifts DOWN
// When banking left (-1): left wing shifts DOWN, right wing shifts UP
wire wing_raise = (tilt_dir == 2'sd1 && !is_right_half) || (tilt_dir == -2'sd1 && is_right_half);
wire wing_lower = (tilt_dir == 2'sd1 && is_right_half)  || (tilt_dir == -2'sd1 && !is_right_half);

always @* begin
    sprite_on    = 1'b0;
    sprite_color = C_BLACK;

    case (sprite_type)
        // =============================================================
        // 1. Galaxip Player Ship (Authentic NES Video Match)
        // =============================================================
        TYPE_SHIP: begin
            // A. Red Dome Nose (Rounded Umbrella Top)
            if (dy <= 5'd2 && dx <= 5'd3) begin
                sprite_on = 1'b1;
                sprite_color = C_RED;
            end
            else if (dy >= 5'd3 && dy <= 5'd6 && dx <= 5'd5) begin
                sprite_on = 1'b1;
                sprite_color = C_RED;
            end
            // B. Vertical Red Divider Line through Center Fuselage
            else if (dy >= 5'd7 && dy <= 5'd21 && dx <= 5'd1) begin
                sprite_on = 1'b1;
                sprite_color = C_RED;
            end
            // C. Cyan Center Fuselage Columns
            else if (dy >= 5'd7 && dy <= 5'd21 && dx >= 5'd2 && dx <= 5'd4) begin
                sprite_on = 1'b1;
                sprite_color = C_CYAN;
            end
            // D. Cyan Cross Struts connecting to Side Pods
            else if (dy >= 5'd13 && dy <= 5'd16 && dx >= 5'd5 && dx <= 5'd7) begin
                sprite_on = 1'b1;
                sprite_color = C_CYAN;
            end
            // E. Twin Outer Engine Pods / Wings (White Shell + Cyan Core)
            // Needle antenna tip on top of each pod
            else if (dy >= 5'd4 && dy <= 5'd7 && (dx == 5'd9 || dx == 5'd10)) begin
                sprite_on = 1'b1;
                sprite_color = C_WHITE;
            end
            // White Outer Shell of Pods
            else if (dy >= 5'd8 && dy <= 5'd24 && (dx == 5'd8 || dx == 5'd11)) begin
                sprite_on = 1'b1;
                sprite_color = C_WHITE;
            end
            // White Top and Bottom Caps of Pods
            else if ((dy == 5'd8 || dy == 5'd24 || dy == 5'd25) && (dx >= 5'd8 && dx <= 5'd11)) begin
                sprite_on = 1'b1;
                sprite_color = C_WHITE;
            end
            // Cyan Glowing Core inside each Pod
            else if (dy >= 5'd9 && dy <= 5'd23 && (dx == 5'd9 || dx == 5'd10)) begin
                sprite_on = 1'b1;
                sprite_color = C_CYAN;
            end
            // F. Dynamic Jet Thruster Flames (Flickering Exhaust Plume)
            else if (dy >= 5'd26 && dy <= (anim_phase[0] ? 5'd31 : 5'd28) &&
                     ((dx >= 5'd9 && dx <= 5'd10) || (dx <= 5'd1))) begin
                sprite_on = 1'b1;
                if (dy <= 5'd28)
                    sprite_color = anim_phase[1] ? C_YELLOW : C_WHITE;
                else
                    sprite_color = anim_phase[0] ? C_ORANGE : C_RED;
            end
        end

        // =============================================================
        // 2. Boss Galaxian (Yellow Flagship / Commander)
        // =============================================================
        TYPE_BOSS: begin
            // Red Trident Crown & Center Spike
            if (dy <= 5'd5 && dx <= 5'd2) begin
                sprite_on = 1'b1;
                sprite_color = C_RED;
            end
            else if (dy >= 5'd6 && dy <= 5'd10 && dx <= 5'd1) begin
                sprite_on = 1'b1;
                sprite_color = C_RED;
            end
            // Orange/Yellow Chest and Body
            else if (dy >= 5'd6 && dy <= 5'd12 && dx >= 5'd2 && dx <= 5'd6) begin
                sprite_on = 1'b1;
                sprite_color = C_ORANGE;
            end
            else if (dy >= 5'd12 && dy <= 5'd16 && dx <= 5'd4) begin
                sprite_on = 1'b1;
                sprite_color = C_YELLOW;
            end
            // Orange Tail Stem
            else if (dy >= 5'd16 && dy <= 5'd22 && dx <= 5'd1) begin
                sprite_on = 1'b1;
                sprite_color = C_ORANGE;
            end
            // Blue Flared Wings (with authentic banking tilt during dives)
            else if (dx >= 5'd6 && dx <= wing_max_boss &&
                    ((!wing_raise && !wing_lower && dy >= 5'd3 && dy <= 5'd15) ||
                     (wing_raise && dy >= 5'd1 && dy <= 5'd13) ||
                     (wing_lower && dy >= 5'd5 && dy <= 5'd17))) begin
                sprite_on = 1'b1;
                sprite_color = C_BLUE;
            end
        end

        // =============================================================
        // 3. Red Escort Alien (Galaxian Guard)
        // =============================================================
        TYPE_ESCORT: begin
            // Red Upper Horns / Mandibles
            if (dy >= 5'd3 && dy <= 5'd7 && (dx == 5'd1 || dx == 5'd5 || dx == 5'd6)) begin
                sprite_on = 1'b1;
                sprite_color = C_RED;
            end
            // Glowing Orange Eyes
            else if (dy >= 5'd8 && dy <= 5'd10 && (dx == 5'd2 || dx == 5'd3)) begin
                sprite_on = 1'b1;
                sprite_color = C_ORANGE;
            end
            // Red Main Body Dome
            else if (dy >= 5'd7 && dy <= 5'd17 && dx <= 5'd5) begin
                sprite_on = 1'b1;
                sprite_color = C_RED;
            end
            // Red Tail Stinger
            else if (dy >= 5'd18 && dy <= 5'd22 && dx <= 5'd1) begin
                sprite_on = 1'b1;
                sprite_color = C_RED;
            end
            // Blue Outer Wings (with authentic banking tilt during dives)
            else if (dx >= 5'd5 && dx <= wing_max_escort &&
                    ((!wing_raise && !wing_lower && dy >= 5'd12 && dy <= 5'd19) ||
                     (wing_raise && dy >= 5'd9  && dy <= 5'd16) ||
                     (wing_lower && dy >= 5'd15 && dy <= 5'd22))) begin
                sprite_on = 1'b1;
                sprite_color = C_BLUE;
            end
        end

        // =============================================================
        // 4. Green Drone Alien (Standard Convoy Fighter)
        // =============================================================
        TYPE_DRONE: begin
            // Green Vertical Horns
            if (dy <= 5'd5 && (dx == 5'd2 || dx == 5'd3)) begin
                sprite_on = 1'b1;
                sprite_color = C_GREEN;
            end
            // Upturned Brow Bar Tips
            else if (dy >= 5'd3 && dy <= 5'd5 && (dx == 5'd7 || dx == 5'd8)) begin
                sprite_on = 1'b1;
                sprite_color = C_GREEN;
            end
            // Horizontal Green Brow Bar
            else if (dy >= 5'd5 && dy <= 5'd8 && dx <= 5'd8) begin
                sprite_on = 1'b1;
                sprite_color = C_GREEN;
            end
            // Orange Glowing Eyes
            else if (dy >= 5'd7 && dy <= 5'd9 && (dx == 5'd2 || dx == 5'd3)) begin
                sprite_on = 1'b1;
                sprite_color = C_ORANGE;
            end
            // Green Diamond Chin pointing downwards (zero adders: constant ranges)
            else if ((dy >= 5'd9  && dy <= 5'd11 && dx <= 5'd5) ||
                     (dy >= 5'd12 && dy <= 5'd13 && dx <= 5'd3) ||
                     (dy >= 5'd14 && dy <= 5'd15 && dx <= 5'd1)) begin
                sprite_on = 1'b1;
                sprite_color = C_GREEN;
            end
            // Green Tail Tip
            else if (dy >= 5'd16 && dy <= 5'd18 && dx <= 5'd1) begin
                sprite_on = 1'b1;
                sprite_color = C_GREEN;
            end
            // Blue Flared Wings (with authentic banking tilt during dives)
            else if (dx >= 5'd5 && dx <= wing_max_drone &&
                    ((!wing_raise && !wing_lower && dy >= 5'd11 && dy <= 5'd17) ||
                     (wing_raise && dy >= 5'd8  && dy <= 5'd14) ||
                     (wing_lower && dy >= 5'd14 && dy <= 5'd20))) begin
                sprite_on = 1'b1;
                sprite_color = C_BLUE;
            end
        end

        // =============================================================
        // 5. Authentic Explosion (Rotating Pinwheel Cross & Alien Burst)
        // =============================================================
        TYPE_EXPLOSION: begin
            case (anim_phase)
                // --- Stage 0: Initial Cross Impact ---
                2'b00: begin
                    // Diagonal White Lightning Spikes
                    if ((dx == abs_dy) && dx <= 5'd11) begin
                        sprite_on = 1'b1;
                        sprite_color = C_WHITE;
                    end
                    // Jagged Flaming Red Petals
                    else if (dx >= 5'd1 && dx <= 5'd9 && abs_dy >= 5'd1 && abs_dy <= 5'd9 && (dx[1] ^ abs_dy[1])) begin
                        sprite_on = 1'b1;
                        sprite_color = C_RED;
                    end
                    // Intense Cyan Inner Core
                    else if (dx <= 5'd3 && abs_dy <= 5'd3) begin
                        sprite_on = 1'b1;
                        sprite_color = C_CYAN;
                    end
                end

                // --- Stage 1: 45-degree Rotated Pinwheel ---
                2'b01: begin
                    // Orthogonal White Spikes (Axis-aligned 0, 90, 180, 270 deg)
                    if ((dx <= 5'd1 && abs_dy <= 5'd13) || (abs_dy <= 5'd1 && dx <= 5'd13)) begin
                        sprite_on = 1'b1;
                        sprite_color = C_WHITE;
                    end
                    // Diagonal Flaming Red Petals
                    else if (dx >= 5'd2 && dx <= 5'd8 && abs_dy >= 5'd2 && abs_dy <= 5'd8) begin
                        sprite_on = 1'b1;
                        sprite_color = C_RED;
                    end
                    // Glowing Cyan Core
                    else if (dx <= 5'd4 && abs_dy <= 5'd4) begin
                        sprite_on = 1'b1;
                        sprite_color = C_CYAN;
                    end
                end

                // --- Stage 2: Wide Expanding Shard Burst ---
                2'b10: begin
                    // Extended White Lightning Spikes
                    if ((dx == abs_dy) && dx >= 5'd4 && dx <= 5'd15) begin
                        sprite_on = 1'b1;
                        sprite_color = C_WHITE;
                    end
                    // Expanding Red Debris Ring
                    else if ((dx == 5'd10 || dx == 5'd12 || abs_dy == 5'd10 || abs_dy == 5'd12) && (dx[1] ^ abs_dy[1])) begin
                        sprite_on = 1'b1;
                        sprite_color = C_RED;
                    end
                    // Cyan Core Ring
                    else if (dx <= 5'd5 && abs_dy <= 5'd5 && (dx >= 5'd2 || abs_dy >= 5'd2)) begin
                        sprite_on = 1'b1;
                        sprite_color = C_CYAN;
                    end
                end

                // --- Stage 3: Dissipating Embers & Starburst Dust ---
                2'b11: begin
                    if ((dx[1:0] == abs_dy[1:0]) && (dx <= 5'd15)) begin
                        sprite_on = 1'b1;
                        sprite_color = (rel_x[0] ^ rel_y[0]) ? C_ORANGE : C_RED;
                    end else if (dx <= 5'd2 && abs_dy <= 5'd2) begin
                        sprite_on = 1'b1;
                        sprite_color = C_WHITE;
                    end
                end
            endcase
        end

        // =============================================================
        // 6. Alien Bomb (Twin White Capsule as seen in Video)
        // =============================================================
        TYPE_BOMB: begin
            if (rel_x < 6'd6 && rel_y < 6'd14) begin
                sprite_on = 1'b1;
                sprite_color = C_WHITE;
            end
        end

        default: begin
            sprite_on    = 1'b0;
            sprite_color = C_BLACK;
        end
    endcase
end

endmodule
