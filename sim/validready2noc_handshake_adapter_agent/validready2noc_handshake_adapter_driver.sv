// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file validready2noc_handshake_adapter_driver.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Driver for validready2noc_handshake_adapter Testbench
//
//
//Drive transactions from the generator to the DUV through DUV interfaces
//
class validready2noc_handshake_adapter_driver #(
  int VirtualChannelIdWidth   = 0,
  int NumberOfVirtualChannels = 0
);

  // Total transaction processed
  int numberof_processed_transactions = 0;
  
  // From the total transactions, how many
  // satisfy valid == 1
  int numberof_valid_transactions = 0;

  // This interface is to drive DUV synchronously,
  // since DUV it is combinational.
  ///
  virtual clk_mockup_if clk_vif;
  
  virtual valid_ready_if #(
    .VirtualChannelIdWidth(VirtualChannelIdWidth)
  ) valid_ready_vif;  
  
  virtual avail_valid_if #(
    .NumberOfVirtualChannels(NumberOfVirtualChannels)
  ) avail_valid_vif;   

  // Mailboxes to receive transaction items from
  // the generator
  mailbox m_valid_ready_mbx;
  mailbox m_avail_valid_mbx;
  
  // Mailbox to send the reference model for checking
  // to the scoreboard
  mailbox m_scoreboard_mbx;

  function new(virtual valid_ready_if #(
                 .VirtualChannelIdWidth(VirtualChannelIdWidth)
               ) valid_ready_vif, 
               virtual avail_valid_if #(
                 .NumberOfVirtualChannels(NumberOfVirtualChannels)
               ) avail_valid_vif,
               virtual clk_mockup_if clk_vif,
               mailbox valid_ready_mbx,
               mailbox avail_valid_mbx,
               mailbox scoreboard_mbx
  );
    this.valid_ready_vif = valid_ready_vif;
    this.avail_valid_vif = avail_valid_vif;
    this.clk_vif = clk_vif;
    m_valid_ready_mbx = valid_ready_mbx;
    m_avail_valid_mbx = avail_valid_mbx;
    m_scoreboard_mbx = scoreboard_mbx;
  endfunction

  // Reset the interface signals
  task reset();
    wait(clk_vif.rst);
    $display("[T=%0t] [Driver] Reset started...", $time);
     
    avail_valid_vif.driver.avail <= {NumberOfVirtualChannels{1'b1}};
          
    valid_ready_vif.driver.valid <= 0;
    valid_ready_vif.driver.virtual_channel_id <= 0;
    
    wait(!clk_vif.rst);
    $display("[T=%0t] [Driver] Reset completed...", $time);    
  endtask

  task run();
    fork
      valid_ready_if_driver();
      avail_valid_if_driver();
    join_none
  endtask
  
  task avail_valid_if_driver();
    int transaction_id = 0;
    forever begin
      avail_valid_item #(
        .NumberOfVirtualChannels(NumberOfVirtualChannels)   
      ) avail_valid_item;
      
      m_avail_valid_mbx.get(avail_valid_item);          
      
      // drive interface      
      @(posedge clk_vif.clk);
      avail_valid_vif.driver.avail <= avail_valid_item.avail;
      
      $display("[T=%0t] [Driver] Received and driven Transaction %0d for avail_valid_if: avail=%b;", 
               $time, ++transaction_id, avail_valid_item.avail);                                       
    end
  endtask
  
  task valid_ready_if_driver();
  
    // Let's start to drive the interface when it is ready
    wait(valid_ready_vif.driver.ready == 1);
          
    forever begin
      valid_ready_item #(
        .VirtualChannelIdWidth(VirtualChannelIdWidth),
        .NumberOfVirtualChannels(NumberOfVirtualChannels)            
      ) item;
      
      bit handshake_completed;
      
      m_valid_ready_mbx.get(item);            
    
      @(posedge clk_vif.clk);
      
      $display("[T=%0t] [Driver] Received Transaction %0d for valid_ready_if. valid=%b; virtual_channel=%x;", 
               $time, numberof_processed_transactions+1, 
               item.valid, item.virtual_channel_id);        
      
      handshake_completed = valid_ready_vif.driver.ready & valid_ready_vif.driver.valid;
      if (handshake_completed) begin
        valid_ready_vif.valid <= item.valid;
        valid_ready_vif.virtual_channel_id <= item.virtual_channel_id;
        $display("[T=%0t] [Driver] Transaction %0d for valid_ready_if driven. handshake_completed 1", 
                 $time, numberof_processed_transactions+1);          
      end else if (valid_ready_vif.driver.valid == 0) begin
        valid_ready_vif.valid <= item.valid;
        valid_ready_vif.virtual_channel_id <= item.virtual_channel_id;
        $display("[T=%0t] [Driver] Transaction %0d for valid_ready_if driven. no_onfly_transaction", 
                 $time, numberof_processed_transactions+1);           
      end else begin
        $display("[T=%0t] [Driver] Transaction %0d for valid_ready_if rescheduled. handshake_completed=0 && valid_ready_if.valid=1",
                 $time, numberof_processed_transactions+1);     
        wait((valid_ready_vif.driver.valid == 1) && (valid_ready_vif.driver.ready == 1));
        @(posedge clk_vif.clk);
        valid_ready_vif.valid <= item.valid;
        valid_ready_vif.virtual_channel_id <= item.virtual_channel_id;   
        $display("[T=%0t] [Driver] Transaction %0d for valid_ready_if driven. handshake_complete 2", 
                 $time, numberof_processed_transactions+1);                 
      end
      
      if (item.valid == 1) begin
        m_scoreboard_mbx.put(item);      
        numberof_valid_transactions++;
      end
                   
      numberof_processed_transactions++;
    end  // forever
  endtask
endclass

