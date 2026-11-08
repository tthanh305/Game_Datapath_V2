# Run from the Tcl Console of the copied Game_Datapath_V2 project.
# This creates an isolated simulation set; sources_1 stays on the static baseline.
set game_v2_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    error "Open Game_Datapath_V2.xpr before running this script."
}
if {[get_property NAME [current_project]] ne "Game_Datapath_V2"} {
    error "Wrong project. Open Game_Datapath_V2; do not use the golden project."
}
if {![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $game_v2_root]} {
    error "The open project directory differs from the directory containing this script."
}

set game_v2_simset [get_filesets -quiet sim_physics_v2]
if {[llength $game_v2_simset] == 0} {
    create_fileset -simset sim_physics_v2
    set game_v2_simset [get_filesets sim_physics_v2]
}

# Do not inherit the old physics_engine in sources_1: it has the same module name.
set_property SOURCE_SET {} $game_v2_simset
set_property INCLUDE_DIRS [list [file join $game_v2_root rtl game]] $game_v2_simset

foreach game_v2_file [list \
        [file join $game_v2_root rtl game game_params.vh] \
        [file join $game_v2_root rtl game physics_engine.v] \
        [file join $game_v2_root sim tb_physics_engine.sv]] {
    if {![file exists $game_v2_file]} { error "Missing file: $game_v2_file" }
    if {[llength [get_files -quiet -of_objects $game_v2_simset $game_v2_file]] == 0} {
        add_files -fileset sim_physics_v2 -norecurse $game_v2_file
    }
}
set_property TOP tb_physics_engine $game_v2_simset
set_property TOP_AUTO_SET false $game_v2_simset
current_fileset -simset $game_v2_simset
update_compile_order -fileset sim_physics_v2
puts "READY: sim_physics_v2. sources_1 is unchanged."
puts "NEXT: launch_simulation -simset sim_physics_v2 -mode behavioral"
puts "Then run: run all"
