`timescale 1ns / 1ps

// Assert reset on system reset/lock loss, release it only on PCK edges.
// requested_720p is a single decoded level from the AXI/SYSCLK domain.
// active_720p is already in PCK (the existing VSync-latched timing select).
module game_clock_reset #(
    // Production receives requested_720p from timing_sel_sync, which is
    // already synchronized and frame-latched in the PCK domain. Standalone
    // users may leave this at zero to synchronize an asynchronous request.
    parameter integer REQUESTED_720P_IS_SYNCED = 0
)(
    input wire pck,
    input wire system_reset,
    input wire clock_locked,
    input wire requested_720p,
    input wire active_720p,
    output wire video_reset,
    output wire game_reset,
    output wire requested_720p_sync
);

wire async_reset = system_reset || !clock_locked;
wire requested_720p_pck;
reg [2:0] mode_release_pipe = 3'b111;

// AMD's reset synchronizer asynchronously asserts on PS reset or MMCM lock
// loss and releases only on PCK edges. Keep this reset source independent of
// mode decode so no combinational mode logic drives asynchronous reset pins.
xpm_cdc_async_rst #(
    .DEST_SYNC_FF(3),
    .INIT_SYNC_FF(1),
    .RST_ACTIVE_HIGH(1)
) video_reset_sync_inst (
    .src_arst(async_reset),
    .dest_clk(pck),
    .dest_arst(video_reset)
);

generate
    if (REQUESTED_720P_IS_SYNCED) begin : g_request_already_synchronized
        assign requested_720p_pck = requested_720p;
        assign requested_720p_sync = requested_720p;
    end else begin : g_request_synchronizer
        (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
        reg [1:0] request_sync = 2'b00;

        always @(posedge pck or posedge async_reset) begin
            if (async_reset)
                request_sync <= 2'b00;
            else
                request_sync <= {request_sync[0], requested_720p};
        end

        assign requested_720p_pck = request_sync[1];
        assign requested_720p_sync = request_sync[1];
    end
endgenerate

always @(posedge pck) begin
    if (!requested_720p_pck || !active_720p)
        mode_release_pipe <= 3'b111;
    else
        mode_release_pipe <= {mode_release_pipe[1:0], 1'b0};
end

// The mode reset is synchronous to PCK. It waits three safe edges after the
// requested and active mode agree before allowing game state to advance.
assign game_reset = video_reset || mode_release_pipe[2] ||
                    !requested_720p_pck || !active_720p;

endmodule
