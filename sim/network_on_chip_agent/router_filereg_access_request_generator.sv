// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file router_filereg_access_request_generator.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 29th, 2024 (Adapt for powerful testbench)
//
// @title Router FileReg Access Request Generator
//
// Generates filereg access requests and transform them
// into AXI-Stream transactions for the driver
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

class router_filereg_access_request_generator extends network_on_chip_generator;

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
    super.new(m_axis_agent, s_axis_agent, 
          generator2driver_mbx, 
          driver2generator,
          generator_done, 
          total_messages,
          ready_policy,
          control_and_status_virtual_network,
          tile_types,
          id);
  endfunction

  // Generates AXI-Stream Manager transactions
  // using the AXI-Stream Manager VIP.
  virtual task m_axis_generator();
    logic [7:0] data[3:0];
    bit [31:0] xy_lookup_table[] = {
      32'b001111000101, //0
      32'b001111000111, //1
      32'b001111000111, //2
      32'b001111000011, //3
      32'b001111001100, //4
      32'b001111001110, //5
      32'b001111001110, //6
      32'b001111001010  //7
    };

    bit [31:0] yx_lookup_table[] = {
      32'b110000110101, //0
      32'b110000110111, //1
      32'b110000110111, //2
      32'b110000110011, //3
      32'b110000111100, //4
      32'b110000111110, //5
      32'b110000111110, //6
      32'b110000111010  //7
    };

    // At this simulation time starts reconfiguration
    // So before that point the network must be flushed,
    // Perhaps it could be generated a network reset
    # 55000;
    
    if (verbosity != 0) begin
      $display("[T=%0t] [Generator Tile %0d] Start generating transactions for routing algorithm reconfiguration", $time, id);
    end

    // Renconfigure VN2 and VN3 to YX
    for(int i = 1; i < 8; i++) begin : loop_i
      for (int j = 1; j < 4; j++) begin : loop_j
        axi4stream_transaction item_2;
        axi4stream_transaction item_1 = m_axis_agent.driver.create_transaction("axis_manager_config_transaction");
        request_filereg_item_t cfg_transaction = new();
        //WR_TRANSACTION_FAIL: assert(item_1.randomize());
      
        cfg_transaction.module_address = i;
        cfg_transaction.command = 1;
        cfg_transaction.register_address = j;
        cfg_transaction.value = yx_lookup_table[i];
      
        // TID must be the control_and_status_virtual_network
        item_1.set_id(control_and_status_virtual_network);
        item_1.set_dest(cfg_transaction.module_address);
        item_1.set_last(0);
        
        item_2 = item_1.my_clone();

        // Second transfer must assert TLAST
        item_2.set_last(1);

        cfg_transaction.get_data_message_word(1, data);
        item_1.set_data(data);
        cfg_transaction.get_data_message_word(0, data);
        item_2.set_data(data);

        // Send the two AXIS transactions that encapsulate a configuration
        // filereg access to the driver
        generator2driver_mbx.put(item_1);
        generator2driver_mbx.put(item_2);

        
        numberof_m_axis_transactions_generated += 2;
        numberof_m_axis_frames_generated++;

        @(driver2generator);
        @(driver2generator);
      end : loop_j
    end : loop_i

    if (verbosity != 0) begin
      $display("[T=%0t] [Generator Tile %0d] Finish generating transactions for routing algorithm reconfiguration", $time, id);
    end

    -> done;
  endtask
  
endclass

