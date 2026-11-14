`timescale 1ns / 1ps

// =============================================================================
// Module: sprite_rom_32x32 (Dual-Port BRAM 32-Tile Sprite & VFX ROM)
// 32 Sprites / VFX tiles of 32x32 pixels, 4-bit color index
// Total depth: 32 * 1024 = 32,768 words x 4-bit (4 RAMB36E1 blocks, 0 mux LUTs)
//
// Tile Layout (5-bit tile_id[4:0]):
//   Tile 00 (0x0000): Player Interceptor Ship - Straight (32x32)
//   Tile 01 (0x0400): Row 0 Elite Alien - Frame 0 (32x32)
//   Tile 02 (0x0800): Row 1 Escort Alien - Frame 0 (32x32)
//   Tile 03 (0x0C00): Row 2/3 Drone Alien - Frame 0 (32x32)
//   Tile 04 (0x1000): Hexagonal Energy Shield + 2 Gun-pods (32x32)
//   Tile 05 (0x1400): Legacy Asteroid (32x32)
//   Tile 06 (0x1800): 4 sub-tiles 16x16:
//                     [Top-Left]:     Starburst Muzzle Flash
//                     [Top-Right]:    Item [P] Power-Up Capsule
//                     [Bottom-Left]:  Item [S] Shield Capsule
//                     [Bottom-Right]: Item [R] Rage/Laser Capsule
//   Tile 07..10:      4-Stage Explosion Animation (32x32)
//   Tile 11 (0x2C00): Overdrive Laser Emitter Shockwave Ring (32x32)
//   Tile 12..15:      Native 64x64 Giant Cratered Asteroid (TL=12, TR=13, BL=14, BR=15)
//   Tile 16 (0x4000): Player Interceptor Ship - Bank Left (32x32)
//   Tile 17 (0x4400): Row 0 Elite Alien - Frame 1 (32x32)
//   Tile 18 (0x4800): Row 1 Escort Alien - Frame 1 (32x32)
//   Tile 19 (0x4C00): Row 2/3 Drone Alien - Frame 1 (32x32)
//   Tile 20 (0x5000): Player Interceptor Ship - Bank Right (32x32)
//   Tile 21 (0x5400): Row 0 Elite Alien - Frame 2 (Deep Flap & Core Surge)
//   Tile 22 (0x5800): Row 1 Escort Alien - Frame 2 (Twin Scythe Strike & Visor Flare)
//   Tile 23 (0x5C00): Row 2/3 Drone Alien - Frame 2 (Tentacles Curled & Cannon Surge)
//   Tile 24..27:      Native 64x64 Dreadnought Boss - Frame 0 (TL=24, TR=25, BL=26, BR=27)
//   Tile 28..31:      Native 64x64 Dreadnought Boss - Frame 1 (TL=28, TR=29, BL=30, BR=31)
// =============================================================================

(* keep_hierarchy = "yes" *)
module sprite_rom_32x32 (
    input  wire        clk,
    // Port A (Main entities: Player Ship, Enemies, Explosions, 64x64 Boss & Asteroid)
    input  wire [14:0] addr_a,
    output reg  [3:0]  data_a,
    // Port B (Overlays: Shield + Gun-pods, Muzzle Flash, Item [P]/[S]/[R] Capsules, Shockwave)
    input  wire [14:0] addr_b,
    output reg  [3:0]  data_b
);

    (* ram_style = "block" *) reg [3:0] rom [0:32767];

    initial begin
        // Vivado registers this memory in sources_1; standalone simulation
        // scripts stage the canonical rtl/game asset in their run directory.
        $readmemh("sprites_32x32.mem", rom);
    end

    always @(posedge clk) begin
        data_a <= rom[addr_a];
        data_b <= rom[addr_b];
    end

endmodule
