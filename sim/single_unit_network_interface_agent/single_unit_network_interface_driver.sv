// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file single_unit_network_interface_driver.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 04th, 2024
//
// @title Single Unit Network Interface (SUNI) Driver
//
// Drive transactions from the generator to the
// AXI-Stream Subordinate interface of the SUNI.
//
// This driver uses the AXI-Stream VIP manager and subordinate
// agents to handle the AXI-Stream transactions and interfaces.
// For such purpose, two AXI-Stream VIP cores has been generated
// using Vivado 2022.2. Their names are:
//  - axi4stream_vip_m
//  - axi4stream_vip_s
//
// This approach constraint the verification environment of the
// Single Unit Network Interface to simulators that are able to
// work with Vivado libraries

class single_unit_network_interface_driver #(
);
  
  int numberof_m_axis_frames_transmitted = 0;  
  
  // AXI-Stream Manager and Subordinate VIP agents
  // Given by AXI VIP Vivado IP Core
  axi4stream_vip_m_mst_t m_axis_manager_agent;
  axi4stream_vip_s_slv_t m_axis_subordinate_agent;

  // Mailboxes for IPC between the generator and the driver
  mailbox m_axis_manager_generator_mbx;
  mailbox m_axis_subordinate_generator_mbx;
  
  // Mailbox to use for notification of the network_ready signal
  // to the driver
  mailbox m_network_if_subordinate_generator_mbx;
  
  // Mailbox for IPC with driver for network flits that would come
  // from the network
  mailbox m_network_if_manager_generator_mbx;  
  
  // Mailbox for IPC between driver and scoreboard to send the
  // reference model for the transmit and receiver channels
  mailbox m_network_if_manager_scoreboard_mbx;
  mailbox m_axis_manager_scoreboard_mbx;

  // Network virtual interface
  network_vif_t network_manager_vif;
  network_vif_t network_subordinate_vif;
 
  int network_if_manager_numberof_processed_transactions = 0;
  int network_if_manager_numberof_valid_network_transactions = 0;
  
  int verbosity = 0;

  function new(axi4stream_vip_m_mst_t axis_manager,
               axi4stream_vip_s_slv_t axis_subordinate,
               mailbox axis_manager_generator2driver_mbx,
               mailbox axis_subordinate_generator2driver_mbx,
               mailbox network_if_subordinate_generator2driver_mbx,
               mailbox network_if_manager_generator2driver_mbx,
               mailbox axis_manager_driver2scoreboard_mbx,
               mailbox network_if_manager_driver2scoreboard_mbx,
               network_vif_t network_manager_vif,
               network_vif_t network_subordinate_vif);
    m_axis_manager_agent = axis_manager;
    m_axis_subordinate_agent = axis_subordinate;
    m_axis_manager_generator_mbx = axis_manager_generator2driver_mbx;
    m_axis_subordinate_generator_mbx = axis_subordinate_generator2driver_mbx;
    m_network_if_subordinate_generator_mbx = network_if_subordinate_generator2driver_mbx;
    m_network_if_manager_generator_mbx = network_if_manager_generator2driver_mbx;  
    
    m_axis_manager_scoreboard_mbx = axis_manager_driver2scoreboard_mbx;
    m_network_if_manager_scoreboard_mbx = network_if_manager_driver2scoreboard_mbx;
    
    this.network_manager_vif = network_manager_vif;
    this.network_subordinate_vif = network_subordinate_vif;
  endfunction

  task reset();
    wait(network_manager_vif.rst);
    $display("[T=%0t] [Driver] Reset started...", $time);
     
    network_manager_vif.manager_driver.manager_clock_block.valid <= 0;
    network_manager_vif.manager_driver.manager_clock_block.flit <= 0;
    network_manager_vif.manager_driver.manager_clock_block.flit_type <= 0;
    network_manager_vif.manager_driver.manager_clock_block.broadcast <= 0;
    network_manager_vif.manager_driver.manager_clock_block.virtual_identifier <= 0;
    
    network_subordinate_vif.subordinate_driver.subordinate_clock_block.ready <= {NUMBEROF_VIRTUAL_CHANNELS{1'b1}};
    
    wait(!network_manager_vif.rst);
    $display("[T=%0t] [Driver] Reset completed...", $time);        
  endtask


  // Drives transactions to the AXI-Stream interface of the NI
  // using the AXI-Stream Manager VIP.
  // Transactions are got from the generator
  task axis_manager_driver();
    forever begin
      axi4stream_transaction item;
      
      m_axis_manager_generator_mbx.get(item);    
      m_axis_manager_scoreboard_mbx.put(item);
      m_axis_manager_agent.driver.send(item);
      
      if (verbosity != 0) begin
        $display("[T=%0t] [Driver] AXI-Stream Manager transaction send to DUV. tid=%0d, tdest=%0d, tlast=%b", 
                 $time,
                 item.get_id(),
                 item.get_dest(),
                 item.get_last());
      end
      
      if (item.get_last() == 1) begin
        numberof_m_axis_frames_transmitted++;
        
        if (verbosity != 0) begin
          $display("[T=%0t] [Driver] numberof_axis_frames_transmitted=%0d", 
                   $time,
                   numberof_m_axis_frames_transmitted);
        end
      end      
    end
  endtask
  
  // Drives transactions to the AXI-Stream interface of the NI
  // using the AXI-Stream Subordinate VIP
  // Transactions are got from the generator
  task axis_subordinate_driver();
    forever begin
      axi4stream_ready_gen item;
      m_axis_subordinate_generator_mbx.get(item);
      m_axis_subordinate_agent.driver.send_tready(item);
    end
  endtask
  
  // Drives transactions from the generator to the
  // network manager interface of the NI. This means,
  // the driver acts as a subordinate
  task network_if_subordinate_driver();
    forever begin
      network_flit_item_t item;
      m_network_if_subordinate_generator_mbx.get(item);
      
      @(posedge network_subordinate_vif.clk);
      network_subordinate_vif.subordinate_driver.subordinate_clock_block.ready <= item.ready;
      
      if (verbosity != 0) begin
        $display("[T=%0t] [Driver] Driven network_if.ready_i=%b", 
                 $time,
                 item.ready);
      end
    end
  endtask
 
  task network_if_manager_driver();
    network_flit_ejection_item_t item;
    network_packet_t packet;
    bit transfer;
    int numberof_network_packet_transmitted = 0;
    
    forever begin
      m_network_if_manager_generator_mbx.get(item);
    
      // drive network_if according to network handshake avail/valid protocol
      // so, valid can only be asserted when ready is asserted and there is
      // a valid flit       
      @(posedge network_manager_vif.clk);
      
      item.ready = network_manager_vif.driver.driver_clock_block.ready;
      
      if (verbosity != 0) begin
        $display("[T=%0t] [Driver] Received Transaction %0d for network_if. network_if.ready=%b; network_if.valid=%b; flit_valid=%b; flit=%x; flit_type=%x, broadcast=%b, virtual_channel=%x (%x);", 
                 $time, network_if_manager_numberof_processed_transactions+1, 
                 network_manager_vif.driver.driver_clock_block.ready, network_manager_vif.monitor.monitor_clock_block.valid, 
                 item.valid,
                 item.flit, item.flit_type, item.broadcast, item.virtual_identifier, 
                 {item.virtual_identifier, item.broadcast, item.flit_type, item.flit});
      end        
      
      transfer = &(item.ready) & item.valid;
      network_manager_vif.driver.driver_clock_block.valid <= transfer;
      
      if (transfer) begin
        m_network_if_manager_scoreboard_mbx.put(item);
        network_if_manager_numberof_valid_network_transactions++; 

        network_manager_vif.driver.driver_clock_block.flit               <= item.flit;
        network_manager_vif.driver.driver_clock_block.flit_type          <= item.flit_type;      
        network_manager_vif.driver.driver_clock_block.broadcast          <= item.broadcast;
        network_manager_vif.driver.driver_clock_block.virtual_identifier <= item.virtual_identifier;

        if (verbosity != 0) begin
          $display("[T=%0t] [Driver] Transaction %0d for network_if driven --> network_if.ready=%b && flit_valid=%b", 
                   $time, network_if_manager_numberof_processed_transactions+1, 
                   network_manager_vif.driver.driver_clock_block.ready, item.valid);
        end              
      end else if (item.valid == 1) begin
        if (verbosity != 0) begin
          $display("[T=%0t] [Driver] Transaction %0d for network_if rescheduled --> network_if.ready=%b && flit_valid=%b", 
                  $time, network_if_manager_numberof_processed_transactions+1, network_manager_vif.driver.driver_clock_block.ready, item.valid);   
        end
        
        wait(network_manager_vif.driver.driver_clock_block.ready == {NUMBEROF_VIRTUAL_NETWORKS{1'b1}});
        network_manager_vif.driver.driver_clock_block.valid              <= 1;
        network_manager_vif.driver.driver_clock_block.flit               <= item.flit;
        network_manager_vif.driver.driver_clock_block.flit_type          <= item.flit_type;      
        network_manager_vif.driver.driver_clock_block.broadcast          <= item.broadcast;
        network_manager_vif.driver.driver_clock_block.virtual_identifier <= item.virtual_identifier;     
        
        m_network_if_manager_scoreboard_mbx.put(item);
        network_if_manager_numberof_valid_network_transactions++;        
        
        if (verbosity != 0) begin
          $display("[T=%0t] [Driver] Transaction %0d for network_if driven --> network_if.ready=%b && flit_valid=%b", 
                   $time, network_if_manager_numberof_processed_transactions+1, 
                   network_manager_vif.driver.driver_clock_block.ready, item.valid);
        end                      
      end 
      
      if (verbosity != 0) begin
        if ((item.valid == 1) && ((item.flit_type == FLIT_TYPE_TAIL) || (item.flit_type == FLIT_TYPE_HEADER_TAIL))) begin
          numberof_network_packet_transmitted++;
          
          $display("[T=%0t] [Driver] numberof_network_packet_transmitted=%0d",
                   $time,
                   numberof_network_packet_transmitted);                   
        end
      end            
      
      network_if_manager_numberof_processed_transactions++;
    end
  endtask
 
  task run();
    fork
      axis_manager_driver();
      axis_subordinate_driver();
      network_if_manager_driver();
      network_if_subordinate_driver();
    join_none
  endtask

endclass