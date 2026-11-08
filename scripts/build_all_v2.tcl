set game_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    open_project [file join $game_root Game_Datapath_V2.xpr]
}

puts "=== STEP 1: SYNTHESIZING HDMI OOC ==="
source [file join $game_root scripts synth_hdmi_ooc.tcl]

puts "=== STEP 2: SYNTHESIZING FULL SYSTEM ==="
source [file join $game_root scripts synth_system_v2.tcl]

puts "=== STEP 3: CHECKING 720P TIMING CONSTRAINTS ==="
source [file join $game_root scripts check_720p_timing.tcl]

puts "=== STEP 4: IMPLEMENTATION & ROUTING ==="
source [file join $game_root scripts implement_game_v2.tcl]

puts "=== STEP 5: GENERATE BITSTREAM & XSA ==="
source [file join $game_root scripts generate_bitstream_and_xsa.tcl]

puts "=== ALL STEPS COMPLETED SUCCESSFULLY ==="

