`timescale 1ns / 1ps
`include "game_params.vh"

module tb_physics_engine;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst = 1, game_reset = 0, frame_tick = 0, game_enable = 0;
    reg move_left = 0, move_right = 0, fire = 0;
    wire hit_flag, fire_ready, fire_accepted, win, projectile_active;
    wire [3:0] hit_target_id;
    wire [4:0] score;
    wire [10:0] ship_x, ship_y, projectile_x, projectile_y;
    wire [15:0] alive_flags;
    wire [175:0] target_x_flat, target_y_flat;

    physics_engine dut (
        .clk(clk), .rst(rst), .game_reset(game_reset), .frame_tick(frame_tick),
        .game_enable(game_enable), .move_left(move_left), .move_right(move_right),
        .fire(fire), .hit_flag(hit_flag), .hit_target_id(hit_target_id),
        .fire_ready(fire_ready), .fire_accepted(fire_accepted),
        .score(score), .win(win), .ship_x(ship_x), .ship_y(ship_y),
        .projectile_x(projectile_x), .projectile_y(projectile_y),
        .projectile_active(projectile_active), .alive_flags(alive_flags),
        .target_x_flat(target_x_flat), .target_y_flat(target_y_flat)
    );

    // This projectile crosses several target rows in a single frame.
    reg fast_rst = 1, fast_tick = 0, fast_left = 0, fast_fire = 0;
    wire fast_hit, fast_active, fast_accepted;
    wire [3:0] fast_hit_id;
    wire [4:0] fast_score;
    wire [10:0] fast_ship_x;
    wire [15:0] fast_alive;
    physics_engine #(.SHIP_STEP(264), .PROJECTILE_STEP(600)) fast_dut (
        .clk(clk), .rst(fast_rst), .game_reset(1'b0), .frame_tick(fast_tick),
        .game_enable(1'b1), .move_left(fast_left), .move_right(1'b0),
        .fire(fast_fire), .hit_flag(fast_hit), .hit_target_id(fast_hit_id),
        .fire_ready(), .fire_accepted(fast_accepted), .score(fast_score), .win(),
        .ship_x(fast_ship_x), .ship_y(), .projectile_x(), .projectile_y(),
        .projectile_active(fast_active), .alive_flags(fast_alive),
        .target_x_flat(), .target_y_flat()
    );

    integer checks = 0;
    integer i, row, col, killed, frames, expected_id;
    integer held_x, held_y;
    reg [15:0] expected_alive;

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL: %s at %0t", message, $time);
                $fatal(1, "Physics assertion failed");
            end
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

    task automatic fast_frame;
        begin
            @(negedge clk); fast_tick = 1;
            @(posedge clk); #1;
            @(negedge clk); fast_tick = 0;
        end
    endtask

    task automatic reset_game;
        begin
            rst = 1; game_reset = 0; frame_tick = 0;
            game_enable = 0; move_left = 0; move_right = 0; fire = 0;
            repeat (3) @(negedge clk);
            rst = 0;
            idle_cycle();
            check(ship_x == 608 && ship_y == 640, "reset ship position");
            check(alive_flags == 16'hffff && score == 0 && !win, "reset game state");
            check(!projectile_active && !hit_flag && !fire_accepted, "reset events and bullet");
        end
    endtask

    task automatic go_to_x(input integer destination);
        integer guard;
        begin
            guard = 0;
            while (ship_x != destination && guard < 200) begin
                move_left = ship_x > destination;
                move_right = ship_x < destination;
                step_frame();
                guard = guard + 1;
            end
            move_left = 0; move_right = 0;
            check(ship_x == destination, "reach selected target column");
        end
    endtask

    task automatic shoot_expect_hit(input integer target_id);
        integer guard;
        begin
            check(fire_ready, "ready before a new shot");
            fire = 1; step_frame(); fire = 0;
            check(fire_accepted && projectile_active, "one projectile accepted");
            guard = 0;
            while (!hit_flag && guard < 100) begin
                step_frame();
                guard = guard + 1;
            end
            check(hit_flag && hit_target_id == target_id, "expected target hit before timeout");
            check(!projectile_active, "bullet consumed by collision");
            expected_alive[target_id] = 0;
            killed = killed + 1;
            check(alive_flags == expected_alive, "only the selected live target is removed");
            check(score == killed, "exactly one point per removed target");
            check(win == (killed == 16), "win appears on the final hit only");
            idle_cycle();
            check(!hit_flag && !fire_accepted, "event pulses clear after one clk");
        end
    endtask

    // Independent accounting invariant, including pauses and idle cycles.
    always @(posedge clk) begin
        #2;
        if (!rst && !game_reset) begin
            check(score == 16 - $countones(alive_flags), "score equals number of destroyed targets");
            check(ship_x <= 1216, "ship remains within visible horizontal bounds");
            if (win)
                check(alive_flags == 0 && score == 16 && !projectile_active,
                      "winning state is complete and stable");
        end
    end

    initial begin
        #1000000;
        $fatal(1, "Simulation watchdog: no PASS result before timeout");
    end

    initial begin
        reset_game();
        for (i = 0; i < 16; i = i + 1) begin
            check(target_x_flat[i*11 +: 11] == 336 + (i % 4)*176,
                  "target X layout in native 720p coordinates");
            check(target_y_flat[i*11 +: 11] == 120 + (i / 4)*72,
                  "target Y layout in native 720p coordinates");
        end
        $display("CHECKPOINT: reset and 720p layout PASS");

        game_enable = 1; move_right = 1; fire = 1;
        repeat (5) idle_cycle();
        check(ship_x == 608 && !projectile_active, "commands require a frame tick");
        fire = 0;
        repeat (3) step_frame();
        check(ship_x == 632, "three right ticks move 24 pixels");
        move_right = 0; move_left = 1;
        repeat (2) step_frame();
        check(ship_x == 616, "two left ticks move 16 pixels");
        move_right = 1; step_frame();
        check(ship_x == 616, "opposite movement commands cancel");

        move_right = 0;
        repeat (160) step_frame();
        check(ship_x == 0, "left saturation without underflow");
        move_left = 0; move_right = 1;
        repeat (180) step_frame();
        check(ship_x == 1216, "right saturation without overflow");

        game_enable = 0; fire = 1;
        repeat (4) step_frame();
        check(ship_x == 1216 && !projectile_active && !fire_ready,
              "disabled game ignores movement and fire");
        $display("CHECKPOINT: movement, boundaries and enable PASS");

        reset_game(); game_enable = 1;
        move_left = 1; fire = 1; step_frame();
        move_left = 0; fire = 0;
        check(ship_x == 600 && projectile_x == 629 && projectile_y == 624,
              "simultaneous movement and fire use the new ship position");
        check(projectile_active && fire_accepted, "spawn and accepted pulse");
        idle_cycle();
        check(!fire_accepted, "accepted pulse is one clk wide");
        step_frame();
        check(projectile_y == 612, "projectile advances by configured pixels per frame");

        held_x = projectile_x; held_y = projectile_y;
        game_enable = 0; move_right = 1; fire = 1;
        repeat (4) step_frame();
        check(ship_x == 600 && projectile_x == held_x && projectile_y == held_y &&
              projectile_active && score == 0, "pause freezes ship and active projectile");
        game_enable = 1; move_right = 0;
        step_frame();
        check(projectile_x == held_x && projectile_y == held_y - 12 && !fire_accepted,
              "fire while busy neither respawns nor relocates the projectile");
        fire = 0;

        frames = 0;
        while (projectile_active && frames < 100) begin
            step_frame(); frames = frames + 1;
            check(!hit_flag && score == 0, "shot through a gap misses all targets");
        end
        check(!projectile_active && projectile_y == 0 && fire_ready,
              "top edge retires projectile and reopens firing");
        $display("CHECKPOINT: firing, pause, busy handling and top edge PASS");

        // Held fire is a level request, accepted again on a later ready frame.
        fire = 1; step_frame();
        check(fire_accepted, "held fire starts first shot");
        frames = 0;
        while (projectile_active && frames < 100) begin
            step_frame(); frames = frames + 1;
            check(!fire_accepted, "held fire cannot create a second active projectile");
        end
        check(!projectile_active, "held-fire first shot retires");
        step_frame();
        check(fire_accepted && projectile_active, "held fire repeats on next ready frame");
        fire = 0;

        // Gameplay reset must work while paused and with no frame tick.
        game_enable = 0; game_reset = 1; idle_cycle();
        check(ship_x == 608 && !projectile_active && alive_flags == 16'hffff && score == 0,
              "game_reset is independent of enable and frame tick");
        game_reset = 0;

        reset_game(); game_enable = 1;
        killed = 0; expected_alive = 16'hffff;
        for (col = 0; col < 4; col = col + 1) begin
            go_to_x(344 + col*176);
            for (row = 3; row >= 0; row = row - 1)
                shoot_expect_hit(row*4 + col);

            if (col == 0) begin
                fire = 1; step_frame(); fire = 0;
                frames = 0;
                while (projectile_active && frames < 100) begin
                    step_frame(); frames = frames + 1;
                    check(!hit_flag && score == 4 && alive_flags == expected_alive,
                          "destroyed targets cannot be hit or scored again");
                end
                check(!projectile_active, "shot through destroyed column leaves the screen");
            end
        end
        check(win && score == 16 && alive_flags == 0 && !fire_ready,
              "all sixteen targets produce a winning state");
        held_x = ship_x;
        move_left = 1; fire = 1;
        repeat (6) step_frame();
        check(win && ship_x == held_x && !projectile_active && score == 16,
              "win latches and blocks further movement and shots");
        game_reset = 1; idle_cycle(); game_reset = 0;
        move_left = 0; fire = 0;
        check(!win && score == 0 && alive_flags == 16'hffff && ship_x == 608,
              "new-game reset restores all state after win");
        $display("CHECKPOINT: all 16 collisions, no double score, win and restart PASS");

        repeat (2) @(negedge clk);
        fast_rst = 0; fast_left = 1;
        fast_frame(); fast_left = 0;
        check(fast_ship_x == 344, "fast test aligns with first target column");
        for (i = 0; i < 4; i = i + 1) begin
            fast_fire = 1; fast_frame(); fast_fire = 0;
            check(fast_accepted && fast_active, "fast projectile spawned");
            fast_frame();
            expected_id = 12 - i*4;
            check(fast_hit && fast_hit_id == expected_id && !fast_active,
                  "swept collision chooses nearest live target during a large step");
            check(fast_score == i + 1 && !fast_alive[expected_id],
                  "large step still destroys and scores exactly one target");
            idle_cycle();
            check(!fast_hit, "fast collision pulse is one clk wide");
        end
        $display("CHECKPOINT: high-speed sweep and nearest-target priority PASS");
        $display("PASS: tb_physics_engine checks=%0d, default game cleared 16 targets, score=16, win=1", checks);
        $finish;
    end
endmodule
