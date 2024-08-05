// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_generator.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 20th, 2024
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
  
  // AXI-Stream Manager and Subordinate VIP agents
  // Given by AXI VIP Vivado IP Core
  axi4stream_vip_m_mst_t m_axis_manager_agent;
  axi4stream_vip_s_slv_t m_axis_subordinate_agent;

  // Mailboxes for IPC between the generator and the driver
  mailbox m_axis_manager_driver_mbx;
  mailbox m_axis_subordinate_driver_mbx;
  
  // Total number of transactions to generate
  int total_transactions = 10;

  int numberof_m_axis_transactions_generated = 0;
  int numberof_m_axis_frames_generated = 0;

  // Event to signal transaction completion
  event done;

  function new(axi4stream_vip_m_mst_t axis_manager,
               axi4stream_vip_s_slv_t axis_subordinate,
               mailbox axis_manager_generator2driver_mbx,
               mailbox axis_subordinate_generator2driver_mbx,
               event generator_done);
    m_axis_manager_agent = axis_manager;
    m_axis_subordinate_agent = axis_subordinate;
    m_axis_manager_driver_mbx = axis_manager_generator2driver_mbx;
    m_axis_subordinate_driver_mbx = axis_subordinate_generator2driver_mbx;
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
      if ((next_transfer_belong_to_same_axiframe == 0)/* && (item.get_last() == 0)*/) begin
        next_transfer_belong_to_same_axiframe = 1;
        tid_axiframe = item.get_id();
        tdest_axiframe = 0;
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

      numberof_m_axis_transactions_generated++;
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
    axi4stream_ready_gen item = m_axis_subordinate_agent.driver.create_ready("axis_subordinate_ready_gen_transaction");
    item.set_ready_policy(XIL_AXI4STREAM_READY_GEN_NO_BACKPRESSURE); //XIL_AXI4STREAM_READY_GEN_RANDOM); 
    m_axis_subordinate_driver_mbx.put(item);
  endtask
  
  task run();
    fork
      axis_manager_generator();
      axis_subordinate_generator();
    join_none
  endtask  
  
endclass

