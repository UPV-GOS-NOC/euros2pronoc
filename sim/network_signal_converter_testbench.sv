// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_signal_converter_testbench.v
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date February 12th, 2024
//
// @title Network Signal Converter Testbench
//
//

`timescale 1ns/1ns

class network_signal_converter_item #(
  int FlitWidth             = 0,
  int FlitTypeWidth         = 0,
  int BroadcastWidth        = 0,
  int VirtualNetworkIdWidth = 0
);

  localparam int DataWidth = FlitWidth +
                             FlitTypeWidth +
                             BroadcastWidth +
                             VirtualNetworkIdWidth;
 
  // Generate transaction data
  rand bit [DataWidth-1:0] generate_data;
  rand bit                 generate_valid;
  rand bit                 generate_ready;
  
  // Capture transaction
  bit                             capture_ready;
  bit                             capture_valid;
  bit [FlitWidth-1:0]             capture_flit;
  bit [FlitTypeWidth-1:0]         capture_flit_type;
  bit [BroadcastWidth-1:0]        capture_broadcast;
  bit [VirtualNetworkIdWidth-1:0] capture_virtual_network_id;
endclass

class network_signal_converter_driver #(
  int FlitWidth             = 0,
  int FlitTypeWidth         = 0,
  int BroadcastWidth        = 0,
  int VirtualNetworkIdWidth = 0
);
  virtual network_signal_converter_if #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth)     
  ) network_signal_converter_vif;

  virtual clk_if clk_vif;
  event accept_next;
  mailbox mbx;

  task run();
    $display("[T=%0t] [Driver] starting...", $time);
    forever begin
      network_signal_converter_item #(
        .FlitWidth            (FlitWidth),
        .FlitTypeWidth        (FlitTypeWidth),
        .BroadcastWidth       (BroadcastWidth),
        .VirtualNetworkIdWidth(VirtualNetworkIdWidth)
      ) item;
    
      $display("[T=%0t] [Driver] waiting for next item", $time);
      mbx.get(item);
      @(posedge clk_vif.clk);
      $display("[T=%0t] [Driver] Item: valid=%b; ready=%b; data=%x", $time, item.generate_valid, item.generate_ready, item.generate_data);
      network_signal_converter_vif.drive_inputs(item.generate_data, item.generate_valid, item.generate_ready);
      -> accept_next;
    end
     $display("[T=%0t] [Driver] Done!", $time);   
  endtask
endclass

class network_signal_converter_generator #(
  int FlitWidth             = 0,
  int FlitTypeWidth         = 0,
  int BroadcastWidth        = 0,
  int VirtualNetworkIdWidth = 0  
);

  int total_generations = 10;
  event accept_next;
  mailbox mbx;

  task run();
    for (int i = 0; i < total_generations; i++) begin
      network_signal_converter_item #( 
        .FlitWidth            (FlitWidth),
        .FlitTypeWidth        (FlitTypeWidth),
        .BroadcastWidth       (BroadcastWidth),
        .VirtualNetworkIdWidth(VirtualNetworkIdWidth)     
      ) item = new;
      item.randomize();
      $display("[T=%0t] [Generator] Loop:%d/%d create item", $time, i + 1, total_generations); 
      mbx.put(item);
      $display("[T=%0t] [Generator] Wait for Driver to be done", $time); 
      @(accept_next);
    end
    $display("[T=%0t] [Generator] Done generation for %0d items", $time, total_generations);
  endtask
endclass

// The monitor has a virtual interface handle with which it can monitor
// the events happening on the interface. It sees new transactions and then
// captures information into a packet and sends it to the scoreboard
// using another mailbox.
class network_signal_converter_monitor #(
  int FlitWidth             = 0,
  int FlitTypeWidth         = 0,
  int BroadcastWidth        = 0,
  int VirtualNetworkIdWidth = 0    
);
  
  virtual network_signal_converter_if #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth)     
  ) network_signal_converter_vif;

  virtual clk_if clk_vif;
  mailbox mbx;
  
  task run();
    $display("[T=%0t] [Monitor] starting...", $time);
    
    forever begin
      network_signal_converter_item #(
        .FlitWidth            (FlitWidth),
        .FlitTypeWidth        (FlitTypeWidth),
        .BroadcastWidth       (BroadcastWidth),
        .VirtualNetworkIdWidth(VirtualNetworkIdWidth)     
      ) item = new;
      @(posedge clk_vif.clk);
      #1;
      network_signal_converter_vif.get(item);
      $display("[T=%0t] [Monitor] Transaction item: valid=%b(%b); ready=%b(%b); Data=%x(%x)", 
               $time, 
               item.capture_valid, item.generate_valid,
               item.capture_ready, item.generate_ready,
               {item.capture_virtual_network_id, item.capture_broadcast, item.capture_flit_type, item.capture_flit}, item.generate_data);
      mbx.put(item);
    end
    $display("[T=%0t] [Monitor] Done!", $time);
  endtask
endclass

// The scoreboard is responsible to check data integrity. Since the design
// simple pass inputs to outputs, scoreboard helps to check if the
// output has changed for given set of inputs based on expected logic
class network_signal_converter_scoreboard #(
  int FlitWidth             = 0,
  int FlitTypeWidth         = 0,
  int BroadcastWidth        = 0,
  int VirtualNetworkIdWidth = 0    
);
  
  // Let's use Constant convention here since both Constant and Parameters are mixed here
  localparam int FLIT_LSB = 0;
  localparam int FLIT_MSB = FLIT_LSB + FlitWidth - 1;
  localparam int FLIT_TYPE_LSB = FLIT_MSB + 1;
  localparam int FLIT_TYPE_MSB = FLIT_TYPE_LSB + FlitTypeWidth - 1;
  localparam int BROADCAST_LSB = FLIT_TYPE_MSB + 1;
  localparam int BROADCAST_MSB = BROADCAST_LSB + BroadcastWidth - 1;
  localparam int VIRTUAL_NETWORK_ID_LSB = BROADCAST_MSB + 1;
  localparam int VIRTUAL_NETWORK_ID_MSB = VIRTUAL_NETWORK_ID_LSB + VirtualNetworkIdWidth - 1;  
  
  mailbox mbx;
  
  task run();
    forever begin
      network_signal_converter_item #(
        .FlitWidth            (FlitWidth),
        .FlitTypeWidth        (FlitTypeWidth),
        .BroadcastWidth       (BroadcastWidth),
        .VirtualNetworkIdWidth(VirtualNetworkIdWidth)     
      ) item; 
      mbx.get(item);
    
      // check that output is equal to input
      if (item.generate_valid != item.capture_valid) begin
        $display("[T=%0t] [Scoreboard] Error! valid not propagated correctly", $time);
        break;
      end
      
      if (item.generate_ready != item.capture_ready) begin
        $display("[T=%0t] [Scoreboard] Error! ready not propagated correctly", $time);
        break;
      end
      
      if (item.generate_data[FLIT_MSB:FLIT_LSB] != item.capture_flit) begin
        $display("[T=%0t] [Scoreboard] Error! Flit not propagated correctly", $time);
        break;
      end
      
      if (item.generate_data[FLIT_TYPE_MSB:FLIT_TYPE_LSB] != item.capture_flit_type) begin
        $display("[T=%0t] [Scoreboard] Error! Flit Type not propagated correctly", $time);
        break;
      end
      
      if (item.generate_data[BROADCAST_MSB:BROADCAST_LSB] != item.capture_broadcast) begin
        $display("[T=%0t] [Scoreboard] Error! Broadcast not propagated correctly", $time);
        break;
      end
      
      if (item.generate_data[VIRTUAL_NETWORK_ID_MSB:VIRTUAL_NETWORK_ID_LSB] != item.capture_virtual_network_id) begin
        $display("[T=%0t] [Scoreboard] Error! Virtual Network Id not propagated correctly", $time);
        break;
      end
    end
    $display("[T=%0t] [Scoreboard] Done!", $time);
  endtask
endclass


class network_signal_converter_env #(
  int FlitWidth             = 0,
  int FlitTypeWidth         = 0,
  int BroadcastWidth        = 0,
  int VirtualNetworkIdWidth = 0  
);
  
  network_signal_converter_generator #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth)    
  ) generator;

  network_signal_converter_driver #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth)  
  ) driver;
  
  network_signal_converter_monitor #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth)
  ) monitor;
  
  network_signal_converter_scoreboard #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth)  
  ) scoreboard;
  
  virtual network_signal_converter_if #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth)  
  ) network_signal_converter_vif;
  
  virtual clk_if clk_vif;
  
  mailbox driver_mbx;
  mailbox scoreboard_mbx;
  event accept_next;

  function new();
    generator = new();
    driver = new();
    monitor = new();
    scoreboard = new();
    driver_mbx = new();
    scoreboard_mbx = new();
  endfunction
  
  virtual task run();
    // Connect instances
    driver.network_signal_converter_vif = network_signal_converter_vif;
    monitor.network_signal_converter_vif = network_signal_converter_vif;
    driver.mbx = driver_mbx;
    generator.mbx = driver_mbx;
    scoreboard.mbx = scoreboard_mbx;
    monitor.mbx = scoreboard_mbx;
    driver.accept_next = accept_next;
    generator.accept_next = accept_next;
    driver.clk_vif = clk_vif;
    monitor.clk_vif = clk_vif;
    
    // Run the different components of the environment in different processes
    // The processes are running forever, except the generator that must
    // finish at some point, and the join_any will force the other processes
    // to finish as well 
    fork
      scoreboard.run();
      driver.run();
      monitor.run();
      generator.run();
    join_any
  endtask
endclass

class test #(
  int FlitWidth             = 0,
  int FlitTypeWidth         = 0,
  int BroadcastWidth        = 0,
  int VirtualNetworkIdWidth = 0  
);

  network_signal_converter_env #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth)
  ) env;
  
  function new();
    env = new();
  endfunction
  
  task run();
    env.run();
  endtask
endclass

interface network_signal_converter_if #(
  int FlitWidth             = 0,
  int FlitTypeWidth         = 0,
  int BroadcastWidth        = 0,
  int VirtualNetworkIdWidth = 0
);

  localparam int DataWidth = FlitWidth +
                             FlitTypeWidth +
                             BroadcastWidth +
                             VirtualNetworkIdWidth;
  
  logic [DataWidth-1:0] network_data_i;
  logic                 network_valid_i;
  logic                 network_ready_o;
  
  logic                             network_ready_i;
  logic                             network_valid_o;
  logic [FlitWidth-1:0]             network_flit_o;
  logic [FlitTypeWidth-1:0]         network_flit_type_o;
  logic [BroadcastWidth-1:0]        network_broadcast_o;
  logic [VirtualNetworkIdWidth-1:0] network_virtual_network_id_o;
  
  
  task drive_valid(input logic valid);
    network_valid_i <= valid;
  endtask
  
  task drive_ready(input logic ready);
    network_ready_i <= ready;
  endtask
  
  task drive_data(input logic [DataWidth-1:0] data);
    network_data_i <= data;
  endtask
 
  task drive_inputs(input logic [DataWidth-1:0] data_i, 
                    input logic valid_i, 
                    input logic ready_i);
    network_valid_i <= valid_i;
    network_ready_i <= ready_i;
    network_data_i  <= data_i;
  endtask
  
  task get_outputs(output logic ready_o, 
                   output logic valid_o, 
                   output logic [FlitWidth-1:0] flit_o, 
                   output logic [FlitTypeWidth-1:0] flit_type_o, 
                   output logic [BroadcastWidth-1:0] broadcast_o, 
                   output logic [VirtualNetworkIdWidth-1:0] virtual_network_id_o);
    valid_o              <= network_valid_o;
    ready_o              <= network_ready_o;
    flit_o               <= network_flit_o;
    flit_type_o          <= network_flit_type_o;
    broadcast_o          <= network_broadcast_o;
    virtual_network_id_o <= network_virtual_network_id_o;
  endtask
  
  task automatic get(ref 
    network_signal_converter_item #( 
      .FlitWidth            (FlitWidth),
      .FlitTypeWidth        (FlitTypeWidth),
      .BroadcastWidth       (BroadcastWidth),
      .VirtualNetworkIdWidth(VirtualNetworkIdWidth)       
    ) item);
    item.generate_data              = network_data_i;
    item.generate_valid             = network_valid_i;
    item.generate_ready             = network_ready_o;
    
    item.capture_valid              = network_valid_o;
    item.capture_ready              = network_ready_i;
    item.capture_flit               = network_flit_o;
    item.capture_flit_type          = network_flit_type_o;
    item.capture_broadcast          = network_broadcast_o;
    item.capture_virtual_network_id = network_virtual_network_id_o;
  endtask;
endinterface

// Although the DUV does not have a clock, let us create a mock clock
// used in the testbench to synchronize when values are driven and when
// values are sampled. Typically combinational logic is used between
// sequential elements like FF in a real circuit. So, let us assume
// that inputs to the DUV is provided at some posedge clock. But because
// the design does not have clock in its input, we will keep this clock
// in a separate interface that is available only to testbench components
interface clk_if();
  logic clk;
  
  initial clk <= 0;
  
  always #10 clk = ~clk;
endinterface

module network_signal_converter_testbench();

  parameter int FlitWidth = 64;
  parameter int FlitTypeWidth = 2;
  parameter int BroadcastWidth = 1;
  parameter int VirtualNetworkIdWidth = 3;

  network_signal_converter_if #(
    .FlitWidth            (FlitWidth),
    .FlitTypeWidth        (FlitTypeWidth),
    .BroadcastWidth       (BroadcastWidth),
    .VirtualNetworkIdWidth(VirtualNetworkIdWidth) 
  ) m_network_signal_converter_if();

  clk_if m_clk_if();

  network_signal_converter #(
    .NetworkIfFlitWidth            (FlitWidth),
    .NetworkIfFlitTypeWidth        (FlitTypeWidth),
    .NetworkIfBroadcastWidth       (BroadcastWidth),
    .NetworkIfVirtualNetworkIdWidth(VirtualNetworkIdWidth)  
  ) network_signal_converter_inst (
    .network_valid_i(m_network_signal_converter_if.network_valid_i),
    .network_ready_o(m_network_signal_converter_if.network_ready_o),
    .network_data_i (m_network_signal_converter_if.network_data_i),

    .network_valid_o             (m_network_signal_converter_if.network_valid_o),
    .network_ready_i             (m_network_signal_converter_if.network_ready_i),
    .network_flit_o              (m_network_signal_converter_if.network_flit_o),
    .network_flit_type_o         (m_network_signal_converter_if.network_flit_type_o),
    .network_broadcast_o         (m_network_signal_converter_if.network_broadcast_o),
    .network_virtual_network_id_o(m_network_signal_converter_if.network_virtual_network_id_o)
  );

  initial begin
    test #(
      .FlitWidth            (FlitWidth),
      .FlitTypeWidth        (FlitTypeWidth),
      .BroadcastWidth       (BroadcastWidth),
      .VirtualNetworkIdWidth(VirtualNetworkIdWidth)    
    ) t0;
    
    t0 = new();
    t0.env.network_signal_converter_vif = m_network_signal_converter_if;
    t0.env.clk_vif = m_clk_if;
    t0.run();


    // Once the main stimulus is over, wait for some time
    // until all transactions are finished and then end
    // simulation. Note that $finish is required because
    // there are components that are running forever in
    // the background like clk, monitor, driver, etc
    #50 $finish;
  end

endmodule