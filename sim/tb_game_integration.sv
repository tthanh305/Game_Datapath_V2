`timescale 1ns / 1ps

// Functional game-core integration: accelerated frame enables, no video timing
// generator/TMDS model yet. Runs two full autonomous games and two restarts.
module tb_game_integration;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, frame_tick = 0, auto_enable = 1;
    reg [10:0] pixel_x = 572, pixel_y = 440;
    wire hit_flag, fire_ready, fire_accepted, win, projectile_active;
    wire [3:0] hit_target_id, target_id_debug;
    wire [4:0] score;
    wire [15:0] alive_flags;
    wire [10:0] ship_x, ship_y, projectile_x, projectile_y, aim_x_debug;
    wire [175:0] target_x_flat, target_y_flat;
    wire [7:0] red, green, blue;
    wire game_reset_debug, game_enable_debug, move_left_debug, move_right_debug, fire_debug;
    wire [2:0] auto_state_debug;
    localparam integer HOLD_FRAMES = 4;

    game_core #(.WIN_HOLD_FRAMES(HOLD_FRAMES)) dut (
        .clk(clk), .rst(rst), .frame_tick(frame_tick), .pixel_active(1'b1),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .auto_enable(auto_enable),
        // These deliberately conflicting external commands must be ignored.
        .control_game_reset(1'b1), .control_game_enable(1'b0),
        .control_move_left(1'b1), .control_move_right(1'b1), .control_fire(1'b1),
        .hit_flag(hit_flag), .hit_target_id(hit_target_id), .fire_ready(fire_ready),
        .fire_accepted(fire_accepted), .score(score), .win(win), .alive_flags(alive_flags),
        .ship_x(ship_x), .ship_y(ship_y), .projectile_x(projectile_x),
        .projectile_y(projectile_y), .projectile_active(projectile_active),
        .target_x_flat(target_x_flat), .target_y_flat(target_y_flat),
        .red(red), .green(green), .blue(blue), .game_reset_debug(game_reset_debug),
        .game_enable_debug(game_enable_debug), .move_left_debug(move_left_debug),
        .move_right_debug(move_right_debug), .fire_debug(fire_debug),
        .auto_state_debug(auto_state_debug), .target_id_debug(target_id_debug),
        .aim_x_debug(aim_x_debug)
    );

    reg manual_rst = 1, manual_reset = 0, manual_enable = 0;
    reg manual_left = 0, manual_right = 0, manual_fire = 0;
    reg [10:0] manual_pixel_x = 0, manual_pixel_y = 0;
    wire [10:0] manual_ship_x, manual_projectile_x, manual_projectile_y;
    wire manual_projectile_active;
    wire [7:0] manual_red, manual_green, manual_blue;
    game_core #(.AUTO_DEMO(0)) manual_dut (
        .clk(clk), .rst(manual_rst), .frame_tick(frame_tick), .pixel_active(1'b1),
        .pixel_x(manual_pixel_x), .pixel_y(manual_pixel_y), .auto_enable(1'b0),
        .control_game_reset(manual_reset), .control_game_enable(manual_enable),
        .control_move_left(manual_left), .control_move_right(manual_right),
        .control_fire(manual_fire), .hit_flag(), .hit_target_id(), .fire_ready(),
        .fire_accepted(), .score(), .win(), .alive_flags(), .ship_x(manual_ship_x),
        .ship_y(), .projectile_x(manual_projectile_x), .projectile_y(manual_projectile_y),
        .projectile_active(manual_projectile_active), .target_x_flat(), .target_y_flat(),
        .red(manual_red), .green(manual_green), .blue(manual_blue),
        .game_reset_debug(), .game_enable_debug(), .move_left_debug(),
        .move_right_debug(), .fire_debug(), .auto_state_debug(),
        .target_id_debug(), .aim_x_debug()
    );

    integer checks = 0, frames = 0, wins = 0, restarts = 0;
    integer round_shots = 0, round_hits = 0, total_shots = 0, total_hits = 0;
    integer hold_ticks = 0, expected_id, saved_ship, saved_bullet_y;
    reg [15:0] seen_targets = 0;
    reg previous_win = 0, previous_hit = 0, previous_accepted = 0;
    reg [4:0] previous_score = 0;
    reg paused_once = 0;

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL: %s at %0t state=%0d score=%0d", message, $time,
                         auto_state_debug, score);
                $fatal(1, "Autonomous game integration assertion failed");
            end
        end
    endtask

    task automatic cycle;
        begin
            @(negedge clk);
            @(posedge clk); #2;
        end
    endtask

    task automatic step_frame;
        begin
            @(negedge clk); frame_tick = 1;
            @(posedge clk); #2;
            @(negedge clk); frame_tick = 0;
            // Give one-clock handshakes time to reach the controller.
            repeat (5) @(negedge clk);
            frames = frames + 1;
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (rst) begin
            wins = 0; restarts = 0; round_shots = 0; round_hits = 0;
            total_shots = 0; total_hits = 0; seen_targets = 0;
            previous_win = 0; previous_hit = 0; previous_accepted = 0;
            previous_score = 0; hold_ticks = 0;
        end else begin
            check(!(hit_flag && previous_hit), "hit pulse remains one clock wide");
            check(!(fire_accepted && previous_accepted), "accepted pulse remains one clock wide");
            check(!(move_left_debug && move_right_debug), "autonomous directions never conflict");
            if (projectile_active)
                check(!move_left_debug && !move_right_debug, "ship waits while its projectile travels");

            if (fire_accepted) begin
                check(projectile_active, "accepted request creates an active projectile");
                check(projectile_x == 373 + (round_shots/4)*176,
                      "autonomous shot is aligned to the expected target column");
                round_shots = round_shots + 1; total_shots = total_shots + 1;
                check(round_shots <= 16, "no unnecessary shots in a round");
            end
            if (hit_flag) begin
                expected_id = (3 - (round_hits%4))*4 + round_hits/4;
                check(hit_target_id == expected_id, "deterministic column/row hit order");
                check(!seen_targets[hit_target_id], "a target is never scored twice");
                seen_targets[hit_target_id] = 1;
                round_hits = round_hits + 1; total_hits = total_hits + 1;
                check(score == round_hits, "each autonomous hit adds exactly one point");
            end
            if (win && !previous_win) begin
                wins = wins + 1;
                check(score == 16 && alive_flags == 0 && round_hits == 16 && round_shots == 16,
                      "autonomous round wins with sixteen hits and sixteen shots");
                check({red,green,blue} == 24'hffff00, "autonomous win reaches the WIN renderer");
                hold_ticks = 0;
                $display("CHECKPOINT: autonomous round %0d WIN, shots=%0d hits=%0d score=%0d",
                         wins, round_shots, round_hits, score);
            end else if (win && previous_win && frame_tick && auto_enable) begin
                hold_ticks = hold_ticks + 1;
            end
            if (previous_score == 16 && score == 0) begin
                restarts = restarts + 1;
                check(hold_ticks == HOLD_FRAMES, "win is held for exactly the configured number of frames");
                check(alive_flags == 16'hffff && ship_x == 608 && !projectile_active && !win,
                      "automatic restart restores the complete game state");
                round_shots = 0; round_hits = 0; seen_targets = 0;
            end
            previous_win = win; previous_hit = hit_flag;
            previous_accepted = fire_accepted; previous_score = score;
        end
    end

    initial begin
        #5000000;
        $fatal(1, "Autonomous integration watchdog expired");
    end

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (4) cycle();
        while (restarts < 2 && frames < 4000) begin
            step_frame();
            if (!paused_once && projectile_active && projectile_y <= 600 && score == 0) begin
                auto_enable = 0; saved_ship = ship_x; saved_bullet_y = projectile_y;
                repeat (4) step_frame();
                check(ship_x == saved_ship && projectile_y == saved_bullet_y && score == 0 &&
                      !game_enable_debug && !fire_debug && !move_left_debug && !move_right_debug,
                      "auto_enable pauses command outputs and the active game");
                auto_enable = 1; paused_once = 1;
            end
        end
        check(paused_once && wins == 2 && restarts == 2 && total_shots == 32 && total_hits == 32,
              "two complete autonomous games and two restarts finish within the frame budget");
        auto_enable = 0;
        pixel_x = 204; pixel_y = 28; #1;
        check({red,green,blue} == 24'h00dfff, "restarted game renders score 00");
        $display("CHECKPOINT: two autonomous games/restarts PASS, frames=%0d shots=%0d hits=%0d",
                 frames, total_shots, total_hits);

        // Exercise the external-control configuration without changing Physics.
        repeat (2) @(negedge clk);
        manual_rst = 0; manual_enable = 1; manual_right = 1;
        repeat (2) step_frame();
        manual_right = 0;
        check(manual_ship_x == 624, "external-control mode moves with auto_enable tied low");
        manual_fire = 1; step_frame(); manual_fire = 0;
        check(manual_projectile_active && manual_projectile_x == 653 && manual_projectile_y == 624,
              "external fire reaches the unchanged Datapath");
        manual_pixel_x = 653; manual_pixel_y = 624; #1;
        check({manual_red,manual_green,manual_blue} == 24'hffffff,
              "external-control projectile is rendered");
        manual_enable = 0; manual_left = 1;
        repeat (3) step_frame();
        check(manual_ship_x == 624 && manual_projectile_y == 624,
              "external game_enable pauses the external-control configuration");
        manual_reset = 1; cycle(); manual_reset = 0; manual_left = 0;
        check(manual_ship_x == 608 && !manual_projectile_active,
              "external game_reset works independently of frame_tick and auto_enable");
        $display("CHECKPOINT: external Control Path interface mode PASS");
        $display("PASS: tb_game_integration checks=%0d wins=%0d restarts=%0d shots=%0d hits=%0d",
                 checks, wins, restarts, total_shots, total_hits);
        $finish;
    end
endmodule
