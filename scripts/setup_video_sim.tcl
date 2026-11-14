# Isolated PCK reset/frame-tick tests and real-counter 720p video simulation.
# The clock model belongs to simulation only. Design Sources remain unchanged.
set game_v2_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    error "Open Game_Datapath_V2.xpr before running this script."
}
if {[get_property NAME [current_project]] ne "Game_Datapath_V2"} {
    error "Wrong project. Use Game_Datapath_V2, never the golden project."
}
if {![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $game_v2_root]} {
    error "The open project directory differs from the directory containing this script."
}

set game_v2_gamefiles [list]
foreach game_v2_name {game_params.vh palette_lut.vh physics_engine.v game_hud.v color_mapper.v datapath.v auto_game_controller.v game_core.v game_button_input.v game_control_path.v game_menu_renderer.v font_rom.v game_buzzer.v sprite_rom_bank.v galaxian_starfield.v sprite_rom_32x32.v sprites_32x32.mem space_bg_stereden.v} {
    lappend game_v2_gamefiles [file join $game_v2_root rtl game $game_v2_name]
}
set game_v2_unitfiles [list \
    [file join $game_v2_root rtl video game_clock_reset.v] \
    [file join $game_v2_root rtl video frame_tick.v]]
set game_v2_clockmodel [file join $game_v2_root sim models pckgen_triple_model.v]
set game_v2_videofiles [concat $game_v2_gamefiles $game_v2_unitfiles [list \
    [file join $game_v2_root rtl video game_video.v] \
    [file join $game_v2_root rtl video pattern_multi.v] \
    [file join $game_v2_root Game_Datapath_V2.srcs sources_1 imports hdmi_axi_src_720p rtl syncgen_multi.v] \
    $game_v2_clockmodel]]
set game_v2_specs [list \
    [list sim_video_unit_v2 tb_video_unit $game_v2_unitfiles tb_video_unit.sv] \
    [list sim_video_v2 tb_video_integration $game_v2_videofiles tb_video_integration.sv]]

# Check all paths before creating or changing any simulation fileset.
foreach game_v2_spec $game_v2_specs {
    lassign $game_v2_spec game_v2_setname game_v2_top game_v2_rtl game_v2_tb
    foreach game_v2_file [concat $game_v2_rtl [list [file join $game_v2_root sim $game_v2_tb]]] {
        if {![file exists $game_v2_file]} { error "Missing file: $game_v2_file" }
    }
}
foreach game_v2_spec $game_v2_specs {
    lassign $game_v2_spec game_v2_setname game_v2_top game_v2_rtl game_v2_tb
    set game_v2_simset [get_filesets -quiet $game_v2_setname]
    if {[llength $game_v2_simset] == 0} {
        create_fileset -simset $game_v2_setname
        set game_v2_simset [get_filesets $game_v2_setname]
    }
    set_property SOURCE_SET {} $game_v2_simset
    set_property INCLUDE_DIRS [list [file join $game_v2_root rtl game]] $game_v2_simset
    set game_v2_missing [list]
    foreach game_v2_file [concat $game_v2_rtl [list [file join $game_v2_root sim $game_v2_tb]]] {
        if {[llength [get_files -quiet -of_objects $game_v2_simset $game_v2_file]] == 0} {
            lappend game_v2_missing $game_v2_file
        }
    }
    if {[llength $game_v2_missing] > 0} {
        add_files -fileset $game_v2_setname -norecurse $game_v2_missing
    }
    if {$game_v2_setname eq "sim_video_v2"} {
        set game_v2_modelobj [get_files -of_objects $game_v2_simset $game_v2_clockmodel]
        set_property USED_IN_SYNTHESIS false $game_v2_modelobj
        set_property USED_IN_IMPLEMENTATION false $game_v2_modelobj
    }
    set_property TOP $game_v2_top $game_v2_simset
    set_property TOP_AUTO_SET false $game_v2_simset
    update_compile_order -fileset $game_v2_setname
    puts "READY: $game_v2_setname, top=$game_v2_top"
}
current_fileset -simset [get_filesets sim_video_unit_v2]
puts "ACTIVE: sim_video_unit_v2. HDMI sources_1 is unchanged."
puts "NEXT: launch_simulation -simset sim_video_unit_v2 -mode behavioral"
puts "Then run: run all"
puts "After PASS and close_sim: launch_simulation -simset sim_video_v2 -mode behavioral"
puts "Then run: run all"
puts "NOTE: video simulation uses real syncgen_multi counters and an ideal PCK model; it does not test MMCM/DRP/TMDS."
