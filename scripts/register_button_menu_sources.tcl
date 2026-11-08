set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0 || [get_property NAME [current_project]] ne "Game_Datapath_V2" ||
    ![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $root]} {
    error "Open Game_Datapath_V2.xpr from its project directory. Never run this in Game_Test."
}
set fs [get_filesets sources_1]
if {[get_property TOP $fs] ne "system_wrapper"} { error "Expected system_wrapper top." }
set add_list [list \
    [file join $root rtl game game_button_input.v] \
    [file join $root rtl game game_control_path.v] \
    [file join $root rtl game game_menu_renderer.v] \
    [file join $root rtl game font_rom.v]]
foreach f $add_list {
    if {![file exists $f]} { error "Missing V2 integration source: $f" }
}
foreach f $add_list {
    if {[llength [get_files -quiet -of_objects $fs $f]] == 0} {
        add_files -fileset sources_1 -norecurse $f
    }
}
set inc [get_property INCLUDE_DIRS $fs]
set game_inc [file join $root rtl game]
if {[lsearch -nocase -exact $inc $game_inc] < 0} {
    lappend inc $game_inc
    set_property INCLUDE_DIRS $inc $fs
}
set_property TOP_AUTO_SET false $fs
update_compile_order -fileset sources_1
puts "REGISTERED: button synchronizer, game Control Path, and Long menu/font in sources_1."
puts "UNCHANGED: BD, PS/AXI, HDMI timing/clock/TMDS; no synthesis was launched."
puts "NEXT: Refresh the pattern_hdmi_axi module reference in the Block Design and externalize its BTN[4:0] pin as BTN."
