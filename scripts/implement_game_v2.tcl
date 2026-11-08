# Fresh V2 implementation through routing, with runtime 720p timing analysis.
# Does not regenerate BD/IP, synthesize again, write a bitstream or export XSA.
set game_imp_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] != 1 || [get_property NAME [current_project]] ne "Game_Datapath_V2" ||
    ![string equal -nocase [file normalize [get_property DIRECTORY [current_project]]] $game_imp_root]} {
    error "Wrong project or directory. Use Game_Datapath_V2, never Game_Test."
}
if {[get_property PART [current_project]] ne "xc7z010clg400-1" ||
    [get_property TOP [get_filesets sources_1]] ne "system_wrapper"} { error "Unexpected FPGA part or project top." }
foreach game_imp_name {synth_1 impl_1 system_pattern_hdmi_axi_0_2_synth_1} {
    if {[regexp -nocase {running|queued} [get_property STATUS [get_runs $game_imp_name]]]} { error "Wait for active run: $game_imp_name" }
}
set game_imp_synth [get_runs synth_1]
if {![string match -nocase "*synth_design Complete*" [get_property STATUS $game_imp_synth]] ||
    [get_property NEEDS_REFRESH $game_imp_synth]} { error "Fresh full-system synthesis is required." }
foreach {game_imp_status game_imp_prefix} {
    {verification/system_synth/status.txt} {PASS: full-system synthesis with dynamic HDMI/game checkpoint.}
    {verification/timing_720p/status.txt} {MODEL_CHECKED:}
} {
    set game_imp_file [file join $game_imp_root $game_imp_status]
    if {![file exists $game_imp_file]} { error "Missing prior checkpoint status: $game_imp_status" }
    set game_imp_ch [open $game_imp_file r]
    set game_imp_text [read $game_imp_ch]
    close $game_imp_ch
    if {[string first $game_imp_prefix $game_imp_text] != 0} { error "Prior checkpoint not ready: $game_imp_status" }
}
set game_imp_run [get_runs impl_1]
set game_imp_dir [file normalize [get_property DIRECTORY $game_imp_run]]
if {![string equal -nocase $game_imp_dir [file join $game_imp_root Game_Datapath_V2.runs impl_1]]} {
    error "Refusing to reset implementation outside the expected V2 directory: $game_imp_dir"
}
set game_imp_out [file join $game_imp_root verification implementation]
file mkdir $game_imp_out
set game_imp_ch [open [file join $game_imp_out status.txt] w]
puts $game_imp_ch "PENDING: V2 implementation/runtime timing has not completed."
close $game_imp_ch
set game_imp_protected [list \
    [file join $game_imp_root Game_Datapath_V2.srcs sources_1 bd system system.bd] \
    [file join $game_imp_root Game_Datapath_V2.srcs constrs_1 imports constraints hdmi_axi_720p.xdc] \
    [file join $game_imp_root Game_Datapath_V2.srcs sources_1 imports hdmi_axi_src_720p rtl pckgen_triple.v]]
set game_imp_original [list]
foreach game_imp_file $game_imp_protected {
    set game_imp_ch [open $game_imp_file rb]
    lappend game_imp_original [read $game_imp_ch]
    close $game_imp_ch
}
if {[llength [get_designs -quiet]]} { close_design }
set game_imp_xdc [file join $game_imp_root constraints game_720p_impl.xdc]
if {![file exists $game_imp_xdc]} { error "Missing 720p implementation clock model." }
set game_imp_hook [file join $game_imp_root scripts apply_720p_impl_clocks.tcl]
if {![file exists $game_imp_hook]} { error "Missing 720p implementation hook." }
set game_imp_previous_hook [get_property STEPS.OPT_DESIGN.TCL.PRE $game_imp_run]
if {$game_imp_previous_hook ne "" && ![string equal -nocase [file normalize $game_imp_previous_hook] $game_imp_hook]} {
    error "A different implementation pre-hook is already configured; inspect it before replacing."
}
# Use a run-local hook so no constraint files are added to the synthesis set.
set_property STEPS.OPT_DESIGN.TCL.PRE $game_imp_hook $game_imp_run
if {[get_property NEEDS_REFRESH $game_imp_synth]} { error "Synthesis became stale unexpectedly; inspect before rebuilding." }
set game_imp_checkpoint [file join $game_imp_dir system_wrapper_routed.dcp]
set game_imp_backup [file join $game_imp_out checkpoint_before_implementation.dcp]
if {[file exists $game_imp_checkpoint] && ![file exists $game_imp_backup]} { file copy $game_imp_checkpoint $game_imp_backup }
set_property INCREMENTAL_CHECKPOINT {} $game_imp_run
set game_imp_start [clock seconds]
reset_run impl_1
launch_runs impl_1 -to_step route_design -scripts_only -jobs 1
set game_imp_script [file join $game_imp_dir system_wrapper.tcl]
set game_imp_ch [open $game_imp_script r]
set game_imp_generated [string tolower [read $game_imp_ch]]
close $game_imp_ch
foreach game_imp_bad {D:/FPGA_Projects/Game_test/ D:/FPGA_Projects/FPGA_Game_Datapath/ pckgen_triple_model.v} {
    if {[string first [string tolower $game_imp_bad] $game_imp_generated] >= 0} { error "Unsafe path in implementation script: $game_imp_bad" }
}
if {[string first [string tolower $game_imp_hook] $game_imp_generated] < 0} { error "Generated implementation script lacks the runtime clock pre-hook." }
reset_run impl_1
puts "RUNNING: fresh V2 implementation through route_design, jobs=4; 720p runtime clocks enabled."
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {![string match -nocase "*route_design Complete*" [get_property STATUS $game_imp_run]] ||
    ![file exists $game_imp_checkpoint] || [file mtime $game_imp_checkpoint] < $game_imp_start} {
    error "Implementation failed or routed checkpoint is stale; inspect $game_imp_dir/runme.log"
}
puts "CHECKPOINT: routing complete. Checking the actual runtime 720p CMB timing in a temporary analysis session."
source [file join $game_imp_root scripts report_720p_postroute.tcl]
foreach game_imp_file $game_imp_protected game_imp_before $game_imp_original {
    set game_imp_ch [open $game_imp_file rb]
    set game_imp_after [read $game_imp_ch]
    close $game_imp_ch
    if {$game_imp_after ne $game_imp_before} { error "Protected baseline file changed: $game_imp_file" }
}
set game_imp_ch [open [file join $game_imp_out status.txt] w]
puts $game_imp_ch "PASS: V2 implementation through routing and internal runtime-720p timing checks."
puts $game_imp_ch $game_rt_summary
puts $game_imp_ch "BD, original pin XDC and MMCM HDL/INIT unchanged. Supplementary timing constraints apply only to implementation."
puts $game_imp_ch "LIMIT: CDC/reset warnings (baseline and V2) and absent external TMDS delay model require protocol review; hardware test pending."
puts $game_imp_ch "BITSTREAM_PENDING: no bitstream, XSA, Vitis or kit test performed."
close $game_imp_ch
puts "PASS: V2 implementation through routing and internal runtime-720p timing checks."
puts "BITSTREAM_PENDING: send this log before generating the V2 bitstream."
