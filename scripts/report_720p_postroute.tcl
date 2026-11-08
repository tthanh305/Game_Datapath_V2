# Analyze a routed design at the real DRP mode, without saving altered MMCM INIT.
# Reopens the original routed result after analysis, on success or report failure.
set game_rt_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] != 1 || [get_property NAME [current_project]] ne "Game_Datapath_V2" ||
    ![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $game_rt_root]} {
    error "Open Game_Datapath_V2 in its own directory."
}
if {[get_property PART [current_project]] ne "xc7z010clg400-1" ||
    [get_property TOP [get_filesets sources_1]] ne "system_wrapper"} { error "Unexpected part or top." }
set game_rt_run [get_runs impl_1]
if {![string match -nocase "*route_design Complete*" [get_property STATUS $game_rt_run]] ||
    [get_property NEEDS_REFRESH $game_rt_run]} { error "Fresh routed impl_1 is required." }
set game_rt_out [file join $game_rt_root verification implementation]
file mkdir $game_rt_out
set game_rt_ch [open [file join $game_rt_out runtime_timing_status.txt] w]
puts $game_rt_ch "PENDING: runtime timing has not passed."
close $game_rt_ch
if {[llength [get_designs -quiet]]} { close_design }
open_run impl_1
set game_rt_cmb_name system_i/pattern_hdmi_axi_0/inst/pattern_multi/syncgen_multi/pckgen_triple/MMCM_RECONFIG
set game_rt_cmb [get_cells -quiet $game_rt_cmb_name]
if {[llength $game_rt_cmb] != 1 || [get_property REF_NAME $game_rt_cmb] ne "MMCME2_ADV"} { error "Missing original MMCM." }
set game_rt_init [list]
foreach {game_rt_prop game_rt_value} {CLKFBOUT_MULT_F 17.625 DIVCLK_DIVIDE 2 CLKOUT0_DIVIDE_F 35 CLKOUT1_DIVIDE 7} {
    if {abs(double([get_property $game_rt_prop $game_rt_cmb]) - $game_rt_value) > 0.000001} {
        error "Routed checkpoint has unexpected MMCM INIT: $game_rt_prop"
    }
    lappend game_rt_init $game_rt_prop [get_property $game_rt_prop $game_rt_cmb]
}
set game_rt_rc [catch {
    foreach {game_rt_pin game_rt_clock game_rt_period game_rt_powerup_clock} {
        CLKOUT0 game_pck_720p 13.468013468 iPCK
        CLKOUT1 game_serial_720p 2.693602694 iSerialClk
    } {
        set game_rt_clocks [get_clocks -quiet -of_objects [get_pins $game_rt_cmb_name/$game_rt_pin]]
        if {[lsearch -exact $game_rt_clocks $game_rt_clock] < 0 ||
            [lsearch -exact $game_rt_clocks $game_rt_powerup_clock] < 0} {
            error "Routed checkpoint was not implemented with the required 720p clocks."
        }
        set game_rt_runtime_obj [get_clocks -quiet $game_rt_clock]
        if {[llength $game_rt_runtime_obj] != 1 ||
            abs(double([get_property PERIOD $game_rt_runtime_obj]) - $game_rt_period) > 0.001} {
            error "Routed checkpoint has an invalid runtime clock: $game_rt_clock."
        }
    }
    report_route_status -file [file join $game_rt_out route_status.rpt]
    report_utilization -file [file join $game_rt_out utilization_routed.rpt]
    report_clocks -file [file join $game_rt_out clocks_routed_init.rpt]
    report_methodology -file [file join $game_rt_out methodology_routed_init.rpt]
    # Timing-only mirror of the mode-2 DRP settings in pckgen_triple.v.
    # No checkpoint, bitstream, XSA or write_verilog is permitted in this session.
    set_property -dict {CLKFBOUT_MULT_F 37.125 DIVCLK_DIVIDE 5 CLKOUT0_DIVIDE_F 10 CLKOUT1_DIVIDE 2} $game_rt_cmb
    report_clocks -file [file join $game_rt_out clocks_runtime_720p.rpt]
    report_methodology -file [file join $game_rt_out methodology_runtime_720p.rpt]
    report_cdc -details -file [file join $game_rt_out cdc_runtime_720p.rpt]
    report_drc -file [file join $game_rt_out drc_runtime_720p.rpt]
    set game_rt_timing [report_timing_summary -check_timing_verbose -report_unconstrained -max_paths 5 -return_string]
    set game_rt_ch [open [file join $game_rt_out timing_runtime_720p.rpt] w]
    puts $game_rt_ch $game_rt_timing
    close $game_rt_ch
    set game_rt_numbers [list]
    foreach game_rt_line [split $game_rt_timing \n] {
        set game_rt_fields [regexp -all -inline {\S+} $game_rt_line]
        if {[llength $game_rt_fields] != 12} { continue }
        set game_rt_numeric 1
        foreach game_rt_field $game_rt_fields {
            if {![string is double -strict $game_rt_field]} { set game_rt_numeric 0; break }
        }
        if {$game_rt_numeric} { set game_rt_numbers $game_rt_fields; break }
    }
    if {[llength $game_rt_numbers] != 12} { error "Cannot parse complete design timing summary; inspect report." }
    foreach game_rt_idx {0 4 8} {
        if {[lindex $game_rt_numbers $game_rt_idx] < 0} { error "Runtime setup/hold/pulse-width timing is not met: $game_rt_numbers" }
    }
    foreach game_rt_idx {2 6 10} {
        if {[lindex $game_rt_numbers $game_rt_idx] != 0} { error "Runtime timing has failing endpoints: $game_rt_numbers" }
    }
    foreach game_rt_check {no_clock unconstrained_internal_endpoints multiple_clock generated_clocks loops} {
        if {![regexp "checking $game_rt_check \\(0\\)" $game_rt_timing]} { error "Timing coverage check failed: $game_rt_check" }
    }
    set game_rt_ch [open [file join $game_rt_out methodology_runtime_720p.rpt] r]
    set game_rt_methodology [read $game_rt_ch]
    close $game_rt_ch
    if {[regexp {\|\s*TIMING-1\s*\|} $game_rt_methodology] || [string first "Critical Warning" $game_rt_methodology] >= 0} {
        error "Runtime methodology still has a critical warning; inspect report."
    }
    set game_rt_summary "RUNTIME_720P: WNS=[lindex $game_rt_numbers 0] ns WHS=[lindex $game_rt_numbers 4] ns WPWS=[lindex $game_rt_numbers 8] ns; failing endpoints=0/0/0."
    puts $game_rt_summary
} game_rt_error game_rt_options]
# Restore all INIT attributes, then discard this analysis session entirely.
set_property -dict $game_rt_init [get_cells $game_rt_cmb_name]
close_design
open_run impl_1
foreach {game_rt_prop game_rt_value} $game_rt_init {
    if {[get_property $game_rt_prop [get_cells $game_rt_cmb_name]] ne $game_rt_value} {
        error "Original routed MMCM INIT did not restore: $game_rt_prop"
    }
}
if {$game_rt_rc} { return -options $game_rt_options $game_rt_error }
set game_rt_ch [open [file join $game_rt_out runtime_timing_status.txt] w]
puts $game_rt_ch "PASS: routed internal timing at the runtime 720p CMB settings."
puts $game_rt_ch $game_rt_summary
puts $game_rt_ch "Original VGA MMCM INIT restored by reopening the saved routed design; no modified netlist was written."
puts $game_rt_ch "LIMIT: CDC/reset warnings include baseline and V2 reset paths and require protocol review; TMDS external output-delay model is absent. Not CDC-clean, external-interface or hardware sign-off."
close $game_rt_ch
puts "PASS: routed internal timing at the runtime 720p CMB settings."
puts "CHECKPOINT: original VGA MMCM INIT restored; no bitstream or XSA generated."
