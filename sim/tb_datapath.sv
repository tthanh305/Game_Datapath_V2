`timescale 1ns / 1ps

module tb_datapath;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, game_reset = 0, frame_tick = 0, game_enable = 0;
    reg move_left = 0, move_right = 0, fire = 0, pixel_active = 1;
    reg [10:0] pixel_x = 0, pixel_y = 0;
    wire hit_flag, fire_ready, fire_accepted, win, projectile_active;
    wire [3:0] hit_target_id;
    wire [4:0] score;
    wire [15:0] alive_flags;
    wire [10:0] ship_x, ship_y, projectile_x, projectile_y;
    wire [175:0] target_x_flat, target_y_flat;
    wire [7:0] red, green, blue;
    integer checks = 0, frames, column, row, kills;
    integer saved_x, saved_y;
    reg [15:0] expected_alive;

    datapath dut (
        .clk(clk), .rst(rst), .game_reset(game_reset), .frame_tick(frame_tick),
        .game_enable(game_enable), .move_left(move_left), .move_right(move_right),
        .fire(fire), .pixel_active(pixel_active), .pixel_x(pixel_x), .pixel_y(pixel_y),
        .hit_flag(hit_flag), .hit_target_id(hit_target_id), .fire_ready(fire_ready),
        .fire_accepted(fire_accepted), .score(score), .win(win), .alive_flags(alive_flags),
        .ship_x(ship_x), .ship_y(ship_y), .projectile_x(projectile_x),
        .projectile_y(projectile_y), .projectile_active(projectile_active),
        .target_x_flat(target_x_flat), .target_y_flat(target_y_flat),
        .red(red), .green(green), .blue(blue)
    );

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL: %s at %0t", message, $time);
                $fatal(1, "Datapath integration assertion failed");
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

    task automatic step_frame;
        begin
            @(negedge clk); frame_tick = 1;
            @(posedge clk); #1;
            @(negedge clk); frame_tick = 0;
        end
    endtask

    task automatic idle_cycle;
        begin
            @(negedge clk);
            @(posedge clk); #1;
        end
    endtask

    task automatic go_to_x(input integer destination);
        integer guard;
        begin
            guard = 0;
            while (ship_x != destination && guard < 200) begin
                move_left = ship_x > destination;
                move_right = ship_x < destination;
                step_frame(); guard = guard + 1;
            end
            move_left = 0; move_right = 0;
            check(ship_x == destination, "controller commands reach selected column");
        end
    endtask

    task automatic shoot_target(input integer id);
        integer guard, tx, ty;
        begin
            check(fire_ready, "Datapath exposes fire_ready");
            fire = 1; step_frame(); fire = 0;
            check(fire_accepted && projectile_active, "Datapath exposes accepted shot");
            sample(projectile_x, projectile_y, 24'hffffff, "new projectile appears in RGB");
            guard = 0;
            while (!hit_flag && guard < 100) begin
                step_frame(); guard = guard + 1;
            end
            check(hit_flag && hit_target_id == id && !projectile_active,
                  "hit event and ID pass through Datapath");
            expected_alive[id] = 0; kills = kills + 1;
            check(alive_flags == expected_alive && score == kills,
                  "target bitmap and score remain consistent through wrapper");
            tx = 376 + (id%4)*176; ty = 138 + (id/4)*72;
            sample(tx, ty, 24'h000000, "hit target immediately disappears from RGB");
            check(win == (kills == 16), "win reaches renderer on final hit only");
            idle_cycle();
            check(!hit_flag && !fire_accepted, "wrapper preserves single-clock event pulses");
        end
    endtask

    initial begin
        #1000000;
        $fatal(1, "Datapath simulation watchdog expired");
    end

    initial begin
        repeat (3) @(negedge clk);
        sample(640, 650, 24'h000000, "system reset masks gameplay RGB");
        rst = 0; idle_cycle();
        check(ship_x == 608 && ship_y == 640 && score == 0 && !win && alive_flags == 16'hffff,
              "reset state propagates through Datapath");
        check(target_x_flat[15*11 +: 11] == 864 && target_y_flat[15*11 +: 11] == 336,
              "target positions are available to future controllers");
        sample(640, 650, 24'h00ff00, "initial ship visible while game is disabled");
        sample(376, 354, 24'hff0000, "initial target visible");
        sample(204, 28, 24'h00dfff, "initial score displays 00");
        sample(572, 440, 24'h000000, "win banner initially hidden");
        $display("CHECKPOINT: reset state, renderer and exposed state buses PASS");

        game_enable = 1;
        go_to_x(344);
        sample(640, 650, 24'h000000, "old ship position clears after movement");
        sample(376, 650, 24'h00ff00, "new ship position becomes green");
        fire = 1; step_frame(); fire = 0;
        check(fire_accepted && projectile_active && projectile_x == 373 && projectile_y == 624,
              "shot handshake and spawn coordinates");
        sample(373, 624, 24'hffffff, "spawned bullet visible");
        game_enable = 0; saved_x = projectile_x; saved_y = projectile_y;
        repeat (4) step_frame();
        check(projectile_x == saved_x && projectile_y == saved_y && score == 0,
              "pause freezes the state connected to the renderer");
        sample(373, 624, 24'hffffff, "paused projectile stays visible");
        game_enable = 1; step_frame();
        sample(373, 612, 24'hffffff, "moving projectile appears at new pixel");
        sample(373, 639, 24'h000000, "old projectile trailing pixels clear");
        fire = 1; step_frame(); fire = 0;
        check(!fire_accepted && projectile_x == 373, "busy projectile cannot be respawned");
        frames = 0;
        while (!hit_flag && frames < 100) begin
            step_frame(); frames = frames + 1;
        end
        check(hit_flag && hit_target_id == 12 && score == 1, "first collision reaches wrapper outputs");
        sample(376, 354, 24'h000000, "first hit removes target from RGB");
        sample(552, 354, 24'hff0000, "neighboring target survives");
        sample(204, 28, 24'h000000, "score changes from 00 to 01 without another frame");

        pixel_active = 0;
        sample(376, 650, 24'h000000, "blanking masks ship through Datapath");
        sample(36, 28, 24'h000000, "blanking masks HUD through Datapath");
        pixel_active = 1;
        game_enable = 0; game_reset = 1;
        sample(552, 354, 24'h000000, "game reset masks RGB");
        idle_cycle(); game_reset = 0;
        check(score == 0 && alive_flags == 16'hffff && !projectile_active,
              "game reset reaches Physics while paused");
        sample(376, 354, 24'hff0000, "reset restores target rendering");
        sample(204, 28, 24'h00dfff, "reset restores score 00");
        $display("CHECKPOINT: movement, bullet, pause, collision, blanking and reset RGB PASS");

        game_enable = 1; kills = 0; expected_alive = 16'hffff;
        for (column = 0; column < 4; column = column + 1) begin
            go_to_x(344 + column*176);
            for (row = 3; row >= 0; row = row - 1)
                shoot_target(row*4 + column);
        end
        check(win && score == 16 && alive_flags == 0, "full integrated game reaches win");
        sample(180, 28, 24'h000000, "score tens digit is 1");
        sample(204, 28, 24'h00dfff, "score units digit is 6");
        sample(572, 440, 24'hffff00, "Physics win makes WIN glyph visible");
        sample(904, 650, 24'h00ff00, "ship remains visible in winning state");
        fire = 1; move_left = 1;
        repeat (3) step_frame();
        check(win && !projectile_active && ship_x == 872 && score == 16,
              "winning Datapath remains frozen");
        game_reset = 1; idle_cycle(); game_reset = 0;
        fire = 0; move_left = 0;
        sample(572, 440, 24'h000000, "new game removes WIN banner");
        sample(376, 354, 24'hff0000, "new game restores destroyed targets");
        check(!win && score == 0 && alive_flags == 16'hffff, "new-game state restored");
        $display("CHECKPOINT: full 16-target game, score HUD, WIN and restart integration PASS");
        $display("PASS: tb_datapath checks=%0d", checks);
        $finish;
    end
endmodule
