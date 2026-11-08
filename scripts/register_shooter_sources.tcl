# Register new Steredenn Shmup RTL & BRAM assets into Game_Datapath_V2.xpr
set game_v2_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    error "Open Game_Datapath_V2.xpr first."
}
set game_v2_sources [get_filesets sources_1]
set new_shooter_files [list \
    [file join $game_v2_root rtl game palette_lut.vh] \
    [file join $game_v2_root rtl game sprite_rom_32x32.v] \
    [file join $game_v2_root rtl game space_bg_stereden.v] \
    [file join $game_v2_root rtl game sprites_32x32.mem] \
]

set to_add [list]
foreach f $new_shooter_files {
    if {![file exists $f]} {
        error "Missing required file: $f"
    }
    if {[llength [get_files -quiet -of_objects $game_v2_sources $f]] == 0} {
        lappend to_add $f
    }
}
if {[llength $to_add] > 0} {
    add_files -fileset sources_1 -norecurse $to_add
    puts "Added [llength $to_add] new shooter files to sources_1."
} else {
    puts "All shooter files already registered in sources_1."
}
update_compile_order -fileset sources_1
puts "READY: Steredenn Shmup 11x4 sources registered in sources_1."

