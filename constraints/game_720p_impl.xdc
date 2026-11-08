# Runtime timing model for fixed-720p V2. Sourced by the implementation PRE hook
# after the baseline design/constraints are loaded, before opt/place/route.
# MMCM INIT and all pin/IO constraints remain in the unchanged baseline design.
# DRP mode 2: M=37.125, D=5, O0=10, O1=2 from SYSCLK=100 MHz.
# The implementation engine must optimize for 74.25 / 371.25 MHz, not VGA INIT.
# TIMING-1 versus INIT is reviewed separately by timing-only runtime CMB analysis.
set game_impl_cmb system_i/pattern_hdmi_axi_0/inst/pattern_multi/syncgen_multi/pckgen_triple/MMCM_RECONFIG
create_generated_clock -name game_pck_720p -source [get_pins $game_impl_cmb/CLKIN1] \
    -multiply_by 297 -divide_by 400 -add -master_clock [get_clocks clk_fpga_0] \
    [get_pins $game_impl_cmb/CLKOUT0]
create_generated_clock -name game_serial_720p -source [get_pins $game_impl_cmb/CLKIN1] \
    -multiply_by 297 -divide_by 80 -add -master_clock [get_clocks clk_fpga_0] \
    [get_pins $game_impl_cmb/CLKOUT1]

# The MMCM power-up clocks and DRP runtime clocks occupy the same output pins,
# but only one profile is active at a time. Keep both named profiles for reports
# while excluding impossible cross-profile paths.
set_clock_groups -physically_exclusive \
    -group [get_clocks -quiet {iPCK iSerialClk}] \
    -group [get_clocks -quiet {game_pck_720p game_serial_720p}]
# AXI, PCK and SerialClk are related clocks. Keep inter-clock data paths timed.
# The vendor TMDS reset synchronizer uses asynchronous PRE pins for assertion;
# cut only those reset-control endpoints. Its synchronizer data paths stay timed.
set game_impl_tmds_reset_pre [get_pins -hier -filter {NAME =~ *rgb2dvi_inst/LockLostReset/SyncAsyncx/oSyncStages_reg*/PRE}]
if {[llength $game_impl_tmds_reset_pre] != 2} {
    error "Expected two asynchronous preset pins in the TMDS reset synchronizer."
}
set_false_path -to $game_impl_tmds_reset_pre
# Asynchronous external button inputs are excepted only to their first PCK
# synchronizer stage; PCK <-> SerialClk remains timed at the 1:5 ratio.
set game_impl_btn_sync_d [get_pins -hier -filter {NAME =~ *button_input_inst/sync_meta_reg*/D}]
if {[llength $game_impl_btn_sync_d] != 5} { error "Expected five button synchronizer first-stage D pins." }
set_false_path -from [get_ports {BTN[*]}] -to $game_impl_btn_sync_d
