// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_controller_tile_is_zero_env_cfg.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 29th, 2024 (creation)
//
// @title Environment runtime configuration parameters
//
// This class is used to generate some configuration runtime
// parameters of the simulation environment randomly and
// constraint noc controller to tile 0 and disable
// managers and subordinates in tiles 0 and 4.
//

class network_on_chip_controller_tile_is_zero_env_cfg extends network_on_chip_env_cfg;

  constraint c_tile_0_type_controller {
    tile_type[0] == 1;
  }
  
  constraint c_tile_noc_controller_zero {
    tile_noc_controller == 0;
  }
  
  constraint c_control_and_status_virtual_network_is_zero {
    control_and_status_virtual_network == 0;
  }  
  
  function new(int numberof_tiles, int numberof_virtual_networks);
    super.new(numberof_tiles, numberof_virtual_networks);
  endfunction

endclass
