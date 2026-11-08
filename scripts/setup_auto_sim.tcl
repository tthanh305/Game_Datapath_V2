# Isolated Auto Controller and functional game-core simulations.
# Does not switch the HDMI Design Sources away from the static baseline.
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

foreach game_v2_spec {
    {sim_auto_v2 tb_auto_game_controller {game_params.vh auto_game_controller.v} tb_auto_game_controller.sv}
    {sim_game_v2 tb_game_integration {game_params.vh physics_engine.v game_hud.v color_mapper.v datapath.v auto_game_controller.v game_core.v} tb_game_integration.sv}
} {
    lassign $game_v2_spec game_v2_setname game_v2_top game_v2_rtl game_v2_tb
    set game_v2_simset [get_filesets -quiet $game_v2_setname]
    if {[llength $game_v2_simset] == 0} {
        create_fileset -simset $game_v2_setname
        set game_v2_simset [get_filesets $game_v2_setname]
    }
    set_property SOURCE_SET {} $game_v2_simset
    set_property INCLUDE_DIRS [list [file join $game_v2_root rtl game]] $game_v2_simset
    set game_v2_files [list]
    foreach game_v2_rtlfile $game_v2_rtl {
        lappend game_v2_files [file join $game_v2_root rtl game $game_v2_rtlfile]
    }
    lappend game_v2_files [file join $game_v2_root sim $game_v2_tb]
    foreach game_v2_file $game_v2_files {
        if {![file exists $game_v2_file]} { error "Missing file: $game_v2_file" }
        if {[llength [get_files -quiet -of_objects $game_v2_simset $game_v2_file]] == 0} {
            add_files -fileset $game_v2_setname -norecurse $game_v2_file
        }
    }
    set_property TOP $game_v2_top $game_v2_simset
    set_property TOP_AUTO_SET false $game_v2_simset
    update_compile_order -fileset $game_v2_setname
    puts "READY: $game_v2_setname, top=$game_v2_top"
}
current_fileset -simset [get_filesets sim_game_v2]
puts "ACTIVE: sim_game_v2. HDMI sources_1 is unchanged."
puts "NEXT: launch_simulation -simset sim_game_v2 -mode behavioral"
puts "Then run: run all"
