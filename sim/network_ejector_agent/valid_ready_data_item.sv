// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file valid_ready_data_item.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Basic valid/ready with data transaction item
//
class valid_ready_data_item #(
  int DataWidth = 0
);

  rand bit                 valid;
  rand bit                 ready;
  rand bit [DataWidth-1:0] data;
  
  function void display(string str);
    $display("[T=%0t] %s data_if --> valid=%b; ready=%b; data=%x", 
            $time, str, valid, ready, data);
  endfunction
  
endclass
