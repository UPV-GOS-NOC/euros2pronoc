// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file avail_valid_item.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Avail/Valid NoC handshake transaction item for
// validready2noc_handshake_adapter testbench
//

// Transaction item for the NoC interface of the validready2noc_handshake_adapter
class avail_valid_item #(
  int NumberOfVirtualChannels = 0
);

  rand bit                               valid;
  rand bit [NumberOfVirtualChannels-1:0] avail;
  
  function void display(string str);
    $display("[T=%0t] %s valid_avail_item --> valid=%b; avail=%b;", 
            $time, str, valid, avail);
  endfunction
  
endclass


