set game_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    open_project [file join $game_root Game_Datapath_V2.xpr]
}
open_run impl_1
set bit_path [file join $game_root Game_Datapath_V2.runs impl_1 system_wrapper.bit]
set xsa_path [file join $game_root Game_Datapath_V2.xsa]
puts "GENERATING_BITSTREAM: $bit_path"
write_bitstream -force $bit_path
puts "EXPORTING_XSA: $xsa_path"
write_hw_platform -fixed -include_bit -force -file $xsa_path
puts "SUCCESS: bitstream and XSA generated successfully."

