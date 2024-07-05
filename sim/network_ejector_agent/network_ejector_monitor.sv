// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_ejector_monitor.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network Ejector monitor
//
// It monitores the network and valid_ready interfaces
// to generate transaction items for the scoreboard
class network_ejector_monitor #(
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

  function new(virtual network_if #(
                   .FlitWidth                        (FlitWidth),
                   .FlitTypeWidth                    (FlitTypeWidth),
                   .BroadcastWidth                   (BroadcastWidth),
                   .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
                   .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)
               ) network_vif, 
               virtual valid_ready_data_if #(
                   .DataWidth(DataWidth)
               ) data_vif,
               mailbox flit_mbx,
               mailbox data_mbx
  );
    this.network_vif = network_vif;
    this.data_vif = data_vif;
    m_flit_mbx = flit_mbx;
    m_data_mbx = data_mbx;
  endfunction

  task run();
    fork
      network_if_monitor();
      data_if_monitor();
    join_none
  endtask
  
  task data_if_monitor();     
    forever begin
      valid_ready_data_item #( 
        .DataWidth(DataWidth)
      ) data = new(); 
                  
      @(posedge data_vif.monitor.clk);                  
      data.valid = data_vif.monitor.monitor_clock_block.valid;
      data.data  = data_vif.monitor.monitor_clock_block.data;        
      data.ready = data_vif.monitor.monitor_clock_block.ready;        
        
      m_data_mbx.put(data);
    end
  endtask
  
  task network_if_monitor();
    forever begin
      network_flit_item #(
        .FlitWidth                        (FlitWidth),
        .FlitTypeWidth                    (FlitTypeWidth),
        .BroadcastWidth                   (BroadcastWidth),
        .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
        .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)        
      ) flit_item = new();
      
      @(posedge network_vif.monitor.clk);      
        
      flit_item.valid = network_vif.monitor.monitor_clock_block.valid;
      flit_item.ready = network_vif.monitor.monitor_clock_block.ready;
      flit_item.flit               = network_vif.monitor.monitor_clock_block.flit;
      flit_item.flit_type          = network_vif.monitor.monitor_clock_block.flit_type;
      flit_item.broadcast          = network_vif.monitor.monitor_clock_block.broadcast;
      flit_item.virtual_identifier = network_vif.monitor.monitor_clock_block.virtual_identifier;                  
      
      //flit_item.display("Monitor");  
      m_flit_mbx.put(flit_item);
            
    end
  endtask  

endclass
