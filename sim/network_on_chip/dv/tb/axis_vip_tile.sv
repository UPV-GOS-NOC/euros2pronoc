// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file axis_vip_tile.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 08th, 2024
//
// @title AXI-Stream VIP Tile
//
// This module is the place holder for a Processing
// Element or Unit that connects to the NoC.
//
// For verification purposes the tile must contain
// an AXIS Manager and/or Subordinate Verification IP
//


`timescale 1ns / 1ns

module axis_vip_tile #(
  parameter  integer NetworkSwitchAddressId      = 0,  // Network configuration. Address identifier for this network interface
  parameter  integer NetworkSwitchAddressIdWidth = 0,  // Network configuration. Number of bits required to encode the NetworkAddressId
  parameter  integer NetworkSwitchNumberOfPorts  = 0,  // Network configuration. Number of network data ports for the switch.
  parameter  integer MeshTopologyDimensionX      = 0,  // Network configuration. Size of the horizontal dimension (dim X) of the 2D-mesh topology
  localparam integer MeshTopologyDimensionXWidth = bitsize(MeshTopologyDimensionX),
  parameter  integer MeshTopologyDimensionY      = 0,  // Network configuration. Size of the vertical dimension (dim Y) of the 2D-mesh topology   
  localparam integer MeshTopologyDimensionYWidth = bitsize(MeshTopologyDimensionY),

  parameter  integer NetworkIfFlitWidth               = 0,  // Network configuration. Flit size (in bits). This is the flow control unit used in the network. This is the network_layer_packet.
  parameter  integer NetworkIfFlitTypeWidth           = 0,  // Network configuration. Flit type size (in bits).
  parameter  integer NetworkIfBroadcastWidth          = 0,  // Network configuration. Size (in bits) of the broadcast signal
  parameter  integer NetworkIfVirtualNetworkIdWidth   = 0,  // Network configuration. Size of virtual network identifier (in bits).
  parameter  integer NetworkIfVirtualChannelIdWidth   = 0,  // Network configuration. Size of the virtual channel identifier (in bits).
  parameter  integer NetworkIfNumberOfVirtualChannels = 0,  // Network configuration. Total number of virtual channels in the network.
  parameter  integer NetworkIfNumberOfVirtualNetworks = 0,  // Network configuration. Total number of virtual networks.
  localparam integer NetworkIfDataWidth = NetworkIfFlitWidth +
                                          NetworkIfFlitTypeWidth +
                                          NetworkIfBroadcastWidth +
                                          NetworkIfVirtualChannelIdWidth, 
  
  // Total number of data signals of the switch when they are packed on a signal bus.
  localparam integer NetworkSwitchPackedDataSignalsWidth = NetworkSwitchNumberOfPorts * NetworkIfDataWidth,
  
  parameter integer AxiStreamTargetIfEnable     = 0,  // Unit AXI Stream Target interface configuration. 0 to disable the interface, any other value to enable it.
  parameter integer AxiStreamTargetIfTDataWidth = 0,  // Unit AXI Stream Target interface configuration. Size (in bits) of the data signal.
  parameter integer AxiStreamTargetIfTIdWidth   = 0,  // Unit AXI Stream Target interface configuration. Size (in bits) of the stream identifier signal.
  parameter integer AxiStreamTargetIfTDestWidth = 0,  // Unit AXI Stream Target interface configuration. Size (in bits) of the stream destination signal.

  parameter integer AxiStreamInitiatorIfEnable      = 0,  // Unit AXI Stream Initiator interface configuration. 0 to disable the interface, any other value to enable it.
  parameter integer AxiStreamInitiatorIfTDataWidth  = 0,  // Unit AXI Stream Initiator interface configuration. Size (in bits) of the data signal.
  parameter integer AxiStreamInitiatorIfTIdWidth    = 0,  // Unit AXI Stream Initiator interface configuration. Size (in bits) of the stream identifier signal.
  parameter integer AxiStreamInitiatorIfTDestWidth  = 0   // Unit AXI Stream Initiator interface configuration. Size (in bits) of the stream destination signal  
) (
  // clocks and resets
  input clk_s_axis_i,
  input clk_m_axis_i,
  input clk_network_i,
  input clk_upsizer_i,
  input clk_downsizer_i,

  input rst_s_axis_ni,
  input rst_m_axis_ni,
  input rst_network_i,
  input rst_upsizer_i,
  input rst_downsizer_i,

  // Network ports (to connect tiles)
  // They are packed signals
  input  [NetworkSwitchNumberOfPorts-1:0]                                  network_valid_i,
  output [NetworkSwitchNumberOfPorts*NetworkIfNumberOfVirtualChannels-1:0] network_go_o,
  input  [NetworkSwitchPackedDataSignalsWidth-1:0]                         network_data_i,
  output [NetworkSwitchNumberOfPorts-1:0]                                  network_valid_o,
  input  [NetworkSwitchNumberOfPorts*NetworkIfNumberOfVirtualChannels-1:0] network_go_i,
  output [NetworkSwitchPackedDataSignalsWidth-1:0]                         network_data_o
);

  `include "common_functions.vh"

  //
  // Gets the number of bits required to encode a value
  //
  // Params:
  //  value, the value to encode
  //
  // Returns:
  //  The number of bits required to encode value input param
  //
  function integer bitsize(integer value);
    begin
      if (value <= 1)
        bitsize = 1;
      else
        bitsize = Log2(value);
    end
  endfunction  

  `include "network_instance.vh"    

  // TODO Instance the Processing Element after this comment.
  //      Use next wires, declared already in network_instance.vh, 
  //      to connect network_s_axis/network_m_axis interfaces of the PE to the interconnect.
  //      A PE could have an Initiator or Manager (network_m_axis) interface
  //      and/or a Target or Subordinate (network_s_axis) interface.
  //
  //  network_m_axis signals drive the AXI-Stream Manager or Initiator interface of the PE
  //  with the Subordinate or Target interface of the NI.
  //  While, network_s_axis signals drive the AXI-Stream Subordinate or Target 
  //  interface of the PE, if it exists,
  //  with the Manager or Initiator interface of the NI.
  //
  //  input                                   clk_s_axis_i
  //  input                                   rst_s_axis_ni
  //  wire                                    network_s_axis_tvalid;
  //  wire                                    network_s_axis_tready;
  //  wire [AxiStreamTargetIfDataWidth-1:0]   network_s_axis_tdata;
  //  wire                                    network_s_axis_tlast;
  //  wire [AxiStreamTargetIfTidWidth-1:0]    network_s_axis_tid;
  //  wire [AxiStreamTargetIfDestIdWidth-1:0] network_s_axis_tdest;

  //  input                                      clk_m_axis_i
  //  input                                      rst_m_axis_ni
  //  wire [AxiStreamInitiatorIfDataWidth-1:0]   network_m_axis_tdata;
  //  wire                                       network_m_axis_tvalid;
  //  wire                                       network_m_axis_tready;
  //  wire                                       network_m_axis_tlast;
  //  wire [AxiStreamInitiatorIfTidWidth-1:0]    network_m_axis_tid;
  //  wire [AxiStreamInitiatorIfDestIdWidth-1:0] network_m_axis_tdest;   

  // A processing element could have:
  // - both the network_m_axis and network_s_axis
  //   interfaces enabled, that would means that it would be the
  //   source and reception of network data communications.
  // - only the network_m_axis interface enabled, which means that it will
  //   generate traffic for the network, but it will not receive
  //   data from the network.
  // - only the network_s_axis interface enabled. In this case the PE
  //   acts as a subordinate device and will receive data from
  //   some network_m_axis, but it will not generate any data for the network  
  generate
    if (AxiStreamInitiatorIfEnable != 0) begin : network_m_axis_vip 
      axi4stream_vip_m inst (
        .aclk   (clk_m_axis_i),
        .aresetn(rst_m_axis_ni),
    
        .m_axis_tvalid(network_m_axis_tvalid),
        .m_axis_tready(network_m_axis_tready),
        .m_axis_tdata (network_m_axis_tdata),
        .m_axis_tlast (network_m_axis_tlast),
        .m_axis_tid   (network_m_axis_tid),
        .m_axis_tdest (network_m_axis_tdest)
      );
    end else begin
      assign network_m_axis_tvalid = 1'b0;
      assign network_m_axis_tdata  = {AxiStreamInitiatorIfTDataWidth{1'b0}};
      assign network_m_axis_tlast  = 1'b0;
      assign network_m_axis_tid    = {AxiStreamInitiatorIfTIdWidth{1'b0}};
      assign network_m_axis_tdest  = {AxiStreamInitiatorIfTDestWidth{1'b0}};
    end
  endgenerate
  
  generate
    if (AxiStreamTargetIfEnable) begin : network_s_axis_vip
      axi4stream_vip_s inst (
        .aclk   (clk_s_axis_i),
        .aresetn(rst_s_axis_ni),
    
        .s_axis_tvalid(network_s_axis_tvalid),
        .s_axis_tready(network_s_axis_tready),
        .s_axis_tdata (network_s_axis_tdata),
        .s_axis_tlast (network_s_axis_tlast),
        .s_axis_tid   (network_s_axis_tid),
        .s_axis_tdest (network_s_axis_tdest)
      );
    end else begin
      assign network_s_axis_tready = 1'b0;
    end
  endgenerate
  
endmodule
