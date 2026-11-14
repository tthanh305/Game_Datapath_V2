`timescale 1ns / 1ps

// Real, unchanged syncgen_multi counters and two complete 720p video frames.
// Only the clock generator is replaced by a simulation-only PCK source model.
module tb_video_integration;
    reg test_done = 0;
    reg CLK = 0, RST = 1;
    reg [4:0] BTN = 5'b11111; // Active-low idle (all buttons released)
    initial begin : clock_driver
        forever #6.734 CLK = ~CLK; // nominal 74.25 MHz, rounded to simulator precision
    end
    wire [7:0] red, green, blue;
    wire hsync, vsync, de, pck, serial_clk, locked, reconfig_done;
    pattern_multi dut (
        .CLK(CLK), .RST(RST), .timing_sel(2'd2), .timing_sel_imm(2'd2),
        .pattern_sel(4'd0), .reconfig_req(1'b0), .BTN(BTN),
        .VGA_R(red), .VGA_G(green), .VGA_B(blue), .VGA_HS(hsync), .VGA_VS(vsync),
        .VGA_DE(de), .PCK(pck), .SerialClk(serial_clk), .locked(locked),
        .reconfig_done(reconfig_done)
    );

    localparam integer FRAME_CLOCKS = 1650*750;
    integer checks = 0, pixels = 0, frames = 0, frame_pixels = 0;
    integer visible_pixels = 0, line_pixels = 0, lines = 0;
    integer hs_clocks = 0, vs_clocks = 0, frame_ticks = 0;
    integer previous_tick_pixel = 0;
    integer old_h, old_v, x, y;
    reg expected_de;
    reg [23:0] expected_rgb;

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL: %s pixel=%0d h=%0d v=%0d frame=%0d RGB=%06h",
                         message, pixels, old_h, old_v, frames, {red,green,blue});
                $fatal(1, "Video integration assertion failed");
            end
        end
    endtask

    always @(posedge pck) begin
        if (!test_done && (RST || dut.syncgen_multi.pck_reset)) begin
            #1;
            if (dut.syncgen_multi.pck_reset && dut.game_video.video_reset_pck)
                check(!de && {red,green,blue} == 0, "system reset clears registered video output");
        end else if (!test_done) begin
            old_h = dut.HCNT;
            old_v = dut.VCNT;
            expected_de = old_h >= 369 && old_h < 1649 && old_v >= 30 && old_v < 750;
            expected_rgb = 0;
            if (expected_de && !dut.game_reset_pck) begin
                if (dut.game_video.menu_active_d) begin
                    if (dut.game_video.scoreboard_active_d && dut.game_video.hud_pixel_on)
                        expected_rgb = {dut.game_video.hud_color[23:16],
                                        dut.game_video.hud_color[15:8],
                                        dut.game_video.hud_color[7:0]};
                    else
                        expected_rgb = {dut.game_video.menu_red,
                                        dut.game_video.menu_green,
                                        dut.game_video.menu_blue};
                end else begin
                    expected_rgb = {dut.game_video.game_red,
                                    dut.game_video.game_green,
                                    dut.game_video.game_blue};
                end
            end
            x = old_h - 369;
            y = old_v - 30;
            #1;
            pixels = pixels + 1;
            frame_pixels = frame_pixels + 1;
            if (de !== expected_de || {red,green,blue} !== expected_rgb) begin
                $display("FAIL: RGB/DE latency or active window at h=%0d v=%0d DE=%b expected=%b RGB=%06h expectedRGB=%06h",
                         old_h, old_v, de, expected_de, {red,green,blue}, expected_rgb);
                $fatal(1, "Registered pixel alignment failed");
            end
            if (!de && {red,green,blue} !== 24'h000000)
                $fatal(1, "Nonblack blanking interval");
            if (old_h >= 1650 || old_v >= 750)
                $fatal(1, "Timing counters escaped the 720p frame");

            if (de) begin
                visible_pixels = visible_pixels + 1;
                line_pixels = line_pixels + 1;
                if (!dut.game_video.menu_active &&
                    (x == 376 || x == 552 || x == 728 || x == 904) &&
                    (y == 138 || y == 210 || y == 282 || y == 354))
                    check({red,green,blue} == 24'hff0000, "target RGB at the real scan coordinate");
                if (x == 430 && y == 350)
                    check({red,green,blue} == 24'h55e6ff,
                          "New Game is highlighted on the startup menu");
                if (x == 610 && y == 350)
                    check({red,green,blue} == 24'h172532,
                          "Resume is not highlighted on the startup menu");
            end
            if (hsync) hs_clocks = hs_clocks + 1;
            if (vsync) vs_clocks = vs_clocks + 1;

            if (old_h == 1649) begin
                check(line_pixels == (old_v >= 30 ? 1280 : 0), "exact active width on every scan line");
                line_pixels = 0; lines = lines + 1;
            end
            if (old_h == 1649 && old_v == 749) begin
                check(frame_pixels == FRAME_CLOCKS, "1650 by 750 clocks per video frame");
                check(visible_pixels == 1280*720, "1280 by 720 active pixels per frame");
                check(lines == 750, "750 total scan lines per frame");
                check(hs_clocks == 40*750 && vs_clocks == 5*1650,
                      "unchanged 720p positive HS/VS pulse widths");
                frames = frames + 1;
                $display("CHECKPOINT: 720p frame %0d PASS, active_pixels=%0d clocks=%0d",
                         frames, visible_pixels, frame_pixels);
                visible_pixels = 0; frame_pixels = 0; lines = 0;
                hs_clocks = 0; vs_clocks = 0;
            end

            if (dut.game_frame_tick) begin
                check(dut.HCNT == 1 && dut.VCNT == 0 && !de,
                      "frame tick is registered in vertical blanking");
                if (frame_ticks > 0)
                    check(pixels - previous_tick_pixel == FRAME_CLOCKS,
                          "frame enables are spaced by exactly 1237500 PCK cycles");
                previous_tick_pixel = pixels;
                frame_ticks = frame_ticks + 1;
            end
        end
    end

    initial begin : watchdog
        #50000000;
        $fatal(1, "Video integration watchdog expired");
    end

    initial begin
        repeat (10) @(negedge CLK);
        RST = 0;
        wait (frames == 2);
        repeat (6) @(posedge pck);
        #2;
        check(frame_ticks == 2 && dut.game_video.control_state == 0 &&
              dut.game_video.menu_active,
              "startup remains in the interactive menu before a button press");
        check(!dut.game_reset_pck && dut.game_score == 0 && !dut.game_win,
              "gameplay state remains reset while the menu is active");
        // Leave no clock/watchdog events pending if the GUI resumes $finish.
        test_done = 1;
        disable watchdog;
        disable clock_driver;
        $display("PASS: tb_video_integration checks=%0d frames=%0d ticks=%0d pixels=%0d",
                 checks, frames, frame_ticks, pixels);
        $finish;
    end
endmodule
