// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_config_filereg_access_driver.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 23th, 2024
//
// @title Network Configuration FileReg Access Driver
//
// Drive the AXIS transactions, that encapsulate configuration
// filereg accesses, generated by the generator to the
// NoC through the NI
//
// This driver uses the AXI-Stream VIP manager
// agent to handle the AXI-Stream transactions and interfaces.
// For such purpose, one AXI-Stream VIP core has been generated
// using Vivado 2022.2:
//  - axi4stream_vip_m
//
// This approach constraint the verification environment of the
// Network Configuration FileReg Acess to simulators that are able to
// work with Vivado libraries

class noc_config_filereg_access_driver #(
  int NumberOfTiles = 0
);
  
  // Counts the number of AXIS frames that the driver
  // has transmitted to the NI through the AXIS Manager
  // VIP core
  int numberof_m_axis_frames_transmitted = 0;  
  
  // AXI-Stream Manager VIP agent
  // Given by AXI VIP Vivado IP Core
  axi4stream_vip_m_mst_t m_axis_manager_agent;

  // Mailboxes for IPC between the generator and the driver
  mailbox m_axis_transaction_generator_mbx;
  
  // Mailbox for IPC between driver and scoreboard to send the
  // reference model
  mailbox m_config_filereg_transaction_scoreboard_mbx[0:NumberOfTiles-1];

  int verbosity = 0;

  function new(input axi4stream_vip_m_mst_t axis_manager,
               input mailbox axis_transaction_generator2driver_mbx,
               input mailbox config_filereg_transaction_driver2scoreboard_mbx[0:NumberOfTiles-1]);
    m_axis_manager_agent = axis_manager;
    
    m_axis_transaction_generator_mbx = axis_transaction_generator2driver_mbx;
    
    for (int i = 0; i < NumberOfTiles; i++) begin
      m_config_filereg_transaction_scoreboard_mbx[i] = config_filereg_transaction_driver2scoreboard_mbx[i];
    end
  endfunction

  task reset();
  endtask

  // Drives transactions to the AXI-Stream interface of the NI
  // using the AXI-Stream Manager VIP.
  // Transactions are got from the generator
  // In addition, it rebuilds config_filreg_items from
  // the AXIS transactions to send the scoreboard the reference model
  task drive_transactions();
    logic [7:0] data[3:0];
    bit [10:0] destination;
    bit [5:0] command;
    bit [10:0] address;
    bit [31:0] value;
 
    forever begin
      axi4stream_transaction item_1;
      axi4stream_transaction item_2;
      request_filereg_item_t cfg_transaction;
      
      m_axis_transaction_generator_mbx.get(item_1);
      m_axis_transaction_generator_mbx.get(item_2);

      // the LSB word of the config filereg access message comes in second transfer
      item_1.get_data(data);
      destination = item_1.get_dest();
      address = data[0][4:0];
      command = data[0][6:5];
      item_2.get_data(data);
      value = {data[3], data[2], data[1], data[0]}; 

      // Send the reference model (Configuration FileReg Access) to
      // the right scoreboard that must receive the actual 
      // configuration filereg transaction from the filereg access router
      // interface through the right monitor
      cfg_transaction = new(destination, command, address, value);
      if (command == 1) begin
        // Only write request are sent to the scoreboard
        m_config_filereg_transaction_scoreboard_mbx[destination].put(cfg_transaction);
      end

      // An AXIS frame consists of two transfers
      m_axis_manager_agent.driver.send(item_1);
      m_axis_manager_agent.driver.send(item_2);
      
      if (verbosity != 0) begin
        $display("[T=%0t] [Driver] AXI-Stream Frame send to DUV. tid=%0d, tdest=%0d. destination=%0d, command=%0x, address=%0x, value=%0x", 
                 $time,
                 item_1.get_id(),
                 item_1.get_dest(),
                 destination,
                 command,
                 address,
                 value);
      end
      
      numberof_m_axis_frames_transmitted++;
        
      if (verbosity != 0) begin
        $display("[T=%0t] [Driver] numberof_axis_frames_transmitted=%0d", 
                 $time,
                 numberof_m_axis_frames_transmitted);
      end
    end // forever
  endtask
  
  task run();
    fork
      drive_transactions();
    join_none
  endtask

endclass
