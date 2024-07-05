// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file validready2noc_handshake_adapter_generator.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Transaction items generator for 
//        validready2noc_handshake_adapter Testbench
//
// Generates both valid_ready_item and avail_valid_item transactions.
// The test could decide to overwrite control signals for checking adhoc
// non-random scenarios
//
class validready2noc_handshake_adapter_generator #(
  int VirtualChannelIdWidth    = 0,
  int NumberOfVirtualChannels = 0 
);

  int total_transactions = 10;
  
  // Keeps the number of transaction generated
  // with valid = 1
  int numberof_valid_transactions = 0;

  // Mailboxes to send transaction to the driver
  mailbox m_valid_ready_mbox;
  mailbox m_avail_valid_mbox;
  
  // Event to signal the completion of the process
  event generator_done;
  
  // Constructor
  function new(mailbox valid_ready_mbox, mailbox avail_valid_mbox, event done);
    m_valid_ready_mbox = valid_ready_mbox;
    m_avail_valid_mbox = avail_valid_mbox;
    
    generator_done = done;
  endfunction

  // Main task. Creates and randomizes transaction items for the driver
  task run();
    fork
      run_valid_ready_if_generator();
      run_avail_valid_if_generator();
    join_none
  endtask
  
  task run_avail_valid_if_generator();
    forever begin
       avail_valid_item #(
        .NumberOfVirtualChannels(NumberOfVirtualChannels)
      ) avail_valid = new;
      
      assert(avail_valid.randomize());
      #10 m_avail_valid_mbox.put(avail_valid);
    end
  endtask
  
  task run_valid_ready_if_generator();
    // last transction must not be valid to avoid valid signal remains 1 forever,
    // although here there would not be any problem with it.
    valid_ready_item #( 
      .VirtualChannelIdWidth  (VirtualChannelIdWidth),
      .NumberOfVirtualChannels(NumberOfVirtualChannels)
    ) valid_ready_last = new;      
    assert(valid_ready_last.randomize());   
    valid_ready_last.valid = 0;
  
    for (int i = 0; i < total_transactions-1; i++) begin
      valid_ready_item #( 
        .VirtualChannelIdWidth  (VirtualChannelIdWidth),
        .NumberOfVirtualChannels(NumberOfVirtualChannels)
      ) valid_ready = new; 
      
      assert(valid_ready.randomize());
      
      if (valid_ready.valid == 1) begin
        numberof_valid_transactions++;
      end
      
      $display("[T=%0t] [Generator] Loop: %0d/%0d create valid_ready_item", $time, i + 1, total_transactions); 
      m_valid_ready_mbox.put(valid_ready);
    end
    
    $display("[T=%0t] [Generator] Loop: %0d/%0d create valid_ready_item", $time, total_transactions, total_transactions); 
    m_valid_ready_mbox.put(valid_ready_last);    
    
    $display("[T=%0t] [Generator] Done generation for %0d items; Total valid transaction items=%0d", 
             $time, total_transactions, numberof_valid_transactions);
    -> generator_done;  
  endtask
endclass
