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

`timescale 1ns/1ns

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
  input  wire [NetworkIfVirtualNetworkIdWidth-1:0]   network_virtual_network_id_i   // Network interface. Receiver channel. Virtual channel identifier
);

  wire                          network_ready;
  wire [NetworkIfDataWidth-1:0] network_data_in;  // packed network data signals

  assign network_data_in  = {
      network_virtual_network_id_i,
      network_broadcast_i,
      network_flit_type_i,
      network_flit_i
  };

  assign network_ready_o = {NetworkIfNumberOfVirtualNetworks{network_ready}};

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
    .data_o      (data_o),
    .data_valid_o(valid_o),
    .full_i      (~ready_i)
  );
  

endmodule