// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_generator.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 20th, 2024 (create)
// @date July 29th, 2024 (Adapt for powerful testbench)
//
// @title Network-on-Chip Generator
//
// Generates M_AXIS/S_AXIS transactions for the driver.
//
// This generator uses the AXI-Stream VIP manager and subordinate
// agents to handle the AXI-Stream transactions and interfaces.
// For such purpose, two AXI-Stream VIP core has been generated
// using Vivado 2022.2. Their names are:
//  - axi4stream_vip_m
//  - axi4stream_vip_s
//
// This approach constraint the verification environment of the
// Network-on-Chip DUV to simulators that are able to
// work with Vivado libraries

class network_on_chip_generator;
  int id = 0;
  
  // AXI-Stream Manager and Subordinate VIP agents
  // Given by AXI VIP Vivado IP Core
  axi4stream_vip_m_mst_t m_axis_agent;
  axi4stream_vip_s_slv_t s_axis_agent;

  // Mailbox for IPC between the generator and the driver
  mailbox generator2driver_mbx;
  
  // Total number of messages to generate
  // it will be converted into transfers
  int total_messages = 0;
  
  // Policy for the S_AXIS_VIP
  protected int ready_policy = 0;
  
  // For Router filereg access
  protected int control_and_status_virtual_network = 0;
  
  protected bit tile_types[];

  int numberof_m_axis_transactions_generated = 0;
  int numberof_m_axis_frames_generated = 0;

  // Event to detect driver done for current transaction
  event driver2generator;

  // Event to notify the environment when the total number
  // of messages has been generated and given to the driver
  event done;

  protected int verbosity = 0;

  function new(input axi4stream_vip_m_mst_t m_axis_agent,
               input axi4stream_vip_s_slv_t s_axis_agent,
               input mailbox generator2driver_mbx,
               input event driver2generator,
               input event generator_done,
               input int total_messages,
               input int ready_policy,
               input int control_and_status_virtual_network,
               input bit tile_types[],
               input int id);
    this.m_axis_agent = m_axis_agent;
    this.s_axis_agent = s_axis_agent;
    this.generator2driver_mbx = generator2driver_mbx;
    this.driver2generator = driver2generator;
    this.done = generator_done;
    this.total_messages = total_messages;
    this.ready_policy = ready_policy;
    this.control_and_status_virtual_network = control_and_status_virtual_network;
    this.id = id;
    this.tile_types = new[tile_types.size()];
    foreach(tile_types[i]) this.tile_types[i] = tile_types[i];
  endfunction
  
  //
  // Setters and getters
  //
  virtual function void set_verbosity(int verbosity);
    this.verbosity = verbosity;
  endfunction
  
  function int get_id();
    return id;
  endfunction  

  //
  // Run and test
  //

  // Generates AXI-Stream Manager transactions
  // using the AXI-Stream Manager VIP.
  virtual task m_axis_generator();
    logic [7:0] data[4];
    int tid_axiframe = 0;
    int tdest_axiframe = 0;
    int next_transfer_belong_to_same_axiframe = 0;
    int vn = 0;
    int counter_data = 0;
    
    if (verbosity > 100) begin
      $display("[T=%0t] [Generator Tile %0d]  %0d AXI-Stream Manager transactions (AXI transfers) to generate", 
               $time, id, total_messages);
    end    
    
    for(int i = 0; i < total_messages; i++) begin : loop
      axi4stream_transaction item = m_axis_agent.driver.create_transaction("axis_manager_data_transaction"); 
      
      // Some hacks to the current transfer since it is required a continuous stream,
      // which means that the TID/TDEST must be kept until TLAST is asserted 
      if ((next_transfer_belong_to_same_axiframe == 0)) begin : first_transfer_of_frame
        next_transfer_belong_to_same_axiframe = 1;

        // Transfer cannot be for the same tile, use the control and status virtual network and
        // addressed to a other Manager tile
        do begin
          WR_TRANSACTION_FAIL: assert(item.randomize());
          // hack: going to the same destination through the different VN is not allowed
          item.set_id(1);
          vn = item.get_id() % 4;
        end while ((item.get_dest() == id) || (vn == control_and_status_virtual_network) || (tile_types[item.get_dest()] == 0));
        
        tdest_axiframe = item.get_dest();
        tid_axiframe = item.get_id();
      end : first_transfer_of_frame
      
      item.set_data({counter_data[7:0], counter_data[15:8], counter_data[23:16], counter_data[31:24]});
      counter_data++;
      
      if ((item.get_last() == 0) && (i == total_messages - 1)) begin
        // last transaction to drive. Set tlast
        item.set_last(1);
      end      
      
      if ((item.get_last() == 0) || 
         ((next_transfer_belong_to_same_axiframe == 1) && (item.get_last() == 1))) begin : middle_transfer_of_frame
        item.set_dest(tdest_axiframe);
        item.set_id(tid_axiframe);
      end : middle_transfer_of_frame
      
      if (item.get_last() == 1) begin : last_transfer_of_frame
        next_transfer_belong_to_same_axiframe = 0;
        numberof_m_axis_frames_generated++;
      end : last_transfer_of_frame
      
      numberof_m_axis_transactions_generated++;      
      
      if (verbosity != 0) begin
        item.get_data(data);
        $display("[T=%0t] [Generator Tile %0d] AXI-Stream Manager transaction %0d/%0d generated for driver. tid=%0d, tdest=%0d, tlast=%b, tdata=%0x",
                 $time, id,
                 numberof_m_axis_transactions_generated,
                 total_messages,
                 item.get_id(),
                 item.get_dest(),
                 item.get_last(),
                 {data[3], data[2], data[1], data[0]}
                 );
      end
      
      generator2driver_mbx.put(item);            
      @(driver2generator);
    end : loop
    
    if (verbosity > 100) begin
      $display("[T=%0t] [Generator Tile %0d] DONE!!!!  %0d AXI-Stream Manager transactions (AXI transfers) and %0d AXI frames", 
               $time, id,
               numberof_m_axis_transactions_generated,
               numberof_m_axis_frames_generated);
    end
             
    -> done;
  endtask
  
  // Generates AXI-Stream Subordinate transactions
  // using the AXI-Stream Subordinate VIP
  virtual task s_axis_generator(); 
    axi4stream_ready_gen item = s_axis_agent.driver.create_ready("s_axis_ready_gen_transaction");
    xil_axi4stream_ready_gen_policy_t rp;
    $cast(rp, ready_policy);
    item.set_ready_policy(rp); 
    s_axis_agent.driver.send_tready(item);
  endtask
  
  virtual task run();
    fork
      m_axis_generator();
      s_axis_generator();
    join_none
  endtask  
  
endclass

