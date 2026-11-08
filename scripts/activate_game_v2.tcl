# Switch only the V2 project's Design Sources to the simulated dynamic game.
# No source file is deleted or overwritten. No synthesis/run reset is launched.
set game_v2_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} { error "Open Game_Datapath_V2.xpr first." }
if {[get_property NAME [current_project]] ne "Game_Datapath_V2" ||
    ![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $game_v2_root]} {
    error "Wrong project or directory. Use Game_Datapath_V2, never Game_Test."
}
if {[get_property PART [current_project]] ne "xc7z010clg400-1"} { error "Unexpected FPGA part." }
set game_v2_sources [get_filesets sources_1]
if {[get_property TOP $game_v2_sources] ne "system_wrapper"} { error "Expected system_wrapper as project top." }
set game_v2_hdmi_dir [file join $game_v2_root Game_Datapath_V2.srcs sources_1 imports hdmi_axi_src_720p rtl]
set game_v2_old_game [file join $game_v2_root Game_Datapath_V2.srcs sources_1 imports FPGA_Projects FPGA_Game_Datapath rtl]
set game_v2_bd_path [file join $game_v2_root Game_Datapath_V2.srcs sources_1 bd system system.bd]
set game_v2_newfiles [list]
foreach game_v2_name {game_params.vh palette_lut.vh physics_engine.v game_hud.v color_mapper.v datapath.v auto_game_controller.v game_core.v game_button_input.v game_control_path.v game_menu_renderer.v font_rom.v game_buzzer.v galaxian_starfield.v sprite_rom_bank.v sprite_rom_32x32.v space_bg_stereden.v sprites_32x32.mem} {
    lappend game_v2_newfiles [file join $game_v2_root rtl game $game_v2_name]
}
foreach game_v2_name {game_clock_reset.v frame_tick.v game_video.v pattern_multi.v} {
    lappend game_v2_newfiles [file join $game_v2_root rtl video $game_v2_name]
}
set game_v2_oldfiles [list [file join $game_v2_hdmi_dir pattern_multi.v]]
foreach game_v2_name {game_params.vh physics_engine.v color_mapper.v datapath.v} {
    lappend game_v2_oldfiles [file join $game_v2_old_game $game_v2_name]
}
# Preflight all inputs before altering references.
foreach game_v2_file [concat $game_v2_newfiles [list $game_v2_bd_path]] {
    if {![file exists $game_v2_file]} { error "Missing file: $game_v2_file" }
}
foreach game_v2_name {pattern_hdmi_axi.v axi_hdmi_ctrl.v syncgen_multi.v pckgen_triple.v} {
    set game_v2_file [file join $game_v2_hdmi_dir $game_v2_name]
    if {[llength [get_files -quiet -of_objects $game_v2_sources $game_v2_file]] != 1} {
        error "Expected the original HDMI source in sources_1: $game_v2_file"
    }
}
set game_v2_mmcm_include [file join $game_v2_root Game_Datapath_V2.srcs sources_1 imports mmcm_drp]
if {![file exists [file join $game_v2_mmcm_include mmcm_pll_drp_func_7s_mmcm.vh]]} {
    error "Missing original MMCM header."
}
foreach game_v2_file [get_files -of_objects $game_v2_sources] {
    if {[file tail $game_v2_file] eq "pckgen_triple_model.v" ||
        [string match -nocase "$game_v2_root/sim/*" [file normalize $game_v2_file]]} {
        error "Simulation source found in Design Sources: $game_v2_file. Remove its Design Sources reference first."
    }
}

set game_v2_logdir [file join $game_v2_root verification design_setup]
set game_v2_backupdir [file join $game_v2_logdir before_activation]
file mkdir $game_v2_backupdir
foreach game_v2_pair [list \
        [list [file join $game_v2_root Game_Datapath_V2.xpr] project_before.xpr] \
        [list $game_v2_bd_path system_before.bd]] {
    lassign $game_v2_pair game_v2_from game_v2_to
    set game_v2_dest [file join $game_v2_backupdir $game_v2_to]
    if {[file exists $game_v2_from] && ![file exists $game_v2_dest]} {
        file copy $game_v2_from $game_v2_dest
    }
}
set game_v2_before_list [file join $game_v2_backupdir sources_1.txt]
if {![file exists $game_v2_before_list]} {
    set game_v2_channel [open $game_v2_before_list w]
    puts $game_v2_channel "INCLUDE_DIRS: [get_property INCLUDE_DIRS $game_v2_sources]"
    puts $game_v2_channel [join [lsort [get_files -of_objects $game_v2_sources]] \n]
    close $game_v2_channel
}
set game_v2_channel [open $game_v2_bd_path rb]
set game_v2_bd_before [read $game_v2_channel]
close $game_v2_channel

set game_v2_changed false
foreach game_v2_file $game_v2_oldfiles {
    if {[llength [get_files -quiet -of_objects $game_v2_sources $game_v2_file]]} {
        remove_files -fileset sources_1 $game_v2_file
        set game_v2_changed true
    }
}
set game_v2_missing [list]
foreach game_v2_file $game_v2_newfiles {
    if {![llength [get_files -quiet -of_objects $game_v2_sources $game_v2_file]]} { lappend game_v2_missing $game_v2_file }
}
if {[llength $game_v2_missing]} {
    add_files -fileset sources_1 -norecurse $game_v2_missing
    set game_v2_changed true
}
set game_v2_includes [get_property INCLUDE_DIRS $game_v2_sources]
set game_v2_includes_before $game_v2_includes
foreach game_v2_dir [list [file join $game_v2_root rtl game] $game_v2_mmcm_include] {
    if {[lsearch -nocase -exact $game_v2_includes $game_v2_dir] < 0} { lappend game_v2_includes $game_v2_dir }
}
if {$game_v2_includes ne $game_v2_includes_before} {
    set_property INCLUDE_DIRS $game_v2_includes $game_v2_sources
    set game_v2_changed true
}
if {[get_property TOP_AUTO_SET $game_v2_sources]} {
    set_property TOP_AUTO_SET false $game_v2_sources
    set game_v2_changed true
}

# pattern_hdmi_axi ports/parameters are unchanged: only descendant RTL changed.
# Keep the existing BD and generated system IP, including the baseline's locked
# SmartConnect revision. No BD save, IP upgrade or global regeneration here.
set game_v2_channel [open $game_v2_bd_path rb]
set game_v2_bd_after [read $game_v2_channel]
close $game_v2_channel
if {$game_v2_bd_after ne $game_v2_bd_before} { error "Block Design changed unexpectedly. Stop before building." }

# Do not force parser/compile-order work in the same invocation as source edits.
# Vivado GUI may still be refreshing. Check cached membership here; verify the
# actual compile order separately after Sources settles or the project reopens.
foreach game_v2_file $game_v2_newfiles {
    if {[llength [get_files -quiet -of_objects $game_v2_sources $game_v2_file]] != 1} {
        error "Expected one Design Sources reference: $game_v2_file"
    }
}
set game_v2_channel [open [file join $game_v2_logdir activation_status.txt] w]
puts $game_v2_channel "SOURCES_UPDATED: V2 gameplay references are installed."
puts $game_v2_channel "COMPILE_ORDER_PENDING: run verify_game_v2_sources.tcl after Sources finishes refreshing."
puts $game_v2_channel "TOP: [get_property TOP $game_v2_sources]"
puts $game_v2_channel "Synthesis/implementation/bitstream have not been launched by this script."
close $game_v2_channel
puts "SOURCES_UPDATED: V2 gameplay references are installed. changed=$game_v2_changed"
puts "CHECKPOINT: Block Design file unchanged; no system IP upgrade or regeneration."
puts "COMPILE_ORDER_PENDING: wait for Sources to settle, then source scripts/verify_game_v2_sources.tcl."
puts "After Spawn failed, close/reopen Vivado before running that verifier; do not add sources again."
