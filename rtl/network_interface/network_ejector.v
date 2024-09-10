// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file single_unit_network_interface.v
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network Ejector
//
// This module provides the ejection interface with
// the network.
//
// It receives network traffic in form of flits, that belong to packets,
// and propagates them to a single sink. 
//
// First, it converts NoC handshake to standard valid/ready handshake.
//
// Then, the module packs the network signals (flit, flit_type, broadcast}.
//
// Finally, it drives the traffic ejector interface with the packed signals, 
// plus the virtual network identifier.
//
// The first implementation will not use a demultiplexor since there
// is only a single sink.
//
//
// update Sep 9th, 20024
//  Add a new interface to allow local traffic so packets addressed from same
//  source to same destination are permited. This is achieved connecting the
//  network injector and ejector modules through the network local interface.
//  A fixed priority arbiter is used for arbitrating access to the output port.
//  Priority is given to the local traffic.

`timescale 1ns/1ns

`include "net_common.h"

module network_ejector #(
  parameter  integer NetworkIfFlitWidth               = 0,  // Network configuration. Flit size (in bits). This is the flow control unit used in the network.
  parameter  integer NetworkIfFlitTypeWidth           = 0,  // Network configuration. Flit type size (in bits).
  parameter  integer NetworkIfBroadcastWidth          = 0,  // Network configuration. Size (in bits) of the broadcast signal
  parameter  integer NetworkIfVirtualNetworkIdWidth   = 0,  // Network configuration. Size of virtual network identifier (in bits).
  parameter  integer NetworkIfNumberOfVirtualNetworks = 0,  // Network configuration. Total number of virtual networks.
  localparam integer NetworkIfDataWidth = NetworkIfFlitWidth +
                                          NetworkIfFlitTypeWidth +
                                          NetworkIfBroadcastWidth +
                                          NetworkIfVirtualNetworkIdWidth  // Network configuration. Size (in bits) to pack the network signals
) (
  // Clocks and resets
  input wire clk_i,
  input wire rst_i,

  // Traffic ejector interface
  output wire                          valid_o,
  input  wire                          ready_i,
  output wire [NetworkIfDataWidth-1:0] data_o,

  // Network interface
  input  wire                                        network_valid_i,
  output wire [NetworkIfNumberOfVirtualNetworks-1:0] network_ready_o,               // Network interface. Receiver channel. Ready signal for the adhoc NoC-based handshake (Ready is asserted even if valid is not asserted)
  input  wire [NetworkIfFlitWidth-1:0]               network_flit_i,                // Network interface. Receiver channel. Flit
  input  wire [NetworkIfFlitTypeWidth-1:0]           network_flit_type_i,           // Network interface. Receiver channel. Flit type (header, header_tail, payload, tail)
  input  wire [NetworkIfBroadcastWidth-1:0]          network_broadcast_i,           // Network interface. Receiver channel. Asserted when the flit is to be broadcasted to every unit
  input  wire [NetworkIfVirtualNetworkIdWidth-1:0]   network_virtual_network_id_i,  // Network interface. Receiver channel. Virtual channel identifier

  // Network interface for local traffic (valid/ready handshake)
  input                                       local_valid_i,
  output                                      local_ready_o,
  input  [NetworkIfFlitWidth-1:0]             local_flit_i,
  input  [NetworkIfFlitTypeWidth-1:0]         local_flit_type_i,
  input  [NetworkIfBroadcastWidth-1:0]        local_broadcast_i,
  input  [NetworkIfVirtualNetworkIdWidth-1:0] local_virtual_network_id_i
);


  localparam integer NETWORK_FLIT_HEADER          = `header;
  localparam integer NETWORK_FLIT_TAIL            = `tail;
  localparam integer NETWORK_FLIT_HEADER_AND_TAIL = `header_tail;

  wire grant_local;
  wire grant_remote;

  wire                          network_valid;
  wire                          network_ready;
  wire [NetworkIfDataWidth-1:0] network_data_in;  // packed network data signals
  wire [NetworkIfDataWidth-1:0] network_data;
  wire                          network_flit_tail;
  wire                          network_flit_header;
  reg                           network_hold_q;
  wire                          network_handshake_complete;

  wire [NetworkIfDataWidth-1:0] local_data_in;
  wire                          local_flit_tail;
  wire                          local_flit_header;
  reg                           local_hold_q;
  wire                          local_handshake_complete;  

  reg                          valid_from_mux;
  reg [NetworkIfDataWidth-1:0] data_from_mux; 

  assign network_data_in  = {
      network_virtual_network_id_i,
      network_broadcast_i,
      network_flit_type_i,
      network_flit_i
  };
  
  assign local_data_in = {
    local_virtual_network_id_i,
    local_broadcast_i,
    local_flit_type_i,
    local_flit_i
  };

  assign network_ready_o = {NetworkIfNumberOfVirtualNetworks{network_ready}};
  assign local_ready_o   = (ready_i == 1) && (grant_local == 1);
  assign valid_o         = valid_from_mux;
  assign data_o          = data_from_mux;

  assign network_flit_tail   = (network_data[65:64] == NETWORK_FLIT_TAIL) || (network_data[65:64] == NETWORK_FLIT_HEADER_AND_TAIL);
  assign network_flit_header = (network_data[65:64] == NETWORK_FLIT_HEADER);
  assign network_handshake_complete = (network_flit_tail == 1) && (network_valid == 1) && (ready_i == 1) && (grant_remote == 1);

  assign local_flit_tail          = (local_flit_type_i == NETWORK_FLIT_TAIL) || (local_flit_type_i == NETWORK_FLIT_HEADER_AND_TAIL);
  assign local_flit_header        = (local_flit_type_i == NETWORK_FLIT_HEADER);
  assign local_handshake_complete = (local_flit_tail == 1) && (local_valid_i == 1) && (ready_i == 1) && (grant_local == 1);

  always @(posedge clk_i) begin
    if (rst_i) begin
      network_hold_q <= 0;
    end else begin
      if ((network_flit_header == 1) && (network_valid == 1)) begin
        network_hold_q <= 1; 
      end else if ((network_flit_tail == 1) && (network_handshake_complete == 1)) begin
        network_hold_q <= 0;
      end
    end
  end

  always @(posedge clk_i) begin
    if (rst_i) begin
      local_hold_q <= 0;
    end else begin
      if ((local_flit_header == 1) && (local_valid_i == 1)) begin
        local_hold_q <= 1; 
      end else if ((local_flit_tail == 1) && (local_handshake_complete == 1)) begin
        local_hold_q <= 0;
      end
    end
  end

  // Mux
  always @(*) begin
    data_from_mux  = network_data;
    valid_from_mux = network_valid;
    
    if (grant_local == 1) begin
      data_from_mux  = local_data_in;
      valid_from_mux = local_valid_i;
    end
  end

  // The request is held until the packet reception completes with TAIL flit
  fixed_priority_arbiter_with_hold #(
    .NumberOfRequesters(2)
  ) arbiter_inst (
    .clk_i(clk_i),
    
    .request_i({network_valid, local_valid_i}),
    .hold_i   ({network_hold_q == 1, local_hold_q == 1}),
    .grant_o  ({grant_remote, grant_local})
  );

  noc_outport_handshake_adapter #(
    .DataWidth(NetworkIfDataWidth)
  ) noc2axis_handshake_adapter_inst (
    .clk(clk_i),
    .rst(rst_i),

    // This interface uses 'NoC custom valid/avail' handshake
    .data_i      (network_data_in),
    .data_valid_i(network_valid_i),
    .avail_o     (network_ready),

    // This interface uses 'valid/ready' handshake
    .data_o      (network_data), //data_o),
    .data_valid_o(network_valid), //valid_o),
    .full_i      (~ready_i)
  );
  

endmodule