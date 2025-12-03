# =============================================================================
# Vivado TCL Script for AWG Project Creation
# Target: XC7A35T-ICPG236C (Basys3)
# =============================================================================

# Project settings
set project_name "awg_project"
set project_dir "./vivado_project"
set part_number "xc7a35tcpg236-1"

# Create project
create_project $project_name $project_dir -part $part_number -force

# Add source files
add_files -norecurse {
    ./awg_top.v
    ./button_debounce.v
    ./input_processor.v
    ./sweep_controller.v
    ./phase_accumulator.v
    ./sine_generator.v
    ./sawtooth_generator.v
    ./triangle_generator.v
    ./square_generator.v
    ./seven_seg_controller.v
    ./pulse_generator_mhz.v
    ./ila_debug.v
}

# Add constraints file
add_files -fileset constrs_1 -norecurse ./basys3_constraints.xdc

# Add simulation files
add_files -fileset sim_1 -norecurse ./awg_testbench.v

# Set top module
set_property top awg_top [current_fileset]
set_property top awg_tb [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# =============================================================================
# Synthesis Settings
# =============================================================================
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]

# =============================================================================
# Implementation Settings
# =============================================================================
set_property strategy Performance_ExtraTimingOpt [get_runs impl_1]

# =============================================================================
# Generate ILA Core (Optional - uncomment to use)
# =============================================================================
# create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
# set_property -dict [list \
#     CONFIG.C_PROBE0_WIDTH {12} \
#     CONFIG.C_PROBE1_WIDTH {12} \
#     CONFIG.C_PROBE2_WIDTH {20} \
#     CONFIG.C_PROBE3_WIDTH {2} \
#     CONFIG.C_PROBE4_WIDTH {2} \
#     CONFIG.C_PROBE5_WIDTH {20} \
#     CONFIG.C_PROBE6_WIDTH {10} \
#     CONFIG.C_PROBE7_WIDTH {7} \
#     CONFIG.C_PROBE8_WIDTH {1} \
#     CONFIG.C_NUM_OF_PROBES {9} \
#     CONFIG.C_DATA_DEPTH {4096} \
# ] [get_ips ila_0]
# generate_target all [get_ips ila_0]

# =============================================================================
# Run Synthesis and Implementation (Optional - uncomment to auto-run)
# =============================================================================
# launch_runs synth_1 -jobs 4
# wait_on_run synth_1
# launch_runs impl_1 -jobs 4
# wait_on_run impl_1
# launch_runs impl_1 -to_step write_bitstream -jobs 4
# wait_on_run impl_1

puts "Project created successfully!"
puts "Open Vivado and run: source create_project.tcl"
puts "Or use Vivado GUI to open: $project_dir/$project_name.xpr"
