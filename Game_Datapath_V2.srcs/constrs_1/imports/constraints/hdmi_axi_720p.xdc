# EBAZ4205 constraints file for AXI-controlled HDMI pattern generator
# Project: 06_hdmi_test with AXI4-Lite control
# Note: CLK and RST are provided by PS FCLK_CLK1 and FCLK_RESET1_N (no external pins)

# UART on Type-C
set_property PACKAGE_PIN H16 [get_ports UART_0_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports UART_0_rxd]
set_property PACKAGE_PIN H17 [get_ports UART_0_txd]
set_property IOSTANDARD LVCMOS33 [get_ports UART_0_txd]

# EBAZ4205 user buttons, matching D:/FPGA_Projects/05_Zynq7000/vivado/EBAZ4205.xdc
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports {BTN[0]}]
set_property -dict {PACKAGE_PIN P19 IOSTANDARD LVCMOS33} [get_ports {BTN[1]}]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD LVCMOS33} [get_ports {BTN[2]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {BTN[3]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports {BTN[4]}]

# Buzzer on expansion board (D18)
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports BEEP]

# HDMI TX outputs
set_property -dict {PACKAGE_PIN F20 IOSTANDARD TMDS_33} [get_ports HDMI_CLK_N]
set_property -dict {PACKAGE_PIN F19 IOSTANDARD TMDS_33} [get_ports HDMI_CLK_P]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD TMDS_33} [get_ports {HDMI_N[0]}]
set_property -dict {PACKAGE_PIN D19 IOSTANDARD TMDS_33} [get_ports {HDMI_P[0]}]
set_property -dict {PACKAGE_PIN B20 IOSTANDARD TMDS_33} [get_ports {HDMI_N[1]}]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD TMDS_33} [get_ports {HDMI_P[1]}]
set_property -dict {PACKAGE_PIN A20 IOSTANDARD TMDS_33} [get_ports {HDMI_N[2]}]
set_property -dict {PACKAGE_PIN B19 IOSTANDARD TMDS_33} [get_ports {HDMI_P[2]}]

# The AXI and MMCM-derived video clocks are related to the same PS clock.
# Keep their paths timed. Only the asynchronous board-button inputs are
# excepted, and only as far as the first PCK-domain synchronizer stage.
set_false_path -from [get_ports {BTN[*]}] \
    -to [get_pins -hier -filter {NAME =~ *button_input_inst/sync_meta_reg*/D}]

# The control-mode buses are held stable by the AXI registers and cross into
# two-stage PCK synchronizers. Cut only the first-stage D pins; keep the second
# stage and all ordinary AXI/PCK paths timed.
set game_timing_meta_cells [get_cells -hier -filter {NAME =~ *axi_ctrl/timing_sel_meta_reg*}]
set game_pattern_meta_cells [get_cells -hier -filter {NAME =~ *axi_ctrl/pattern_sel_meta_reg*}]
set_false_path -from [get_clocks clk_fpga_0] \
    -to [get_pins -of_objects $game_timing_meta_cells -filter {REF_PIN_NAME == D}]
set_false_path -from [get_clocks clk_fpga_0] \
    -to [get_pins -of_objects $game_pattern_meta_cells -filter {REF_PIN_NAME == D}]
set game_lock_meta_cells [get_cells -hier -filter {NAME =~ *axi_ctrl/locked_meta_reg*}]
set_false_path -to [get_pins -of_objects $game_lock_meta_cells -filter {REF_PIN_NAME == D}]
