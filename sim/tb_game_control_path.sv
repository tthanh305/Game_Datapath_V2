`timescale 1ns / 1ps

module tb_game_control_path;
reg clk = 0;
always #5 clk = ~clk;
reg rst = 1;
reg frame_tick = 0;
reg [4:0] buttons_raw = 0;
reg game_win = 0;
reg fire_accepted = 0;
reg [4:0] score = 0;
wire game_reset, game_enable, move_left, move_right, fire;
wire menu_active, scoreboard_active;
wire [1:0] selected_option;
wire [4:0] high_score;
wire [2:0] state_debug;
integer checks = 0;
reg saw_game_reset = 0;

game_control_path #(.BUTTON_ACTIVE_LOW(0), .DEBOUNCE_FRAMES(2)) dut (
    .clk(clk), .rst(rst), .frame_tick(frame_tick), .buttons_raw(buttons_raw),
    .game_win(game_win), .fire_accepted(fire_accepted), .score(score),
    .game_reset(game_reset), .game_enable(game_enable), .move_left(move_left),
    .move_right(move_right), .fire(fire), .menu_active(menu_active),
    .scoreboard_active(scoreboard_active), .selected_option(selected_option),
    .high_score(high_score), .state_debug(state_debug)
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

task automatic check(input reg condition, input [255:0] label);
    begin
        checks = checks + 1;
        if (!condition) begin
            $display("FAIL: %0s at %0t state=%0d selected=%0d", label, $time, state_debug, selected_option);
            $fatal(1);
        end
    end
endtask

initial begin
    repeat (5) @(posedge clk);
    rst = 0;
    repeat (3) @(posedge clk);
    check(state_debug == 0 && menu_active && !game_enable, "reset enters main menu");

    press_button(1); check(selected_option == 1, "next selects Resume");
    press_button(1); check(selected_option == 2, "next selects Score Board");
    press_button(1); check(selected_option == 0, "next wraps to New Game");
    press_button(2); check(state_debug == 1 && game_enable, "select starts gameplay");
    repeat (2) @(posedge clk);

    buttons_raw[0] = 1;
    repeat (3) @(posedge clk);
    tick_frame(); tick_frame();
    check(move_left && !move_right, "held BTN0 moves left");
    buttons_raw[0] = 0;
    repeat (3) @(posedge clk);
    tick_frame(); tick_frame();
    check(!move_left, "release stops movement");

    press_button(2);
    check(fire, "fire request remains asserted pending acceptance");
    fire_accepted = 1;
    @(posedge clk); #1;
    fire_accepted = 0;
    @(posedge clk); #1;
    check(!fire, "accepted shot clears pending request");

    press_button(3); check(state_debug == 2 && !game_enable, "BTN3 pauses game");
    press_button(3); check(state_debug == 1 && game_enable, "BTN3 resumes game");
    saw_game_reset = 0;
    press_button(4); check(saw_game_reset, "BTN4 requests round reset");
    @(posedge clk); #1;

    press_button(3); check(state_debug == 2, "pause before scoreboard");
    press_button(1); check(selected_option == 2, "pause menu selects scoreboard");
    press_button(2); check(state_debug == 3 && scoreboard_active, "scoreboard opens");
    press_button(3); check(state_debug == 2 && !scoreboard_active, "scoreboard returns to pause");
    press_button(3); check(state_debug == 1, "resume after scoreboard");

    score = 7;
    game_win = 1;
    @(posedge clk); #1;
    game_win = 0;
    check(state_debug == 4 && high_score == 7, "win screen records score");
    press_button(2); check(state_debug == 0 && menu_active, "win screen returns to menu");
    saw_game_reset = 0;
    press_button(4); check(state_debug == 1 && saw_game_reset, "quick start/restart from menu");

    $display("PASS: tb_game_control_path checks=%0d", checks);
    $finish;
end
endmodule
