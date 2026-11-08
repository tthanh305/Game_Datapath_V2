# Verify and finalize an already completed system_wrapper synthesis checkpoint.
# This does not launch synthesis, implementation, or bitstream generation.
set v_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0 || [get_property NAME [current_project]] ne "Game_Datapath_V2" ||
    ![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $v_root]} {
    error "Open Game_Datapath_V2.xpr from its project directory."
}
if {[get_property PART [current_project]] ne "xc7z010clg400-1" ||
    [get_property TOP [get_filesets sources_1]] ne "system_wrapper"} { error "Unexpected project part or top." }
source [file join $v_root scripts verify_game_v2_sources.tcl]
set v_run [get_runs synth_1]
if {![string match -nocase "*synth_design Complete*" [get_property STATUS $v_run]] ||
    [get_property NEEDS_REFRESH $v_run]} { error "Full-system synthesis is incomplete or stale." }
set v_status_dir [file join $v_root verification system_synth]
set v_ooc_status [file join $v_root verification hdmi_ooc status.txt]
if {![file exists $v_ooc_status]} { error "Missing verified HDMI OOC status." }
set v_ch [open $v_ooc_status r]; set v_ooc_text [read $v_ch]; close $v_ch
if {[string first "PASS: HDMI OOC synthesis;" $v_ooc_text] != 0} { error "HDMI OOC checkpoint is not verified." }
set v_ooc_dcp [file join $v_root Game_Datapath_V2.runs system_pattern_hdmi_axi_0_2_synth_1 system_pattern_hdmi_axi_0_2.dcp]
set v_ip_dcp [file join $v_root Game_Datapath_V2.gen sources_1 bd system ip system_pattern_hdmi_axi_0_2 system_pattern_hdmi_axi_0_2.dcp]
foreach v_file [list $v_ooc_dcp $v_ip_dcp] { if {![file exists $v_file]} { error "Missing HDMI checkpoint: $v_file" } }
set v_ch [open $v_ooc_dcp rb]; set v_a [read $v_ch]; close $v_ch
set v_ch [open $v_ip_dcp rb]; set v_b [read $v_ch]; close $v_ch
if {$v_a ne $v_b} { error "Generated HDMI IP checkpoint differs from the verified OOC checkpoint." }
set v_checkpoint [file join [get_property DIRECTORY $v_run] system_wrapper.dcp]
if {![file exists $v_checkpoint]} { error "Missing full-system synthesis checkpoint." }
if {[llength [get_designs -quiet]]} { close_design }
open_run synth_1
set v_summary [list]
foreach v_kind {ship_x alive_flags score} {
    set v_cells [get_cells -quiet -hierarchical -filter "NAME =~ *physics_inst*${v_kind}_reg* && IS_SEQUENTIAL == 1"]
    if {![llength $v_cells]} { error "Dynamic Physics state missing: $v_kind" }
    lappend v_summary "$v_kind registers: [llength $v_cells]"
}
set v_control [get_cells -quiet -hierarchical -filter {NAME =~ *control_path_inst* && IS_SEQUENTIAL == 1}]
if {![llength $v_control]} { error "Game Control Path state missing from full-system netlist." }
lappend v_summary "game Control Path state registers: [llength $v_control]"
foreach v_primitive {PS7 MMCME2_ADV OSERDESE2} {
    set v_cells [get_cells -quiet -hierarchical -filter "REF_NAME == $v_primitive"]
    if {![llength $v_cells]} { error "System primitive missing: $v_primitive" }
    lappend v_summary "$v_primitive cells: [llength $v_cells]"
}
set v_blackboxes [get_cells -quiet -hierarchical -filter {IS_BLACKBOX == 1}]
if {[llength $v_blackboxes]} { error "Unresolved black boxes: $v_blackboxes" }
report_utilization -file [file join $v_status_dir utilization_synth.rpt]
report_clocks -file [file join $v_status_dir clocks_synth.rpt]
set v_ch [open [file join $v_status_dir status.txt] w]
puts $v_ch "PASS: full-system synthesis with dynamic HDMI/game checkpoint."
puts $v_ch [join $v_summary \n]
puts $v_ch "TIMING_PENDING: runtime 720p timing is not signed off; do not implement yet."
puts $v_ch "No implementation, bitstream, XSA, Vitis or hardware test was performed."
close $v_ch
foreach v_line $v_summary { puts "SYSTEM_NETLIST: $v_line" }
puts "PASS: full-system synthesis checkpoint verified; no synthesis rerun was launched."
puts "TIMING_PENDING: runtime 720p clock/timing checks are still required before implementation."