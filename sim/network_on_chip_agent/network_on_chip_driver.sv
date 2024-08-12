// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_driver.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 20th, 2024
//
// @title Network-on-Chip Driver
//
// Drive transactions from the generator to the
// NoC through.
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

class network_on_chip_driver #(
);
  protected int id = 0;

  // AXI-Stream Manager VIP agent
  // Given by AXI VIP Vivado IP Core
  axi4stream_vip_m_mst_t m_axis_agent;

  // Queue for callback methods
  network_on_chip_driver_callback callback_sequence[$];

  // Mailbox for IPC between the generator and the driver
  protected mailbox generator2driver_mbx;

  protected event driver2generator;

  protected int verbosity = 0;

  protected int tile_noc_controller = 0;

  int numberof_m_axis_frames_transmitted = 0;

  function new(input axi4stream_vip_m_mst_t m_axis_agent,
               input mailbox generator2driver_mbx,
               input event driver2generator,
               input int tile_noc_controller,
               input int id);
    this.m_axis_agent = m_axis_agent;
    this.generator2driver_mbx = generator2driver_mbx;
    this.driver2generator = driver2generator;
    this.tile_noc_controller = tile_noc_controller;
    this.id = id;
  endfunction

  //
  // Setters and getters
  //

  function void set_verbosity(int verbosity);
    this.verbosity = verbosity;
  endfunction

  function int get_id();
    return id;
  endfunction

  //
  // Run and test
  //

  task reset();
    m_axis_agent.driver.vif_proxy.wait_areset_deassert();
    
    if (verbosity != 0) begin
      $display("[T=%0t] [Driver Tile %0d] Reset completed!!!",
               $time, id);
    end    
  endtask

  // Drives transactions to the AXI-Stream interface of the NI
  // using the AXI-Stream Manager VIP.
  // Transactions are got from the generator
  task m_axis_driver();
    axi4stream_transaction item;
    int numberof_transaction = 0;

    forever begin : loop_ever
      generator2driver_mbx.get(item);
      numberof_transaction++;

      foreach(callback_sequence[i]) begin
        callback_sequence[i].pre_drive(this, item);
      end

      if (verbosity != 0) begin
        $display("[T=%0t] [Driver Tile %0d] AXI-Stream Manager transaction %0d send to DUV. tid=%0d, tdest=%0d, tlast=%b",
                 $time, id,
                 numberof_transaction,
                 item.get_id(),
                 item.get_dest(),
                 item.get_last());
      end
      
      m_axis_agent.driver.send(item);

      if (item.get_last() == 1) begin
        numberof_m_axis_frames_transmitted++;

        if (verbosity != 0) begin
          $display("[T=%0t] [Driver Tile %0d] numberof_axis_frames_transmitted=%0d",
                   $time, id,
                   numberof_m_axis_frames_transmitted);
        end
      end

      foreach(callback_sequence[i]) begin
        callback_sequence[i].post_drive(this, item);
      end

     // wait for network routing reconfiguration
     // which should start at 55000 ns, but the packet must be completely transmited (tlast == 1)
     if (($time > 40000) && ($time < 200000) && (tile_noc_controller != id) && (item.get_last() == 1)) begin
       if (verbosity != 0) begin
         $display("[T=%0t] [Driver Tile %0d] Wait Router Reconfiguration for 10000 ns", $time, id);
       end
       # 165000;
       if (verbosity != 0) begin
         $display("[T=%0t] [Driver Tile %0d] Assuming Router Reconfiguration done!!!", $time, id);
       end       
     end

      -> driver2generator;

    end : loop_ever
  endtask

  task run();
    fork
      m_axis_driver();
    join_none
  endtask

endclass
