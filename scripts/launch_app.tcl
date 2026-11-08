set proj_root [file normalize [file dirname [file dirname [info script]]]]

connect
targets -set -nocase -filter {name =~ "*Cortex-A9*#0"}
stop
source "$proj_root/vitis_game_v2/platformgame_platform_v2/export/platformgame_platform_v2/hw/sdt/ps7_init.tcl"
ps7_init
ps7_post_config
dow "$proj_root/vitis_game_v2/hdmi_game_app_v2/build/hdmi_game_app_v2.elf"
con
puts "=========================================================="
puts " SUCCESS: hdmi_game_app_v2.elf is loaded and running!"
puts " HDMI 720p 60Hz display is now active on your monitor."
puts "=========================================================="
