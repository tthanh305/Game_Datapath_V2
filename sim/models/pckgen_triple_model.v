`timescale 1ns / 1ps

// SIMULATION ONLY. The testbench supplies nominal 74.25-MHz PCK on SYSCLK.
// Keeps syncgen_multi/counters unchanged while avoiding MMCM/DRP/SERDES models.
// SerialClk is intentionally not a 5x model and is not tested/used for TMDS.
// Never add this file to hardware Design Sources.
module pckgen_triple (
    input wire SYSCLK,
    input wire [1:0] timing_sel,
    input wire reconfig_req,
    output wire PCK,
    output wire SerialClk,
    output wire locked,
    output wire reconfig_done
);
assign PCK = SYSCLK;
assign SerialClk = SYSCLK;
assign locked = 1'b1;
assign reconfig_done = 1'b0;
endmodule
