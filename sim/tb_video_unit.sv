`timescale 1ns / 1ps

module tb_video_unit;
    reg test_done = 0;
    reg pck = 0, clock_running = 1;
    initial begin : clock_driver
        forever begin
            #5;
            if (clock_running) pck = ~pck;
            else pck = 0;
        end
    end
    reg system_reset = 1, clock_locked = 0;
    reg requested_720p = 0, active_720p = 0, enable = 1;
    reg [10:0] hcount = 1, vcount = 0;
    wire game_reset, request_sync, tick;
    reg previous_tick = 0;
    integer checks = 0, pulses = 0, i;

    game_clock_reset reset_dut (
        .pck(pck), .system_reset(system_reset), .clock_locked(clock_locked),
        .requested_720p(requested_720p), .active_720p(active_720p),
        .game_reset(game_reset), .requested_720p_sync(request_sync)
    );
    frame_tick tick_dut (
        .clk(pck), .rst(game_reset), .enable(enable),
        .hcount(hcount), .vcount(vcount), .tick(tick)
    );

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL: %s at %0t reset=%b request_sync=%b tick=%b",
                         message, $time, game_reset, request_sync, tick);
                $fatal(1, "Video reset/frame-tick assertion failed");
            end
        end
    endtask

    task automatic cycle;
        begin @(posedge pck); #2; end
    endtask

    task automatic set_counter(input integer h, input integer v);
        begin
            @(negedge pck); hcount = h; vcount = v;
            cycle();
        end
    endtask

    always @(posedge pck) begin
        #3;
        if (!test_done) begin
            if (game_reset) begin
                check(!tick, "reset suppresses tick");
                previous_tick = 0;
            end else begin
                check(!(tick && previous_tick), "tick is only one PCK wide");
                if (tick) pulses = pulses + 1;
                previous_tick = tick;
            end
        end
    end

    initial begin : watchdog
        #20000;
        $fatal(1, "Video unit watchdog expired");
    end

    initial begin
        repeat (3) cycle();
        check(game_reset && !tick, "startup is reset while PLL is unlocked");
        @(negedge pck); system_reset = 0; clock_locked = 1;
        repeat (6) cycle();
        check(game_reset, "VGA/default mode keeps gameplay reset");
        @(negedge pck); requested_720p = 1;
        repeat (8) cycle();
        check(request_sync && game_reset, "request alone cannot release an inactive timing mode");
        @(negedge pck); active_720p = 1;
        cycle(); check(game_reset, "first safe release edge");
        cycle(); check(game_reset, "second safe release edge");
        cycle(); check(!game_reset, "third safe release edge enables gameplay");
        cycle();

        set_counter(0, 0);
        check(tick, "entry into frame origin emits a tick");
        repeat (5) begin cycle(); check(!tick, "held origin cannot retrigger"); end
        set_counter(1, 0); check(!tick, "ordinary pixel is not a frame tick");
        set_counter(0, 1); check(!tick, "line start outside first line is not a frame tick");
        set_counter(1, 0);
        set_counter(0, 0); check(tick, "next origin entry generates next tick");
        cycle();

        enable = 0;
        set_counter(1, 0);
        set_counter(0, 0); check(!tick, "disabled generator suppresses origin");
        enable = 1; cycle();
        check(!tick, "enabling while origin is held does not invent a frame");
        set_counter(1, 0);
        set_counter(0, 0); check(tick, "tick resumes on the next real origin entry");
        cycle();
        $display("CHECKPOINT: frame origin, one-cycle enable and stalled-counter handling PASS");

        @(negedge pck); active_720p = 0; #1;
        check(game_reset && !tick, "leaving active 720p resets gameplay and pending tick");
        repeat (3) cycle();
        @(negedge pck); active_720p = 1;
        cycle(); check(game_reset, "mode resume release edge one");
        cycle(); check(game_reset, "mode resume release edge two");
        cycle(); check(!game_reset, "mode resume release edge three");
        repeat (2) cycle();
        check(!tick, "reset release at held origin remains tick-free");

        @(negedge pck); requested_720p = 0;
        cycle(); check(request_sync && !game_reset, "request crossing first synchronizer edge");
        cycle(); check(!request_sync && game_reset, "request crossing second synchronizer edge");
        cycle();
        @(negedge pck); requested_720p = 1;
        for (i = 0; i < 4; i = i + 1) begin cycle(); check(game_reset, "request re-entry remains held safely"); end
        cycle(); check(!game_reset, "request re-entry releases after synchronizer and safe edges");
        $display("CHECKPOINT: active mode and requested-mode CDC gating PASS");

        @(negedge pck); clock_running = 0; clock_locked = 0; #1;
        check(game_reset && !tick, "lock loss asserts reset even when PCK stops");
        #30; clock_locked = 1; #30;
        check(game_reset && !tick, "lock restoration cannot release reset without PCK edges");
        clock_running = 1;
        for (i = 0; i < 4; i = i + 1) begin cycle(); check(game_reset, "clock restart remains reset through synchronization"); end
        cycle(); check(!game_reset, "clock restart releases on the fifth safe PCK edge");
        repeat (2) cycle();
        check(!tick, "clock restart at held origin has no false tick");

        @(negedge pck); system_reset = 1; #1;
        check(game_reset && !tick, "system reset asserts immediately");
        @(negedge pck); system_reset = 0;
        repeat (4) begin cycle(); check(game_reset, "system reset release remains synchronized"); end
        cycle(); check(!game_reset, "system reset releases after safe PCK edges");
        $display("CHECKPOINT: stopped clock, MMCM lock loss and reset recovery PASS");
        // XSim GUI can resume after $finish. Cancel background processes so a
        // second run cannot report a timeout or run forever after success.
        test_done = 1;
        disable watchdog;
        disable clock_driver;
        $display("PASS: tb_video_unit checks=%0d pulses=%0d", checks, pulses);
        $finish;
    end
endmodule
