# Place and route the current synthesized system with the checked 720p runtime
# clock profile. The temporary clock model is applied only to this in-memory
# run; project constraints and MMCM INIT values are not modified.
set game_route_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0 || [get_property NAME [current_project]] ne "Game_Datapath_V2" ||
    ![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $game_route_root]} {
    error "Open Game_Datapath_V2.xpr from its project directory."
}
if {[get_property PART [current_project]] ne "xc7z010clg400-1" ||
    [get_property TOP [get_filesets sources_1]] ne "system_wrapper"} {
    error "Unexpected project part or top."
}
foreach game_route_run {synth_1 impl_1 system_pattern_hdmi_axi_0_2_synth_1} {
    if {[regexp -nocase {running|queued} [get_property STATUS [get_runs $game_route_run]]]} {
        error "Wait for the active run to finish: $game_route_run"
    }
}
set game_route_synth [get_runs synth_1]
if {![string match -nocase "*synth_design Complete*" [get_property STATUS $game_route_synth]] ||
    [get_property NEEDS_REFRESH $game_route_synth]} {
    error "Fresh full-system synthesis is required."
}
set game_route_system_status [file join $game_route_root verification system_synth status.txt]
if {![file exists $game_route_system_status]} { error "Missing verified system synthesis status." }
set game_route_ch [open $game_route_system_status r]
set game_route_status_text [read $game_route_ch]
close $game_route_ch
if {[string first "PASS: full-system synthesis with dynamic HDMI/game checkpoint." $game_route_status_text] != 0} {
    error "Full-system synthesis checkpoint has not passed verification."
}
set game_route_xdc [file join $game_route_root constraints game_720p_timing.xdc]
if {![file exists $game_route_xdc] || [llength [get_files -quiet $game_route_xdc]]} {
    error "Expected the analysis-only 720p clock model to exist outside the project constraint set."
}
set game_route_out [file join $game_route_root verification timing_720p]
file mkdir $game_route_out
set game_route_status_file [file join $game_route_out routed_status.txt]
set game_route_ch [open $game_route_status_file w]
puts $game_route_ch "PENDING: routed 720p timing analysis has not completed."
close $game_route_ch

if {[llength [get_designs -quiet]]} { close_design }
open_run synth_1
set game_route_rc [catch {
    source $game_route_xdc
    set game_route_mmcm system_i/pattern_hdmi_axi_0/inst/pattern_multi/syncgen_multi/pckgen_triple/MMCM_RECONFIG
    foreach {game_route_pin game_route_clock game_route_period game_route_powerup} {
        CLKOUT0 game_pck_720p 13.468013468 iPCK
        CLKOUT1 game_serial_720p 2.693602694 iSerialClk
    } {
        set game_route_pin_clocks [get_clocks -quiet -of_objects [get_pins $game_route_mmcm/$game_route_pin]]
        if {[lsearch -exact $game_route_pin_clocks $game_route_clock] < 0 ||
            [lsearch -exact $game_route_pin_clocks $game_route_powerup] < 0} {
            error "Missing runtime or power-up clock on $game_route_pin: $game_route_pin_clocks"
        }
        set game_route_clock_obj [get_clocks -quiet $game_route_clock]
        if {[llength $game_route_clock_obj] != 1 ||
            abs(double([get_property PERIOD $game_route_clock_obj]) - $game_route_period) > 0.001} {
            error "Unexpected runtime clock period for $game_route_clock."
        }
    }
    set game_route_serializers [get_cells -quiet -hierarchical -filter {REF_NAME == OSERDESE2}]
    if {[llength $game_route_serializers] != 8} { error "Expected eight original OSERDES cells." }
    foreach game_route_ser $game_route_serializers {
        foreach {game_route_pin game_route_clock} {CLK game_serial_720p CLKDIV game_pck_720p} {
            set game_route_pin_clocks [get_clocks -quiet -of_objects [get_pins $game_route_ser/$game_route_pin]]
            if {[lsearch -exact $game_route_pin_clocks $game_route_clock] < 0} {
                error "Runtime clock $game_route_clock is missing from $game_route_ser/$game_route_pin"
            }
        }
    }

    opt_design
    place_design
    phys_opt_design
    route_design
    report_timing_summary -check_timing_verbose -report_unconstrained -max_paths 10 \
        -file [file join $game_route_out timing_routed_720p.rpt]
    report_methodology -file [file join $game_route_out methodology_routed_720p.rpt]
    report_drc -file [file join $game_route_out drc_routed_720p.rpt]
    report_route_status -file [file join $game_route_out route_status_720p.rpt]
    set game_route_setup [get_timing_paths -quiet -delay_type max -max_paths 1]
    set game_route_hold [get_timing_paths -quiet -delay_type min -max_paths 1]
    if {![llength $game_route_setup] || ![llength $game_route_hold]} {
        error "Could not obtain routed setup and hold paths."
    }
    set game_route_wns [get_property SLACK $game_route_setup]
    set game_route_whs [get_property SLACK $game_route_hold]
    write_checkpoint -force [file join $game_route_out system_wrapper_720p_routed.dcp]
} game_route_result game_route_options]

if {$game_route_rc} {
    set game_route_ch [open $game_route_status_file w]
    puts $game_route_ch "ROUTE_ERROR: $game_route_result"
    close $game_route_ch
    return -options $game_route_options $game_route_result
}

set game_route_status [expr {($game_route_wns >= 0.0 && $game_route_whs >= 0.0) ? "PASS" : "TIMING_FAIL"}]
set game_route_ch [open $game_route_status_file w]
puts $game_route_ch "$game_route_status: routed 720p profile, setup_slack=$game_route_wns ns, hold_slack=$game_route_whs ns."
puts $game_route_ch "Clock model: 74.25 MHz PCK and 371.25 MHz SerialClk; power-up profile retained as physically exclusive."
puts $game_route_ch "Reports: timing_routed_720p.rpt, methodology_routed_720p.rpt, drc_routed_720p.rpt, route_status_720p.rpt."
puts $game_route_ch "This routed checkpoint is an analysis result; it does not create or program a bitstream."
close $game_route_ch
puts "$game_route_status: routed 720p profile, setup_slack=$game_route_wns ns, hold_slack=$game_route_whs ns."
puts "CHECKPOINT: temporary runtime clocks were used for routed analysis; project constraints and MMCM INIT remain unchanged."
