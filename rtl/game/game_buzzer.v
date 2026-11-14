`timescale 1ns / 1ps

// Galaxian Steredenn 3-Channel Chiptune PSG (Programmable Sound Generator)
// Features:
//   - Channel A: Melody, Swooping Dive Siren, Power-Up Arpeggio, Overdrive Laser FM Hum, Victory Fanfare, Game Over
//   - Channel B: Dedicated Rapid-fire Laser Cannon Synthesizer
//   - Channel C: 16-bit LFSR White Noise Explosion & Impact Crunch Synthesizer
module game_buzzer #(
    parameter integer CLK_FREQ_HZ = 74250000
)(
    input  wire clk,
    input  wire rst,
    input  wire frame_tick,

    // SFX trigger pulses
    input  wire sound_fire,       // Player fires laser
    input  wire sound_hit,        // Alien / Asteroid hit or destroyed
    input  wire sound_dive,       // Alien swooping attack
    input  wire sound_player_die, // Player ship exploded
    input  wire sound_win,        // Wave cleared
    input  wire sound_game_over,  // Game Over sorrowful tone
    input  wire sound_powerup,    // 3-note rising arpeggio on picking up Item P/S/R
    input  wire sound_laser,      // Active while Overdrive Laser beam is firing

    output reg  buzzer_out
);

// =========================================================================
// Channel A: Melody / Dive Siren / Power-Up Arpeggio / Laser Beam / Fanfare / Game Over
// =========================================================================
localparam [2:0] CH_A_IDLE      = 3'd0;
localparam [2:0] CH_A_DIVE      = 3'd1;
localparam [2:0] CH_A_WIN       = 3'd2;
localparam [2:0] CH_A_GAME_OVER = 3'd3;
localparam [2:0] CH_A_POWERUP   = 3'd4;
localparam [2:0] CH_A_LASER     = 3'd5;

reg [2:0]  ch_a_state;
reg [6:0]  ch_a_timer;
reg [18:0] ch_a_half_period;
reg [18:0] ch_a_counter;
reg        ch_a_wave;

always @(posedge clk) begin
    if (rst) begin
        ch_a_state <= CH_A_IDLE;
        ch_a_timer <= 7'd0;
    end else begin
        if (sound_game_over) begin
            ch_a_state <= CH_A_GAME_OVER;
            ch_a_timer <= 7'd60; // 1.0s
        end else if (sound_win && (ch_a_state != CH_A_GAME_OVER)) begin
            ch_a_state <= CH_A_WIN;
            ch_a_timer <= 7'd48; // 0.8s
        end else if (sound_powerup && (ch_a_state != CH_A_GAME_OVER && ch_a_state != CH_A_WIN)) begin
            ch_a_state <= CH_A_POWERUP;
            ch_a_timer <= 7'd18; // 0.3s 3-note arpeggio
        end else if (sound_laser && (ch_a_state == CH_A_IDLE || ch_a_state == CH_A_DIVE || ch_a_state == CH_A_LASER)) begin
            ch_a_state <= CH_A_LASER;
            if (ch_a_timer == 7'd0)
                ch_a_timer <= 7'd8;
        end else if (sound_dive && (ch_a_state == CH_A_IDLE)) begin
            ch_a_state <= CH_A_DIVE;
            ch_a_timer <= 7'd24; // 0.4s
        end else if (frame_tick) begin
            if (!sound_laser && ch_a_state == CH_A_LASER) begin
                ch_a_state <= CH_A_IDLE;
                ch_a_timer <= 7'd0;
            end else if (ch_a_timer > 7'd0) begin
                ch_a_timer <= ch_a_timer - 7'd1;
                if (ch_a_timer == 7'd1 && ch_a_state != CH_A_LASER)
                    ch_a_state <= CH_A_IDLE;
            end
        end
    end
end

// Channel A Tone frequency and volume synthesis
always @(posedge clk) begin
    case (ch_a_state)
        CH_A_DIVE: begin
            if (ch_a_timer[2])
                ch_a_half_period <= 19'd24750 + (ch_a_timer[1:0] * 19'd800);
            else
                ch_a_half_period <= 19'd35357 - (ch_a_timer[1:0] * 19'd800);
        end

        CH_A_POWERUP: begin
            // 3-note rising power-up arpeggio: E5 (659Hz) -> G#5 (830Hz) -> B5 (987Hz)
            if (ch_a_timer > 7'd12) begin
                ch_a_half_period <= 19'd56335; // E5
            end else if (ch_a_timer > 7'd6) begin
                ch_a_half_period <= 19'd44696; // G#5
            end else begin
                ch_a_half_period <= 19'd37614; // B5
            end
        end

        CH_A_LASER: begin
            // Vibrating Overdrive Laser FM beam hum (alternating 440Hz / 660Hz / 880Hz)
            case (ch_a_timer[1:0])
                2'd0: ch_a_half_period <= 19'd84375;
                2'd1: ch_a_half_period <= 19'd56250;
                2'd2: ch_a_half_period <= 19'd42187;
                2'd3: ch_a_half_period <= 19'd63281;
            endcase
        end

        CH_A_WIN: begin
            if (ch_a_timer > 7'd36) begin
                ch_a_half_period <= 19'd70984; // C5
            end else if (ch_a_timer > 7'd24) begin
                ch_a_half_period <= 19'd56335; // E5
            end else if (ch_a_timer > 7'd12) begin
                ch_a_half_period <= 19'd47353; // G5
            end else begin
                ch_a_half_period <= 19'd35492; // C6
            end
        end

        CH_A_GAME_OVER: begin
            if (ch_a_timer > 7'd45) begin
                ch_a_half_period <= 19'd142241; // C4
            end else if (ch_a_timer > 7'd30) begin
                ch_a_half_period <= 19'd150914; // B3
            end else if (ch_a_timer > 7'd15) begin
                ch_a_half_period <= 19'd159334; // Bb3
            end else begin
                ch_a_half_period <= 19'd168750; // A3
            end
        end

        default: begin
            ch_a_half_period <= 19'd0;
        end
    endcase
end

// Channel A Tone oscillator
always @(posedge clk) begin
    if (rst || ch_a_state == CH_A_IDLE || ch_a_half_period == 19'd0) begin
        ch_a_counter <= 19'd0;
        ch_a_wave    <= 1'b0;
    end else begin
        if (ch_a_counter >= ch_a_half_period) begin
            ch_a_counter <= 19'd0;
            ch_a_wave    <= ~ch_a_wave;
        end else begin
            ch_a_counter <= ch_a_counter + 19'd1;
        end
    end
end

// =========================================================================
// Channel B: Dedicated Rapid-fire Laser Cannon Synthesizer
// =========================================================================
reg [4:0]  ch_b_timer;
reg [18:0] ch_b_half_period;
reg [18:0] ch_b_counter;
reg        ch_b_wave;

always @(posedge clk) begin
    if (rst) begin
        ch_b_timer <= 5'd0;
    end else begin
        if (sound_fire) begin
            ch_b_timer <= 5'd11;
        end else if (frame_tick && (ch_b_timer > 5'd0)) begin
            ch_b_timer <= ch_b_timer - 5'd1;
        end
    end
end

always @(posedge clk) begin
    if (ch_b_timer > 5'd0) begin
        ch_b_half_period <= 19'd15468 + ((5'd11 - ch_b_timer) * 19'd4200);
    end else begin
        ch_b_half_period <= 19'd0;
    end
end

always @(posedge clk) begin
    if (rst || ch_b_half_period == 19'd0) begin
        ch_b_counter <= 19'd0;
        ch_b_wave    <= 1'b0;
    end else begin
        if (ch_b_counter >= ch_b_half_period) begin
            ch_b_counter <= 19'd0;
            ch_b_wave    <= ~ch_b_wave;
        end else begin
            ch_b_counter <= ch_b_counter + 19'd1;
        end
    end
end

// =========================================================================
// Channel C: 16-bit LFSR White Noise Explosion & Impact Generator
// =========================================================================
reg [5:0]  ch_c_timer;
reg [15:0] noise_lfsr;
reg [16:0] noise_clk_div;
reg [16:0] noise_period;
reg        noise_out;

always @(posedge clk) begin
    if (rst) begin
        ch_c_timer <= 6'd0;
    end else begin
        if (sound_player_die) begin
            ch_c_timer <= 6'd36;
        end else if (sound_hit) begin
            ch_c_timer <= 6'd10;
        end else if (frame_tick && (ch_c_timer > 6'd0)) begin
            ch_c_timer <= ch_c_timer - 6'd1;
        end
    end
end

always @(posedge clk) begin
    if (ch_c_timer > 6'd0) begin
        noise_period <= 17'd12000 + ((6'd36 - ch_c_timer) * 17'd1100);
    end else begin
        noise_period <= 17'd0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        noise_lfsr    <= 16'hACE1;
        noise_clk_div <= 17'd0;
        noise_out     <= 1'b0;
    end else if (ch_c_timer > 6'd0 && noise_period > 17'd0) begin
        if (noise_clk_div >= noise_period) begin
            noise_clk_div <= 17'd0;
            noise_lfsr    <= {noise_lfsr[14:0], noise_lfsr[15] ^ noise_lfsr[13] ^ noise_lfsr[12] ^ noise_lfsr[10]};
            noise_out     <= noise_lfsr[0];
        end else begin
            noise_clk_div <= noise_clk_div + 17'd1;
        end
    end else begin
        noise_clk_div <= 17'd0;
        noise_out     <= 1'b0;
    end
end

wire ch_a_active = (ch_a_state != CH_A_IDLE);
wire ch_b_active = (ch_b_timer > 5'd0);
wire ch_c_active = (ch_c_timer > 6'd0);

always @(posedge clk) begin
    if (rst) begin
        buzzer_out <= 1'b0;
    end else begin
        if (ch_a_state == CH_A_POWERUP)
            buzzer_out <= ch_a_wave;
        else if (ch_b_active && ch_c_active)
            buzzer_out <= ch_b_wave ^ noise_out;
        else if (ch_c_active)
            buzzer_out <= noise_out;
        else if (ch_a_active)
            buzzer_out <= ch_a_wave;
        else if (ch_b_active)
            buzzer_out <= ch_b_wave;
        else
            buzzer_out <= 1'b0;
    end
end

endmodule
