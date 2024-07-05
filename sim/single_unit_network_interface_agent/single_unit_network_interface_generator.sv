// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file single_unit_network_interface_generator.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 04th, 2024
//
// @title Single Unit Network Interface (SUNI) Generator
//
// Generates transactions for the driver.
//
// This generator uses the AXI-Stream VIP manager and subordinate
// agents to handle the AXI-Stream transactions and interfaces.
// For such purpose, two AXI-Stream VIP core has been generated
// using Vivado 2022.2. Their names are:
//  - axi4stream_vip_m
//  - axi4stream_vip_s
//
// This approach constraint the verification environment of the
// Single Unit Network Interface to simulators that are able to
// work with Vivado libraries


class single_unit_network_interface_generator;
  
  // AXI-Stream Manager and Subordinate VIP agents
  // Given by AXI VIP Vivado IP Core
  axi4stream_vip_m_mst_t m_axis_manager_agent;
  axi4stream_vip_s_slv_t m_axis_subordinate_agent;

  // Mailboxes for IPC between the generator and the driver
  mailbox m_axis_manager_driver_mbx;
  mailbox m_axis_subordinate_driver_mbx;
  
  // Mailbox to use for notification of the network_ready signal
  // to the driver
  mailbox m_network_if_subordinate_driver_mbx;
  
  // Mailbox for IPC with driver for network flits that would come
  // from the network
  mailbox m_network_if_manager_driver_mbx;

  // Total number of transactions to generate
  int total_transactions = 10;

  int numberof_m_axis_frames_generated = 0;
  int numberof_network_valid_transactions = 0;
  int numberof_network_packet_generated = 0;

  // Set the configuration to test in the NI.
  // AXI-Stream Manager interface (manager_mode != 0)
  // AXI-Stream Subordinate interface (subordinate_mode != 0)
  // They are exclusive
  protected int axis_manager_mode = 0;
  protected int axis_subordinate_mode  = 0;
 

  // Event to signal transaction completion
  event done;

  function new(axi4stream_vip_m_mst_t axis_manager,
               axi4stream_vip_s_slv_t axis_subordinate,
               mailbox axis_manager_generator2driver_mbx,
               mailbox axis_subordinate_generator2driver_mbx,
               mailbox network_if_subordinate_generator2driver_mbx,
               mailbox network_if_manager_generator2driver_mbx,
               event generator_done);
    m_axis_manager_agent = axis_manager;
    m_axis_subordinate_agent = axis_subordinate;
    m_axis_manager_driver_mbx = axis_manager_generator2driver_mbx;
    m_axis_subordinate_driver_mbx = axis_subordinate_generator2driver_mbx;
    m_network_if_subordinate_driver_mbx = network_if_subordinate_generator2driver_mbx;
    m_network_if_manager_driver_mbx = network_if_manager_generator2driver_mbx;
    done = generator_done;
  endfunction

  // Generates AXI-Stream Manager transactions
  // using the AXI-Stream Manager VIP.
  task axis_manager_generator();
    int tid_axiframe = 0;
    int tdest_axiframe = 0;
    int next_transfer_belong_to_same_axiframe = 0;
    for(int i = 0; i < total_transactions; i++) begin
      axi4stream_transaction item = m_axis_manager_agent.driver.create_transaction("axis_manager_data_transaction"); 
      WR_TRANSACTION_FAIL: assert(item.randomize());
      if ((next_transfer_belong_to_same_axiframe == 0) && (item.get_last() == 0)) begin
        next_transfer_belong_to_same_axiframe = 1;
        tid_axiframe = item.get_id();
        tdest_axiframe = item.get_dest();
      end 
      
      if ((item.get_last() == 0) || 
         ((next_transfer_belong_to_same_axiframe == 1) && (item.get_last() == 1))) begin
        item.set_dest(tdest_axiframe);
        item.set_id(tid_axiframe);
      end
      
      if (item.get_last() == 1) begin
        next_transfer_belong_to_same_axiframe = 0;
      end
      
      m_axis_manager_driver_mbx.put(item);
      if (item.get_last() == 1) begin
        numberof_m_axis_frames_generated++;
      end
    end
    $display("[T=%0t] [Generator] Generated %0d AXI-Stream Manager transactions (AXI transfers) and %0d AXI frames", 
             $time, 
             total_transactions,
             numberof_m_axis_frames_generated);
    -> done;
  endtask
  
  // Generates AXI-Stream Subordinate transactions
  // using the AXI-Stream Subordinate VIP
  task axis_subordinate_generator();
    // First, create the ready transaction with the most random policy 
    // TODO try different policies
    axi4stream_ready_gen item = m_axis_subordinate_agent.driver.create_ready("axis_subordinate_ready_gen_transaction");
    item.set_ready_policy(XIL_AXI4STREAM_READY_GEN_RANDOM); 
    m_axis_subordinate_driver_mbx.put(item);
  endtask
  
  // Generates the network ready signal randomly
  task network_if_subordinate_generator();
    forever begin
      network_flit_item_t item = new();
      assert(item.randomize());
      #10 m_network_if_subordinate_driver_mbx.put(item);
    end
  endtask
  
  // Generates network flits randomly
  task network_if_manager_generator();
    for (int i = 0; i < total_transactions; i++) begin
      network_flit_ejection_item_t item = new();
      network_packet_t packet;

      assert(item.randomize());
      packet = item.generate_network_packet();
      if (item.valid == 1)  begin
        numberof_network_packet_generated++;
      end
         
      do begin
        network_flit_ejection_item_t item_transaction = new();
        item_transaction.valid = item.valid;
        item_transaction.flit = packet.flit.pop_front();
        item_transaction.flit_type = packet.flit_type.pop_front();
        item_transaction.broadcast = packet.broadcast;
        item_transaction.virtual_identifier = packet.virtual_identifier;
        if (item_transaction.valid == 1) begin
          numberof_network_valid_transactions++;
        end
                
        m_network_if_manager_driver_mbx.put(item_transaction);
      end while(packet.flit_type.size() > 0);
    end
    $display("[T=%0t] [Generator] Generated %0d network packets (%0d valid transactions) for the driver", 
             $time, numberof_network_packet_generated, numberof_network_valid_transactions);
    -> done;
  endtask
  
  task run();
    fork
      if (axis_manager_mode) begin
        $display("[T=%0t] [Generator] Configured to generate ASI-Stream Manager (AXI Frames) and Network Subordinate (READY) transactions", $time);      
        axis_manager_generator();
        network_if_subordinate_generator();
      end else if (axis_subordinate_mode) begin
        $display("[T=%0t] [Generator] Configured to generate AXI-Stream subordinate (TREADY) and Network Manager (Flits) transactions", $time);      
        axis_subordinate_generator();
        network_if_manager_generator();
      end
    join_none
  endtask  
  
  task set_axis_manager_mode();
    axis_manager_mode = 1;
    axis_subordinate_mode = 0;
  endtask
  
  task set_axis_subordinate_mode();
    axis_subordinate_mode = 1;
    axis_manager_mode = 0;
  endtask
  
  function int get_axis_manager_mode();
    return axis_manager_mode;
  endfunction
  
  function int get_axis_subordinate_mode();
    return axis_subordinate_mode;
  endfunction  
endclass