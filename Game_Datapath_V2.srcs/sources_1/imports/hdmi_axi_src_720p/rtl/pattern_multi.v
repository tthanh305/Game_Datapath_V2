`timescale 1ns / 1ps

/*
 * pattern_multi.v
 *
 * Phiên bản dùng để TEST DATAPATH trên FPGA.
 *
 * Mục tiêu hiện tại:
 *  - Giữ nguyên hệ thống video timing của project 06_hdmi_test.
 *  - Lấy disp_x, disp_y từ syncgen_multi.
 *  - Đưa disp_x, disp_y vào datapath.
 *  - Lấy RGB từ color_mapper bên trong datapath.
 *  - Xuất RGB đó sang pipeline HDMI.
 *
 * Bản test này là STATIC TEST:
 *
 *      vsync_tick = 0
 *      game_enable = 0
 *      move_left = 0
 *      move_right = 0
 *      fire = 0
 *
 * Vì vậy:
 *  - tàu đứng ở vị trí reset
 *  - 16 target còn sống
 *  - projectile chưa hoạt động
 *
 * Màn hình dự kiến:
 *  - nền đen
 *  - 16 target đỏ
 *  - 1 ship xanh
 */

module pattern_multi(
    input               CLK,
    input               RST,

    input       [1:0]   timing_sel,
    input       [1:0]   timing_sel_imm,

    // Giữ lại port này để tương thích module cấp trên.
    // Bản test Datapath hiện tại không sử dụng pattern_sel.
    input       [3:0]   pattern_sel,

    input               reconfig_req,

    output reg  [7:0]   VGA_R,
    output reg  [7:0]   VGA_G,
    output reg  [7:0]   VGA_B,

    output              VGA_HS,
    output              VGA_VS,

    output reg          VGA_DE,

    output              PCK,
    output              SerialClk,

    output              locked,
    output              reconfig_done
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


// ============================================================
// 6. DATAPATH SIGNALS
// ============================================================
//
// Không dùng macro TARGET_COUNT / COORD_WIDTH ở đây.
//
// Interface hiện tại của Datapath:
//
//      TARGET_COUNT = 16
//      COORD_WIDTH  = 10
//
// nên:
//      alive_flags   = 16 bit
//      object coords = 10 bit
// ============================================================


// RGB output của color_mapper

wire [7:0] game_red;
wire [7:0] game_green;
wire [7:0] game_blue;


// Collision information

wire       game_hit_flag;
wire [3:0] game_hit_target_id;


// 16 targets

wire [15:0] game_alive_flags;


// Ship coordinates

wire [9:0] game_ship_x;
wire [9:0] game_ship_y;


// Projectile coordinates

wire [9:0] game_projectile_x;
wire [9:0] game_projectile_y;

wire       game_projectile_active;


// ============================================================
// 7. GAME DATAPATH
// ============================================================
//
// Datapath hierarchy:
//
//      datapath
//          |
//          +-- physics_engine
//          |
//          +-- color_mapper
//
// Bản đầu này chỉ test HÌNH TĨNH.
//
// Ta khóa toàn bộ control:
//
//      vsync_tick  = 0
//      game_enable = 0
//      move_left   = 0
//      move_right  = 0
//      fire        = 0
//
// Do đó physics_engine giữ trạng thái reset.
//
// color_mapper vẫn hoạt động bình thường vì nó liên tục nhận
// disp_x và disp_y của từng pixel.
// ============================================================

datapath game_datapath (

    // --------------------------------------------------------
    // Clock + Reset
    // --------------------------------------------------------

    .clk                (CLK),
    .rst                (RST),


    // --------------------------------------------------------
    // Game update
    // --------------------------------------------------------

    .vsync_tick         (1'b0),


    // --------------------------------------------------------
    // Temporary game controls
    //
    // Control Path chưa được sử dụng.
    // --------------------------------------------------------

    .game_enable        (1'b0),
    .move_left          (1'b0),
    .move_right         (1'b0),
    .fire               (1'b0),


    // --------------------------------------------------------
    // Current pixel coordinates
    // --------------------------------------------------------

    .pixel_x            (disp_x),
    .pixel_y            (disp_y),


    // --------------------------------------------------------
    // Physics outputs
    // --------------------------------------------------------

    .hit_flag           (game_hit_flag),
    .hit_target_id      (game_hit_target_id),

    .alive_flags        (game_alive_flags),

    .ship_x             (game_ship_x),
    .ship_y             (game_ship_y),

    .projectile_x       (game_projectile_x),
    .projectile_y       (game_projectile_y),

    .projectile_active  (game_projectile_active),


    // --------------------------------------------------------
    // Renderer output
    // --------------------------------------------------------

    .red                (game_red),
    .green              (game_green),
    .blue               (game_blue)

);


// ============================================================
// 8. RGB OUTPUT
// ============================================================
//
// Trước đây:
//
//      pattern_r/g/b
//          |
//          v
//      VGA_R/G/B
//
// Bây giờ:
//
//      game_red/green/blue
//          |
//          v
//      VGA_R/G/B
//
// RGB vẫn được register bằng PCK giống thiết kế HDMI gốc.
// ============================================================

always @(posedge PCK) begin

    if (RST) begin

        VGA_R <= 8'h00;
        VGA_G <= 8'h00;
        VGA_B <= 8'h00;

    end

    else if (disp_enable) begin

        VGA_R <= game_red;
        VGA_G <= game_green;
        VGA_B <= game_blue;

    end

    else begin

        VGA_R <= 8'h00;
        VGA_G <= 8'h00;
        VGA_B <= 8'h00;

    end

end


// ============================================================
// 9. DISPLAY ENABLE
// ============================================================
//
// RGB phía trên được register qua 1 pixel clock.
//
// Vì vậy disp_enable cũng được delay 1 PCK để tạo VGA_DE,
// giữ cho DE và RGB khớp timing.
//
// Phần này giữ nguyên nguyên lý của project HDMI gốc.
// ============================================================

always @(posedge PCK) begin

    if (RST)

        VGA_DE <= 1'b0;

    else

        VGA_DE <= disp_enable;

end


endmodule