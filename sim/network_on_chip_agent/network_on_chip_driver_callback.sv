// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_driver_callback.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 29th, 2024 (creation)
//
// @title Driver Callback class
//
// Base class to derive any driver callback method
//

class network_on_chip_driver_callback;

  function new();
  endfunction

  virtual task pre_drive(input network_on_chip_driver driver, 
                         input axi4stream_transaction item);
  endtask

  virtual task post_drive(input network_on_chip_driver driver, 
                          input axi4stream_transaction item);
  endtask

endclass
