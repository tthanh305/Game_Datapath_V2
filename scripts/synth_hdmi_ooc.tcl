# Rebuild only the HDMI module-reference checkpoint using V2 RTL.
# Existing PS/SmartConnect/reset IP and the BD/XDC/RTL files are preserved.
set game_ooc_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} { error "Open Game_Datapath_V2.xpr first." }
if {[get_property NAME [current_project]] ne "Game_Datapath_V2" ||
    ![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $game_ooc_root]} {
    error "Wrong project or directory. Use Game_Datapath_V2, never Game_Test."
}
if {[get_property PART [current_project]] ne "xc7z010clg400-1" ||
    [get_property TOP [get_filesets sources_1]] ne "system_wrapper"} { error "Unexpected part or project top." }
# One compile-order verification before run preparation, while Sources is idle.
source [file join $game_ooc_root scripts verify_game_v2_sources.tcl]
set game_ooc_name system_pattern_hdmi_axi_0_2_synth_1
set game_ooc_run [get_runs -quiet $game_ooc_name]
if {[llength $game_ooc_run] != 1} { error "Missing HDMI OOC run: $game_ooc_name" }
set game_ooc_dir [file normalize [get_property DIRECTORY $game_ooc_run]]
set game_ooc_expected_dir [file join $game_ooc_root Game_Datapath_V2.runs $game_ooc_name]
if {![string equal -nocase $game_ooc_dir $game_ooc_expected_dir]} {
    error "Refusing to reset a run outside this project's expected HDMI run directory: $game_ooc_dir"
}
if {[regexp -nocase {running|queued} [get_property STATUS $game_ooc_run]]} { error "HDMI OOC run is already active." }
set game_ooc_set [get_filesets -quiet [get_property SRCSET $game_ooc_run]]
if {[llength $game_ooc_set] != 1 || [get_property NAME $game_ooc_set] ne "system_pattern_hdmi_axi_0_2"} {
    error "Unexpected HDMI OOC source fileset."
}
set game_ooc_includes [get_property INCLUDE_DIRS $game_ooc_set]
set game_ooc_includes_before $game_ooc_includes
foreach game_ooc_inc [list [file join $game_ooc_root rtl game] \
        [file join $game_ooc_root Game_Datapath_V2.srcs sources_1 imports mmcm_drp]] {
    if {[lsearch -nocase -exact $game_ooc_includes $game_ooc_inc] < 0} { lappend game_ooc_includes $game_ooc_inc }
}
if {$game_ooc_includes ne $game_ooc_includes_before} { set_property INCLUDE_DIRS $game_ooc_includes $game_ooc_set }
set game_ooc_reportdir [file join $game_ooc_root verification hdmi_ooc]
file mkdir $game_ooc_reportdir
set game_ooc_checkpoint [file join $game_ooc_dir system_pattern_hdmi_axi_0_2.dcp]
set game_ooc_backup [file join $game_ooc_reportdir checkpoint_before_rebuild.dcp]
if {[file exists $game_ooc_checkpoint] && ![file exists $game_ooc_backup]} { file copy $game_ooc_checkpoint $game_ooc_backup }
set game_ooc_bd [file join $game_ooc_root Game_Datapath_V2.srcs sources_1 bd system system.bd]
set game_ooc_channel [open $game_ooc_bd rb]
set game_ooc_bd_before [read $game_ooc_channel]
close $game_ooc_channel
set game_ooc_started [clock seconds]
set game_ooc_channel [open [file join $game_ooc_reportdir status.txt] w]
puts $game_ooc_channel "PENDING: HDMI OOC synthesis has not completed."
close $game_ooc_channel

# Reset only this V2 child run. Generate and inspect the fresh script before
# launching it: copied baseline run scripts can contain golden-project paths.
reset_run $game_ooc_name
launch_runs $game_ooc_name -scripts_only -jobs 1
set game_ooc_script [file join $game_ooc_dir system_pattern_hdmi_axi_0_2.tcl]
if {![file exists $game_ooc_script]} { error "Fresh HDMI synthesis script was not generated." }
set game_ooc_channel [open $game_ooc_script r]
set game_ooc_script_text [string tolower [read $game_ooc_channel]]
close $game_ooc_channel
foreach game_ooc_file {game_params.vh physics_engine.v game_hud.v color_mapper.v datapath.v auto_game_controller.v game_core.v game_buzzer.v sprite_rom_32x32.v space_bg_stereden.v} {
    if {[string first [string tolower [file join $game_ooc_root rtl game $game_ooc_file]] $game_ooc_script_text] < 0} {
        error "Generated OOC script omits V2 source: $game_ooc_file"
    }
}
foreach game_ooc_file {game_clock_reset.v frame_tick.v game_video.v pattern_multi.v} {
    if {[string first [string tolower [file join $game_ooc_root rtl video $game_ooc_file]] $game_ooc_script_text] < 0} {
        error "Generated OOC script omits V2 video source: $game_ooc_file"
    }
}
foreach game_ooc_bad {D:/FPGA_Projects/Game_test/ D:/FPGA_Projects/FPGA_Game_Datapath/ pckgen_triple_model.v} {
    if {[string first [string tolower $game_ooc_bad] $game_ooc_script_text] >= 0} { error "Unsafe or stale path in generated OOC script: $game_ooc_bad" }
}
puts "CHECKPOINT: fresh OOC script uses all 11 V2 files and local project paths."
puts "RUNNING: HDMI OOC synthesis only, jobs=1; wait for completion."
# A scripts-only run has status Scripts Generated and cannot be launched again
# directly in this Vivado version. Reset that same isolated run before launch;
# its input properties/source membership remain exactly those just inspected.
reset_run $game_ooc_name
launch_runs $game_ooc_name -jobs 4
wait_on_run $game_ooc_name
set game_ooc_status [get_property STATUS $game_ooc_run]
if {![string match -nocase "*synth_design Complete*" $game_ooc_status] ||
    ![file exists $game_ooc_checkpoint] || [file mtime $game_ooc_checkpoint] < $game_ooc_started} {
    error "HDMI OOC synthesis did not create a fresh checkpoint: status=$game_ooc_status. Inspect $game_ooc_dir/runme.log"
}
set game_ooc_gen_dcp [file join $game_ooc_root Game_Datapath_V2.gen sources_1 bd system ip system_pattern_hdmi_axi_0_2 system_pattern_hdmi_axi_0_2.dcp]
file copy -force $game_ooc_checkpoint $game_ooc_gen_dcp
open_run $game_ooc_name
set game_ooc_summary [list]
foreach game_ooc_kind {ship_x form_alive score} {
    set game_ooc_cells [get_cells -quiet -hierarchical -filter "NAME =~ *physics_inst*${game_ooc_kind}_reg* && IS_SEQUENTIAL == 1"]
    if {![llength $game_ooc_cells]} { error "Fresh netlist lacks dynamic Physics registers: $game_ooc_kind" }
    lappend game_ooc_summary "$game_ooc_kind registers: [llength $game_ooc_cells]"
}
set game_ooc_control [get_cells -quiet -hierarchical -filter {NAME =~ *control_path_inst* && IS_SEQUENTIAL == 1}]
if {![llength $game_ooc_control]} { error "Fresh netlist lacks game Control Path state registers." }
lappend game_ooc_summary "game Control Path state registers: [llength $game_ooc_control]"
foreach game_ooc_primitive {MMCME2_ADV OSERDESE2} {
    set game_ooc_cells [get_cells -quiet -hierarchical -filter "REF_NAME == $game_ooc_primitive"]
    if {![llength $game_ooc_cells]} { error "Original HDMI hardware primitive missing: $game_ooc_primitive" }
    lappend game_ooc_summary "$game_ooc_primitive cells: [llength $game_ooc_cells]"
}
report_utilization -file [file join $game_ooc_reportdir utilization_synth.rpt]
set game_ooc_channel [open $game_ooc_bd rb]
set game_ooc_bd_after [read $game_ooc_channel]
close $game_ooc_channel
if {$game_ooc_bd_after ne $game_ooc_bd_before} { error "Block Design file changed unexpectedly during OOC synthesis." }
set game_ooc_channel [open [file join $game_ooc_reportdir status.txt] w]
puts $game_ooc_channel "PASS: HDMI OOC synthesis; dynamic game registers and original HDMI hardware present."
puts $game_ooc_channel [join $game_ooc_summary \n]
puts $game_ooc_channel "This is not full-system synthesis, 720p timing closure, implementation, bitstream or hardware PASS."
close $game_ooc_channel
foreach game_ooc_line $game_ooc_summary { puts "NETLIST: $game_ooc_line" }
puts "PASS: HDMI OOC synthesis; dynamic game registers and original HDMI hardware present."
puts "NEXT: full-system build and timing checks for the runtime 720p clocks."
