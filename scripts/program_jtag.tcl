# Connect to JTAG hardware server
connect

# 1. Clear DAP transaction errors and reset system
puts "Step 0: Resetting Zynq system via DAP..."
catch {
    targets -set -nocase -filter {name =~ "*DAP*"}
    rst -system
}
after 1000

# 2. Download FPGA Bitstream (Galaxian game core + HDMI 720p 60Hz)
puts "Step 1: Downloading FPGA bitstream..."
targets -set -nocase -filter {name =~ "*xc7z010*"}
fpga "E:/Game_Datapath_V2/Game_Datapath_V2.runs/impl_1/system_wrapper.bit"

# 3. Initialize PS7 (ARM Cortex-A9 Clocks & DDR3 Memory Controller)
puts "Step 2: Selecting Cortex-A9 Core 0..."
targets -set -nocase -filter {name =~ "*Cortex-A9*#0"}
rst -processor
after 500

puts "Step 3: Initializing Zynq PS7 & DDR3..."
source "E:/Game_Datapath_V2/vitis_game_v2/platformgame_platform_v2/export/platformgame_platform_v2/hw/sdt/ps7_init.tcl"
ps7_init
ps7_post_config

# 4. Download and run software application ELF
puts "Step 4: Downloading hdmi_game_app_v2.elf..."
dow "E:/Game_Datapath_V2/vitis_game_v2/hdmi_game_app_v2/build/hdmi_game_app_v2.elf"

puts "Step 5: Starting execution..."
con

puts "=========================================================="
puts " SUCCESS: Galaxian Game is running on EBAZ4205!"
puts " Output: HDMI 1280x720@60Hz | Audio: Buzzer on pin D18"
puts " Controls: KEY4 (U19)=Left, KEY1 (T19)=Right, KEY3 (U20)=Fire/Select"
puts "           KEY2 (P19)=Up/Pause, KEY5 (V20)=Down/Reset"
puts "=========================================================="
