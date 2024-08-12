// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_coverage_monitor_callback.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 29th, 2024 (creation)
//
// @title Coverage Monitor Callback class
//
// This class extends network_on_chip_monitor_callback and 
// enables the monitor to call a coverage method
// when performing its action.
//

class network_on_chip_coverage_monitor_callback extends network_on_chip_monitor_callback;
  network_on_chip_env_cov cov;

  function new(input network_on_chip_env_cov cov);
    this.cov = cov;
  endfunction

  virtual task post_monitor(input network_on_chip_monitor monitor, 
                            input axi4stream_monitor_transaction item);
    cov.sample_item(monitor.get_id(), item);
  endtask

endclass
