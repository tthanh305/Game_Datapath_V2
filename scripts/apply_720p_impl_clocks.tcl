# Implementation OPT_DESIGN.TCL.PRE hook. Does not change any MMCM parameter.
set game_hook_root [file normalize [file join [file dirname [info script]] ..]]
set game_hook_run [file join $game_hook_root Game_Datapath_V2.runs impl_1]
if {![string equal -nocase [file normalize [pwd]] $game_hook_run]} {
    error "720p clock hook must run only inside this V2 impl_1 directory."
}
if {![llength [get_designs -quiet]]} { error "No linked implementation design." }
set game_hook_mmcm [get_cells -quiet system_i/pattern_hdmi_axi_0/inst/pattern_multi/syncgen_multi/pckgen_triple/MMCM_RECONFIG]
if {[llength $game_hook_mmcm] != 1 || [get_property REF_NAME $game_hook_mmcm] ne "MMCME2_ADV"} { error "Missing HDMI MMCM." }
foreach {game_hook_prop game_hook_value} {CLKFBOUT_MULT_F 17.625 DIVCLK_DIVIDE 2 CLKOUT0_DIVIDE_F 35 CLKOUT1_DIVIDE 7} {
    if {abs(double([get_property $game_hook_prop $game_hook_mmcm]) - $game_hook_value) > 0.000001} { error "Unexpected MMCM INIT." }
}
source [file join $game_hook_root constraints game_720p_impl.xdc]
set game_hook_timing_meta [get_cells -hier -filter {NAME =~ *axi_ctrl/timing_sel_meta_reg*}]
set game_hook_pattern_meta [get_cells -hier -filter {NAME =~ *axi_ctrl/pattern_sel_meta_reg*}]
set game_hook_lock_meta [get_cells -hier -filter {NAME =~ *axi_ctrl/locked_meta_reg*}]
if {[llength $game_hook_timing_meta] != 2 || [llength $game_hook_pattern_meta] != 4 ||
    [llength $game_hook_lock_meta] != 1} {
    error "Expected timing/pattern/LOCKED first-stage synchronizers: timing=[llength $game_hook_timing_meta], pattern=[llength $game_hook_pattern_meta], LOCKED=[llength $game_hook_lock_meta]."
}
foreach {game_hook_clock game_hook_period} {game_pck_720p 13.468013468 game_serial_720p 2.693602694} {
    set game_hook_clock_obj [get_clocks -quiet $game_hook_clock]
    if {[llength $game_hook_clock_obj] != 1} {
        error "Expected exactly one implementation clock named $game_hook_clock; found $game_hook_clock_obj"
    }
    set game_hook_actual_period [get_property PERIOD $game_hook_clock_obj]
    puts "IMPLEMENTATION_CLOCK_CHECK: $game_hook_clock period=$game_hook_actual_period ns master=[get_property MASTER_CLOCK $game_hook_clock_obj]"
    if {![string is double -strict $game_hook_actual_period] ||
        abs(double($game_hook_actual_period) - $game_hook_period) > 0.001} {
        error "Invalid implementation clock period for $game_hook_clock: $game_hook_actual_period ns; expected $game_hook_period ns."
    }
}
puts "IMPLEMENTATION_CLOCKS: PCK=74.25 MHz SerialClk=371.25 MHz; original MMCM INIT retained."
