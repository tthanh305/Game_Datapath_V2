set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    open_project [file join $root Game_Datapath_V2.xpr]
}
open_bd_design [get_files system.bd]
validate_bd_design
save_bd_design
generate_target -force all [get_files system.bd]
export_ip_user_files -of_objects [get_files system.bd] -no_script -sync -force -quiet
make_wrapper -files [get_files system.bd] -top -force
close_bd_design [get_bd_designs system]
puts "BD_GEN_DONE: Target generated successfully for system.bd"

