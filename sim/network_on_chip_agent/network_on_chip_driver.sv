// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_driver.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 20th, 2024
//
// @title Network-on-Chip Driver
//
// Drive transactions from the generator to the
// NoC through.
//
// This driver uses the AXI-Stream VIP manager and subordinate
// agents to handle the AXI-Stream transactions and interfaces.
// For such purpose, two AXI-Stream VIP cores has been generated
// using Vivado 2022.2. Their names are:
//  - axi4stream_vip_m
//  - axi4stream_vip_s
//
// This approach constraint the verification environment of the
// Single Unit Network Interface to simulators that are able to
// work with Vivado libraries

class network_on_chip_driver #(
);
  
  int numberof_m_axis_frames_transmitted = 0;  
  
  // AXI-Stream Manager and Subordinate VIP agents
  // Given by AXI VIP Vivado IP Core
  axi4stream_vip_m_mst_t m_axis_manager_agent;
  axi4stream_vip_s_slv_t m_axis_subordinate_agent;

  // Mailboxes for IPC between the generator and the driver
  mailbox m_axis_manager_generator_mbx;
  mailbox m_axis_subordinate_generator_mbx;
  
  // Mailbox for IPC between driver and scoreboard to send the
  // reference model for the transmit and receiver channels
  mailbox m_axis_manager_scoreboard_mbx;

  int verbosity = 0;

  function new(axi4stream_vip_m_mst_t axis_manager,
               axi4stream_vip_s_slv_t axis_subordinate,
               mailbox axis_manager_generator2driver_mbx,
               mailbox axis_subordinate_generator2driver_mbx,
               mailbox axis_manager_driver2scoreboard_mbx);
    m_axis_manager_agent = axis_manager;
    m_axis_subordinate_agent = axis_subordinate;
    m_axis_manager_generator_mbx = axis_manager_generator2driver_mbx;
    m_axis_subordinate_generator_mbx = axis_subordinate_generator2driver_mbx;
    m_axis_manager_scoreboard_mbx = axis_manager_driver2scoreboard_mbx;
  endfunction

  task reset();
  endtask

  // Drives transactions to the AXI-Stream interface of the NI
  // using the AXI-Stream Manager VIP.
  // Transactions are got from the generator
  task axis_manager_driver();
    forever begin
      axi4stream_transaction item;
      
      m_axis_manager_generator_mbx.get(item);
          
      m_axis_manager_scoreboard_mbx.put(item);

      m_axis_manager_agent.driver.send(item);
      
      if (verbosity != 0) begin
        $display("[T=%0t] [Driver] AXI-Stream Manager transaction send to DUV. tid=%0d, tdest=%0d, tlast=%b", 
                 $time,
                 item.get_id(),
                 item.get_dest(),
                 item.get_last());
      end
      
      if (item.get_last() == 1) begin
        numberof_m_axis_frames_transmitted++;
        
        if (verbosity != 0) begin
          $display("[T=%0t] [Driver] numberof_axis_frames_transmitted=%0d", 
                   $time,
                   numberof_m_axis_frames_transmitted);
        end
      end      
    end
  endtask
  
  // Drives transactions to the AXI-Stream interface of the NI
  // using the AXI-Stream Subordinate VIP
  // Transactions are got from the generator
  task axis_subordinate_driver();
    forever begin
      axi4stream_ready_gen item;
      m_axis_subordinate_generator_mbx.get(item);
      m_axis_subordinate_agent.driver.send_tready(item);
    end
  endtask
  
  task run();
    fork
      axis_manager_driver();
      axis_subordinate_driver();
    join_none
  endtask

endclass
