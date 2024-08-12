// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip__monitor_callback.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 29th, 2024 (creation)
//
// @title Monitor Callback class
//
// Base class to derive any monitor callback method
//

class network_on_chip_monitor_callback;

  function new();
  endfunction

  virtual task pre_monitor(input network_on_chip_monitor monitor, 
                            input axi4stream_monitor_transaction item);
  endtask

  virtual task post_monitor(input network_on_chip_monitor monitor, 
                            input axi4stream_monitor_transaction item);
  endtask

endclass
