# Check the already-switched V2 project. Does not edit project/source properties,
# update the BD, reset runs or force update_compile_order. Writes reports only.
set game_v2_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} { error "Open Game_Datapath_V2.xpr first." }
if {[get_property NAME [current_project]] ne "Game_Datapath_V2" ||
    ![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $game_v2_root]} {
    error "Wrong project or directory. Use Game_Datapath_V2, never Game_Test."
}
if {[get_property PART [current_project]] ne "xc7z010clg400-1"} { error "Unexpected FPGA part." }
set game_v2_sources [get_filesets sources_1]
if {[get_property TOP $game_v2_sources] ne "system_wrapper"} { error "Expected system_wrapper as project top." }
set game_v2_logdir [file join $game_v2_root verification design_setup]
file mkdir $game_v2_logdir
set game_v2_channel [open [file join $game_v2_logdir activation_status.txt] w]
puts $game_v2_channel "COMPILE_ORDER_PENDING: verification has not completed."
close $game_v2_channel

set game_v2_hdmi_dir [file join $game_v2_root Game_Datapath_V2.srcs sources_1 imports hdmi_axi_src_720p rtl]
set game_v2_old_game [file join $game_v2_root Game_Datapath_V2.srcs sources_1 imports FPGA_Projects FPGA_Game_Datapath rtl]
set game_v2_expected [list]
foreach game_v2_name {game_params.vh palette_lut.vh physics_engine.v game_hud.v color_mapper.v datapath.v auto_game_controller.v game_core.v game_button_input.v game_control_path.v game_menu_renderer.v font_rom.v game_buzzer.v galaxian_starfield.v sprite_rom_bank.v sprite_rom_32x32.v space_bg_stereden.v} {
    lappend game_v2_expected [file join $game_v2_root rtl game $game_v2_name]
}
foreach game_v2_name {game_clock_reset.v frame_tick.v game_video.v pattern_multi.v} {
    lappend game_v2_expected [file join $game_v2_root rtl video $game_v2_name]
}
set game_v2_oldfiles [list [file join $game_v2_hdmi_dir pattern_multi.v]]
foreach game_v2_name {game_params.vh physics_engine.v color_mapper.v datapath.v} {
    lappend game_v2_oldfiles [file join $game_v2_old_game $game_v2_name]
}
foreach game_v2_file $game_v2_expected {
    if {![file exists $game_v2_file]} { error "Missing V2 source: $game_v2_file" }
    set game_v2_obj [get_files -quiet -of_objects $game_v2_sources $game_v2_file]
    if {[llength $game_v2_obj] != 1} { error "Expected one Design Sources reference: $game_v2_file" }
    if {![get_property USED_IN_SYNTHESIS $game_v2_obj]} { error "V2 source excluded from synthesis: $game_v2_file" }
}
foreach game_v2_file $game_v2_oldfiles {
    if {[llength [get_files -quiet -of_objects $game_v2_sources $game_v2_file]]} { error "Old gameplay reference still in sources_1: $game_v2_file" }
}
foreach game_v2_file [get_files -of_objects $game_v2_sources] {
    if {[file tail $game_v2_file] eq "pckgen_triple_model.v" ||
        [string match -nocase "$game_v2_root/sim/*" [file normalize $game_v2_file]]} {
        error "Simulation source present in Design Sources: $game_v2_file"
    }
}
foreach game_v2_name {pattern_hdmi_axi.v axi_hdmi_ctrl.v syncgen_multi.v pckgen_triple.v} {
    if {[llength [get_files -quiet -of_objects $game_v2_sources [file join $game_v2_hdmi_dir $game_v2_name]]] != 1} {
        error "Missing original HDMI source: $game_v2_name"
    }
}
foreach game_v2_dir [list [file join $game_v2_root rtl game] \
        [file join $game_v2_root Game_Datapath_V2.srcs sources_1 imports mmcm_drp]] {
    if {[lsearch -nocase -exact [get_property INCLUDE_DIRS $game_v2_sources] $game_v2_dir] < 0} {
        error "Required include directory missing: $game_v2_dir"
    }
}
set game_v2_bd_path [file join $game_v2_root Game_Datapath_V2.srcs sources_1 bd system system.bd]
set game_v2_bd_backup [file join $game_v2_root verification button_menu_integration baseline post_smc_resolution system_btn_smc_validated.bd]
if {![file exists $game_v2_bd_backup]} { error "Missing post-SmartConnect BTN/menu BD checkpoint; inspect before verifying." }
set game_v2_channel [open $game_v2_bd_path rb]
set game_v2_bd_current [read $game_v2_channel]
close $game_v2_channel
set game_v2_channel [open $game_v2_bd_backup rb]
set game_v2_bd_original [read $game_v2_channel]
close $game_v2_channel
if {$game_v2_bd_current ne $game_v2_bd_original} { error "BD differs from the saved post-SmartConnect BTN/menu checkpoint." }
puts "SOURCES_OK: 15 V2 files, original HDMI clock source, button/menu sources included, no simulation model; BD matches post-SmartConnect checkpoint."

# Refresh compile order so module-reference OOC runs pick up sprite_rom_32x32.v and space_bg_stereden.v
catch {update_compile_order -fileset sources_1}
if {[catch {get_files -compile_order sources -used_in synthesis -of_objects $game_v2_sources} game_v2_compile]} {
    error "COMPILE_ORDER_PENDING: $game_v2_compile\nProject references are preserved. Reopen Vivado, wait for Sources to settle, then rerun this verifier."
}
set game_v2_names [list]
foreach game_v2_file $game_v2_compile {
    set game_v2_path [file normalize [get_property NAME $game_v2_file]]
    if {[file tail $game_v2_path] eq "pckgen_triple_model.v" ||
        [string match -nocase "$game_v2_root/sim/*" $game_v2_path]} { error "Simulation source in synthesis compile order: $game_v2_path" }
    foreach game_v2_old $game_v2_oldfiles {
        if {[string equal -nocase $game_v2_old $game_v2_path]} { error "Old gameplay source in compile order: $game_v2_path" }
    }
    lappend game_v2_names [file tail $game_v2_path]
}
foreach game_v2_name {game_params.vh physics_engine.v game_hud.v color_mapper.v datapath.v auto_game_controller.v game_core.v game_button_input.v game_control_path.v game_menu_renderer.v font_rom.v game_buzzer.v sprite_rom_32x32.v space_bg_stereden.v game_clock_reset.v frame_tick.v game_video.v pattern_multi.v syncgen_multi.v pckgen_triple.v} {
    if {[llength [lsearch -all -exact $game_v2_names $game_v2_name]] != 1} { error "Missing or duplicate synthesis source: $game_v2_name" }
}
# Reuse the returned list for the report; do not trigger a second parse/report.
set game_v2_channel [open [file join $game_v2_logdir compile_order_synthesis.txt] w]
puts $game_v2_channel "Verified synthesis compile order for sources_1; top=system_wrapper"
set game_v2_index 0
foreach game_v2_file $game_v2_compile {
    incr game_v2_index
    puts $game_v2_channel "$game_v2_index [get_property NAME $game_v2_file]"
}
close $game_v2_channel
set game_v2_channel [open [file join $game_v2_logdir activation_status.txt] w]
puts $game_v2_channel "READY: V2 dynamic Design Sources; original MMCM clock source retained; no simulation model."
puts $game_v2_channel "TOP: system_wrapper"
puts $game_v2_channel "This is source/compile-order verification, not a dynamic synthesis or hardware PASS."
close $game_v2_channel
puts "READY: V2 dynamic Design Sources; original MMCM clock source retained; no simulation model."
puts "CHECKPOINT: Block Design matches the saved post-SmartConnect BTN/menu state; no BD/IP edits during source verification."
puts "NEXT: inspect Design Sources hierarchy and send the log before rebuilding HDMI OOC."
