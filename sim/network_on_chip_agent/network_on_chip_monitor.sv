// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_monitor.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 20th, 2024
//
// @title Network-on-Chip Monitor
//
// Monitors the AXI-Stream interfaces to generate
// transactions for the scoreboard.
//
// This monitor uses the AXI-Stream VIP manager and subordinate
// agents to handle the AXI-Stream transactions and interfaces.
// For such purpose, two AXI-Stream VIP core has been generated
// using Vivado 2022.2. Their names are:
//  - axi4stream_vip_m
//  - axi4stream_vip_s
//
// This approach constraint the verification environment of the
// Single Unit Network Interface to simulators that are able to
// work with Vivado libraries


class network_on_chip_monitor #(
);
  protected int id = 0;
  
  protected int verbosity = 0;

  axi4stream_vip_s_slv_t s_axis_agent;

  network_on_chip_monitor_callback callback_sequence [$];  

  function new(input axi4stream_vip_s_slv_t s_axis_agent,
               input int id);
    this.s_axis_agent = s_axis_agent;
    this.id = id;
  endfunction
  
  //
  // Getters and setters
  //
 
  function int get_id();
    return id;
  endfunction
 
  function void set_verbosity(int verbosity);
    this.verbosity = verbosity;
  endfunction 
 
   //
   // Run and test methods
   //
 
  // Gets the AXI-Stream (subordinate) interface port signals state and send it to the scoreboard
  // through a mailbox
  task s_axis_monitor();
    axi4stream_monitor_transaction item;

    forever begin
      s_axis_agent.monitor.item_collected_port.get(item);

      foreach(callback_sequence[i]) begin
        callback_sequence[i].post_monitor(this, item);
      end
    end
  endtask
  
  task run();
    fork
      s_axis_monitor();
    join_none
  endtask
  
endclass
