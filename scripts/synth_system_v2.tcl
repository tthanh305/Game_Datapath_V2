# Fresh synthesis of system_wrapper using the newly rebuilt HDMI checkpoint.
# Reuses PS/SmartConnect/reset checkpoints. Does not implement or write a bitstream.
set game_system_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} { error "Open Game_Datapath_V2.xpr first." }
if {[get_property NAME [current_project]] ne "Game_Datapath_V2" ||
    ![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $game_system_root]} {
    error "Wrong project or directory. Use Game_Datapath_V2, never Game_Test."
}
if {[get_property PART [current_project]] ne "xc7z010clg400-1" ||
    [get_property TOP [get_filesets sources_1]] ne "system_wrapper"} { error "Unexpected part or project top." }
foreach game_system_runname {synth_1 impl_1 system_pattern_hdmi_axi_0_2_synth_1} {
    if {[regexp -nocase {running|queued} [get_property STATUS [get_runs $game_system_runname]]]} {
        error "Wait for the active run to finish: $game_system_runname"
    }
}
if {[llength [get_designs -quiet]]} { close_design }
source [file join $game_system_root scripts verify_game_v2_sources.tcl]
set game_system_hdmi_run [get_runs system_pattern_hdmi_axi_0_2_synth_1]
if {![string match -nocase "*synth_design Complete*" [get_property STATUS $game_system_hdmi_run]] ||
    [get_property NEEDS_REFRESH $game_system_hdmi_run]} { error "Rebuild HDMI OOC before system synthesis." }
set game_system_ooc_status [file join $game_system_root verification hdmi_ooc status.txt]
if {![file exists $game_system_ooc_status]} { error "Missing HDMI OOC netlist verification status." }
set game_system_channel [open $game_system_ooc_status r]
set game_system_text [read $game_system_channel]
close $game_system_channel
if {[string first "PASS: HDMI OOC synthesis;" $game_system_text] != 0} { error "HDMI OOC netlist verification has not passed." }
set game_system_run [get_runs synth_1]
set game_system_dir [file normalize [get_property DIRECTORY $game_system_run]]
if {![string equal -nocase $game_system_dir [file join $game_system_root Game_Datapath_V2.runs synth_1]]} {
    error "Refusing to reset a run outside the expected V2 synthesis directory: $game_system_dir"
}
set game_system_hdmi_dcp [file join $game_system_root Game_Datapath_V2.runs system_pattern_hdmi_axi_0_2_synth_1 system_pattern_hdmi_axi_0_2.dcp]
set game_system_gen_dcp [file join $game_system_root Game_Datapath_V2.gen sources_1 bd system ip system_pattern_hdmi_axi_0_2 system_pattern_hdmi_axi_0_2.dcp]
foreach game_system_file [list $game_system_hdmi_dcp $game_system_gen_dcp] {
    if {![file exists $game_system_file]} { error "Missing fresh HDMI checkpoint: $game_system_file" }
}
set game_system_channel [open $game_system_hdmi_dcp rb]
set game_system_dcp_run [read $game_system_channel]
close $game_system_channel
set game_system_channel [open $game_system_gen_dcp rb]
set game_system_dcp_gen [read $game_system_channel]
close $game_system_channel
if {$game_system_dcp_run ne $game_system_dcp_gen} { error "HDMI checkpoint in generated IP does not match the verified OOC run." }
unset game_system_dcp_run game_system_dcp_gen
set game_system_reportdir [file join $game_system_root verification system_synth]
file mkdir $game_system_reportdir
set game_system_checkpoint [file join $game_system_dir system_wrapper.dcp]
set game_system_backup [file join $game_system_reportdir checkpoint_before_rebuild.dcp]
if {[file exists $game_system_checkpoint] && ![file exists $game_system_backup]} { file copy $game_system_checkpoint $game_system_backup }
set game_system_bd [file join $game_system_root Game_Datapath_V2.srcs sources_1 bd system system.bd]
set game_system_channel [open $game_system_bd rb]
set game_system_bd_before [read $game_system_channel]
close $game_system_channel
set game_system_started [clock seconds]
set game_system_channel [open [file join $game_system_reportdir status.txt] w]
puts $game_system_channel "PENDING: full-system synthesis has not completed."
close $game_system_channel

# The copied project retained an incremental reference to the static baseline.
# Disable it for this first full V2 build, without deleting the saved checkpoint.
set_property AUTO_INCREMENTAL_CHECKPOINT 0 $game_system_run
set_property INCREMENTAL_CHECKPOINT {} $game_system_run
reset_run synth_1
launch_runs synth_1 -scripts_only -jobs 1
set game_system_script [file join $game_system_dir system_wrapper.tcl]
if {![file exists $game_system_script]} { error "Fresh system synthesis Tcl was not generated." }
set game_system_channel [open $game_system_script r]
set game_system_script_text [string tolower [read $game_system_channel]]
close $game_system_channel
foreach game_system_bad {D:/FPGA_Projects/Game_test/ D:/FPGA_Projects/FPGA_Game_Datapath/ pckgen_triple_model.v} {
    if {[string first [string tolower $game_system_bad] $game_system_script_text] >= 0} { error "Unsafe or stale path in generated system script: $game_system_bad" }
}
if {[string first [string tolower $game_system_bd] $game_system_script_text] < 0} {
    error "System synthesis script does not use the local Block Design."
}
puts "CHECKPOINT: local BD with verified dynamic HDMI checkpoint; static incremental reference disabled."
# Scripts Generated must be reset before a managed launch in this Vivado.
reset_run synth_1
puts "RUNNING: full-system synthesis only, jobs=4."
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![string match -nocase "*synth_design Complete*" [get_property STATUS $game_system_run]] ||
    ![file exists $game_system_checkpoint] || [file mtime $game_system_checkpoint] < $game_system_started} {
    error "Full-system synthesis failed or checkpoint is stale. Inspect $game_system_dir/runme.log"
}
open_run synth_1
set game_system_summary [list]
foreach game_system_kind {ship_x form_alive score} {
    set game_system_cells [get_cells -quiet -hierarchical -filter "NAME =~ *physics_inst*${game_system_kind}_reg* && IS_SEQUENTIAL == 1"]
    if {![llength $game_system_cells]} { error "Dynamic Physics state missing from full-system netlist: $game_system_kind" }
    lappend game_system_summary "$game_system_kind registers: [llength $game_system_cells]"
}
set game_system_control [get_cells -quiet -hierarchical -filter {NAME =~ *control_path_inst* && IS_SEQUENTIAL == 1}]
if {![llength $game_system_control]} { error "Game Control Path state missing from full-system netlist." }
lappend game_system_summary "game Control Path state registers: [llength $game_system_control]"
foreach game_system_primitive {PS7 MMCME2_ADV OSERDESE2} {
    set game_system_cells [get_cells -quiet -hierarchical -filter "REF_NAME == $game_system_primitive"]
    if {![llength $game_system_cells]} { error "System primitive missing: $game_system_primitive" }
    lappend game_system_summary "$game_system_primitive cells: [llength $game_system_cells]"
}
set game_system_blackboxes [get_cells -quiet -hierarchical -filter {IS_BLACKBOX == 1}]
if {[llength $game_system_blackboxes]} { error "Unresolved black boxes in the linked system: $game_system_blackboxes" }
report_utilization -file [file join $game_system_reportdir utilization_synth.rpt]
report_clocks -file [file join $game_system_reportdir clocks_synth.rpt]
set game_system_channel [open $game_system_bd rb]
set game_system_bd_after [read $game_system_channel]
close $game_system_channel
if {$game_system_bd_after ne $game_system_bd_before} { error "Block Design file changed unexpectedly." }
if {[get_property TOP [get_filesets sources_1]] ne "system_wrapper"} { error "Project top changed unexpectedly." }
set game_system_channel [open [file join $game_system_reportdir status.txt] w]
puts $game_system_channel "PASS: full-system synthesis with dynamic HDMI/game checkpoint."
puts $game_system_channel [join $game_system_summary \n]
puts $game_system_channel "TIMING_PENDING: runtime 720p PCK/SerialClk timing is not signed off; do not implement yet."
puts $game_system_channel "No implementation, bitstream, XSA, Vitis or hardware test was performed."
close $game_system_channel
foreach game_system_line $game_system_summary { puts "SYSTEM_NETLIST: $game_system_line" }
puts "PASS: full-system synthesis with dynamic HDMI/game checkpoint."
puts "TIMING_PENDING: next check is the runtime 720p clock constraints and timing before implementation."
