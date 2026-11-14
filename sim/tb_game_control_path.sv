`timescale 1ns / 1ps
`include "game_params.vh"

module tb_game_control_path;
reg clk = 0;
always #5 clk = ~clk;
reg rst = 1;
reg frame_tick = 0;
reg [4:0] buttons_raw = 5'b00000; // BUTTON_ACTIVE_LOW=0: active-high in this unit TB
reg game_win = 0;
reg game_over = 0;
reg fire_accepted = 0;
reg [`GAME_SCORE_WIDTH-1:0] score = 0;
wire game_reset, game_enable, move_left, move_right, move_up, move_down, fire, laser_trigger;
wire menu_active, scoreboard_active;
wire [1:0] selected_option;
wire [`GAME_SCORE_WIDTH-1:0] high_score, high_score_2, high_score_3;
wire [2:0] state_debug;
integer checks = 0;
reg saw_game_reset = 0;

// Button mapping (game_control_path.v):
//   BTN[0] = Right, BTN[1] = Up, BTN[2] = Center, BTN[3] = Left, BTN[4] = Down
game_control_path #(.BUTTON_ACTIVE_LOW(0), .DEBOUNCE_FRAMES(2)) dut (
    .clk(clk), .rst(rst), .frame_tick(frame_tick), .buttons_raw(buttons_raw),
    .game_win(game_win), .game_over(game_over),
    .fire_accepted(fire_accepted), .score(score),
    .game_reset(game_reset), .game_enable(game_enable),
    .move_left(move_left), .move_right(move_right),
    .move_up(move_up), .move_down(move_down),
    .fire(fire), .laser_trigger(laser_trigger),
    .menu_active(menu_active), .scoreboard_active(scoreboard_active),
    .selected_option(selected_option),
    .high_score(high_score), .high_score_2(high_score_2), .high_score_3(high_score_3),
    .state_debug(state_debug)
);

always @(posedge clk) if (game_reset) saw_game_reset <= 1'b1;

task automatic tick_frame;
    begin
        frame_tick = 1;
        @(posedge clk); #1;
        frame_tick = 0;
        repeat (2) begin @(posedge clk); #1; end
    end
endtask

task automatic press_button(input integer button_id);
    begin
        buttons_raw[button_id] = 1'b1;
        repeat (3) begin @(posedge clk); #1; end
        tick_frame();
        tick_frame();
        repeat (3) begin @(posedge clk); #1; end
        buttons_raw[button_id] = 1'b0;
        repeat (3) begin @(posedge clk); #1; end
        tick_frame();
        tick_frame();
        repeat (3) begin @(posedge clk); #1; end
    end
endtask

task automatic hold_center_frames(input integer num_frames);
    integer k;
    begin
        buttons_raw[2] = 1'b1;
        repeat (3) begin @(posedge clk); #1; end
        for (k = 0; k < num_frames; k = k + 1)
            tick_frame();
        buttons_raw[2] = 1'b0;
        repeat (3) begin @(posedge clk); #1; end
        tick_frame();
        tick_frame();
        repeat (3) begin @(posedge clk); #1; end
    end
endtask

task automatic check(input reg condition, input [511:0] label);
    begin
        checks = checks + 1;
        if (!condition) begin
            $display("FAIL: %0s at %0t state=%0d selected=%0d hs1=%05h hs2=%05h hs3=%05h",
                     label, $time, state_debug, selected_option, high_score, high_score_2, high_score_3);
            $fatal(1);
        end
    end
endtask

initial begin
    repeat (5) @(posedge clk);
    rst = 0;
    repeat (3) @(posedge clk);
    check(state_debug == 3'd0 && menu_active && !game_enable, "reset enters main menu");

    // Menu navigation: Down (BTN[4]) moves 0 -> 1 -> 2 -> 0, Up (BTN[1]) wraps
    press_button(4); check(selected_option == 2'd1, "down selects Resume");
    press_button(4); check(selected_option == 2'd2, "down selects Score Board");
    press_button(4); check(selected_option == 2'd0, "down wraps to New Game");
    press_button(1); check(selected_option == 2'd2, "up wraps to Score Board");
    press_button(4); check(selected_option == 2'd0, "down wraps back to New Game");

    // Start game via Center (BTN[2])
    saw_game_reset = 0;
    press_button(2);
    check(state_debug == 3'd1 && game_enable && saw_game_reset, "select starts gameplay with reset");

    // Directional movement (wait 3 clocks for 2-FF synchronizer before frame_tick)
    buttons_raw[3] = 1'b1; // Left
    repeat (3) @(posedge clk);
    tick_frame(); tick_frame();
    check(move_left && !move_right, "held BTN[3] moves left");
    buttons_raw[3] = 1'b0;
    repeat (3) @(posedge clk);
    tick_frame(); tick_frame();
    check(!move_left, "release stops left movement");

    buttons_raw[0] = 1'b1; // Right
    repeat (3) @(posedge clk);
    tick_frame(); tick_frame();
    check(move_right && !move_left, "held BTN[0] moves right");
    buttons_raw[0] = 1'b0;
    repeat (3) @(posedge clk);
    tick_frame(); tick_frame();
    check(!move_right, "release stops right movement");

    buttons_raw[1] = 1'b1; // Up
    repeat (3) @(posedge clk);
    tick_frame(); tick_frame();
    check(move_up && !move_down, "held BTN[1] moves up");
    buttons_raw[1] = 1'b0;
    repeat (3) @(posedge clk);
    tick_frame(); tick_frame();

    buttons_raw[4] = 1'b1; // Down
    repeat (3) @(posedge clk);
    tick_frame(); tick_frame();
    check(move_down && !move_up, "held BTN[4] moves down");
    buttons_raw[4] = 1'b0;
    repeat (3) @(posedge clk);
    tick_frame(); tick_frame();

    // Tap Center -> Overdrive Laser / fire_pending on release
    press_button(2);
    check(fire, "tap center asserts fire pending acceptance");
    fire_accepted = 1;
    @(posedge clk); #1;
    fire_accepted = 0;
    @(posedge clk); #1;
    check(!fire, "accepted shot clears pending request");

    // Hold Center >= 60 frames -> Pause to MENU (selected_option=1) WITHOUT duplicating score into leaderboard
    score = 20'h00500;
    hold_center_frames(64);
    check(state_debug == 3'd0 && menu_active && selected_option == 2'd1 && !game_enable, "hold center pauses to menu Resume");
    check(high_score == 20'h00000, "pausing mid-run does not prematurely record high score");

    // Resume from MENU (selected_option == 1) without resetting
    saw_game_reset = 0;
    press_button(2);
    check(state_debug == 3'd1 && game_enable && !saw_game_reset, "Resume returns to PLAYING without reset");

    // Open Scoreboard from Menu and return
    hold_center_frames(64);
    press_button(4); check(selected_option == 2'd2, "menu selects scoreboard");
    press_button(2); check(state_debug == 3'd3 && scoreboard_active, "scoreboard opens");
    press_button(2); check(state_debug == 3'd0 && !scoreboard_active, "scoreboard returns to menu");

    // Resume and finish run with Win -> records score ONCE
    press_button(1); check(selected_option == 2'd1, "up selects Resume");
    press_button(2); check(state_debug == 3'd1, "resumed playing");
    score = 20'h01200;
    game_win = 1'b1;
    @(posedge clk); #1;
    game_win = 1'b0;
    check(state_debug == 3'd4 && high_score == 20'h01200 && high_score_2 == 20'h00000,
          "win screen records score once without paused duplicate");

    // Start 2nd run from Win Screen, end with Game Over (score 00800) -> Top 2
    saw_game_reset = 0;
    press_button(2); check(state_debug == 3'd1 && saw_game_reset, "win screen starts new run");
    score = 20'h00800;
    game_over = 1'b1;
    @(posedge clk); #1;
    game_over = 1'b0;
    check(state_debug == 3'd5 && high_score == 20'h01200 && high_score_2 == 20'h00800,
          "game over records 2nd highest score");

    // Start 3rd run from Game Over, end with Game Over (score 02500) -> shifts Top 3
    press_button(2); check(state_debug == 3'd1, "game over starts new run");
    score = 20'h02500;
    game_over = 1'b1;
    @(posedge clk); #1;
    game_over = 1'b0;
    check(state_debug == 3'd5 && high_score == 20'h02500 && high_score_2 == 20'h01200 && high_score_3 == 20'h00800,
          "top 3 high scores shift correctly");

    $display("PASS: tb_game_control_path checks=%0d", checks);
    $finish;
end
endmodule
