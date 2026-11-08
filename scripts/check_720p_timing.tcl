# Read-only netlist analysis of runtime 720p. Does not change project constraints,
# MMCM INIT parameters, RTL, run settings, checkpoints or bitstreams.
set game_check_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} { error "Open Game_Datapath_V2.xpr first." }
if {[get_property NAME [current_project]] ne "Game_Datapath_V2" ||
    ![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $game_check_root]} {
    error "Wrong project or directory. Use Game_Datapath_V2, never Game_Test."
}
if {[get_property PART [current_project]] ne "xc7z010clg400-1" ||
    [get_property TOP [get_filesets sources_1]] ne "system_wrapper"} { error "Unexpected part or top." }
foreach game_check_run {synth_1 impl_1 system_pattern_hdmi_axi_0_2_synth_1} {
    if {[regexp -nocase {running|queued} [get_property STATUS [get_runs $game_check_run]]]} {
        error "Wait for the active run: $game_check_run"
    }
}
set game_check_synth [get_runs synth_1]
if {![string match -nocase "*synth_design Complete*" [get_property STATUS $game_check_synth]] ||
    [get_property NEEDS_REFRESH $game_check_synth]} { error "Fresh full-system synthesis is required." }
set game_check_status [file join $game_check_root verification system_synth status.txt]
if {![file exists $game_check_status]} { error "Missing verified system synthesis status." }
set game_check_ch [open $game_check_status r]
set game_check_text [read $game_check_ch]
close $game_check_ch
if {[string first "PASS: full-system synthesis with dynamic HDMI/game checkpoint." $game_check_text] != 0} {
    error "Full-system netlist verification has not passed."
}
set game_check_xdc [file join $game_check_root constraints game_720p_timing.xdc]
if {![file exists $game_check_xdc]} { error "Missing runtime clock analysis model." }
# This first check intentionally keeps the model out of the project constraint set.
if {[llength [get_files -quiet $game_check_xdc]]} {
    error "Runtime model is already a project constraint; inspect its run usage before this analysis-only check."
}
set game_check_out [file join $game_check_root verification timing_720p]
file mkdir $game_check_out
set game_check_ch [open [file join $game_check_out status.txt] w]
puts $game_check_ch "PENDING: runtime clock model check has not completed."
close $game_check_ch
if {[llength [get_designs -quiet]]} { close_design }
open_run synth_1
set game_check_mmcm system_i/pattern_hdmi_axi_0/inst/pattern_multi/syncgen_multi/pckgen_triple/MMCM_RECONFIG
set game_check_cell [get_cells -quiet $game_check_mmcm]
if {[llength $game_check_cell] != 1 || [get_property REF_NAME $game_check_cell] ne "MMCME2_ADV"} {
    error "Expected the original HDMI MMCM."
}
set game_check_init [list]
foreach {game_check_prop game_check_expected} {
    CLKFBOUT_MULT_F 17.625 DIVCLK_DIVIDE 2 CLKOUT0_DIVIDE_F 35 CLKOUT1_DIVIDE 7
} {
    set game_check_value [get_property $game_check_prop $game_check_cell]
    if {abs(double($game_check_value) - $game_check_expected) > 0.000001} {
        error "Unexpected MMCM power-up parameter: $game_check_prop=$game_check_value"
    }
    lappend game_check_init $game_check_prop $game_check_value
}

# Always discard the temporary clock definitions, even if an analysis check fails.
set game_check_rc [catch {
    if {[llength [get_cells -quiet -hierarchical -filter {IS_BLACKBOX == 1}]]} { error "Unresolved system black boxes." }
    foreach game_check_state {ship_x form_alive score} {
        if {![llength [get_cells -quiet -hierarchical -filter "NAME =~ *physics_inst*${game_check_state}_reg* && IS_SEQUENTIAL == 1"]]} {
            error "Missing dynamic Physics state: $game_check_state"
        }
    }
    report_clocks -file [file join $game_check_out clocks_powerup.rpt]
    # source executes only the clock commands. read_xdc in project mode would
    # register an extra constraint file and replay it when synth_1 is reopened.
    source $game_check_xdc
    foreach {game_check_pin game_check_name game_check_period game_check_powerup_name} {
        CLKOUT0 game_pck_720p 13.468013468 iPCK
        CLKOUT1 game_serial_720p 2.693602694 iSerialClk
    } {
        set game_check_clocks [get_clocks -quiet -of_objects [get_pins $game_check_mmcm/$game_check_pin]]
        if {[lsearch -exact $game_check_clocks $game_check_name] < 0} {
            error "Runtime clock $game_check_name is missing from $game_check_pin: $game_check_clocks"
        }
        if {[lsearch -exact $game_check_clocks $game_check_powerup_name] < 0} {
            error "Power-up clock $game_check_powerup_name was not retained on $game_check_pin: $game_check_clocks"
        }
        set game_check_runtime_clock [get_clocks -quiet $game_check_name]
        if {[llength $game_check_runtime_clock] != 1} {
            error "Expected one runtime clock named $game_check_name."
        }
        set game_check_actual [get_property PERIOD $game_check_runtime_clock]
        if {abs(double($game_check_actual) - $game_check_period) > 0.001} {
            error "Unexpected runtime clock period: $game_check_name=$game_check_actual"
        }
        puts "CLOCK_MODEL: $game_check_name period=$game_check_actual ns master=[get_property MASTER_CLOCK $game_check_runtime_clock]"
        if {[get_property MASTER_CLOCK $game_check_runtime_clock] ne "clk_fpga_0"} { error "Wrong runtime clock master." }
    }
    set game_check_serializers [get_cells -quiet -hierarchical -filter {REF_NAME == OSERDESE2}]
    if {[llength $game_check_serializers] != 8} { error "Expected eight original OSERDES cells." }
    foreach game_check_ser $game_check_serializers {
        foreach {game_check_pin game_check_name} {CLK game_serial_720p CLKDIV game_pck_720p} {
            set game_check_ser_clocks [get_clocks -quiet -of_objects [get_pins $game_check_ser/$game_check_pin]]
            if {[lsearch -exact $game_check_ser_clocks $game_check_name] < 0} {
                error "Wrong serializer clock: $game_check_ser/$game_check_pin"
            }
        }
    }
    report_clocks -file [file join $game_check_out clocks_runtime_720p.rpt]
    report_timing_summary -check_timing_verbose -report_unconstrained -max_paths 3 \
        -file [file join $game_check_out timing_preroute_720p.rpt]
    report_methodology -file [file join $game_check_out methodology_preroute_720p.rpt]
    set game_check_summary [list]
    foreach {game_check_type game_check_label} {max SETUP min HOLD} {
        set game_check_path [get_timing_paths -quiet -delay_type $game_check_type -max_paths 1]
        if {![llength $game_check_path]} { error "No constrained $game_check_label paths in linked system." }
        set game_check_line "PREROUTE_$game_check_label: worst_slack=[get_property SLACK $game_check_path] ns"
        lappend game_check_summary $game_check_line
        puts $game_check_line
    }
    foreach {game_check_prop game_check_value} $game_check_init {
        if {[get_property $game_check_prop $game_check_cell] ne $game_check_value} {
            error "MMCM INIT parameter changed unexpectedly: $game_check_prop"
        }
    }
} game_check_result game_check_options]
# Reopen the saved synthesis result; no temporary clock or netlist edit is saved.
if {[llength [get_designs -quiet]]} { close_design }
open_run synth_1
set_property NEEDS_REFRESH false [get_runs synth_1]
if {$game_check_rc} { return -options $game_check_options $game_check_result }
if {[llength [get_files -quiet $game_check_xdc]] ||
    [llength [get_clocks -quiet game_pck_720p]] || [llength [get_clocks -quiet game_serial_720p]]} {
    error "Temporary analysis model was not discarded; inspect before implementation."
}
set game_check_ch [open [file join $game_check_out status.txt] w]
puts $game_check_ch "MODEL_CHECKED: runtime PCK 74.25 MHz / SerialClk 371.25 MHz, same 100 MHz master, eight serializers connected."
puts $game_check_ch [join $game_check_summary \n]
puts $game_check_ch "CLOCK_PROFILES: power-up iPCK/iSerialClk and runtime 720p clocks are retained as physically exclusive profiles; PCK/SerialClk remain timed within each profile."
puts $game_check_ch "MODEL_NOTE: MMCM INIT remains the power-up profile; runtime clocks are an analysis model only."
puts $game_check_ch "TIMING_PENDING: pre-route hold, clock-model methodology, CDC and output timing require review; this is not timing sign-off."
puts $game_check_ch "Temporary clock definitions discarded. Project constraints and MMCM INIT remain unchanged."
close $game_check_ch
puts "MODEL_CHECKED: runtime PCK 74.25 MHz / SerialClk 371.25 MHz; original MMCM INIT unchanged."
puts "CLOCK_PROFILES: power-up and runtime 720p clocks retained as physically exclusive; PCK/SerialClk timing preserved."
puts "TIMING_PENDING: send this log before implementation; pre-route reports are not timing sign-off."
puts "CHECKPOINT: temporary clock definitions discarded; saved synthesis design reopened."
