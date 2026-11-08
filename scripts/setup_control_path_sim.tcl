set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0 || [get_property NAME [current_project]] ne "Game_Datapath_V2"} {
    error "Open the Game_Datapath_V2 project before sourcing this script."
}
set simset [get_filesets -quiet sim_control_v2]
if {[llength $simset] == 0} {
    create_fileset -simset sim_control_v2
    set simset [get_filesets sim_control_v2]
}
set_property SOURCE_SET {} $simset
set_property INCLUDE_DIRS [list [file join $root rtl game]] $simset
set files [list \
    [file join $root rtl game game_button_input.v] \
    [file join $root rtl game game_control_path.v] \
    [file join $root sim tb_game_control_path.sv]]
foreach f $files {
    if {![file exists $f]} { error "Missing simulation source: $f" }
    if {[llength [get_files -quiet -of_objects $simset $f]] == 0} {
        add_files -fileset sim_control_v2 -norecurse $f
    }
}
set_property TOP tb_game_control_path $simset
set_property TOP_AUTO_SET false $simset
update_compile_order -fileset sim_control_v2
current_fileset -simset $simset
puts "READY: sim_control_v2 top=tb_game_control_path; sources_1 unchanged."
puts "NEXT: launch_simulation -simset sim_control_v2 -mode behavioral; then run all"
