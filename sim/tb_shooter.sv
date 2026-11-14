`timescale 1ns / 1ps
`include "game_params.vh"

module tb_shooter;

reg clk = 1'b0;
always #5 clk = ~clk; // 100 MHz sim clock

reg rst = 1'b1;
reg frame_tick = 1'b0;
reg [4:0] buttons_raw = 5'b00000; // Active-high in TB (BUTTON_ACTIVE_LOW=0)

wire game_reset, game_enable;
wire move_left, move_right, move_up, move_down, fire, laser_trigger;
wire menu_active, scoreboard_active;
wire [1:0] selected_option;
wire [`GAME_SCORE_WIDTH-1:0] high_score, high_score_2, high_score_3, score;
wire [2:0] control_state;

wire hit_flag, fire_ready, fire_accepted, win, game_over;
wire [`GAME_TARGET_ID_WIDTH-1:0] hit_target_id;
wire [6:0] wave_num;
wire [`GAME_TARGET_COUNT-1:0] alive_flags;
wire [10:0] ship_x, ship_y, projectile_x, projectile_y;
wire projectile_active;
wire [`GAME_TARGET_COUNT*11-1:0] target_x_flat, target_y_flat;
wire [7:0] red, green, blue;
wire sound_fire, sound_hit, sound_dive, sound_player_die, sound_win, sound_game_over;
wire sound_powerup, sound_laser;

game_control_path #(
    .BUTTON_ACTIVE_LOW(0),
    .DEBOUNCE_FRAMES(1)
) u_ctrl (
    .clk(clk),
    .rst(rst),
    .frame_tick(frame_tick),
    .buttons_raw(buttons_raw),
    .game_win(win),
    .game_over(game_over),
    .fire_accepted(fire_accepted),
    .score(score),
    .game_reset(game_reset),
    .game_enable(game_enable),
    .move_left(move_left),
    .move_right(move_right),
    .move_up(move_up),
    .move_down(move_down),
    .fire(fire),
    .laser_trigger(laser_trigger),
    .menu_active(menu_active),
    .scoreboard_active(scoreboard_active),
    .selected_option(selected_option),
    .high_score(high_score),
    .high_score_2(high_score_2),
    .high_score_3(high_score_3),
    .state_debug(control_state)
);

game_core #(
    .AUTO_DEMO(0)
) u_core (
    .clk(clk),
    .rst(rst),
    .frame_tick(frame_tick),
    .pixel_active(1'b1),
    .pixel_x(11'd640),
    .pixel_y(11'd360),
    .auto_enable(1'b0),
    .control_game_reset(game_reset),
    .control_game_enable(game_enable),
    .control_move_left(move_left),
    .control_move_right(move_right),
    .control_move_up(move_up),
    .control_move_down(move_down),
    .control_fire(fire),
    .control_laser_trigger(laser_trigger),
    .hit_flag(hit_flag),
    .hit_target_id(hit_target_id),
    .fire_ready(fire_ready),
    .fire_accepted(fire_accepted),
    .score(score),
    .win(win),
    .game_over(game_over),
    .wave_num(wave_num),
    .alive_flags(alive_flags),
    .ship_x(ship_x),
    .ship_y(ship_y),
    .projectile_x(projectile_x),
    .projectile_y(projectile_y),
    .projectile_active(projectile_active),
    .target_x_flat(target_x_flat),
    .target_y_flat(target_y_flat),
    .red(red),
    .green(green),
    .blue(blue),
    .game_reset_debug(),
    .game_enable_debug(),
    .move_left_debug(),
    .move_right_debug(),
    .fire_debug(),
    .auto_state_debug(),
    .target_id_debug(),
    .aim_x_debug(),
    .sound_fire(sound_fire),
    .sound_hit(sound_hit),
    .sound_dive(sound_dive),
    .sound_player_die(sound_player_die),
    .sound_win(sound_win),
    .sound_game_over(sound_game_over),
    .sound_powerup(sound_powerup),
    .sound_laser(sound_laser)
);

task step_frame;
    integer c;
    begin
        @(posedge clk);
        frame_tick <= 1'b1;
        @(posedge clk);
        frame_tick <= 1'b0;
        // Wait 180 clocks for post-frame collision FSM to complete
        for (c = 0; c < 180; c = c + 1) @(posedge clk);
    end
endtask

integer i;
integer checks = 0;
integer failures = 0;

task check_cond(input cond, input [8*64-1:0] msg);
    begin
        if (cond !== 1'b1) begin
            failures = failures + 1;
            $display("FAIL: %0s at time %0t", msg, $time);
            $fatal(1);
        end else begin
            checks = checks + 1;
        end
    end
endtask

// Isolate simultaneous pickups from movement/spawning and check public state.
task check_pickup_pair(
    input [1:0] type0, type1,
    input [2:0] initial_power, initial_lives,
    input [1:0] initial_wingmen,
    input [4:0] initial_rage,
    input [2:0] expected_power, expected_lives,
    input [1:0] expected_wingmen,
    input [4:0] expected_rage,
    input [19:0] expected_score
);
    integer slot;
    begin
        @(negedge clk);
        rst = 1'b1;
        buttons_raw = 5'b0;
        repeat (2) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
        u_core.datapath_inst.physics_inst.power_level = initial_power;
        u_core.datapath_inst.physics_inst.player_lives = initial_lives;
        u_core.datapath_inst.physics_inst.wingmen_count = initial_wingmen;
        u_core.datapath_inst.physics_inst.rage_cnt = initial_rage;
        for (slot = 0; slot < 2; slot = slot + 1) begin
            u_core.datapath_inst.physics_inst.pu_active[slot] = 1'b1;
            u_core.datapath_inst.physics_inst.pu_type[slot] = slot == 0 ? type0 : type1;
            u_core.datapath_inst.physics_inst.pu_x[slot] = ship_x + 11'd8;
            u_core.datapath_inst.physics_inst.pu_y[slot] = ship_y + 11'd8;
        end
        // Start at the same player-collision phase reached by the frame scan.
        u_core.datapath_inst.physics_inst.c_state = 3'd4;
        u_core.datapath_inst.physics_inst.c_phase = 2'd0;
        repeat (8) @(negedge clk);
        check_cond(u_core.datapath_inst.physics_inst.pu_active == 0,
                   "Both overlapping pickups consumed");
        check_cond(u_core.datapath_inst.physics_inst.power_level == expected_power &&
                   u_core.datapath_inst.physics_inst.player_lives == expected_lives &&
                   u_core.datapath_inst.physics_inst.wingmen_count == expected_wingmen &&
                   u_core.datapath_inst.physics_inst.rage_cnt == expected_rage,
                   "Both pickup effects accumulated with limits");
        check_cond(score == expected_score, "Both pickup BCD rewards accumulated");
    end
endtask

initial begin
    // 1. Reset
    rst = 1'b1;
    repeat (10) @(posedge clk);
    rst = 1'b0;
    repeat (5) @(posedge clk);

    // Verify initial menu state & Sprite ROM BRAM initialization (Player Ship Tile 0 & Enemy Tile 1)
    check_cond(menu_active == 1'b1, "Starts in MENU");
    check_cond(u_core.datapath_inst.color_mapper_inst.sprite_rom_inst.rom[16] == 4'h4, "Sprite ROM Tile 0 (Player Ship) initialized with non-zero pixel data");
    check_cond(u_core.datapath_inst.color_mapper_inst.sprite_rom_inst.rom[1024 + 8*32 + 16] != 4'h0, "Sprite ROM Tile 1 (Enemy Boss) initialized with non-zero pixel data");

    // 2. Press Center button (BTN[2]) to start New Game
    buttons_raw = 5'b00100;
    step_frame();
    step_frame();
    buttons_raw = 5'b00000;
    step_frame();
    step_frame();

    check_cond(menu_active == 1'b0 && game_enable == 1'b1, "Entered PLAYING state");
    check_cond(u_core.datapath_inst.physics_inst.player_lives == 3'd5, "Player starts with 5 lives");
    check_cond(u_core.datapath_inst.physics_inst.wave_entry_offset > 8'd0, "Enemies start descending from top of screen at wave start");
    check_cond(u_core.datapath_inst.physics_inst.form_alive == 44'hFFF_FFFF_FFFF, "All 44 enemies (11x4) alive at Wave 1 start");
    check_cond(u_core.datapath_inst.physics_inst.enemy_hp[0]  == 5'd6, "Row 0 Boss HP = 6 on Wave 1");
    check_cond(u_core.datapath_inst.physics_inst.enemy_hp[11] == 5'd4, "Row 1 Escort HP = 4 on Wave 1");
    check_cond(u_core.datapath_inst.physics_inst.enemy_hp[22] == 5'd2, "Row 2 Drone HP = 2 on Wave 1");
    check_cond(u_core.datapath_inst.physics_inst.enemy_hp[33] == 5'd2, "Row 3 Gold Drone HP = 2 on Wave 1");

    // 3. Verify Automatic Firing without pressing fire button
    for (i = 0; i < 12; i = i + 1) step_frame();
    check_cond(u_core.datapath_inst.physics_inst.pbul_active != 16'd0, "Ship auto-fires without pressing buttons");

    // 4. Verify 4-Directional Player Movement (Up, Down, Left, Right)
    // Move Up (BTN[1]) and Left (BTN[3])
    buttons_raw = 5'b01010;
    for (i = 0; i < 5; i = i + 1) step_frame();
    check_cond(ship_x < 11'd624 && ship_y < 11'd620, "Ship moved Up and Left");

    // Move Down (BTN[4]) and Right (BTN[0])
    buttons_raw = 5'b10001;
    for (i = 0; i < 5; i = i + 1) step_frame();
    buttons_raw = 5'b00000;
    step_frame();

    // 5. Run 65 frames to verify wave entry descent completes, enemy hits, enemy shooting, and diving
    for (i = 0; i < 65; i = i + 1) step_frame();
    check_cond(u_core.datapath_inst.physics_inst.wave_entry_offset == 8'd0, "Wave entry descent completed into formation position");
    check_cond(u_core.datapath_inst.physics_inst.form_alive != 44'hFFF_FFFF_FFFF, "Auto-fire bullets damage and destroy formation enemies");
    check_cond(u_core.datapath_inst.physics_inst.div_active != 4'd0 || u_core.datapath_inst.physics_inst.ebul_active != 10'd0, "Enemies dive and shoot actively");

    // 6. Test Power-Up Pickup progression (1 -> 5 streams -> 2 wingmen firing homing bullets)
    for (i = 0; i < 6; i = i + 1) begin
        // Place active Item P directly on the ship to simulate pickup
        u_core.datapath_inst.physics_inst.pu_active[0] = 1'b1;
        u_core.datapath_inst.physics_inst.pu_type[0] = 2'd0; // ITEM_TYPE_POWER
        u_core.datapath_inst.physics_inst.pu_x[0] = ship_x + 11'd8;
        u_core.datapath_inst.physics_inst.pu_y[0] = ship_y + 11'd8;
        step_frame();
    end
    check_cond(u_core.datapath_inst.physics_inst.power_level == 3'd5, "Power level upgraded to max 5 streams");
    check_cond(u_core.datapath_inst.physics_inst.wingmen_count == 2'd2, "Wingmen upgraded to max 2 side fighters");

    // 6b. Test 64x64 Asteroid collision & Bullet Impact Effect (imp_active)
    u_core.datapath_inst.physics_inst.ast_active[0] = 1'b1;
    u_core.datapath_inst.physics_inst.ast_x[0] = ship_x - 11'd16;
    u_core.datapath_inst.physics_inst.ast_y[0] = 11'd300;
    u_core.datapath_inst.physics_inst.ast_hp[0] = 5'd10;
    u_core.datapath_inst.physics_inst.pbul_active[0] = 1'b1;
    u_core.datapath_inst.physics_inst.pbul_x[0] = ship_x + 11'd16; // hits within 64x64 box [ship_x-16 .. ship_x+48]
    u_core.datapath_inst.physics_inst.pbul_y[0] = 11'd345;         // hits bottom half of 64x64 box [300..364]
    step_frame();
    check_cond(u_core.datapath_inst.physics_inst.ast_hp[0] < 5'd10, "64x64 Asteroid took bullet damage at outer 64x64 hitbox");
    check_cond(u_core.datapath_inst.imp_active != 4'd0, "Bullet Impact Effect (starburst/ring) spawned on asteroid hit");

    // Wait 20 frames for wingmen to fire homing bullets
    for (i = 0; i < 20; i = i + 1) step_frame();
    check_cond(u_core.datapath_inst.physics_inst.hbul_active != 8'd0, "Wingmen fire homing bullets");

    // 6c. Test Top-Down Return Flight of Diving Enemy & Breakable Purple Shield
    u_core.datapath_inst.physics_inst.div_active[0] = 1'b1;
    u_core.datapath_inst.physics_inst.div_returning[0] = 1'b0;
    u_core.datapath_inst.physics_inst.div_idx[0] = 6'd0;
    u_core.datapath_inst.physics_inst.div_x[0] = 11'd500;
    u_core.datapath_inst.physics_inst.div_y[0] = 11'd702; // Passed bottom of screen
    step_frame();
    check_cond(u_core.datapath_inst.physics_inst.div_active[0] == 1'b1 && u_core.datapath_inst.physics_inst.div_returning[0] == 1'b1, "Diving enemy enters top-down returning state instead of teleporting");
    check_cond(u_core.datapath_inst.physics_inst.div_y[0] < 11'd40, "Returning enemy re-enters from top of screen");

    // Verify Active Purple Shield (invuln_timer > 0) absorbs enemy bullet and breaks immediately
    u_core.datapath_inst.physics_inst.player_lives = 3'd5;
    u_core.datapath_inst.physics_inst.respawn_invuln_timer = 7'd0;
    u_core.datapath_inst.physics_inst.invuln_timer = 7'd80;
    u_core.datapath_inst.physics_inst.laser_timer = 7'd0;
    u_core.datapath_inst.physics_inst.ebul_active[0] = 1'b1;
    u_core.datapath_inst.physics_inst.ebul_x[0] = ship_x + 11'd12;
    u_core.datapath_inst.physics_inst.ebul_y[0] = ship_y + 11'd3;
    u_core.datapath_inst.physics_inst.ebul_vx[0] = 4'sd0;
    u_core.datapath_inst.physics_inst.ebul_type[0] = 2'd0;
    step_frame();
    check_cond(u_core.datapath_inst.physics_inst.invuln_timer == 7'd0, "Purple Shield breaks immediately upon absorbing an enemy bullet hit");
    check_cond(u_core.datapath_inst.physics_inst.player_lives == 3'd5, "Player life is preserved when Purple Shield absorbs a hit");

    // 6d. Test Mothership Boss Special Moves (Death-Ray Telegraph -> Mega Laser & Enrage Mode)
    u_core.datapath_inst.physics_inst.boss_active = 1'b1;
    u_core.datapath_inst.physics_inst.boss_hp = 8'd20;
    u_core.datapath_inst.physics_inst.boss_max_hp = 8'd80;
    u_core.datapath_inst.physics_inst.boss_skill_idx = 2'd2; // Death-Ray Move
    u_core.datapath_inst.physics_inst.boss_shoot_cnt = 6'd38; // Enraged shoot threshold
    step_frame();
    check_cond(u_core.datapath_inst.boss_enraged == 1'b1, "Boss enters Enrage Mode when HP < 50%");
    check_cond(u_core.datapath_inst.boss_warn_timer > 7'd0, "Boss activates Red Telegraph Warning Sight before Death-Ray");
    u_core.datapath_inst.physics_inst.boss_warn_timer = 7'd1;
    step_frame();
    check_cond(u_core.datapath_inst.boss_laser_timer > 7'd0, "Boss fires Mega Death-Ray column after Telegraph Warning");
    u_core.datapath_inst.physics_inst.boss_laser_timer = 7'd0;
    u_core.datapath_inst.physics_inst.boss_active = 1'b0;

    // 7. Test Overdrive Laser (Rage Bar = 20, tap & release Center button BTN[2])
    u_core.datapath_inst.physics_inst.rage_cnt = 5'd20;
    buttons_raw = 5'b00100; // Press Center
    step_frame();
    step_frame();
    buttons_raw = 5'b00000; // Release Center (triggers laser_trigger on release)
    step_frame();
    step_frame();
    check_cond(u_core.datapath_inst.physics_inst.laser_timer > 7'd100, "Overdrive Laser activated on Center button press when Rage is full");
    check_cond(u_core.datapath_inst.physics_inst.rage_cnt == 5'd0, "Rage bar consumed upon laser activation");

    // 7b. Verify returned diver gets mandatory rest period in formation and does not immediately re-dive
    u_core.datapath_inst.physics_inst.wave_transition = 1'b0;
    u_core.datapath_inst.physics_inst.wave_entry_offset = 8'd0;
    u_core.datapath_inst.physics_inst.form_alive = 44'd1; // Only alien 0 alive
    u_core.datapath_inst.physics_inst.div_active = 4'b0001;
    u_core.datapath_inst.physics_inst.div_returning = 4'b0001;
    u_core.datapath_inst.physics_inst.div_idx[0] = 6'd0;
    u_core.datapath_inst.physics_inst.r_form_diving_mask = 44'd1;
    u_core.datapath_inst.physics_inst.div_base_x[0] = 11'd288;
    u_core.datapath_inst.physics_inst.div_base_y[0] = 11'd72;
    u_core.datapath_inst.physics_inst.div_x[0] = 11'd288 + u_core.datapath_inst.physics_inst.fleet_offset_x;
    u_core.datapath_inst.physics_inst.div_y[0] = 11'd70;
    u_core.datapath_inst.physics_inst.dive_cooldown = 8'd0;
    step_frame();
    check_cond(u_core.datapath_inst.physics_inst.div_active[0] == 1'b0 && u_core.datapath_inst.physics_inst.div_step[0] == 6'd63, "Returned diver enters mandatory post-dive rest timer in formation");
    u_core.datapath_inst.physics_inst.dive_cooldown = 8'd0;
    u_core.datapath_inst.physics_inst.diver_scan_ptr = 6'd0;
    step_frame();
    check_cond(u_core.datapath_inst.physics_inst.r_form_diving_mask[0] == 1'b0 && u_core.datapath_inst.physics_inst.div_active == 4'd0, "Last remaining alien rests in formation instead of diving continuously");

    // 8. Test Holding Center Button (BTN[2]) for >= 60 frames (~1 second) to exit to MENU
    buttons_raw = 5'b00100;
    for (i = 0; i < 65; i = i + 1) step_frame();
    check_cond(menu_active == 1'b1, "Holding Center button for 1s exits PLAYING back to MENU");
    check_cond(selected_option == 2'd1, "Menu highlights Continue after exiting via Center hold");

    // Two pickups in one collision pass: progression, saturation and BCD carry.
    check_pickup_pair(0, 0, 1, 5, 0, 0, 3, 5, 0, 0, 20'h00000);
    check_pickup_pair(0, 0, 4, 5, 0, 0, 5, 5, 1, 0, 20'h00000);
    check_pickup_pair(0, 0, 5, 5, 1, 0, 5, 5, 2, 0, 20'h00500);
    check_pickup_pair(0, 0, 5, 5, 2, 0, 5, 5, 2, 0, 20'h01000);
    check_pickup_pair(1, 1, 1, 3, 0, 0, 1, 5, 0, 0, 20'h00400);
    check_pickup_pair(1, 1, 1, 4, 0, 0, 1, 5, 0, 0, 20'h00400);
    check_pickup_pair(2, 2, 1, 5, 0, 0, 1, 5, 0, 12, 20'h00400);
    check_pickup_pair(2, 2, 1, 5, 0, 15, 1, 5, 0, 20, 20'h00400);
    check_pickup_pair(1, 2, 1, 4, 0, 18, 1, 5, 0, 20, 20'h00400);

    if (failures != 0)
        $fatal(1, "FAIL: tb_shooter failures=%0d", failures);
    else
        $display("PASS: tb_shooter all %0d verification checks succeeded!", checks);
    $finish;
end

endmodule

