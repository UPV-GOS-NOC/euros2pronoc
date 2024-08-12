// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_scoreboard_driver_callback.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 29th, 2024 (creation)
//
// @title Scoreboard Driver Callback class
//
// This class extends network_on_chip_driver_callback and 
// enables the driver to call a scoreboard method
// when performing its action, as send items
// to the interface.
//
// It could be used for providing the reference
// model to the scoreborad for instance
//

class network_on_chip_scoreboard_driver_callback extends network_on_chip_driver_callback;
  network_on_chip_scoreboard scoreboard;

  function new(input network_on_chip_scoreboard scb);
    this.scoreboard = scb;
  endfunction

  virtual task post_drive(input network_on_chip_driver driver, 
                          input axi4stream_transaction item);
    scoreboard.save_expected_item(driver.get_id(), item);
  endtask

endclass
