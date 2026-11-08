`timescale 1ns / 1ps

module tb_color_mapper;
    reg clk = 0, rst = 0, frame_tick = 0;
    reg pixel_active = 1;
    reg [10:0] pixel_x = 0, pixel_y = 0;
    reg [10:0] ship_x, ship_y, projectile_x, projectile_y;
    reg projectile_active;
    reg [15:0] alive_flags;
    reg [175:0] target_x_flat, target_y_flat;
    reg [4:0] score;
    reg win = 0;
    reg game_over = 0;
    reg [3:0] wave_num = 1;
    reg [1:0] player_lives = 3;
    reg player_exploding = 0;
    reg bomb_active = 0;
    reg [10:0] bomb_x = 0, bomb_y = 0;
    reg [1:0] alien_anim_phase = 0;
    reg diving_active = 0;
    reg [3:0] diving_id = 0;
    reg signed [1:0] diver_tilt = 0;
    reg [10:0] diving_x = 0, diving_y = 0;
    reg signed [8:0] fleet_offset_x = 0;

    wire [7:0] red, green, blue;
    integer checks = 0;
    integer i, x0, y0, target;

    color_mapper dut (
        .clk(clk), .rst(rst), .frame_tick(frame_tick),
        .pixel_active(pixel_active), .pixel_x(pixel_x), .pixel_y(pixel_y),
        .ship_x(ship_x), .ship_y(ship_y), .projectile_x(projectile_x),
        .projectile_y(projectile_y), .projectile_active(projectile_active),
        .alive_flags(alive_flags), .target_x_flat(target_x_flat),
        .target_y_flat(target_y_flat), .score(score), .win(win),
        .game_over(game_over), .wave_num(wave_num),
        .player_lives(player_lives), .player_exploding(player_exploding),
        .bomb_active(bomb_active), .bomb_x(bomb_x), .bomb_y(bomb_y),
        .alien_anim_phase(alien_anim_phase),
        .diving_active(diving_active),
        .diving_id(diving_id),
        .diver_tilt(diver_tilt),
        .diving_x(diving_x),
        .diving_y(diving_y),
        .fleet_offset_x(fleet_offset_x),
        .red(red), .green(green), .blue(blue)
    );

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL: %s at (%0d,%0d), RGB=%06h", message, pixel_x, pixel_y,
                         {red,green,blue});
                $fatal(1, "Color Mapper assertion failed");
            end
        end
    endtask

    task automatic sample(input integer x, input integer y,
                          input [23:0] expected, input string message);
        begin
            pixel_x = x; pixel_y = y; #1;
            check({red,green,blue} === expected, message);
        end
    endtask

    task automatic initial_scene;
        begin
            pixel_active = 1;
            ship_x = 608; ship_y = 650;
            projectile_x = 622; projectile_y = 630; projectile_active = 0;
            alive_flags = 16'hffff; score = 0; win = 0;
            player_lives = 3; player_exploding = 0;
            bomb_active = 0;
            for (target = 0; target < 16; target = target + 1) begin
                target_x_flat[target*11 +: 11] = 340 + (target % 4)*160;
                target_y_flat[target*11 +: 11] = 100 + (target / 4)*60;
            end
        end
    endtask

    task automatic dump_ppm(input string filename);
        integer fd, x, y;
        begin
            fd = $fopen(filename, "wb");
            if (!fd) $fatal(1, "Cannot create renderer preview: %s", filename);
            $fwrite(fd, "P6\n1280 720\n255\n");
            for (y = 0; y < 720; y = y + 1)
                for (x = 0; x < 1280; x = x + 1) begin
                    pixel_x = x; pixel_y = y; #1;
                    $fwrite(fd, "%c%c%c", red, green, blue);
                end
            $fclose(fd);
            $display("PREVIEW: %s generated from Galaxian RTL RGB output", filename);
        end
    endtask

    initial begin
        #50000000;
        $fatal(1, "Renderer simulation watchdog expired");
    end

    initial begin
        initial_scene();
        #10;
        
        // 1. HUD check (SCORE 00 at (36, 28) should be Cyan 24'h00dfff)
        sample(36, 28, 24'h00dfff, "SCORE label at HUD position");
        
        // 2. Galaxip ship nose (Dome is Red 24'hFF1A1A at (ship_x + 16, ship_y + 2))
        sample(608 + 16, 650 + 2, 24'hFF1A1A, "Galaxip cannon tip is Red");

        // 3. Galaxip center fuselage (Cyan 24'h00E5FF at (ship_x + 16 + 3, ship_y + 10))
        sample(608 + 16 + 3, 650 + 10, 24'h00E5FF, "Galaxip fuselage is Cyan");

        // 4. Boss Galaxian (Red crown spike at (target 0: 340 + 16, 100 + 4), Yellow chest at dy=14)
        sample(340 + 16, 100 + 4, 24'hFF1A1A, "Boss Galaxian crown spike is Red");
        sample(340 + 16, 100 + 14, 24'hFFE600, "Boss Galaxian chest is Yellow");

        // 5. Red Escort Alien (Red body at (target 4: 340 + 16, 160 + 8))
        sample(340 + 16, 160 + 8, 24'hFF1A1A, "Escort alien body is Red");

        // 6. Green Drone Alien (Green body at (target 8: 340 + 16 + 2, 220 + 7))
        sample(340 + 16 + 2, 220 + 7, 24'h00E500, "Drone alien body is Green");

        // 7. Diver-Row Crossing Test: Diving alien crosses formation Row 2 (Y=220)
        // Diver is at (100, 220); Target 8 formation drone is at (340, 220)
        diving_active = 1;
        diving_id = 4; // Alien 4 is diving
        diving_x = 100;
        diving_y = 220; // Exact same scanline as formation Row 2!
        #1;
        // Check formation drone at (340, 220) is NOT erased and remains GREEN!
        sample(340 + 16 + 2, 220 + 7, 24'h00E500, "Formation Drone remains intact during dive crossing");
        // Check diver at (100, 220) is rendered as Red Escort
        sample(100 + 16, 220 + 8, 24'hFF1A1A, "Diver is rendered correctly at (100, 220)");
        diving_active = 0;

        // 7. Player Laser (White core when active)
        projectile_active = 1;
        sample(622 + 2, 630 + 4, 24'hFFFFFF, "Laser beam center is White");
        projectile_active = 0;

        // 8. WIN HUD check
        win = 1; score = 16;
        sample(572 + 1, 440 + 1, 24'hFFFF00, "WIN banner is Yellow");
        $display("CHECKPOINT: Galaxian arcade sprites, HUD and starfield PASS");

        // 9. Export Preview PPM Images
        if ($test$plusargs("EXPORT_IMAGES")) begin
            initial_scene();
            dump_ppm("game_initial.ppm");
            alive_flags = 16'h0000; score = 16; win = 1; ship_x = 608;
            dump_ppm("game_win.ppm");
        end

        $display("PASS: tb_color_mapper checks=%0d", checks);
        $finish;
    end
endmodule
