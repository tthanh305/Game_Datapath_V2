`timescale 1ns / 1ps
`include "game_params.vh"

module tb_gameplay_improvements;

    reg clk = 0;
    always #6.734 clk = ~clk; // ~74.25 MHz pixel clock (period ~13.468ns)

    reg rst = 1;
    reg frame_tick = 0;
    reg [4:0] buttons_raw = 5'h1f; // active-low: all unpressed

    wire game_reset, game_enable, move_left, move_right, move_up, move_down, fire;
    wire laser_trigger, menu_active, scoreboard_active;
    wire [1:0] selected_option;
    wire [2:0] state_debug;
    wire [`GAME_SCORE_WIDTH-1:0] high_score, high_score_2, high_score_3;

    reg game_win = 0;
    reg game_over = 0;
    reg fire_accepted = 0;
    reg [`GAME_SCORE_WIDTH-1:0] score = 0;

    game_control_path #(
        .BUTTON_ACTIVE_LOW(1),
        .DEBOUNCE_FRAMES(1)
    ) ctrl_inst (
        .clk(clk),
        .rst(rst),
        .frame_tick(frame_tick),
        .buttons_raw(buttons_raw),
        .game_win(game_win),
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
        .state_debug(state_debug)
    );

    wire [`GAME_COORD_WIDTH-1:0] ship_x, ship_y;
    wire [2:0] player_lives;
    wire player_exploding;
    wire [6:0] laser_timer, invuln_timer;
    wire respawn_invuln;
    wire [4:0] rage_cnt;
    wire [6:0] wave_num;
    wire boss_active;
    wire [7:0] boss_hp;
    wire [3:0] exp_active;
    wire [1:0] pu_active;

    physics_engine phys_inst (
        .clk(clk),
        .rst(rst),
        .game_reset(game_reset),
        .frame_tick(frame_tick),
        .game_enable(game_enable),
        .move_left(move_left),
        .move_right(move_right),
        .move_up(move_up),
        .move_down(move_down),
        .fire(fire),
        .laser_trigger(laser_trigger),
        .hit_flag(),
        .hit_target_id(),
        .fire_ready(),
        .fire_accepted(),
        .score(),
        .win(),
        .game_over(),
        .wave_num(wave_num),
        .ship_x(ship_x),
        .ship_y(ship_y),
        .projectile_x(),
        .projectile_y(),
        .projectile_active(),
        .projectile2_x(),
        .projectile2_y(),
        .projectile2_active(),
        .alive_flags(),
        .target_x_flat(),
        .target_y_flat(),
        .player_lives(player_lives),
        .player_exploding(player_exploding),
        .player_exp_phase(),
        .diving_x(),
        .diving_y(),
        .diving_active(),
        .diving_id(),
        .bomb_active(),
        .bomb_x(),
        .bomb_y(),
        .alien_anim_phase(),
        .alien_exploding(),
        .alien_explode_x(),
        .alien_explode_y(),
        .alien_explode_timer(),
        .diver_tilt(),
        .ship_tilt_frame(),
        .hit_stop_active(),
        .diver_ghost_x(),
        .diver_ghost_y(),
        .hit_flash_mask(),
        .muzzle_flash_timer(),
        .screen_shake_cnt(),
        .muzzle_timer(),
        .enemy_flash_timer(),
        .flash_alien_id(),
        .freeze_timer(),
        .shake_timer(),
        .shake_dx(),
        .shake_dy(),
        .exp_x_flat(),
        .exp_y_flat(),
        .exp_timer_flat(),
        .exp_active(exp_active),
        .debris_x_flat(),
        .debris_y_flat(),
        .debris_life_flat(),
        .debris_active(),
        .form_alive(),
        .form_diving_mask(),
        .power_level(),
        .wingmen_count(),
        .rage_cnt(rage_cnt),
        .laser_timer(laser_timer),
        .invuln_timer(invuln_timer),
        .respawn_invuln(respawn_invuln),
        .pbul_active_out(),
        .pbul_x_flat(),
        .pbul_y_flat(),
        .hbul_active_out(),
        .hbul_x_flat(),
        .hbul_y_flat(),
        .ebul_active_out(),
        .ebul_x_flat(),
        .ebul_y_flat(),
        .ebul_type_flat(),
        .div_active_out(),
        .div_idx_flat(),
        .div_x_flat(),
        .div_y_flat(),
        .ast_active_out(),
        .ast_x_flat(),
        .ast_y_flat(),
        .ast_hp_flat(),
        .ast_max_hp_out(),
        .pu_active_out(pu_active),
        .pu_x_flat(),
        .pu_y_flat(),
        .pu_type_flat(),
        .boss_active(boss_active),
        .boss_x(),
        .boss_y(),
        .boss_hp(boss_hp),
        .boss_max_hp(),
        .boss_flash_timer(),
        .boss_warn_timer(),
        .boss_laser_timer(),
        .boss_enraged(),
        .row0_hp_flat(),
        .row0_max_hp_out(),
        .fleet_offset_x_out(),
        .wave_entry_offset(),
        .imp_active_out(),
        .imp_x_flat(),
        .imp_y_flat(),
        .imp_timer_flat(),
        .sound_fire(),
        .sound_hit(),
        .sound_dive(),
        .sound_player_die(),
        .sound_win(),
        .sound_game_over(),
        .sound_powerup(),
        .sound_laser()
    );

    task automatic do_frame_tick;
        begin
            @(posedge clk);
            frame_tick = 1'b1;
            @(posedge clk);
            frame_tick = 1'b0;
            repeat (10) @(posedge clk);
        end
    endtask

    integer pass_count = 0;

    initial begin
        $display("=== STARTING GAMEPLAY IMPROVEMENTS VERIFICATION ===");

        // 1. Reset DUT
        repeat (10) @(posedge clk);
        rst = 0;
        do_frame_tick();
        do_frame_tick();

        if (state_debug == 3'd0) begin
            $display("[PASS] Initial state is MENU (0)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Expected MENU, got %d", state_debug);
        end

        // 2. Start Game: Press K3 (Center, active low: bit 2 = 0)
        buttons_raw[2] = 1'b0;
        do_frame_tick();
        buttons_raw[2] = 1'b1;
        do_frame_tick();

        if (state_debug == 3'd1 && game_enable) begin
            $display("[PASS] Successfully entered PLAYING state");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Expected PLAYING, got %d", state_debug);
        end

        // 3. Test Input Latency: Press Left (K4: bit 3 = 0)
        buttons_raw[3] = 1'b0;
        repeat (3) @(posedge clk); // Allow 2-stage sync flip-flops to settle
        do_frame_tick(); // Frame 1: Debounce 1 frame should immediately assert move_left!
        if (move_left) begin
            $display("[PASS] Input response: move_left asserted in 1 FRAME (no 3-frame lag)!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] move_left not asserted in 1 frame");
        end

        // Release Left:
        buttons_raw[3] = 1'b1;
        repeat (3) @(posedge clk);
        do_frame_tick();
        if (!move_left) begin
            $display("[PASS] Input release: stopped moving immediately in 1 FRAME!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] move_left still asserted after release");
        end

        // 4. Test Respawn Invulnerability
        if (respawn_invuln) begin
            $display("[PASS] True God Mode active at game start (respawn_invuln == 1)!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] respawn_invuln is not active at start");
        end

        // 5. Test Tap Center vs Hold Center (Laser vs Pause)
        // Set rage to full so Laser is ready
        force phys_inst.rage_cnt = 5'd20;
        @(posedge clk);

        // Tap Center: press for 2 frames then release
        buttons_raw[2] = 1'b0;
        repeat (3) @(posedge clk);
        do_frame_tick();
        do_frame_tick();
        buttons_raw[2] = 1'b1; // Release
        repeat (3) @(posedge clk);
        do_frame_tick(); // On release frame tick, laser_trigger pulses

        if (laser_timer > 7'd0) begin
            $display("[PASS] TAP Center correctly triggers Overdrive Laser on release!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] laser_trigger not asserted on release of short tap (laser_timer=%d)", laser_timer);
        end

        // Advance frames until laser finishes
        release phys_inst.rage_cnt;
        repeat (130) do_frame_tick();

        // Replenish rage again
        force phys_inst.rage_cnt = 5'd20;
        @(posedge clk);
        release phys_inst.rage_cnt;

        // Hold Center for >= 60 frames to PAUSE / Exit to MENU:
        buttons_raw[2] = 1'b0;
        repeat (65) do_frame_tick();

        if (state_debug == 3'd0) begin
            $display("[PASS] HOLD Center (60 frames) smoothly returns to MENU/PAUSE!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Expected MENU after hold, got %d", state_debug);
        end

        // Check if Laser was wasted:
        if (laser_timer == 7'd0 && phys_inst.rage_cnt == 5'd20) begin
            $display("[PASS] PERFECT! Overdrive Laser was NOT wasted while holding to pause (Rage remains full)!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Laser was inadvertently fired! Rage=%d, laser_timer=%d", phys_inst.rage_cnt, laser_timer);
        end

        buttons_raw[2] = 1'b1;
        do_frame_tick();

        // 6. Test Respawn Invulnerability against Hits
        // Re-enter PLAYING
        buttons_raw[2] = 1'b0; // Press Start
        repeat (3) @(posedge clk);
        do_frame_tick();
        buttons_raw[2] = 1'b1;
        repeat (3) @(posedge clk);
        do_frame_tick();

        // Ship is in PLAYING and has respawn_invuln == 1
        force phys_inst.respawn_invuln_timer = 7'd60;
        // Inject player hit condition (collision pipeline detected hit)
        force phys_inst.r_player_hit_q = 1'b1;
        force phys_inst.c_phase = 2'd2; // Resolve phase
        @(posedge clk);
        do_frame_tick();
        release phys_inst.r_player_hit_q;
        release phys_inst.c_phase;

        if (player_lives == `PLAYER_INIT_LIVES && !player_exploding) begin
            $display("[PASS] Respawn God Mode: Player absorbed hit without losing life or breaking invuln!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Player took damage during respawn protection! lives=%d", player_lives);
        end
        release phys_inst.respawn_invuln_timer;

        // 7. Test Laser Defeating Boss (Double explosion & 2 Powerups)
        force phys_inst.boss_active = 1'b1;
        force phys_inst.boss_hp = 8'd2;
        force phys_inst.boss_x = 11'd600;
        force phys_inst.boss_y = 11'd64;
        force phys_inst.laser_hits_q = 1'b1;
        force phys_inst.c_state = 3'd3; // C_LASER state
        force phys_inst.c_idx = 6'd44;   // Boss check slot
        @(posedge clk);
        do_frame_tick();

        release phys_inst.boss_active;
        release phys_inst.boss_hp;
        release phys_inst.boss_x;
        release phys_inst.boss_y;
        release phys_inst.laser_hits_q;
        release phys_inst.c_state;
        release phys_inst.c_idx;

        if (exp_active[0] && exp_active[1] && pu_active[0] && pu_active[1]) begin
            $display("[PASS] Laser Boss Defeat: Dual explosions and 2 Power-ups spawned identically to standard kill!");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Laser boss kill missing explosions or powerups: exp=%b pu=%b", exp_active, pu_active);
        end

        $display("=== SUMMARY: %0d / 10 CHECKS PASSED ===", pass_count);
        if (pass_count == 10) begin
            $display("ALL 10 GAMEPLAY IMPROVEMENTS VERIFIED SUCCESSFULLY!");
        end
        $finish;
    end

endmodule
