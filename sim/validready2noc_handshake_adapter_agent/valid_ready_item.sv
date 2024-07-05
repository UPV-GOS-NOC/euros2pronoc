// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file valid_ready_item.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Valid/Ready transaction item for
// validready2noc_handshake_adapter testbench
//
//

// Transaction item for the ValidReady interface of the validready2noc_handshake_adapter
class valid_ready_item #(
  int VirtualChannelIdWidth   = 0,
  int NumberOfVirtualChannels = 0
);

  rand bit                             valid;
  rand bit                             ready;
  rand bit [VirtualChannelIdWidth-1:0] virtual_channel_id;
  
  function void display(string str);
    $display("[T=%0t] %s valid_ready_item --> valid=%b; ready=%b; virtual_channel_id=%x", 
            $time, str, valid, ready, virtual_channel_id);
  endfunction
  
  constraint virtual_channel_limit_c { 
    virtual_channel_id < NumberOfVirtualChannels; 
  }
  
endclass
