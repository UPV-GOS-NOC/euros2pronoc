#*****************************************************************************************
# Vivado (TM) v2022.2 (64-bit)
#
# generate_vivado_project_for_network_on_chip_testbench.tcl: 
#   Tcl script for re-creating project 'network_on_chip'
#
# This file contains the Vivado Tcl commands for re-creating the project to the state*
# when this script was generated. In order to re-create the project, please source this
# file in the Vivado Tcl Shell.
#
# * Note that the runs in the created project will be configured the same way as the
#   original project, however they will not be launched automatically. To regenerate the
#   run results please launch the synthesis/implementation runs as needed.
#
#*****************************************************************************************
# NOTE: In order to use this script for source control purposes, please make sure that the
#       following files are added to the source control system:-
#
# 1. This project restoration tcl script
#
# 2. The following source(s) files
#    (Please see '$repo_dir' variable setting below at the start of the script)
#
#    "<repo_dir>/vivado/2022.2/network_on_chip/ip/axi4stream_vip_s/axi4stream_vip_s.xci"
#    "<repo_dir>/vivado/2022.2/network_on_chip/ip/axi4stream_vip_m/axi4stream_vip_m.xci"
#    "<repo_dir>/sim/network_ejector_agent/network_if.sv"
#    "<repo_dir>/sim/network_on_chip/dv/env/network_on_chip_env_pkg.sv"
#    "<repo_dir>/sim/network_on_chip/dv/tests/network_on_chip_base_test.sv"
#    "<repo_dir>/sim/network_on_chip/dv/tests/network_on_chip_ejeccion_test.sv"
#    "<repo_dir>/sim/network_on_chip/dv/tb/axis_vip_tile.sv"
#    "<repo_dir>/sim/network_on_chip/dv/tb/duv.sv"
#    "<repo_dir>/sim/network_on_chip/dv/tb/tb.sv"
#
#    NI:
#    "<repo_dir>/rtl/misc/axis_2_native_fifo.v"
#    "<repo_dir>/rtl/common/axis_converter_signals.v"
#    "<repo_dir>/rtl/network_interface/axis_data_downsizer.v"
#    "<repo_dir>/rtl/network_interface/axis_data_upsizer.v"
#    "<repo_dir>/rtl/network_interface/filereg_fromnet.v"
#    "<repo_dir>/rtl/network_interface/axistream_fromnet.v"
#    "<repo_dir>/rtl/network_interface/axistream_tonet.v"
#    "<repo_dir>/rtl/common/fifo_type_1_async/fifo_mem.v"
#    "<repo_dir>/rtl/common/fifo_type_1_async/fifo_type_1_async.v"
#    "<repo_dir>/rtl/misc/fifo_type_1_async_axis_wrapper.v"
#    "<repo_dir>/rtl/misc/native_fifo_2_axi.v"
#    "<repo_dir>/rtl/network_interface/network_data_axis_downsizer.v"
#    "<repo_dir>/rtl/network_interface/network_ejector.v"
#    "<repo_dir>/rtl/network_interface/network_signal_converter.v"
#    "<repo_dir>/rtl/network_interface/noc_outport_handshake_adapter.v"
#    "<repo_dir>/rtl/network_interface/noc_packet_creator.v"
#    "<repo_dir>/rtl/common/fifo_type_1_async/rd_ptr_empty.v"
#    "<repo_dir>/rtl/network_interface/network_on_chip.v"
#    "<repo_dir>/rtl/common/fifo_type_1_async/sync.v"
#    "<repo_dir>/rtl/network_interface/validready2noc_handshake_adapter.v"
#    "<repo_dir>/rtl/common/fifo_type_1_async/wr_ptr_full.v"
#
#    ROUTER:
#    "<repo_dir>/rtl/router-vc/encoder.v"
#    "<repo_dir>/rtl/router-vc/filereg.v"
#    "<repo_dir>/rtl/router-vc/fpa.v"
#    "<repo_dir>/rtl/router-vc/fpa_x_in.v"
#    "<repo_dir>/rtl/router-vc/ibuffer.v"
#    "<repo_dir>/rtl/router-vc/output_vc.v"
#    "<repo_dir>/rtl/router-vc/rot_left_x_in.v"
#    "<repo_dir>/rtl/router-vc/rot_right_x_in.v"
#    "<repo_dir>/rtl/router-vc/routing_algorithm_lbdr_2d.v"
#    "<repo_dir>/rtl/router-vc/routing_algorithm_xy.v"
#    "<repo_dir>/rtl/router-vc/routing_vc.v"
#    "<repo_dir>/rtl/router-vc/rr_x_in.v"
#    "<repo_dir>/rtl/router-vc/sa_vc.v"
#    "<repo_dir>/rtl/router-vc/switch_vc.v"
#    "<repo_dir>/rtl/router-vc/update_token_x_in.v"
#    "<repo_dir>/rtl/router-vc/va_local_dynamic.v"
#    "<repo_dir>/rtl/router-vc/va_static.v"
#*****************************************************************************************


# Check file required for this script exists
proc checkRequiredFiles { } {
  set status true
  variable project_files
  foreach ifile ${project_files} {
    if { ![file isfile $ifile] } {
      puts " Could not find file $ifile "
      set status false
    }
  }

  return $status
}

# Set the reference directory for source file relative paths (by default the value is script directory path)
set repo_dir "."

# Use repo directory path location variable, if specified in the tcl shell
if { [info exists ::repo_dir_loc] } {
  set repo_dir $::repo_dir_loc
}

# Set the project name
set _xil_proj_name_ "network_on_chip_testbench"

# Use project name variable, if specified in the tcl shell
if { [info exists ::user_project_name] } {
  set _xil_proj_name_ $::user_project_name
}

# set the reference directory for the vivado project to generate
set proj_dir_loc "."

# Use user home variable for project dir, if specified in the tcl shell
if { [info exists $::env(HOME)] } {
  set proj_dir_loc $::env(HOME)
}

# Set the directory path for the original project from where this script was exported
set prj_dir "[file normalize "$proj_dir_loc"]"



variable script_file
set script_file "generate_vivado_project_for_network_on_chip_testbench.tcl"

# Help information for this script
proc print_help {} {
  variable script_file
  set proj_dir_loc_def $::env(HOME)
  puts "\nDescription:"
  puts "Recreate a Vivado project from this script. The created project will be"
  puts "functionally equivalent to the original project for which this script was"
  puts "generated. The script contains commands for creating a project, filesets,"
  puts "runs, adding/importing sources and setting properties on various objects.\n"
  puts "Syntax:"
  puts "$script_file"
  puts "$script_file -tclargs \[--repo_dir <path>\]"
  puts "$script_file -tclargs \[--project_name <name>\]"
  puts "$script_file -tclargs \[--proj_dir <path>\]"
  puts "$script_file -tclargs \[--help\]\n"
  puts "Usage:"
  puts "Name                   Description"
  puts "-------------------------------------------------------------------------"
  puts "\[--repo_dir <path>\]  Determine source file paths. Default"
  puts "                       repo_dir path value is \".\" \n"
  puts "\[--proj_dir <path>\]  Determine the directory for the project to be build. Default"
  puts "                       proj_dir path value is ${proj_dir_loc_def} \n"
   puts "\[--project_name <name>\] Create project with the specified name. Default"
  puts "                       name is the name of the project from where this"
  puts "                       script was generated.\n"
  puts "\[--help\]               Print help information for this script"
  puts "-------------------------------------------------------------------------\n"
  #exit 0
}

if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--repo_dir"   { incr i; set repo_dir [lindex $::argv $i] }
      "--prj_dir"    { incr i; set prj_dir [lindex $::argv $i] }
      "--project_name" { incr i; set _xil_proj_name_ [lindex $::argv $i] }
      "--help"         { print_help }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

puts "Current Configuration:\n"
puts "  repo_dir: ${repo_dir}\n"
puts "  proj_dir: ${prj_dir}\n"
puts "  proj_name: ${_xil_proj_name_}\n"

set source_files_to_add [list \
 [file normalize "${repo_dir}/rtl/misc/axis_2_native_fifo.v"] \
 [file normalize "${repo_dir}/rtl/common/axis_converter_signals.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/axis_data_downsizer.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/axis_data_upsizer.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/filereg_fromnet.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/axistream_fromnet.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/axistream_tonet.v"] \
 [file normalize "${repo_dir}/rtl/common/fifo_type_1_async/fifo_mem.v"] \
 [file normalize "${repo_dir}/rtl/common/fifo_type_1_async/fifo_type_1_async.v"] \
 [file normalize "${repo_dir}/rtl/misc/fifo_type_1_async_axis_wrapper.v"] \
 [file normalize "${repo_dir}/rtl/misc/native_fifo_2_axi.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/network_data_axis_downsizer.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/network_ejector.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/network_signal_converter.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/noc_outport_handshake_adapter.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/noc_packet_creator.v"] \
 [file normalize "${repo_dir}/rtl/common/fifo_type_1_async/rd_ptr_empty.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/single_unit_network_interface.v"] \
 [file normalize "${repo_dir}/rtl/common/fifo_type_1_async/sync.v"] \
 [file normalize "${repo_dir}/rtl/network_interface/validready2noc_handshake_adapter.v"] \
 [file normalize "${repo_dir}/rtl/common/fifo_type_1_async/wr_ptr_full.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/encoder.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/filereg.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/fpa.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/fpa_x_in.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/ibuffer.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/output_vc.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/rot_left_x_in.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/rot_right_x_in.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/routing_algorithm_lbdr_2d.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/routing_algorithm_xy.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/routing_vc.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/rr_x_in.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/sa_vc.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/switch_vc.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/update_token_x_in.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/va_local_dynamic.v"] \
 [file normalize "${repo_dir}/rtl/router-vc/va_static.v"] \
 [file normalize "${repo_dir}/sim/network_on_chip/dv/tb/axis_vip_tile.sv"]\
 [file normalize "${repo_dir}/sim/network_on_chip/dv/tb/duv.sv"]\
]

set sim_files_to_import [list \
 [file normalize "${repo_dir}/vivado/2022.2/network_on_chip/ip/axi4stream_vip_s/axi4stream_vip_s.xci" ]\
 [file normalize "${repo_dir}/vivado/2022.2/network_on_chip/ip/axi4stream_vip_m/axi4stream_vip_m.xci" ]\
]

set sim_files_to_add [list \
 [file normalize "${repo_dir}/sim/network_on_chip_agent/network_on_chip_agent_pkg.sv"]\
 [file normalize "${repo_dir}/sim/network_on_chip/dv/env/network_on_chip_env_pkg.sv"] \
 [file normalize "${repo_dir}/sim/network_on_chip/dv/tests/network_on_chip_base_test.sv"] \
 [file normalize "${repo_dir}/sim/network_on_chip/dv/tb/tb.sv"] \
]

set project_files [list]

foreach ifile ${source_files_to_add} {
  lappend project_files $ifile
}
foreach ifile ${sim_files_to_import} {
  lappend project_files $ifile
}
foreach ifile ${sim_files_to_add} {
  lappend project_files $ifile
}




# Check for paths and files needed for project creation
set validate_required 1
if { $validate_required == 1 } {
  if { [checkRequiredFiles] } {
    puts "Tcl file $script_file is valid. All files required for project creation is accesable. "
  } else {
    puts "Tcl file $script_file is not valid. Not all files required for project creation is accesable. "
    return
  }
}

# Create project
create_project ${_xil_proj_name_} ${prj_dir}/${_xil_proj_name_} -part xczu15eg-ffvb1156-1-e

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]
set_property -name "include_dirs" -value "[file normalize "$repo_dir/rtl/router-vc"] [file normalize "${repo_dir}/sim/network_on_chip/dv/tb"] [file normalize "${repo_dir}/vivado/2022.2/network_on_chip/sim"]" -objects $obj

add_files -norecurse -fileset $obj $source_files_to_add

# Import files into project folder
set imported_files [import_files -fileset sources_1 $sim_files_to_import]


set file "$repo_dir/sim/network_on_chip/dv/tb/axis_vip_tile.sv"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "file_type" -value "SystemVerilog" -objects $file_obj

set file "$repo_dir/sim/network_on_chip/dv/tb/duv.sv"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "file_type" -value "SystemVerilog" -objects $file_obj

set file "axi4stream_vip_m/axi4stream_vip_m.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
generate_target all [get_files $file_obj] 

set file "axi4stream_vip_s/axi4stream_vip_s.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
generate_target all [get_files $file_obj] 

set_property -name "top" -value "duv" -objects $obj

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Empty (no sources present)

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]
set_property -name "target_part" -value "xczu15eg-ffvb1156-1-e" -objects $obj

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
add_files -norecurse -fileset $obj $sim_files_to_add

# Import files into the project folder
set files [list \
 [file normalize "${prj_dir}/${_xil_proj_name_}/${_xil_proj_name_}.gen/sources_1/ip/axi4stream_vip_m/sim/axi4stream_vip_m_pkg.sv" ]\
 [file normalize "${prj_dir}/${_xil_proj_name_}/${_xil_proj_name_}.gen/sources_1/ip/axi4stream_vip_s/sim/axi4stream_vip_s_pkg.sv" ]\
]
set imported_files [import_files -fileset sim_1 $files]

# Set 'sim_1' fileset file properties
set file "$repo_dir/sim/network_on_chip/dv/tb/tb.sv"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sim_1] [list "*$file"]]
set_property -name "file_type" -value "SystemVerilog" -objects $file_obj

set file "$repo_dir/sim/network_on_chip/dv/tests/network_on_chip_base_test.sv"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sim_1] [list "*$file"]]
set_property -name "file_type" -value "SystemVerilog" -objects $file_obj

set file "$repo_dir/sim/network_on_chip/dv/env/network_on_chip_env_pkg.sv"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sim_1] [list "*$file"]]
set_property -name "file_type" -value "SystemVerilog" -objects $file_obj

set file "$repo_dir/sim/network_on_chip_agent/network_on_chip_agent_pkg.sv"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sim_1] [list "*$file"]]
set_property -name "file_type" -value "SystemVerilog" -objects $file_obj

# Set 'sim_1' fileset file properties for local files
set file "sim/axi4stream_vip_m_pkg.sv"
set file_obj [get_files -of_objects [get_filesets sim_1] [list "*$file"]]
set_property -name "file_type" -value "SystemVerilog" -objects $file_obj

set file "sim/axi4stream_vip_s_pkg.sv"
set file_obj [get_files -of_objects [get_filesets sim_1] [list "*$file"]]
set_property -name "file_type" -value "SystemVerilog" -objects $file_obj


# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]
set_property -name "include_dirs" -value "[file normalize "/opt/Xilinx/Vivado/2022.2/data/xilinx_vip/include"] \
                                          [file normalize "$repo_dir/sim/network_on_chip_agent"] \
                                          [file normalize "$repo_dir/sim/network_on_chip"] \
                                          [file normalize "$repo_dir/sim/network_on_chip/dv/tb"] \
                                          [file normalize "$repo_dir/rtl/router-vc"] \
                                          [file normalize "${repo_dir}/vivado/2022.2/network_on_chip/sim"]" -objects $obj
set_property -name "top" -value "tb" -objects $obj
set_property -name "top_lib" -value "xil_defaultlib" -objects $obj
set_property -name "xsim.simulate.xsim.more_options" -value "-sv_seed 13" -objects $obj

# Set 'utils_1' fileset object
set obj [get_filesets utils_1]
# Empty (no sources present)

# Set 'utils_1' fileset properties
set obj [get_filesets utils_1]

# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
    create_run -name synth_1 -part xczu15eg-ffvb1156-1-e -flow {Vivado Synthesis 2022} -strategy "Vivado Synthesis Defaults" -report_strategy {No Reports} -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2022" [get_runs synth_1]
}

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
    create_run -name impl_1 -part xczu15eg-ffvb1156-1-e -flow {Vivado Implementation 2022} -strategy "Vivado Implementation Defaults" -report_strategy {No Reports} -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2022" [get_runs impl_1]
}

# set the current impl run
current_run -implementation [get_runs impl_1]
catch {
 if { $idrFlowPropertiesConstraints != {} } {
   set_param runs.disableIDRFlowPropertyConstraints $idrFlowPropertiesConstraints
 }
}

puts "INFO: Project created:${_xil_proj_name_}"

