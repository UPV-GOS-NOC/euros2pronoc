// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_flit_item.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network flit transaction items generator
//
// Generates random network flits and control signals
// for the driver. The test could
// decide to overwrite control signals for checking adhoc
// non-random scenarios
class network_flit_generator #(
  int FlitWidth                         = 0,
  int FlitTypeWidth                     = 0,
  int BroadcastWidth                    = 0,
  int VirtualNetworkOrChannelIdWidth    = 0,
  int NumberOfVirtualNetworksOrChannels = 0 
);

  parameter int DataWidth = FlitWidth +
                            FlitTypeWidth +
                            BroadcastWidth +
                            VirtualNetworkOrChannelIdWidth;

  int total_transactions = 10;
  int numberof_network_valid_transactions = 0;

  // TODO how to generalize for parameters
  //flit_mailbox_t m_flit_mbox;
  mailbox m_flit_mbox;
  mailbox m_data_mbox;
  
  // Event to signal the completion of the process
  event generator_done;
  
  // Constructor
  function new(mailbox flit_mbox, mailbox data_mbox, event done);
    m_flit_mbox = flit_mbox;
    m_data_mbox = data_mbox;
    
    generator_done = done;
  endfunction

  // Main task. Creates and randomizes transaction items for the driver
  task run();
    fork
      run_data_if_generator();
      run_network_if_generator();
    join_none
  endtask
  
  task run_data_if_generator();
    forever begin
       valid_ready_data_item #(
        .DataWidth(DataWidth)
      ) data = new;
      
      assert(data.randomize());
      #10 m_data_mbox.put(data);
    end
  endtask
  
  task run_network_if_generator();
    // last transction must be not valid to avoid valid signal remains 1 forever
    network_flit_item #( 
      .FlitWidth                        (FlitWidth),
      .FlitTypeWidth                    (FlitTypeWidth),
      .BroadcastWidth                   (BroadcastWidth),
      .VirtualNetworkOrChannelIdWidth   (VirtualNetworkOrChannelIdWidth),
      .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworksOrChannels)  
    ) flit_last = new;      
    assert(flit_last.randomize());   
    flit_last.valid = 0;
  
    for (int i = 0; i < total_transactions-1; i++) begin
      network_flit_item #( 
        .FlitWidth                        (FlitWidth),
        .FlitTypeWidth                    (FlitTypeWidth),
        .BroadcastWidth                   (BroadcastWidth),
        .VirtualNetworkOrChannelIdWidth   (VirtualNetworkOrChannelIdWidth),
        .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworksOrChannels)  
      ) flit = new;
      
      assert(flit.randomize());
      
      if (flit.valid == 1) begin
        numberof_network_valid_transactions++;
      end
      
      $display("[T=%0t] [Generator] Loop: %0d/%0d create item", $time, i + 1, total_transactions); 
      m_flit_mbox.put(flit);
    end
    
    $display("[T=%0t] [Generator] Loop: %0d/%0d create item", $time, total_transactions, total_transactions); 
    m_flit_mbox.put(flit_last);    
    
    $display("[T=%0t] [Generator] Done generation for %0d items; valid_flit_items=%0d", 
             $time, total_transactions, numberof_network_valid_transactions);
    -> generator_done;  
  endtask
endclass

