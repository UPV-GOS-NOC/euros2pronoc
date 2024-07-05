// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file validready2noc_handshake_adapter_monitor.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Monitor for validready2noc_handshake_adapter Testbench
//
// It monitors the valid/Ready and Avail/Valid interfaces
// and pass transaction items to the scoreboard
//
//
class validready2noc_handshake_adapter_monitor #(
  int VirtualChannelIdWidth   = 0,
  int NumberOfVirtualChannels = 0 
);

  // This interface is to monitor DUV synchronously,
  // since DUV it is combinational.
  virtual clk_mockup_if clk_vif;
  
  virtual valid_ready_if #(
    .VirtualChannelIdWidth(VirtualChannelIdWidth)
  ) valid_ready_vif;  
  
  virtual avail_valid_if #(
    .NumberOfVirtualChannels(NumberOfVirtualChannels)
  ) avail_valid_vif; 


  // Mailboxes to send the transaction items monitored in the interfaces
  // to the scoreboard
  mailbox m_valid_ready_mbx;
  mailbox m_avail_valid_mbx;

  function new(virtual valid_ready_if #(
                 .VirtualChannelIdWidth(VirtualChannelIdWidth)
               ) valid_ready_vif, 
               virtual avail_valid_if #(
                 .NumberOfVirtualChannels(NumberOfVirtualChannels)
               ) avail_valid_vif,
               virtual clk_mockup_if clk_vif,
               mailbox valid_ready_mbx,
               mailbox avail_valid_mbx
  );
    this.valid_ready_vif = valid_ready_vif;
    this.avail_valid_vif = avail_valid_vif;
    this.clk_vif = clk_vif;
    m_valid_ready_mbx = valid_ready_mbx;
    m_avail_valid_mbx = avail_valid_mbx;
  endfunction

  task run();
    fork
      valid_ready_if_monitor();
      avail_valid_if_monitor();
    join_none
  endtask
  
  task valid_ready_if_monitor();     
    forever begin
      valid_ready_item #(
        .VirtualChannelIdWidth(VirtualChannelIdWidth),
        .NumberOfVirtualChannels(NumberOfVirtualChannels)            
      ) item = new();
                  
      @(posedge clk_vif.clk);
                        
      item.valid = valid_ready_vif.monitor.valid;        
      item.ready = valid_ready_vif.monitor.ready;
      item.virtual_channel_id = valid_ready_vif.monitor.virtual_channel_id;        
        
      m_valid_ready_mbx.put(item);
    end
  endtask
  
  task avail_valid_if_monitor();
    forever begin
      avail_valid_item #(
        .NumberOfVirtualChannels(NumberOfVirtualChannels)    
      ) item = new();
      
      @(posedge clk_vif.clk);      
        
      item.valid = avail_valid_vif.monitor.valid;
      item.avail = avail_valid_vif.monitor.avail;                
      
      m_avail_valid_mbx.put(item);    
    end
  endtask  

endclass

