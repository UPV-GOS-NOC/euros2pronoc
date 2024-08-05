// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file single_unit_network_interface.v
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 26th, 2024
//
// @title Single Unit Network Interface
//
// Network Interface (NI) that simply allows to
// connect a unique UNIT to a Router.
//
// A UNIT is an application component that could
// require (or not) network services to carry out
// its function. Any sort of (pre)processing element
// or controller fall in the UNIT category in
// our NoC context.
//
// The NI supports the next interfaces to connect
// a UNIT to the network
//
// - AXI-Stream
// - <<add here others when supported>>
//
// The AXI-Stream is a communication protocol designed
// to transfer data streams between two components on a chip.
// It establishes a point-to-point connection,
// ensuring data flows directly from a single transmitter
// to a single receiver.
// Unlike memory access, which involves addresses,
// AXI-Stream focuses purely on the data itself.
// AXI-Stream implements a ready/valid handshake mechanism
// for reliable data transfer between source and destination modules.
// The transmitter (the UINIT) asserts a signal (TValid)
// to indicate that it has valid data (TData) to send.
// The receiver (The NI) responds with a TReady signal
// when it's ready to accept the data.
// This ensures that data is only transmitted when
// the receiving end is prepared to accept it,
// preventing data loss and improving overall system efficiency.
//
// In this module, we use 's_axis' and 'm_axis' prefix to refer to
// the AXI-Stream Subordinate or Target interface and
// Manager or Initiator interface
//
// Originally, the AXI Specification contained terms that could be offensive.
// However, UPV values inclusive communities, thus we have replaced these terms.
// We (as part of the UPV) have decided
// to use the terms Initiator for the entity which generates requests of some type, and Target for the
// entity the request is addressed to
// If you find offensive terms in this module, please contact carles@upv.es
//

`timescale 1ns/1ns

module single_unit_network_interface #(
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
  parameter integer AxiStreamInitiatorIfTDestWidth  = 0   // Unit AXI Stream Initiator interface configuration. Size (in bits) of the stream destination signal.
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

  // TODO interface to access the configuration and monitor register file

  // AXI-Stream (Target) interface to connect an AXI-Stream initiator unit
  input                                   s_axis_tvalid_i,
  output                                  s_axis_tready_o,
  input [AxiStreamTargetIfTDataWidth-1:0] s_axis_tdata_i,
  input                                   s_axis_tlast_i,
  input [AxiStreamTargetIfTIdWidth-1:0]   s_axis_tid_i,
  input [AxiStreamTargetIfTDestWidth-1:0] s_axis_tdest_i,

  // AXI-Stream (Initiator) interface to connect an AXI-Stream target unit
  output                                      m_axis_tvalid_o,
  input                                       m_axis_tready_i,
  output [AxiStreamInitiatorIfTDataWidth-1:0] m_axis_tdata_o,
  output                                      m_axis_tlast_o,
  output [AxiStreamInitiatorIfTIdWidth-1:0]   m_axis_tid_o,
  output [AxiStreamInitiatorIfTDestWidth-1:0] m_axis_tdest_o,

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

  // Width of the compound signals coming from the network
  localparam integer NetworkDataWidth = NetworkIfFlitWidth +
                                        NetworkIfFlitTypeWidth +
                                        NetworkIfBroadcastWidth +
                                        NetworkIfVirtualNetworkIdWidth;

  // Drive connections between Ejector and AXI-Stream fromnet (including mux and arbiter)
  wire                        data_from_network_valid;
  wire                        data_from_network_ready;
  wire [NetworkDataWidth-1:0] data_from_network;


  // Drive AXI-Stream tonet module signals and network output ports
  wire                                      network_valid;
  wire [NetworkIfFlitWidth-1:0]             network_flit;
  wire [NetworkIfFlitTypeWidth-1:0]         network_flit_type;
  wire [NetworkIfBroadcastWidth-1:0]        network_broadcast;
  wire [NetworkIfVirtualChannelIdWidth-1:0] network_virtual_channel_id;

  // Drive axistream fromnet and axi-stream (initiator) output port
  wire [AxiStreamInitiatorIfTDataWidth-1:0]  m_axis_tdata;
  wire                                       m_axis_tvalid;
  wire                                       m_axis_tlast;
  wire [AxiStreamInitiatorIfTIdWidth-1:0]    m_axis_tid;
  wire [AxiStreamInitiatorIfTDestWidth-1:0]  m_axis_tdest;

  wire s_axis_tready;

  // Drive handshake signals between AXI-Stream tonet and axi2noc_handshake converter
  wire axi2noc_valid;
  wire axi2noc_ready;

  assign s_axis_tready_o = s_axis_tready;

  assign m_axis_tvalid_o = m_axis_tvalid;
  assign m_axis_tdata_o  = m_axis_tdata;
  assign m_axis_tlast_o  = m_axis_tlast;
  assign m_axis_tid_o    = m_axis_tid;
  assign m_axis_tdest_o  = m_axis_tdest;

  assign network_valid_o              = network_valid;
  assign network_flit_o               = network_flit;
  assign network_flit_type_o          = network_flit_type;
  assign network_broadcast_o          = network_broadcast;
  assign network_virtual_channel_id_o = network_virtual_channel_id;

  generate
    // This interface is used for connecting to an initiator unit
    if (AxiStreamTargetIfEnable != 0) begin : axis_target_if
      axistream_tonet #(
        .AxiStreamIfTDataWidth(AxiStreamTargetIfTDataWidth),
        .AxiStreamIfTIdWidth  (AxiStreamTargetIfTIdWidth),
        .AxiStreamIfTDestWidth(AxiStreamTargetIfTDestWidth),

        .NetworkIfAddressId              (NetworkIfAddressId),
        .NetworkIfNumberOfVirtualNetworks(NetworkIfNumberOfVirtualNetworks),
        .NetworkIfFlitWidth              (NetworkIfFlitWidth),
        .NetworkIfFlitTypeWidth          (NetworkIfFlitTypeWidth),
        .NetworkIfBroadcastWidth         (NetworkIfBroadcastWidth),
        .NetworkIfVirtualChannelIdWidth  (NetworkIfVirtualChannelIdWidth)
      ) unit2network_decoupler_inst (
        .clk_axis_i     (clk_s_axis_i),
        .clk_network_i  (clk_network_i),
        .clk_downsizer_i(clk_downsizer_i),

        .rst_axis_ni    (rst_s_axis_ni),
        .rst_network_i  (rst_network_i),
        .rst_downsizer_i(rst_downsizer_i),

        .s_axis_tvalid_i(s_axis_tvalid_i),
        .s_axis_tready_o(s_axis_tready),
        .s_axis_tdata_i (s_axis_tdata_i),
        .s_axis_tlast_i (s_axis_tlast_i),
        .s_axis_tid_i   (s_axis_tid_i),
        .s_axis_tdest_i (s_axis_tdest_i),

        .network_valid_o             (axi2noc_valid),
        .network_ready_i             (axi2noc_ready),
        .network_flit_o              (network_flit),
        .network_flit_type_o         (network_flit_type),
        .network_broadcast_o         (network_broadcast),
        .network_virtual_channel_id_o(network_virtual_channel_id)
      );
    end else begin
      assign s_axis_tready   = 1'b1;  // perfect sink, although it is an invalid path actually
      assign axi2noc_valid   = 1'b0;
      assign network_flit    = {NetworkIfFlitWidth{1'b0}};
      assign network_flit_type = {NetworkIfFlitTypeWidth{1'b0}};
      assign network_broadcast = {NetworkIfBroadcastWidth{1'b0}};
      assign network_virtual_channel_id = {NetworkIfVirtualChannelIdWidth{1'b0}};
    end
  endgenerate


  generate
    // This interface is used for connecting to an AXI-Stream target unit
    if (AxiStreamInitiatorIfEnable != 0) begin : axis_initiator_if
      axistream_fromnet #(
        .AxiStreamIfTDataWidth(AxiStreamInitiatorIfTDataWidth),
        .AxiStreamIfTIdWidth  (AxiStreamInitiatorIfTIdWidth),
        .AxiStreamIfTDestWidth(AxiStreamInitiatorIfTDestWidth),

        .NetworkIfFlitWidth            (NetworkIfFlitWidth),
        .NetworkIfFlitTypeWidth        (NetworkIfFlitTypeWidth),
        .NetworkIfBroadcastWidth       (NetworkIfBroadcastWidth),
        .NetworkIfVirtualNetworkIdWidth(NetworkIfVirtualNetworkIdWidth)
      ) network_unit_decoupler_inst (
        .clk_axis_i   (clk_m_axis_i),
        .clk_network_i(clk_network_i),
        .clk_upsizer_i(clk_upsizer_i),

        .rst_axis_ni  (rst_m_axis_ni),
        .rst_network_i(rst_network_i),
        .rst_upsizer_i(rst_upsizer_i),

        .m_axis_tvalid_o(m_axis_tvalid),
        .m_axis_tready_i(m_axis_tready_i),
        .m_axis_tdata_o (m_axis_tdata),
        .m_axis_tlast_o (m_axis_tlast),
        .m_axis_tid_o   (m_axis_tid),
        .m_axis_tdest_o (m_axis_tdest),

        .network_valid_i(data_from_network_valid),
        .network_ready_o(data_from_network_ready),
        .network_data_i (data_from_network)
      );
    end else begin
      assign data_from_network_ready = 1'b1;  // perfect sink, although is an invalid path actually
      assign m_axis_tvalid = 1'b0;
      assign m_axis_tlast  = 1'b0;
      assign m_axis_tdata  = {AxiStreamInitiatorIfTDataWidth{1'b0}};
      assign m_axis_tid    = {AxiStreamInitiatorIfTIdWidth{1'b0}};
      assign m_axis_tdest  = {AxiStreamInitiatorIfTDestWidth{1'b0}};
    end
  endgenerate


  // Adapt standard valid/ready handshake to Router custom handshake
  validready2noc_handshake_adapter #(
    .NumberOfVirtualChannels(NetworkIfNumberOfVirtualChannels),
    .VirtualChannelIdWidth  (NetworkIfVirtualChannelIdWidth)
  ) traffic_injector_inst (
    .valid_i             (axi2noc_valid),
    .ready_o             (axi2noc_ready),
    .virtual_channel_id_i(network_virtual_channel_id),

    .valid_o(network_valid),
    .avail_i(network_ready_i)
  );

  // Entry point for the flits coming from the network through
  // the local port of the router
  network_ejector #(
    .NetworkIfFlitWidth              (NetworkIfFlitWidth),
    .NetworkIfFlitTypeWidth          (NetworkIfFlitTypeWidth),
    .NetworkIfBroadcastWidth         (NetworkIfBroadcastWidth),
    .NetworkIfVirtualNetworkIdWidth  (NetworkIfVirtualNetworkIdWidth),
    .NetworkIfNumberOfVirtualNetworks(NetworkIfNumberOfVirtualNetworks)
  ) traffic_ejector_inst (
    .clk_i(clk_network_i),

    .rst_i(rst_network_i),

    .valid_o(data_from_network_valid),
    .ready_i(data_from_network_ready),
    .data_o (data_from_network),

    // Router interface
    .network_valid_i             (network_valid_i),
    .network_ready_o             (network_ready_o),
    .network_flit_i              (network_flit_i),
    .network_flit_type_i         (network_flit_type_i),
    .network_broadcast_i         (network_broadcast_i),
    .network_virtual_network_id_i(network_virtual_network_id_i)
  );

  // TODO
  //network_interface_register_file #(
  //
  //) configuration_monitor_register_bank_inst (
  //
  //);

endmodule

