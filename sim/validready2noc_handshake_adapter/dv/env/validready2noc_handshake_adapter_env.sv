// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file validready2noc_handshake_adapter_env.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Environment for validready2noc_handshake_adapter Testbench
//
//

class validready2noc_handshake_adapter_env #(
  int VirtualChannelIdWidth   = 0,
  int NumberOfVirtualChannels = 0 
);
  
  validready2noc_handshake_adapter_generator #(
    .VirtualChannelIdWidth  (VirtualChannelIdWidth),
    .NumberOfVirtualChannels(NumberOfVirtualChannels)    
  ) generator;

  validready2noc_handshake_adapter_driver #(
    .VirtualChannelIdWidth  (VirtualChannelIdWidth),
    .NumberOfVirtualChannels(NumberOfVirtualChannels)  
  ) driver;
  
  validready2noc_handshake_adapter_monitor #(
    .VirtualChannelIdWidth  (VirtualChannelIdWidth),
    .NumberOfVirtualChannels(NumberOfVirtualChannels)  
  ) monitor;
  
  validready2noc_handshake_adapter_scoreboard #(
    .VirtualChannelIdWidth  (VirtualChannelIdWidth),
    .NumberOfVirtualChannels(NumberOfVirtualChannels)  
  ) scoreboard;
  
  virtual valid_ready_if #(
    .VirtualChannelIdWidth  (VirtualChannelIdWidth)
  ) valid_ready_vif;  
   
  virtual avail_valid_if #(
    .NumberOfVirtualChannels(NumberOfVirtualChannels)
  ) avail_valid_vif;   
  
  virtual clk_mockup_if clk_vif;
    
  mailbox m_generator2driver_valid_ready_mbx;
  mailbox m_generator2driver_avail_valid_mbx;
  mailbox m_monitor2scoreboard_valid_ready_mbx;
  mailbox m_monitor2scoreboard_avail_valid_mbx;
  mailbox m_driver2scoreboard_mbx;
  
  event generator_done;

  function new(virtual valid_ready_if #(
                 .VirtualChannelIdWidth(VirtualChannelIdWidth)
               ) valid_ready_vif, 
               virtual avail_valid_if #(
                 .NumberOfVirtualChannels(NumberOfVirtualChannels)
               ) avail_valid_vif,
               virtual clk_mockup_if clk_vif
  );
    // Get inteface from test
    this.valid_ready_vif = valid_ready_vif;
    this.avail_valid_vif = avail_valid_vif;
    this.clk_vif         = clk_vif;
    
    // Mailbox handler to be shared between generator and driver
    m_generator2driver_valid_ready_mbx = new();
    m_generator2driver_avail_valid_mbx = new();
    m_monitor2scoreboard_valid_ready_mbx = new();
    m_monitor2scoreboard_avail_valid_mbx = new();
    m_driver2scoreboard_mbx = new();
    
    generator = new(m_generator2driver_valid_ready_mbx, 
                    m_generator2driver_avail_valid_mbx, 
                    generator_done);
    driver = new(valid_ready_vif, avail_valid_vif, clk_vif,
                 m_generator2driver_valid_ready_mbx, 
                 m_generator2driver_avail_valid_mbx, 
                 m_driver2scoreboard_mbx);
    monitor = new(valid_ready_vif, avail_valid_vif, clk_vif,
                  m_monitor2scoreboard_valid_ready_mbx,
                  m_monitor2scoreboard_avail_valid_mbx
                 );
    scoreboard = new(m_monitor2scoreboard_valid_ready_mbx, 
                     m_monitor2scoreboard_avail_valid_mbx, 
                     m_driver2scoreboard_mbx);
  endfunction
  
  virtual task pre_test();
    driver.reset();
  endtask
  
  virtual task post_test();
    wait(generator_done.triggered);
    wait(generator.numberof_valid_transactions == driver.numberof_valid_transactions);
    wait(generator.numberof_valid_transactions == scoreboard.numberof_transactions_processed);   
  endtask
  
  virtual task test();   
    // Run the different components of the environment in different processes
    // The processes are running forever, except the generator that must
    // finish at some point, and the join_any will force the other processes
    // to finish as well 
    fork
      driver.run();
      generator.run();
      monitor.run();      
      scoreboard.run();
    join_any
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

