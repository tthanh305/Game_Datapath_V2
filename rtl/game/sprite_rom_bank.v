`timescale 1ns / 1ps
// =============================================================================
// Module: sprite_rom_bank (Steredenn Big Beautiful Pixels Edition)
// =============================================================================
// 1. SHIP & COMPONENT BANK (steredenn_ship_bank.hex):
//    - Words 0..5119    : 5 Frames Ship Banking 32x32 (1024 words/frame)
//    - Words 5120..6143 : 4 Frames Thruster Exhaust 16x16 (256 words/frame)
//    - Words 6144..6911 : 3 Frames Hit Sparks 16x16 (256 words/frame)
//
// 2. ENEMY FLEET BANK (steredenn_enemy_bank.hex):
//    - Words 0..2047    : Boss f0..f1 (32x32)
//    - Words 2048..4095 : Escort f0..f1 (32x32)
//    - Words 4096..6143 : Drone f0..f1 (32x32)
//
// 3. STEREDENN 16-FRAME MASSIVE EXPLOSION BANK (steredenn_exp_bank.hex):
//    - Words 0..65535   : 16 Frames 64x64 Chunky Smoke & Anamorphic Flare
// =============================================================================

module sprite_rom_bank (
    input  wire        clk,

    // --- Port 1: Tàu người chơi nghiêng (0..4) ---
    input  wire [2:0]  ship_bank_frame, // 0..4
    input  wire [4:0]  ship_x,          // 0..31
    input  wire [4:0]  ship_y,          // 0..31
    output reg  [23:0] ship_rgb,

    // --- Port 2: Lửa động cơ phản lực (0..3) ---
    input  wire [1:0]  thruster_frame,  // 0..3
    input  wire [3:0]  thruster_x,      // 0..15
    input  wire [3:0]  thruster_y,      // 0..15
    output reg  [23:0] thruster_rgb,

    // --- Port 3: Hit Sparks (0..2) ---
    input  wire [1:0]  hit_spark_frame, // 0..2
    input  wire [3:0]  hit_spark_x,     // 0..15
    input  wire [3:0]  hit_spark_y,     // 0..15
    output reg  [23:0] hit_spark_rgb,

    // --- Port 4: Đội hình quái địch (Boss, Escort, Drone) ---
    input  wire [1:0]  enemy_kind,      // 0: Boss, 1: Escort, 2: Drone
    input  wire        enemy_anim,      // 0..1
    input  wire [4:0]  enemy_x,         // 0..31
    input  wire [4:0]  enemy_y,         // 0..31
    output reg  [23:0] enemy_rgb,

    // --- Port 5: Steredenn 16-Frame Massive Explosion (64x64) ---
    input  wire [3:0]  exp_frame,       // 0..15
    input  wire [5:0]  exp_x,           // 0..63
    input  wire [5:0]  exp_y,           // 0..63
    output reg  [23:0] exp_rgb
);

    // =========================================================================
    // 1. SHIP & COMPONENT BRAM (6,912 words)
    // =========================================================================
    (* ram_style = "block" *) reg [23:0] ship_rom [0:6911];

    wire [12:0] ship_addr = {ship_bank_frame, ship_y, ship_x};
    wire [12:0] thrust_addr = 13'd5120 + {thruster_frame, thruster_y, thruster_x};
    wire [12:0] spark_addr  = 13'd6144 + {hit_spark_frame, hit_spark_y, hit_spark_x};

    initial begin
        $readmemh("steredenn_ship_bank.hex", ship_rom);
    end

    always @(posedge clk) begin
        ship_rgb      <= ship_rom[ship_addr];
        thruster_rgb  <= ship_rom[thrust_addr];
        hit_spark_rgb <= ship_rom[spark_addr];
    end

    // =========================================================================
    // 2. ENEMY FLEET BRAM (6,144 words)
    // =========================================================================
    (* ram_style = "block" *) reg [23:0] enemy_rom [0:6143];

    wire [12:0] enemy_addr = {enemy_kind, enemy_anim, enemy_y, enemy_x};

    initial begin
        $readmemh("steredenn_enemy_bank.hex", enemy_rom);
    end

    always @(posedge clk) begin
        enemy_rgb <= enemy_rom[enemy_addr];
    end

    // =========================================================================
    // 3. STEREDENN 16-FRAME MASSIVE EXPLOSION BRAM (65,536 words)
    // =========================================================================
    (* ram_style = "block" *) reg [23:0] exp_rom [0:65535];

    wire [15:0] exp_addr = {exp_frame, exp_y, exp_x};

    initial begin
        $readmemh("steredenn_exp_bank.hex", exp_rom);
    end

    always @(posedge clk) begin
        exp_rgb <= exp_rom[exp_addr];
    end

endmodule
