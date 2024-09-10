// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_env_cfg.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 29th, 2024 (creation)
//
// @title Environment runtime configuration parameters
//
// This class is used to generate some configuration runtime
// parameters of the simulation environment randomly
//

class network_on_chip_env_cfg;

  int numberof_tiles;
  int numberof_virtual_networks;

  // Total AXIS transfers to generate 
  rand bit[31:0] total_messages;

  // 0 = manager, 1 = subordinate
  rand bit tile_type[];

  // Number of messages generated per tile
  rand bit [31:0] messages_per_tile[];
  
  // Control and status virtual network
  rand bit [7:0] control_and_status_virtual_network;
  
  // enable a noc controller
  rand bit[31:0] tile_noc_controller;  

  // Policy for ready generation 
  rand bit [2:0] ready_policy[];

  constraint c_minimum_numberof_messages {
    total_messages > 0;
  }

  constraint c_maximum_numberof_messages {
    total_messages < 5000;
  }

  constraint c_at_least_two_tile_type_subordinate {
    tile_type.sum() > 1;
  }

  constraint c_tile_at_least_a_type_manager {
    tile_type.sum() < numberof_tiles;
  }
 
  constraint c_tile_noc_controller_valid {
    tile_noc_controller < numberof_tiles;   
  }

  constraint c_control_and_status_virtual_network_valid {
    control_and_status_virtual_network < numberof_virtual_networks;
  }

  constraint c_sum_messages {
    messages_per_tile.sum() == total_messages;
  }
 
  constraint c_order_type_and_message {
    foreach(messages_per_tile[i]) {
      //solve tile_type[i] before messages_per_tile[i];
      (tile_type[i] == 1) -> (messages_per_tile[i] == 0);
    }
  }
  

  function new(int numberof_tiles, int numberof_virtual_networks);
    this.numberof_tiles = numberof_tiles;
    this.numberof_virtual_networks = numberof_virtual_networks;
    this.tile_type = new[numberof_tiles];
    this.messages_per_tile = new[numberof_tiles];
    this.ready_policy = new[numberof_tiles];
  endfunction

  virtual function void display(string prefix = "");
    $write("%sConfig: numberof_tiles=%0d; numberof_virtual_networks=%0d; total_messages=%0d; tile_noc_controller=%0d; control_and_status_virtual_network=%0d",
      prefix, numberof_tiles, numberof_virtual_networks, total_messages, tile_noc_controller, control_and_status_virtual_network);
    $write("; tile_type=(");
    foreach(tile_type[i]) $write("%0d ", tile_type[i]);
    $write("); messages_per_tile=(");
    foreach(messages_per_tile[i]) $write("%0d ", messages_per_tile[i]);
    $write("); ready_policy=(");
    foreach(tile_type[i]) $write("%0d ", ready_policy[i]);
    $write(");");    
    $display;
  endfunction

  function int get_total_messages();
    return total_messages;
  endfunction

  function int get_numberof_messages(int tile);
    int res = 0;
    if (tile < numberof_tiles) begin
      res = messages_per_tile[tile];
    end    
    return res;
  endfunction

  function int get_ready_policy(int tile);
    int res = 0;
    if (tile < numberof_tiles) begin
      res = ready_policy[tile];
    end    
    return res;      
  endfunction

  function void get_tile_types(inout bit tile_type[]);
    tile_type = this.tile_type; 
  endfunction
  
  function int get_noc_controller_tile();
    return tile_noc_controller;
  endfunction

  function int get_control_and_status_virtual_network();
    return control_and_status_virtual_network;
  endfunction
endclass
