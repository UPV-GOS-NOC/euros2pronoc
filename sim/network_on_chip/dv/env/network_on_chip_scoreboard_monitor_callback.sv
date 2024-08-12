// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_scoreboard_monitor_callback.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 29th, 2024 (creation)
//
// @title Scoreboard Monitor Callback class
//
// This class extends network_on_chip_monitor_callback and 
// enables the monitor to call a scoreboard method
// when performing its action.
//
// It could be used for providing the actual
// model to the scoreborad for instance
//

class network_on_chip_scoreboard_monitor_callback extends network_on_chip_monitor_callback;
  network_on_chip_scoreboard scoreboard;

  function new(input network_on_chip_scoreboard scb);
    this.scoreboard = scb;
  endfunction

  virtual task post_monitor(input network_on_chip_monitor monitor, 
                            input axi4stream_monitor_transaction item);
    scoreboard.check_actual_item(monitor.get_id(), item);
  endtask

endclass
