`timescale 1ns / 1ps

// One registered PCK-wide enable when the existing counters enter (0,0).
// A held origin, including reset/startup, must not produce repeated ticks.
module frame_tick (
    input wire clk,
    input wire rst,
    input wire enable,
    input wire [10:0] hcount,
    input wire [10:0] vcount,
    output reg tick
);

wire at_origin = hcount == 0 && vcount == 0;
reg previous_origin = 1'b1;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        previous_origin <= 1'b1;
        tick <= 1'b0;
    end else begin
        previous_origin <= at_origin;
        tick <= enable && at_origin && !previous_origin;
    end
end

endmodule
