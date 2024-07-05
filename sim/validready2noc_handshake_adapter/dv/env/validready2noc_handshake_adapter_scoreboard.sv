// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file validready2noc_handshake_adapter_scoreboard.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Scoreboard for validready2noc_handshake_adapter Testbench
//
// It receives transactions items from the monitor and checks them
// against the reference model to determine whether tests are passed or not
//
//

class validready2noc_handshake_adapter_scoreboard #(
  int VirtualChannelIdWidth   = 0,
  int NumberOfVirtualChannels = 0 
);
     
   int error_valid_ready_if = 0;      
   int error_avail_valid_if = 0;
         
   int numberof_transactions_processed = 0;
   
   // Mailboxes to receive transaction items from the monitor                             
   mailbox m_valid_ready_mbx;
   mailbox m_avail_valid_mbx;
   
   // Mailbox to receive the reference model from the driver
   // to check results against 
   mailbox m_driver_mbx;

  function new(mailbox valid_ready_mbx, mailbox avail_valid_mbx, mailbox driver_mbx);
    m_valid_ready_mbx = valid_ready_mbx;
    m_avail_valid_mbx = avail_valid_mbx;
    m_driver_mbx = driver_mbx;
  endfunction
  
  task avail_valid_if_scoreboard();
    avail_valid_item #(
      .NumberOfVirtualChannels(NumberOfVirtualChannels)    
    ) avail_valid;   
    
    forever begin
      valid_ready_item #(
        .VirtualChannelIdWidth(VirtualChannelIdWidth),
        .NumberOfVirtualChannels(NumberOfVirtualChannels)            
      ) valid_ready;     
      
      m_avail_valid_mbx.get(avail_valid);
      
      if (avail_valid.valid == 1) begin
        m_driver_mbx.get(valid_ready);

        if (avail_valid.avail[valid_ready.virtual_channel_id] == 0) begin
          // error
          $error("[T=%0t] [Scoreboard] Error! NoC handshake violated!!! valid==1 && avail[%x]=0", 
                 $time, valid_ready.virtual_channel_id);
          error_avail_valid_if++;          
        end

        
        numberof_transactions_processed++;
        
        $display("[T=%0t] [Scoreboard] %0d transaction(s) completed in avail_valid_if.", 
                 $time, numberof_transactions_processed);              
      end          
    end
  endtask
  
  task valid_ready_if_scoreboard();
    valid_ready_item #(
      .VirtualChannelIdWidth(VirtualChannelIdWidth),
      .NumberOfVirtualChannels(NumberOfVirtualChannels)            
    ) item; 
    
    bit valid_trace = 1;
    bit handshake_completed = 0;
    bit transfer_onfly = 0;

    forever begin
      // From valid_ready_if monitor
      m_valid_ready_mbx.get(item);  
      
      handshake_completed = (item.valid == 1) && (item.ready == 1);
      transfer_onfly = (item.valid == 1) && (item.ready == 0);
              
      // Once valid is asserted it cannot be deasserted until handshake is completed
      if (handshake_completed) begin
        valid_trace = 1;
      end else if (transfer_onfly) begin
        valid_trace &= item.valid;      
      end

      if (transfer_onfly && (valid_trace == 0)) begin
        $error("[T=%0t] [Scoreboard] Error! Valid/Ready violation! Once valid is asserted, it must keep asserted until handshake completes",
               $time);
        error_valid_ready_if++;
      end
    end // forever      
  endtask
  
  task run();
    fork
      valid_ready_if_scoreboard();
      avail_valid_if_scoreboard();
    join_none
  endtask
endclass

