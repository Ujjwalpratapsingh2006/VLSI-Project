# ==============================================================================
# Xilinx Vivado Automation Script: Elevator Controller Project
# Run from Vivado TCL Console or Command Line:
#   vivado -mode gui -source create_project.tcl
# or
#   vivado -mode tcl -source create_project.tcl
# ==============================================================================

set proj_name "Elevator_Controller_Vivado"
set proj_dir  [file normalize [file dirname [info script]]]
set target_part "xc7a35tcpg236-1" ;# Artix-7 (standard Vivado default target)

puts "========================================================================"
puts "Creating Vivado Project: $proj_name in $proj_dir"
puts "========================================================================"

# Create project
create_project -force $proj_name "$proj_dir/$proj_name" -part $target_part

# Add Design Sources (RTL)
add_files -fileset sources_1 [glob "$proj_dir/rtl/*.v"]
set_property top elevator_cont_Machine [current_fileset]

# Add Simulation Sources (Testbenches)
add_files -fileset sim_1 [glob "$proj_dir/tb/*.v"]
set_property top elevator_cont_Machine_tb [get_filesets sim_1]

# Set simulation runtime to 60 seconds (matching original verification timeframe)
set_property -name {xsim.simulate.runtime} -value {60s} -objects [get_filesets sim_1]

# Set Verilog 2001 standard
set_property file_type {Verilog} [get_files [glob "$proj_dir/rtl/*.v"]]
set_property file_type {Verilog} [get_files [glob "$proj_dir/tb/*.v"]]

# Update hierarchy and compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "========================================================================"
puts "Vivado Project Created Successfully!"
puts "Top Design Module:     elevator_cont_Machine"
puts "Top Simulation Module: elevator_cont_Machine_tb"
puts "Default Run Time:      60s"
puts ""
puts "To launch simulation directly, execute:"
puts "    launch_simulation"
puts "========================================================================"
