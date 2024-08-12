// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_env_cov.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 29th, 2024 (creation)
//
// @title Environment functional coverage
//
// This class contains the covergroups to sample the data
// and compute the the functional coverage for the
// simualtion environment.
//

class network_on_chip_env_cov;
  int destination;
  int virtual_network;
  
  int numberof_virtual_networks = 0;

  // Covergroups and coverpoints
  // TODO
  covergroup cg_noc(input int numberof_tiles, input int numberof_virtual_networks);
  
//    c_network_packet_size: coverpoint tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.network_flit_type_i iff (tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.network_valid_i) {
//      bins single_flit_packet = (2'b11[*2:3]);
//      bins short_packet = (2'b00 => 2'b01[*0:5] => 2'b10);
//      bins long_packet = (2'b00 => 2'b01[*5:20] => 2'b10);
//      bins switch_packet[] = (2'b10, 2'b11 => 2'b00, 2'b11);
//      illegal_bins body_after_tail[] = (2'b11, 2'b10 => 2'b01);
//      illegal_bins ht_after_body_or_header[] = (2'b01, 2'b00 => 2'b11);
//    }
    
//    c_flit_content: coverpoint tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.network_flit_i iff (tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.network_valid_i) {
//      bins padding_tail_flit  = { 64'hFF000000_00000000 };
//      wildcard bins tail_flit = { 64'hF0000000_XXXXXXXX };
//      bins allothers = default;
//    }
 
    c_destination: coverpoint destination {
      bins destinations = { [1:numberof_tiles-1] }; 
    }
          
    c_virtual_network_used: coverpoint virtual_network { 
      bins virtual_netword_id[] = { [1:numberof_virtual_networks-1] };
      illegal_bins allothers = default;
    }
  endgroup
  


  //
  // Constructor
  //

  function new(input int numberof_tiles, input int numberof_virtual_networks);
    this.numberof_virtual_networks = numberof_virtual_networks;
    
    cg_noc = new(numberof_tiles, numberof_virtual_networks);
  endfunction

  //
  // Methods
  //

  function void sample_item(int id, axi4stream_monitor_transaction item);
    this.destination = item.get_dest();
    this.virtual_network = item.get_id() % numberof_virtual_networks;
    
    cg_noc.sample();
  endfunction

  function real get_functional_coverage();
    return cg_noc.get_coverage();
  endfunction

endclass
