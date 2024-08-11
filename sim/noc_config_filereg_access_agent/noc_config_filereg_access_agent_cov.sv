// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_config_filereg_access_agent_cov.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 25th, 2024
//
// @title FileReg Interface Coverage model
//

class noc_config_filereg_access_agent_cov;

  bit [11:0] destination;
  bit [1:0]  command;
  bit [4:0]  register_address;
  bit        valid;
  bit        ready;

  covergroup cg_filereg_access;
    c_destination: coverpoint destination iff ((valid == 1) && (ready == 1)) {
      bins tile[] = { [1:7] };
      illegal_bins tile_zero = { 0 };
      bins allothers = default;
    }

    c_register_address: coverpoint register_address iff ((valid == 1) && (ready == 1)) {
      bins register[] = { [1:15] };
      illegal_bins reg_zero = { 0 };
      bins allothers = default;
    }

    c_command: coverpoint command iff ((valid == 1) && (ready == 1)) {
      bins write = { 1 };
      bins read = { 0 };
      bins allothers = default; 
    }
    
    c_cmd_dest_reg: cross c_command, c_destination, c_register_address iff ((valid == 1) && (ready == 1));
     
  endgroup


  function new();
    cg_filereg_access = new();
  endfunction

  function void sample(input request_filereg_item_t request);
    this.destination      = request.get_destination();
    this.command          = request.get_command();
    this.register_address = request.get_register_address();

    this.valid = request.valid;
    this.ready = request.ready;

    cg_filereg_access.sample();
  endfunction

  function real get_functional_coverage();
    return cg_filereg_access.get_coverage();
  endfunction
  
endclass 
