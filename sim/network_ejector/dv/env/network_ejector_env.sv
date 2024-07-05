// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_ejector_env.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network ejector environment
//
class network_ejector_env #(
  int FlitWidth               = 0,
  int FlitTypeWidth           = 0,
  int BroadcastWidth          = 0,
  int VirtualNetworkIdWidth   = 0,
  int NumberOfVirtualNetworks = 0 
);

  localparam int DataWidth = FlitWidth +
                             FlitTypeWidth +
                             BroadcastWidth +
                             VirtualNetworkIdWidth;
  
  network_flit_generator #(
    .FlitWidth                        (FlitWidth),
    .FlitTypeWidth                    (FlitTypeWidth),
    .BroadcastWidth                   (BroadcastWidth),
    .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
    .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)    
  ) generator;

  network_ejector_driver #(
    .FlitWidth              (FlitWidth),
    .FlitTypeWidth          (FlitTypeWidth),
    .BroadcastWidth         (BroadcastWidth),
    .VirtualNetworkIdWidth  (VirtualNetworkIdWidth),
    .NumberOfVirtualNetworks(NumberOfVirtualNetworks)  
  ) driver;
  
  network_ejector_monitor #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth),
    .NumberOfVirtualNetworks(NumberOfVirtualNetworks)
  ) monitor;
  
  network_ejector_scoreboard #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth),
    .NumberOfVirtualNetworks(NumberOfVirtualNetworks)  
  ) scoreboard;
  
  virtual valid_ready_data_if #(
    .DataWidth(DataWidth)
  ) data_vif;  
   
  virtual network_if #(
    .FlitWidth                        (FlitWidth),
    .FlitTypeWidth                    (FlitTypeWidth),
    .BroadcastWidth                   (BroadcastWidth),
    .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
    .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)
  ) network_vif;      
  
  mailbox m_flit_mbx;
  mailbox m_data_mbx;
  mailbox m_monitor_flit_mbx;
  mailbox m_monitor_data_mbx;
  mailbox m_driver2scoreboard_mbx;
  
  event generator_done;

  function new(virtual network_if #(
                   .FlitWidth                        (FlitWidth),
                   .FlitTypeWidth                    (FlitTypeWidth),
                   .BroadcastWidth                   (BroadcastWidth),
                   .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
                   .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)
               ) network_vif, 
               virtual valid_ready_data_if #(
                   .DataWidth(DataWidth)
               ) data_vif
  );
    // Get inteface from test
    this.network_vif = network_vif;
    this.data_vif = data_vif;
    
    // Mailbox handler to be shared between generator and driver
    m_flit_mbx = new();
    m_data_mbx = new();
    m_monitor_flit_mbx = new();
    m_monitor_data_mbx = new();
    m_driver2scoreboard_mbx = new();
    
    generator = new(m_flit_mbx, m_data_mbx, generator_done);
    driver = new(this.network_vif, this.data_vif, m_flit_mbx, m_data_mbx, m_driver2scoreboard_mbx);
    monitor = new(this.network_vif, this.data_vif, m_monitor_flit_mbx, m_monitor_data_mbx);
    scoreboard = new(m_monitor_flit_mbx, m_monitor_data_mbx, m_driver2scoreboard_mbx);
  endfunction
  
  virtual task pre_test();
    driver.reset();
  endtask
  
  virtual task post_test();
    wait(generator_done.triggered);
    wait(generator.numberof_network_valid_transactions == driver.numberof_valid_network_transactions);
    wait(generator.numberof_network_valid_transactions == scoreboard.numberof_transactions_processed);
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

