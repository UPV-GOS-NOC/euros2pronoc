// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_config_filereg_access_generator.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 23th, 2024
//
// @title Network Configuration FileReg and AXIS transactions Generator
//
// It generates configuration filereg transactions that are encapsulated
// into AXIS transactions for the driver
//
// This generator uses the AXI-Stream manager VIP core
// to handle the AXI-Stream transactions.
// For such purpose, the AXI-Stream VIP core has been generated
// using Vivado 2022.2. Their name is:
//  - axi4stream_vip_m
//
// This approach constraint the verification environment of the
// DUV to simulators that are able to work with Vivado libraries

class noc_config_filereg_access_generator;
  
  // AXI-Stream Manager VIP agents
  // Given by AXI VIP Vivado IP Core
  axi4stream_vip_m_mst_t m_axis_manager_agent;

  // Mailboxes for IPC between the generator and the driver
  mailbox m_axis_transaction_driver_mbx;
  
  int control_and_status_virtual_network = 0;

  // Total number of config_filreg_accesses to generate
  int total_config_filereg_accesses = 10;

  int test_read = 0;

  // Event to signal transaction completion
  event done;

  function new(ref axi4stream_vip_m_mst_t axis_manager,
               ref mailbox axis_transaction_generator2driver_mbx,
               input int control_and_status_virtural_network,
               input event generator_done);
    m_axis_manager_agent = axis_manager;
    m_axis_transaction_driver_mbx = axis_transaction_generator2driver_mbx;
    done = generator_done;

    this.control_and_status_virtual_network = control_and_status_virtual_network;
  endfunction

  // Generates AXI-Stream Manager transactions.
  // Using a 32-bit TDATA port, each configuration
  // message requires two transfers to complete, which
  // means that the second transfer must assert TLAST signal
  // It uses the AXI-Stream Manager VIP core to generate AXIS
  // transactions.
  task generate_transactions();
    logic [7:0] data[0:3]; 
    for(int i = 0; i < total_config_filereg_accesses; i++) begin
      // Generates and randomize an AXIS transaction, which could have TVALID
      // set to zero to add some noise during transfers
      // The second transaction is initialized as a clone of the first one to
      // keep the possible noise. Only TDATA and TLAST fields must be modified in second
      // AXIS transaction
      axi4stream_transaction item_2;
      axi4stream_transaction item_1 = m_axis_manager_agent.driver.create_transaction("axis_manager_data_transaction");
      request_filereg_item_t cfg_transaction = new();
      WR_TRANSACTION_FAIL: assert(item_1.randomize());
      assert(cfg_transaction.randomize());
      
      // TID must be the control_and_status_virtual_network
      item_1.set_id(control_and_status_virtual_network);
      item_1.set_dest(cfg_transaction.get_destination());

      item_2 = item_1.my_clone();

      // Second transfer must assert TLAST
      item_2.set_last(1);

      // In order to transfer the configuration message, the first AXIS transfer
      // must carry the MSB word of the two 32-bit words of the message.
      // The second AXIS transfer must carry the LSB word of the two 32-bit
      // words message
      cfg_transaction.get_data_message_word(1, data);
      item_1.set_data(data);
      cfg_transaction.get_data_message_word(0, data);
      item_2.set_data(data);

      // Send the two AXIS transactions that encapsulate a configuration
      // filereg access to the driver
      m_axis_transaction_driver_mbx.put(item_1);
      m_axis_transaction_driver_mbx.put(item_2);
    end
    $display("[T=%0t] [Generator] Generated %0d Config FileReg Access transactions (%0d AXI transfers)", 
             $time, 
             total_config_filereg_accesses,
             total_config_filereg_accesses * 2);
    -> done;
  endtask
  
  task generate_direct_transactions();
    logic [7:0] data[0:3];

    // Write phase
    for(int i = 1; i < 8; i++) begin
      for (int j = 1; j < 16; j++) begin
        axi4stream_transaction item_2;
        axi4stream_transaction item_1 = m_axis_manager_agent.driver.create_transaction("axis_manager_data_transaction");
        request_filereg_item_t cfg_transaction = new();
        WR_TRANSACTION_FAIL: assert(item_1.randomize());
      
        cfg_transaction.module_address = i;
        cfg_transaction.command = 1;
        cfg_transaction.register_address = j;
        cfg_transaction.value = j;
      
        // TID must be the control_and_status_virtual_network
        item_1.set_id(control_and_status_virtual_network);
        item_1.set_dest(cfg_transaction.module_address);
        
        item_2 = item_1.my_clone();

        // Second transfer must assert TLAST
        item_2.set_last(1);

        cfg_transaction.get_data_message_word(1, data);
        item_1.set_data(data);
        cfg_transaction.get_data_message_word(0, data);
        item_2.set_data(data);

        // Send the two AXIS transactions that encapsulate a configuration
        // filereg access to the driver
        m_axis_transaction_driver_mbx.put(item_1);
        m_axis_transaction_driver_mbx.put(item_2);
      end
    end
    
    // Read phase
    for(int i = 1; i < 8; i++) begin
      for (int j = 1; j < 16; j++) begin
        axi4stream_transaction item_2;
        axi4stream_transaction item_1 = m_axis_manager_agent.driver.create_transaction("axis_manager_data_transaction");
        request_filereg_item_t cfg_transaction = new();
        WR_TRANSACTION_FAIL: assert(item_1.randomize());
      
        cfg_transaction.module_address = i;
        cfg_transaction.command = 0;
        cfg_transaction.register_address = j;
        cfg_transaction.value = 0;
      
        // TID must be the control_and_status_virtual_network
        item_1.set_id(control_and_status_virtual_network);
        item_1.set_dest(cfg_transaction.module_address);
        
        item_2 = item_1.my_clone();

        // Second transfer must assert TLAST
        item_2.set_last(1);

        cfg_transaction.get_data_message_word(1, data);
        item_1.set_data(data);
        cfg_transaction.get_data_message_word(0, data);
        item_2.set_data(data);

        // Send the two AXIS transactions that encapsulate a configuration
        // filereg access to the driver
        m_axis_transaction_driver_mbx.put(item_1);
        m_axis_transaction_driver_mbx.put(item_2);
      end
    end    
    
    total_config_filereg_accesses = 7 * 15 * 2;
    $display("[T=%0t] [Generator] Generated %0d Config FileReg Access transactions (%0d AXI transfers)", 
             $time, 
             total_config_filereg_accesses,
             total_config_filereg_accesses * 2);
    -> done;
  endtask  
  
  task run();
    if (test_read == 1) begin
      fork
        generate_direct_transactions();
      join_none    
    end else begin
      fork
        generate_transactions();
      join_none
    end
  endtask  
  
endclass

