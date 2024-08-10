// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file duv.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 05th, 2024
//
// @title Design for Single Unit Network Interface Verification
//
// The design does not provide the filereg access interface,
// So the simulation environment uses Virtual Network 0 as data network

`timescale 1ns / 1ps

module duv #(
  parameter integer NetworkIfAddressId               = 0,  // Network configuration. Address identifier for this network interface
  parameter integer NetworkIfFlitWidth               = 0,  // Network configuration. Flit size (in bits). This is the flow control unit used in the network. This is the network_layer_packet.
  parameter integer NetworkIfFlitTypeWidth           = 0,  // Network configuration. Flit type size (in bits).
  parameter integer NetworkIfBroadcastWidth          = 0,  // Network configuration. Size (in bits) of the broadcast signal
  parameter integer NetworkIfVirtualNetworkIdWidth   = 0,  // Network configuration. Size of virtual network identifier (in bits).
  parameter integer NetworkIfVirtualChannelIdWidth   = 0,  // Network configuration. Size of the virtual channel identifier (in bits).
  parameter integer NetworkIfNumberOfVirtualChannels = 0,  // Network configuration. Total number of virtual channels in the network.
  parameter integer NetworkIfNumberOfVirtualNetworks = 0,  // Network configuration. Total number of virtual networks.
  
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

  // Custom interface for NoC Router connection.
  output                                        network_valid_o,               // Network interface. Transmit channel. Valid signal for the adhoc NoC-based Handshake (valid is asserted when ready is asserted and there is a flit)
  input  [NetworkIfNumberOfVirtualChannels-1:0] network_ready_i,               // Network interface. Transmit channel. Ready signal for the adhoc NoC-based handshake (Ready is asserted even if valid is not asserted)
  output [NetworkIfFlitWidth-1:0]               network_flit_o,                // Network interface. Transmit channel. Flit
  output [NetworkIfFlitTypeWidth-1:0]           network_flit_type_o,           // Network interface. Transmit channel. Flit type (header, header_tail, payload, tail)
  output [NetworkIfBroadcastWidth-1:0]          network_broadcast_o,           // Network interface. Transmit channel. Asserted when the flit has to be broadcasted in the network
  output [NetworkIfVirtualChannelIdWidth-1:0]   network_virtual_channel_id_o,  // Network interface. Transmit channel. Virtual channel identifier
  input                                         network_valid_i,               // Network interface. Receiver channel. Valid signal for the adhoc NoC-based Handshake (valid is asserted when ready is asserted and there is a flit)
  output [NetworkIfNumberOfVirtualNetworks-1:0] network_ready_o,               // Network interface. Receiver channel. Ready signal for the adhoc NoC-based handshake (Ready is asserted even if valid is not asserted)
  input  [NetworkIfFlitWidth-1:0]               network_flit_i,                // Network interface. Receiver channel. Flit
  input  [NetworkIfFlitTypeWidth-1:0]           network_flit_type_i,           // Network interface. Receiver channel. Flit type (header, header_tail, payload, tail)
  input  [NetworkIfBroadcastWidth-1:0]          network_broadcast_i,           // Network interface. Receiver channel. Asserted when the flit is to be broadcasted to every unit
  input  [NetworkIfVirtualNetworkIdWidth-1:0]   network_virtual_network_id_i   // Network interface. Receiver channel. Virtual channel identifier  
);
    
  wire                                      m_axis_tvalid;
  wire                                      m_axis_tready;
  wire [AxiStreamInitiatorIfTDataWidth-1:0] m_axis_tdata;
  wire                                      m_axis_tlast;
  wire [AxiStreamInitiatorIfTIdWidth-1:0]   m_axis_tid;
  wire [AxiStreamInitiatorIfTDestWidth-1:0] m_axis_tdest;
  
  wire                                   s_axis_tvalid;
  wire                                   s_axis_tready;
  wire [AxiStreamTargetIfTDataWidth-1:0] s_axis_tdata;
  wire                                   s_axis_tlast;
  wire [AxiStreamTargetIfTIdWidth-1:0]   s_axis_tid;
  wire [AxiStreamTargetIfTDestWidth-1:0] s_axis_tdest;     
    
  axi4stream_vip_m m_axis_vip_inst (
    .aclk   (clk_m_axis_i),
    .aresetn(rst_m_axis_ni),
    
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tlast (m_axis_tlast),
    .m_axis_tid   (m_axis_tid),
    .m_axis_tdest (m_axis_tdest)
  );
  
  axi4stream_vip_s s_axis_vip_inst (
    .aclk   (clk_s_axis_i),
    .aresetn(rst_s_axis_ni),
    
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tdata (s_axis_tdata),
    .s_axis_tlast (s_axis_tlast),
    .s_axis_tid   (s_axis_tid),
    .s_axis_tdest (s_axis_tdest)
  );  
  
  single_unit_network_interface #(
    .NetworkIfAddressId              (0),
    .NetworkIfFlitWidth              (NetworkIfFlitWidth),
    .NetworkIfFlitTypeWidth          (NetworkIfFlitTypeWidth),
    .NetworkIfBroadcastWidth         (NetworkIfBroadcastWidth),
    .NetworkIfVirtualNetworkIdWidth  (NetworkIfVirtualNetworkIdWidth),
    .NetworkIfVirtualChannelIdWidth  (NetworkIfVirtualChannelIdWidth),
    .NetworkIfNumberOfVirtualChannels(NetworkIfNumberOfVirtualChannels),
    .NetworkIfNumberOfVirtualNetworks(NetworkIfNumberOfVirtualNetworks),

    .AxiStreamTargetIfEnable    (AxiStreamInitiatorIfEnable),
    .AxiStreamTargetIfTDataWidth(AxiStreamInitiatorIfTDataWidth),
    .AxiStreamTargetIfTIdWidth  (AxiStreamInitiatorIfTIdWidth),
    .AxiStreamTargetIfTDestWidth(AxiStreamInitiatorIfTDestWidth),

    .AxiStreamInitiatorIfEnable    (AxiStreamTargetIfEnable),
    .AxiStreamInitiatorIfTDataWidth(AxiStreamTargetIfTDataWidth),
    .AxiStreamInitiatorIfTIdWidth  (AxiStreamTargetIfTIdWidth),
    .AxiStreamInitiatorIfTDestWidth(AxiStreamTargetIfTDestWidth),

    .FileRegInitiatorIfEnable    (0),
    .FileRegInitiatorIfTDataWidth(1),

    .FileRegTargetIfEnable    (0),
    .FileRegTargetIfTDataWidth(1)
  ) suni_inst (
     // clocks and resets
    .clk_s_axis_i   (clk_m_axis_i),
    .clk_m_axis_i   (clk_s_axis_i),
    .clk_network_i  (clk_network_i),
    .clk_upsizer_i  (clk_upsizer_i),
    .clk_downsizer_i(clk_downsizer_i),
  
    .rst_s_axis_ni  (rst_m_axis_ni),
    .rst_m_axis_ni  (rst_s_axis_ni),
    .rst_network_i  (rst_network_i),
    .rst_upsizer_i  (rst_upsizer_i),
    .rst_downsizer_i(rst_downsizer_i),
  
    // Configuration and monitoring file register access interface
    .filereg_s_tvalid_i(1'b0),
    .filereg_s_tready_o(),
    .filereg_s_tdata_i (0),
    .filereg_s_tlast_i (0),
    //
    .filereg_m_tvalid_o(),
    .filereg_m_tready_i(1'b1),
    .filereg_m_tdata_o (),
    .filereg_m_tlast_o (),

    // AXI-Stream (Target) interface to connect an AXI-Stream initiator unit
    .s_axis_tvalid_i(m_axis_tvalid),
    .s_axis_tready_o(m_axis_tready),
    .s_axis_tdata_i (m_axis_tdata),
    .s_axis_tlast_i (m_axis_tlast),
    .s_axis_tid_i   (m_axis_tid),
    .s_axis_tdest_i (m_axis_tdest),
  
    // AXI-Stream (Initiator) interface to connect an AXI-Stream target unit
    .m_axis_tvalid_o(s_axis_tvalid),
    .m_axis_tready_i(s_axis_tready),
    .m_axis_tdata_o (s_axis_tdata),
    .m_axis_tlast_o (s_axis_tlast),
    .m_axis_tid_o   (s_axis_tid),
    .m_axis_tdest_o (s_axis_tdest),
  
    // Custom interface for NoC Router connection.
    .network_valid_o             (network_valid_o),               
    .network_ready_i             (network_ready_i),               
    .network_flit_o              (network_flit_o),                
    .network_flit_type_o         (network_flit_type_o),           
    .network_broadcast_o         (network_broadcast_o),           
    .network_virtual_channel_id_o(network_virtual_channel_id_o),  
    .network_valid_i             (network_valid_i),   
    .network_ready_o             (network_ready_o),
    .network_flit_i              (network_flit_i),  
    .network_flit_type_i         (network_flit_type_i),   
    .network_broadcast_i         (network_broadcast_i),
    .network_virtual_network_id_i(network_virtual_network_id_i)   
  );     
    
endmodule
