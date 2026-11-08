# Analysis-only timing model for the fixed-720p runtime mode after Vitis MMCM DRP.
# check_720p_timing.tcl reads this into a temporary linked design and discards it.
# It is not yet added to constrs_1 or approved as the implementation model.
# Original HDL/MMCM INIT attributes, package pins and baseline XDC are unchanged.
# All video modes use PCK:SerialClk = 1:5 at phase 0; 720p is the fastest mode.
# From 100 MHz SYSCLK, mode 2 uses M=37.125, D=5, O0=10, O1=2:
# PCK = 100 * 297/400 = 74.25 MHz; SerialClk = 100 * 297/80 = 371.25 MHz.
# This models the steady-state runtime clocks, not the VGA power-up waveform.
# Power-up and runtime clock profiles share pins but never run simultaneously.
# Preserve both profiles and mark only cross-profile paths physically exclusive.
set game_timing_mmcm system_i/pattern_hdmi_axi_0/inst/pattern_multi/syncgen_multi/pckgen_triple/MMCM_RECONFIG
set game_timing_input [get_pins $game_timing_mmcm/CLKIN1]
set game_timing_pck_pin [get_pins $game_timing_mmcm/CLKOUT0]
set game_timing_serial_pin [get_pins $game_timing_mmcm/CLKOUT1]
set game_timing_master [get_clocks -quiet clk_fpga_0]
if {[llength $game_timing_master] != 1} {
    error "Expected clk_fpga_0 as the master of the runtime HDMI clocks."
}
create_generated_clock -name game_pck_720p -source $game_timing_input \
    -master_clock $game_timing_master -multiply_by 297 -divide_by 400 -add $game_timing_pck_pin
create_generated_clock -name game_serial_720p -source $game_timing_input \
    -master_clock $game_timing_master -multiply_by 297 -divide_by 80 -add $game_timing_serial_pin

set game_timing_powerup_pck [get_clocks -quiet -of_objects $game_timing_pck_pin]
set game_timing_powerup_serial [get_clocks -quiet -of_objects $game_timing_serial_pin]
if {[lsearch -exact $game_timing_powerup_pck iPCK] < 0 ||
    [lsearch -exact $game_timing_powerup_serial iSerialClk] < 0} {
    error "Expected the original iPCK/iSerialClk clocks to remain on the MMCM outputs."
}
set_clock_groups -physically_exclusive \
    -group [get_clocks -quiet {iPCK iSerialClk}] \
    -group [get_clocks -quiet {game_pck_720p game_serial_720p}]

# AXI, PCK and SerialClk are related clocks. Do not mask whole clock domains.
# Only asynchronous external button inputs are excepted to their first PCK
# synchronizer stage; PCK <-> SerialClk remains timed at the 1:5 ratio.
set game_timing_btn_sync_d [get_pins -hier -filter {NAME =~ *button_input_inst/sync_meta_reg*/D}]
if {[llength $game_timing_btn_sync_d] != 5} { error "Expected five button synchronizer first-stage D pins." }
set_false_path -from [get_ports {BTN[*]}] -to $game_timing_btn_sync_d
