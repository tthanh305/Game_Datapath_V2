`timescale 1ns / 1ps

module tb_auto_game_controller;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, frame_tick = 0, demo_enable = 0;
    reg [10:0] ship_x = 608;
    reg [15:0] alive_flags = 16'hffff;
    reg [175:0] target_x_flat;
    reg fire_ready = 1, fire_accepted = 0, projectile_active = 0, win = 0;
    wire game_reset, game_enable, move_left, move_right, fire;
    wire [2:0] state_debug;
    wire [3:0] target_id_debug;
    wire [10:0] aim_x_debug;
    localparam integer HOLD_FRAMES = 180;
    integer checks = 0, i;

    auto_game_controller #(.WIN_HOLD_FRAMES(HOLD_FRAMES)) dut (
        .clk(clk), .rst(rst), .frame_tick(frame_tick), .demo_enable(demo_enable),
        .ship_x(ship_x), .alive_flags(alive_flags), .target_x_flat(target_x_flat),
        .fire_ready(fire_ready), .fire_accepted(fire_accepted),
        .projectile_active(projectile_active), .win(win),
        .game_reset(game_reset), .game_enable(game_enable), .move_left(move_left),
        .move_right(move_right), .fire(fire), .state_debug(state_debug),
        .target_id_debug(target_id_debug), .aim_x_debug(aim_x_debug)
    );

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL: %s at %0t state=%0d", message, $time, state_debug);
                $fatal(1, "Auto Controller assertion failed");
            end
        end
    endtask

    task automatic cycle;
        begin
            @(negedge clk);
            @(posedge clk); #1;
        end
    endtask

    task automatic step_frame;
        begin
            @(negedge clk); frame_tick = 1;
            @(posedge clk); #1;
            @(negedge clk); frame_tick = 0;
        end
    endtask

    always @(posedge clk) begin
        #2;
        if (!rst) begin
            check(!(move_left && move_right), "movement directions are mutually exclusive");
            check(!(fire && (move_left || move_right)), "aiming and firing never conflict");
            check(!(game_reset && game_enable), "reset cannot enable gameplay");
            if (!demo_enable)
                check(!game_reset && !game_enable && !move_left && !move_right && !fire,
                      "disabled demo masks all command outputs");
        end
    end

    initial begin
        #100000;
        $fatal(1, "Auto Controller watchdog expired");
    end

    initial begin
        for (i = 0; i < 16; i = i + 1)
            target_x_flat[i*11 +: 11] = 336 + (i%4)*176;
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (3) cycle();
        check(state_debug == 0 && !game_reset, "disabled startup waits without resetting game");
        demo_enable = 1; #1;
        check(game_reset && !game_enable, "startup requests reset with no frame tick");
        cycle();
        check(!game_reset && !game_enable && state_debug == 1, "startup reset lasts one clock");
        cycle();
        check(game_enable && state_debug == 2, "startup enters target seek without a frame tick");
        check(target_id_debug == 12 && aim_x_debug == 344, "first goal is bottom target in left column");
        check(move_left && !fire, "ship initially moves left towards target");

        ship_x = 200; #1;
        check(move_right && !move_left && !fire, "ship left of aim moves right");
        ship_x = 347; #1;
        check(fire && !move_left && !move_right, "small alignment error is accepted");
        ship_x = 340; #1;
        check(fire, "alignment tolerance includes lower boundary");
        ship_x = 339; #1;
        check(move_right && !fire, "outside lower alignment boundary keeps moving");
        ship_x = 349; #1;
        check(move_left && !fire, "outside upper alignment boundary keeps moving");
        ship_x = 344; fire_ready = 0; #1;
        check(!fire && !move_left && !move_right, "aligned ship waits while firing is not ready");
        fire_ready = 1;
        step_frame();
        check(state_debug == 3 && fire, "fire request waits for acknowledgement");
        repeat (3) cycle();
        check(state_debug == 3 && fire, "request is held when no acknowledgement has arrived");
        $display("CHECKPOINT: startup reset, targeting, movement and held fire request PASS");

        // ACK occurs between frame ticks while the demo is being paused.
        @(negedge clk);
        fire_accepted = 1; projectile_active = 1; fire_ready = 0; demo_enable = 0;
        @(posedge clk); #1;
        check(state_debug == 4, "one-clock ACK is consumed while paused and between frames");
        @(negedge clk); fire_accepted = 0;
        repeat (3) cycle();
        demo_enable = 1; cycle();
        check(state_debug == 4 && !fire && !move_left && !move_right,
              "resume waits for the existing projectile");
        projectile_active = 0; fire_ready = 1;
        cycle();
        check(state_debug == 2 && fire && target_id_debug == 12,
              "a missed projectile returns to the same live target");

        step_frame();
        @(negedge clk); fire_accepted = 1; fire_ready = 0;
        @(posedge clk); #1;
        check(state_debug == 4 && !fire, "ACK alone is captured even without active feedback");
        @(negedge clk); fire_accepted = 0; alive_flags[12] = 0;
        cycle(); fire_ready = 1; #1;
        check(target_id_debug == 8 && fire, "destroyed bottom target advances aim to next live row");

        alive_flags = 16'heeee; ship_x = 520; #1;
        check(target_id_debug == 13 && aim_x_debug == 520 && fire,
              "empty first column is skipped deterministically");
        target_x_flat[13*11 +: 11] = 544; #1;
        check(aim_x_debug == 552 && move_right && !fire, "aim uses Datapath coordinate feedback");
        target_x_flat[13*11 +: 11] = 512;
        alive_flags[13] = 0; #1;
        check(target_id_debug == 9, "target selection respects live bitmap");

        projectile_active = 1; cycle();
        check(state_debug == 4 && !fire && !move_left && !move_right,
              "active feedback recovers a shot even if ACK was missed");
        projectile_active = 0; alive_flags = 0; cycle();
        repeat (4) step_frame();
        check(!fire && !move_left && !move_right && !game_reset,
              "empty bitmap alone does not invent a win/reset event");
        $display("CHECKPOINT: ACK timing, pause, busy recovery and live-target feedback PASS");

        win = 1; cycle();
        check(state_debug == 5 && !game_enable && !fire, "win enters hold state");
        demo_enable = 0;
        repeat (5) step_frame();
        check(state_debug == 5 && !game_reset, "paused frames do not consume win hold time");
        demo_enable = 1;
        repeat (6) cycle();
        check(state_debug == 5 && !game_reset, "clock cycles without frames do not consume hold time");
        for (i = 1; i < HOLD_FRAMES; i = i + 1) begin
            step_frame();
            check(!game_reset && state_debug == 5, "WIN remains visible before all 180 frames elapse");
        end
        step_frame(); check(game_reset && state_debug == 0, "exact frame 180 requests new game");
        @(posedge clk); #1;
        check(!game_reset && state_debug == 1, "restart reset is one clock wide");
        win = 0; alive_flags = 16'hffff; ship_x = 608;
        cycle();
        check(state_debug == 2 && game_enable && target_id_debug == 12 && move_left,
              "new game resumes the same deterministic route");
        $display("CHECKPOINT: frame-counted win hold, pause and restart PASS");
        $display("PASS: tb_auto_game_controller checks=%0d", checks);
        $finish;
    end
endmodule
