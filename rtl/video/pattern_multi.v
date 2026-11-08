`timescale 1ns / 1ps
`include "game_params.vh"

// Game Datapath V2 integration. Ports, timing selection, active coordinates,
// and the syncgen_multi instance are preserved from the working baseline.
// Clock/MMCM/TMDS implementation lives in the unchanged original modules.

module pattern_multi(
    input               CLK,
    input               RST,

    input       [1:0]   timing_sel,
    input       [1:0]   timing_sel_imm,

    // Giữ lại port này để tương thích module cấp trên.
    // Bản test Datapath hiện tại không sử dụng pattern_sel.
    input       [3:0]   pattern_sel,

    input               reconfig_req,
    input       [4:0]   BTN,

    output wire [7:0]   VGA_R,
    output wire [7:0]   VGA_G,
    output wire [7:0]   VGA_B,

    output              VGA_HS,
    output              VGA_VS,

    output wire         VGA_DE,

    output              PCK,
    output              SerialClk,

    output              locked,
    output              reconfig_done,
    output wire         BEEP
);


// ============================================================
// 1. VIDEO TIMING PARAMETERS
// ============================================================

// ------------------------------------------------------------
// VGA 640x480 @ 60 Hz
// ------------------------------------------------------------

localparam VGA_HPERIOD = 11'd800;
localparam VGA_HFRONT  = 11'd16;
localparam VGA_HWIDTH  = 11'd96;
localparam VGA_HBACK   = 11'd48;

localparam VGA_VPERIOD = 11'd525;
localparam VGA_VFRONT  = 11'd10;
localparam VGA_VWIDTH  = 11'd2;
localparam VGA_VBACK   = 11'd33;


// ------------------------------------------------------------
// 480p 720x480 @ 60 Hz
// ------------------------------------------------------------

localparam P480_HPERIOD = 11'd858;
localparam P480_HFRONT  = 11'd16;
localparam P480_HWIDTH  = 11'd62;
localparam P480_HBACK   = 11'd60;

localparam P480_VPERIOD = 11'd525;
localparam P480_VFRONT  = 11'd9;
localparam P480_VWIDTH  = 11'd6;
localparam P480_VBACK   = 11'd30;


// ------------------------------------------------------------
// 720p 1280x720 @ 60 Hz
// ------------------------------------------------------------

localparam P720_HPERIOD = 11'd1650;
localparam P720_HFRONT  = 11'd110;
localparam P720_HWIDTH  = 11'd40;
localparam P720_HBACK   = 11'd220;

localparam P720_VPERIOD = 11'd750;
localparam P720_VFRONT  = 11'd5;
localparam P720_VWIDTH  = 11'd5;
localparam P720_VBACK   = 11'd20;


// ============================================================
// 2. CURRENT VIDEO TIMING
// ============================================================

reg [10:0] HPERIOD;
reg [10:0] HFRONT;
reg [10:0] HWIDTH;
reg [10:0] HBACK;

reg [10:0] VPERIOD;
reg [10:0] VFRONT;
reg [10:0] VWIDTH;
reg [10:0] VBACK;


always @(*) begin

    case (timing_sel)

        // ----------------------------------------------------
        // 720 x 480
        // ----------------------------------------------------

        2'd1: begin

            HPERIOD = P480_HPERIOD;
            HFRONT  = P480_HFRONT;
            HWIDTH  = P480_HWIDTH;
            HBACK   = P480_HBACK;

            VPERIOD = P480_VPERIOD;
            VFRONT  = P480_VFRONT;
            VWIDTH  = P480_VWIDTH;
            VBACK   = P480_VBACK;

        end


        // ----------------------------------------------------
        // 1280 x 720
        // ----------------------------------------------------

        2'd2: begin

            HPERIOD = P720_HPERIOD;
            HFRONT  = P720_HFRONT;
            HWIDTH  = P720_HWIDTH;
            HBACK   = P720_HBACK;

            VPERIOD = P720_VPERIOD;
            VFRONT  = P720_VFRONT;
            VWIDTH  = P720_VWIDTH;
            VBACK   = P720_VBACK;

        end


        // ----------------------------------------------------
        // Default = VGA 640 x 480
        // ----------------------------------------------------

        default: begin

            HPERIOD = VGA_HPERIOD;
            HFRONT  = VGA_HFRONT;
            HWIDTH  = VGA_HWIDTH;
            HBACK   = VGA_HBACK;

            VPERIOD = VGA_VPERIOD;
            VFRONT  = VGA_VFRONT;
            VWIDTH  = VGA_VWIDTH;
            VBACK   = VGA_VBACK;

        end

    endcase

end


// ============================================================
// 3. VIDEO SYNC GENERATOR
// ============================================================
//
// syncgen_multi tạo:
//
//      PCK
//      SerialClk
//      VGA_HS
//      VGA_VS
//      HCNT
//      VCNT
//      FCNT
//
// HCNT = horizontal pixel counter
// VCNT = vertical line counter
// FCNT = frame counter
//

wire [10:0] HCNT;
wire [10:0] VCNT;

wire [7:0] FCNT;


syncgen_multi syncgen_multi (

    .CLK            (CLK),
    .RST            (RST),

    .timing_sel     (timing_sel),
    .timing_sel_imm (timing_sel_imm),

    .reconfig_req   (reconfig_req),

    .PCK            (PCK),
    .SerialClk      (SerialClk),

    .locked         (locked),
    .reconfig_done  (reconfig_done),

    .VGA_HS         (VGA_HS),
    .VGA_VS         (VGA_VS),

    .HCNT           (HCNT),
    .VCNT           (VCNT),

    .FCNT           (FCNT)

);


// ============================================================
// 4. ACTIVE DISPLAY AREA
// ============================================================
//
// Tổng vùng blank:
//
// horizontal blank:
//      front porch + sync + back porch
//
// vertical blank:
//      front porch + sync + back porch
//

wire [10:0] HBLANK;
wire [10:0] VBLANK;


assign HBLANK =
       HFRONT
     + HWIDTH
     + HBACK;


assign VBLANK =
       VFRONT
     + VWIDTH
     + VBACK;


// ============================================================
// disp_enable
//
// = 1 khi pixel hiện tại nằm trong vùng hình ảnh nhìn thấy.
// ============================================================

wire disp_enable;


assign disp_enable =
       (VBLANK <= VCNT)
    && (HBLANK - 11'd1 <= HCNT)
    && (HCNT < HPERIOD - 11'd1);


// ============================================================
// 5. ACTIVE DISPLAY COORDINATES
// ============================================================
//
// disp_x = tọa độ X trong vùng active display
// disp_y = tọa độ Y trong vùng active display
//
// Đây chính là pixel_x / pixel_y sẽ cấp cho Datapath.
// ============================================================

wire [10:0] disp_x;
wire [10:0] disp_y;


assign disp_x =
       HCNT
     - HBLANK
     + 11'd1;


assign disp_y =
       VCNT
     - VBLANK;


// Gameplay and renderer now share PCK; frame tick is a clock enable.
wire game_frame_tick, game_reset_pck, game_round_reset;
wire [10:0] game_ship_x, game_projectile_y;
wire game_projectile_active;
wire [`GAME_SCORE_WIDTH-1:0] game_score;
wire game_win;
wire [2:0] game_auto_state;

game_video game_video (
    .pck(PCK), .system_reset(RST), .clock_locked(locked),
    // timing_sel is already synchronized into PCK and frame-latched by the
    // AXI controller. Keep the raw immediate AXI value only for MMCM DRP;
    // never let it drive game reset/enable logic across clock domains.
    .timing_active(timing_sel), .timing_requested(timing_sel),
    .buttons_raw(BTN),
    .hcount(HCNT), .vcount(VCNT), .pixel_active(disp_enable),
    .pixel_x(disp_x), .pixel_y(disp_y),
    .red(VGA_R), .green(VGA_G), .blue(VGA_B), .data_enable(VGA_DE),
    .frame_tick_debug(game_frame_tick), .game_reset_debug(game_reset_pck),
    .round_reset_debug(game_round_reset), .ship_x_debug(game_ship_x),
    .projectile_y_debug(game_projectile_y),
    .projectile_active_debug(game_projectile_active),
    .score_debug(game_score), .win_debug(game_win), .auto_state_debug(game_auto_state),
    .buzzer_out(BEEP)
);

endmodule
