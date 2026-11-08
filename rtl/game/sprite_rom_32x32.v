`timescale 1ns / 1ps

// =============================================================================
// Module: sprite_rom_32x32 (Dual-Port BRAM Sprite ROM)
// 12 Sprites / VFX tiles of 32x32 pixels, 4-bit color index
// Total depth: 12 * 1024 = 12,288 words x 4-bit
//
// Tile Layout:
//   Tile 0  (0x0000): Player Ship (32x32)
//   Tile 1  (0x0400): Enemy Boss  (32x32)
//   Tile 2  (0x0800): Enemy Escort (32x32)
//   Tile 3  (0x0C00): Enemy Drone (32x32)
//   Tile 4  (0x1000): Purple Energy Shield + 2 Gun-pods (32x32)
//   Tile 5  (0x1400): Asteroid / Meteor (32x32)
//   Tile 6  (0x1800): 4 sub-tiles 16x16:
//                     [Top-Left]:     Muzzle Flash (rel_x[4]==0, rel_y[4]==0)
//                     [Top-Right]:    Pink Orb Bullet
//                     [Bottom-Left]:  Twin Blue Lasers
//                     [Bottom-Right]: Item P Power-up
//   Tile 7  (0x1C00): Explosion Frame 0 (32x32)
//   Tile 8  (0x2000): Explosion Frame 1 (32x32)
//   Tile 9  (0x2400): Explosion Frame 2 (32x32)
//   Tile 10 (0x2800): Explosion Frame 3 (32x32)
//   Tile 11 (0x2C00): Laser Beam Body & Impact Shockwave Ring
// =============================================================================

module sprite_rom_32x32 (
    input  wire        clk,
    // Port A (Main entities: Player Ship, Enemies, Explosions, Meteor)
    input  wire [13:0] addr_a,
    output reg  [3:0]  data_a,
    // Port B (Overlays: Shield + Gun-pods, Muzzle Flash, Sub-tile VFX)
    input  wire [13:0] addr_b,
    output reg  [3:0]  data_b
);

    (* ram_style = "block" *) reg [3:0] rom [0:12287];

    initial begin
        $readmemh("E:/Game_Datapath_V2/rtl/game/sprites_32x32.mem", rom);
    end

    always @(posedge clk) begin
        data_a <= rom[addr_a];
        data_b <= rom[addr_b];
    end

endmodule

