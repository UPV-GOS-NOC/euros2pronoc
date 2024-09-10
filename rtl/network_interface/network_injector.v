// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_injector.v
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date September 9th, 2024
//
// @title  Network injector
//
// It receives transport layer packets from the
// Tonets and maps them into network packets
// to be forwarded to the network
//
// This module provides two output interfaces, 
// since some of the received packets could be addressed to 
// a remote or local component. The packets going to a remote
// component will leave the module through the network_if interface, while
// the ones addressed to a local component will do it through
// the local_if interface.
//
// In addition, it adapts 'Standard' Valid/Ready handshake to
// the custom avail/valid NoC handshake
//
// In the NoC handshake, valid can only be
// asserted if avail is already asserted
//

`timescale 1ns/1ns

`include "net_common.h"

module network_injector #(
  parameter integer NetworkIfAddressId               = 0,  // Network configuration. Address identifier for this network interface
  parameter integer NetworkIfFlitWidth               = 0,  // Network configuration. Flit size (in bits). This is the flow control unit used in the network. This is the network_layer_packet.
  parameter integer NetworkIfFlitTypeWidth           = 0,  // Network configuration. Flit type size (in bits).
  parameter integer NetworkIfBroadcastWidth          = 0,  // Network configuration. Size (in bits) of the broadcast signal
  parameter integer NetworkIfVirtualNetworkIdWidth   = 0,  // Network configuration. Size of virtual network identifier (in bits).
  parameter integer NetworkIfVirtualChannelIdWidth   = 0,  // Network configuration. Size of the virtual channel identifier (in bits).
  parameter integer NetworkIfNumberOfVirtualChannels = 0,  // Network configuration. Total number of virtual channels in the network.
  parameter integer NetworkIfNumberOfVirtualNetworks = 0   // Network configuration. Total number of virtual networks.
) (
  input clk_i,
  input rst_i,

  // Transport layer interface (valid/ready handshake)
  input                                       tlp_valid_i,
  output                                      tlp_ready_o,
  input  [NetworkIfFlitWidth-1:0]             tlp_flit_i,
  input  [NetworkIfFlitTypeWidth-1:0]         tlp_flit_type_i,
  input  [NetworkIfBroadcastWidth-1:0]        tlp_broadcast_i,
  input  [NetworkIfVirtualChannelIdWidth-1:0] tlp_virtual_channel_id_i,
  
  // Network interface for remote traffic (avail/valid router handshake)
  output                                        network_valid_o,
  input  [NetworkIfNumberOfVirtualChannels-1:0] network_avail_i,
  output [NetworkIfFlitWidth-1:0]               network_flit_o,
  output [NetworkIfFlitTypeWidth-1:0]           network_flit_type_o,
  output [NetworkIfBroadcastWidth-1:0]          network_broadcast_o,
  output [NetworkIfVirtualChannelIdWidth-1:0]   network_virtual_channel_id_o,
  
  // Network interface for local traffic (valid/ready handshake)
  output                                      local_valid_o,
  input                                       local_ready_i,
  output [NetworkIfFlitWidth-1:0]             local_flit_o,
  output [NetworkIfFlitTypeWidth-1:0]         local_flit_type_o,
  output [NetworkIfBroadcastWidth-1:0]        local_broadcast_o,
  output [NetworkIfVirtualNetworkIdWidth-1:0] local_virtual_network_id_o    
);

  localparam integer NETWORK_FLIT_HEADER          = `header;
  localparam integer NETWORK_FLIT_HEADER_AND_TAIL = `header_tail;
  localparam integer NETWORK_FLIT_DESTINATION_MSB = 63;
  localparam integer NETWORK_FLIT_DESTINATION_LSB = 53;
  localparam integer NETWORK_FLIT_REMOTE          = 1;
  localparam integer NETWORK_FLIT_LOCAL           = 0;

  wire noc_valid;
  wire noc_ready;

  // Asserted when there is a valid flit at input addressed to local node
  wire local_valid;
 
  // memory bit to store the target of the packet (remote == 1 and local == 0)
  reg packet_target_q = 0;
  
  // Asserted when the input flit is of header type (header or header_and_tail)
  wire tlp_header;
  
  // Asserted when the input flit is local traffic 
  wire tlp_local;

  // Combinational
  reg tlp_ready;
 
  assign tlp_ready_o = tlp_ready;


  assign noc_valid   = (tlp_valid_i == 1) && 
    (
      ((packet_target_q == NETWORK_FLIT_REMOTE) && (tlp_header == 0)) || 
      ((tlp_header == 1) && (tlp_local == 0))
    );
  assign local_valid = (tlp_valid_i == 1) && 
    (
      ((packet_target_q == NETWORK_FLIT_LOCAL) && (tlp_header == 0)) || 
      ((tlp_header == 1) && (tlp_local == 1))
    );

  assign local_valid_o              = local_valid;
  assign local_flit_o               = tlp_flit_i;
  assign local_flit_type_o          = tlp_flit_type_i;
  assign local_broadcast_o          = tlp_broadcast_i;
  assign local_virtual_network_id_o = tlp_virtual_channel_id_i; // TODO. Now we are assuming a VC per VN so Ids map one-to-one between VC and VN, but this should be generalized

  assign network_flit_o               = tlp_flit_i;
  assign network_flit_type_o          = tlp_flit_type_i;
  assign network_broadcast_o          = tlp_broadcast_i;
  assign network_virtual_channel_id_o = tlp_virtual_channel_id_i;


  // Adapt standard valid/ready handshake to Router custom handshake (avail/valid)
  validready2noc_handshake_adapter #(
    .NumberOfVirtualChannels(NetworkIfNumberOfVirtualChannels),
    .VirtualChannelIdWidth  (NetworkIfVirtualChannelIdWidth)
  ) traffic_injector_inst (
    .valid_i             (noc_valid),
    .ready_o             (noc_ready),
    .virtual_channel_id_i(tlp_virtual_channel_id_i),

    .valid_o(network_valid_o),
    .avail_i(network_avail_i)
  );
  

  // Captures the nature of the network traffic
  assign tlp_header = (tlp_flit_type_i == NETWORK_FLIT_HEADER) || (tlp_flit_type_i == NETWORK_FLIT_HEADER_AND_TAIL); 
  assign tlp_local  = (tlp_flit_i[NETWORK_FLIT_DESTINATION_MSB:NETWORK_FLIT_DESTINATION_LSB] == NetworkIfAddressId);
  always @(posedge clk_i) begin
    if ((tlp_valid_i == 1) && (tlp_header == 1) && (tlp_local == 0)) begin
      packet_target_q <= NETWORK_FLIT_REMOTE;
    end else if ((tlp_valid_i == 1) && (tlp_header == 1) && (tlp_local == 1)) begin
      packet_target_q <= NETWORK_FLIT_LOCAL;
    end   
  end
  
  // Ready logic for the tonet depending whether the transport layer packet goes
  // to local or network 
  always @(*) begin
    tlp_ready = 0;
    
    if ((local_ready_i == 1) && (local_valid)) begin
      tlp_ready = 1;
    end
    
    if ((noc_ready == 1) && (noc_valid == 1)) begin 
      tlp_ready = 1;
    end
  end

endmodule