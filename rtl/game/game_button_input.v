`timescale 1ns / 1ps

// Five asynchronous board buttons: two-flop synchronization, frame-rate
// debounce, held level outputs, and one PCK-wide pulse on each press.
module game_button_input #(
    parameter integer BUTTON_ACTIVE_LOW = 1,
    parameter integer DEBOUNCE_FRAMES = 1
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       frame_tick,
    input  wire [4:0] buttons_raw,
    output reg  [4:0] buttons_pressed,
    output reg  [4:0] buttons_press_pulse
);

localparam integer FILTER_FRAMES = (DEBOUNCE_FRAMES < 1) ? 1 : DEBOUNCE_FRAMES;
localparam integer COUNT_WIDTH = (FILTER_FRAMES < 2) ? 1 : $clog2(FILTER_FRAMES);
wire [4:0] normalized_raw = BUTTON_ACTIVE_LOW ? ~buttons_raw : buttons_raw;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [4:0] sync_meta;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [4:0] sync_buttons;
reg [COUNT_WIDTH-1:0] stable_count [0:4];
integer index;

always @(posedge clk) begin
    if (rst) begin
        sync_meta <= 5'b0;
        sync_buttons <= 5'b0;
        buttons_pressed <= 5'b0;
        buttons_press_pulse <= 5'b0;
        for (index = 0; index < 5; index = index + 1)
            stable_count[index] <= {COUNT_WIDTH{1'b0}};
    end else begin
        sync_meta <= normalized_raw;
        sync_buttons <= sync_meta;
        buttons_press_pulse <= 5'b0;

        if (frame_tick) begin
            for (index = 0; index < 5; index = index + 1) begin
                if (sync_buttons[index] == buttons_pressed[index]) begin
                    stable_count[index] <= {COUNT_WIDTH{1'b0}};
                end else if (stable_count[index] >= FILTER_FRAMES - 1) begin
                    buttons_pressed[index] <= sync_buttons[index];
                    buttons_press_pulse[index] <= sync_buttons[index];
                    stable_count[index] <= {COUNT_WIDTH{1'b0}};
                end else begin
                    stable_count[index] <= stable_count[index] + 1'b1;
                end
            end
        end
    end
end
endmodule
