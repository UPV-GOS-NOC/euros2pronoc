// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file single_unit_network_interface_monitor.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 04th, 2024
//
// @title Single Unit Network Interface (SUNI) Monitor
//
// Monitors the AXI-Stream interfaces of the SUNI to generate
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


class single_unit_network_interface_monitor #(
);

  axi4stream_vip_m_mst_t m_axis_manager_agent;
  axi4stream_vip_s_slv_t m_axis_subordinate_agent;
  
  // Objects for the communication to the manager part of the scoreboard
  axi4stream_monitor_transaction m_axis_manager_transaction;
  mailbox                        m_axis_manager_scoreboard_mbx;
  
  // Objects for IPC between monitor and scoreboard for the subordinate part
  axi4stream_monitor_transaction m_axis_subordinate_transaction;
  mailbox                        m_axis_subordinate_scoreboard_mbx;

  // Mailboxes for IPC between the monitor and scoreboard. They are used for
  // sending the switching activity in the network interface of the NI to
  // the scoreboard
  mailbox m_network_if_manager_scoreboard_mbx;
  mailbox m_network_if_subordinate_scoreboard_mbx;

  // Network Virtual interface
  network_vif_t network_manager_vif;
  network_vif_t network_subordinate_vif;
 
  function new(axi4stream_vip_m_mst_t axis_manager, 
               axi4stream_vip_s_slv_t axis_subordinate,
               mailbox axis_manager_monitor2scoreboard_mbx,
               mailbox axis_subordinate_monitor2scoreboard_mbx,
               mailbox network_if_manager_monitor2scoreboard_mbx,
               mailbox network_if_subordinate_monitor2scoreboard_mbx,
               network_vif_t network_manager_vif,
               network_vif_t network_subordinate_vif);
    m_axis_manager_agent = axis_manager;
    m_axis_subordinate_agent = axis_subordinate;
    m_axis_manager_scoreboard_mbx = axis_manager_monitor2scoreboard_mbx;
    m_axis_subordinate_scoreboard_mbx = axis_subordinate_monitor2scoreboard_mbx;
    m_network_if_manager_scoreboard_mbx = network_if_manager_monitor2scoreboard_mbx;
    m_network_if_subordinate_scoreboard_mbx = network_if_subordinate_monitor2scoreboard_mbx;
    
    this.network_manager_vif = network_manager_vif;
    this.network_subordinate_vif = network_subordinate_vif;
  endfunction
 
  // Gets the AXI-Stream (manager) interface port signals state and send it to the scoreboard
  // through a mailbox
  task axis_manager_monitor();
    forever begin
      m_axis_manager_agent.monitor.item_collected_port.get(m_axis_manager_transaction);
      m_axis_manager_scoreboard_mbx.put(m_axis_manager_transaction);
    end
  endtask
  
  // Gets the AXI-Stream (subordinate) interface port signals state and send it to the scoreboard
  // through a mailbox
  task axis_subordinate_monitor();
    forever begin
      m_axis_subordinate_agent.monitor.item_collected_port.get(m_axis_subordinate_transaction);
      m_axis_subordinate_scoreboard_mbx.put(m_axis_subordinate_transaction);
    end
  endtask
  
  
  // Gets the network (manager -- network_valid_o) interface port signals state and send it to the scoreboard through a mailbox
  // The monitor acts as a subordinate then
  task network_if_subordinate_monitor();
    forever begin
      network_flit_item_t item = new();
      
      @(posedge network_subordinate_vif.monitor.clk);
      
      item.valid              = network_subordinate_vif.monitor.monitor_clock_block.valid;
      item.ready              = network_subordinate_vif.monitor.monitor_clock_block.ready;
      item.flit               = network_subordinate_vif.monitor.monitor_clock_block.flit;
      item.flit_type          = network_subordinate_vif.monitor.monitor_clock_block.flit_type;
      item.broadcast          = network_subordinate_vif.monitor.monitor_clock_block.broadcast;
      item.virtual_identifier = network_subordinate_vif.monitor.monitor_clock_block.virtual_identifier;  
           
      m_network_if_subordinate_scoreboard_mbx.put(item);
    end 
  endtask

  // Gets the network (subordinate -- network_valid_i) interface port signals state and send it to the scoreboard through a mailbox
  // The monitor acts as a manager then
  task network_if_manager_monitor();
    forever begin
      network_flit_item_t item = new();
      
      @(posedge network_manager_vif.monitor.clk);      
        
      item.valid              = network_manager_vif.monitor.monitor_clock_block.valid;
      item.ready              = network_manager_vif.monitor.monitor_clock_block.ready;
      item.flit               = network_manager_vif.monitor.monitor_clock_block.flit;
      item.flit_type          = network_manager_vif.monitor.monitor_clock_block.flit_type;
      item.broadcast          = network_manager_vif.monitor.monitor_clock_block.broadcast;
      item.virtual_identifier = network_manager_vif.monitor.monitor_clock_block.virtual_identifier;  
    
      m_network_if_manager_scoreboard_mbx.put(item);
    end 
  endtask
  
  task run();
    fork
      axis_manager_monitor();
      axis_subordinate_monitor();
      network_if_manager_monitor();
      network_if_subordinate_monitor();
    join_none
  endtask
  
endclass
