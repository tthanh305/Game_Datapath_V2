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

puts "=== STEP 6: GENERATE BOOT.BIN ==="
set bootgen_exe "D:/vivado/Vivado/2024.2/bin/unwrapped/win64.o/bootgen.exe"
if {[file exists $bootgen_exe]} {
    exec $bootgen_exe -image [file join $game_root boot.bif] -arch zynq -o [file join $game_root BOOT.BIN] -w
    puts "SUCCESS: BOOT.BIN generated successfully."
}

puts "=== ALL STEPS COMPLETED SUCCESSFULLY ==="

