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

  axi4stream_vip_m_mst_t m_axis_manager_agent;
  axi4stream_vip_s_slv_t m_axis_subordinate_agent;
  
  // Objects for IPC between monitor and scoreboard for the subordinate part
  axi4stream_monitor_transaction m_axis_subordinate_transaction;
  mailbox                        m_axis_subordinate_scoreboard_mbx;

  function new(axi4stream_vip_m_mst_t axis_manager, 
               axi4stream_vip_s_slv_t axis_subordinate,
               mailbox axis_subordinate_monitor2scoreboard_mbx);
    m_axis_manager_agent = axis_manager;
    m_axis_subordinate_agent = axis_subordinate;
    m_axis_subordinate_scoreboard_mbx = axis_subordinate_monitor2scoreboard_mbx;
  endfunction
 
  // Gets the AXI-Stream (subordinate) interface port signals state and send it to the scoreboard
  // through a mailbox
  task axis_subordinate_monitor();
    forever begin
      m_axis_subordinate_agent.monitor.item_collected_port.get(m_axis_subordinate_transaction);
      m_axis_subordinate_scoreboard_mbx.put(m_axis_subordinate_transaction);
    end
  endtask
  
  task run();
    fork
      axis_subordinate_monitor();
    join_none
  endtask
  
endclass
