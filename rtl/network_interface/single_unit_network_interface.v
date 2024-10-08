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
// In addition to application interfaces, the NI provides
// a control and status register file interface, which could
// be used for accessing certain configuration address spaces.
// This interface is known as FileReg. It uses two given virtual
// networks for routing control and status messages (usually VN0 for requests
// and VN1 for responses). The request and response interfaces can be
// enabled and disabled independently. In case of disabling an interface, 
// the corresponding virtual network would be used for routing data
// packets, instead of routing control and status packets. 
// Anyway, it does not make sense (although it is possible) 
// to enable only the response interface when the request one is disabled.
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
// Notice:
//
// 1. The XXXTargetIf (s) ports of the NI must be connected
//    to YYYInitiatorIf (m) ports of the unit (processing element)
//    that is going to use the provided network services
//    and viceversa
//    The XXXTargetIf parameters of the NI must be connected
//    to YYYInitiatorIf parameters of the unit (processing element)
//    that is going to use the provided network services



`timescale 1ns/1ns

`include "net_common.h"

module single_unit_network_interface #(
  parameter integer NetworkIfAddressId               = 0,  // Network configuration. Address identifier for this network interface
  parameter integer NetworkIfFlitWidth               = 0,  // Network configuration. Flit size (in bits). This is the flow control unit used in the network. This is the network_layer_packet.
  parameter integer NetworkIfFlitTypeWidth           = 0,  // Network configuration. Flit type size (in bits).
  parameter integer NetworkIfBroadcastWidth          = 0,  // Network configuration. Size (in bits) of the broadcast signal
  parameter integer NetworkIfVirtualNetworkIdWidth   = 0,  // Network configuration. Size of virtual network identifier (in bits).
  parameter integer NetworkIfVirtualChannelIdWidth   = 0,  // Network configuration. Size of the virtual channel identifier (in bits).
  parameter integer NetworkIfNumberOfVirtualChannels = 0,  // Network configuration. Total number of virtual channels in the network.
  parameter integer NetworkIfNumberOfVirtualNetworks = 0,  // Network configuration. Total number of virtual networks.

  // Notice: The XXXTargetIf parameters of the NI must be connected
  // to YYYInitiatorIf parameters of the unit (processing element)
  // that is going to use the provided network services

  parameter integer AxiStreamTargetIfEnable     = 0,  // Unit AXI Stream Target interface configuration. 0 to disable the interface, any other value to enable it.
  parameter integer AxiStreamTargetIfTDataWidth = 0,  // Unit AXI Stream Target interface configuration. Size (in bits) of the data signal.
  parameter integer AxiStreamTargetIfTIdWidth   = 0,  // Unit AXI Stream Target interface configuration. Size (in bits) of the stream identifier signal.
  parameter integer AxiStreamTargetIfTDestWidth = 0,  // Unit AXI Stream Target interface configuration. Size (in bits) of the stream destination signal.

  parameter integer AxiStreamInitiatorIfEnable      = 0,  // Unit AXI Stream Initiator interface configuration. 0 to disable the interface, any other value to enable it.
  parameter integer AxiStreamInitiatorIfTDataWidth  = 0,  // Unit AXI Stream Initiator interface configuration. Size (in bits) of the data signal.
  parameter integer AxiStreamInitiatorIfTIdWidth    = 0,  // Unit AXI Stream Initiator interface configuration. Size (in bits) of the stream identifier signal.
  parameter integer AxiStreamInitiatorIfTDestWidth  = 0,  // Unit AXI Stream Initiator interface configuration. Size (in bits) of the stream destination signal.
  
  parameter integer FileRegInitiatorIfEnable     = 0,  // FileReg Initiator interface configuration. 0 to disable the interface, other value to enable it
  parameter integer FileRegInitiatorIfTDataWidth = 0,  // FileReg Initiator interface configuration. Size (in bits) of the data field

  parameter integer FileRegTargetIfEnable        = 0,  // FileReg Target interface configuration. 0 to disable the interface, other value to enable it.
  parameter integer FileRegTargetIfTDataWidth    = 0   // FileReg Target interface configuration. Size (in bits) of the data field
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

  // Interface to access the configuration and monitor register file
  input                                  filereg_s_tvalid_i,
  output                                 filereg_s_tready_o,
  input  [FileRegTargetIfTDataWidth-1:0] filereg_s_tdata_i,
  input                                  filereg_s_tlast_i,

  output                                    filereg_m_tvalid_o,
  input                                     filereg_m_tready_i,
  output [FileRegInitiatorIfTDataWidth-1:0] filereg_m_tdata_o,
  output                                    filereg_m_tlast_o,

  // Notice: The XXXTargetIf (s) ports of the NI must be connected
  // to YYYInitiatorIf (m) ports of the unit (processing element)
  // that is going to use the provided network services
  // and viceversa

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

  // Drive connections between Ejector and fromnets, these signals do not
  // traverse the demultplexor located at the output of network ejector
  wire [NetworkDataWidth-1:0] data_from_network;

  // Drive connections between network ejector and demultiplexor located at
  // the output of network ejector
  wire                        data_from_network_valid;
  reg                         data_from_network_ready; // It's combinational logic inside block always @(*)

  // Drive connections between ejector and demuliplexor, located at
  // the output of network ejector, and different fromnets
  // Currently, there are two fromnets: axistream_fromnet and filereg_fromnet
  reg  [1:0]                                network_ejector_demux_valid;
  wire [1:0]                                network_ejector_demux_ready;
  wire [NetworkIfVirtualNetworkIdWidth-1:0] network_ejector_demux_select;

  // Drive AXI-Stream tonet module signals and network injector input signals
  // This interface will be converted into a Transport Layer Packet (tlp) interface
  // in the future. It will facilitate maintainance when different protocols
  // will be routed through the network
  // The tonets enable the transport layer packet format and protocol
  wire                                      tlp_valid;
  wire                                      tlp_ready;
  wire [NetworkIfFlitWidth-1:0]             tlp_flit;
  wire [NetworkIfFlitTypeWidth-1:0]         tlp_flit_type;
  wire [NetworkIfBroadcastWidth-1:0]        tlp_broadcast;
  wire [NetworkIfVirtualChannelIdWidth-1:0] tlp_virtual_channel_id;

  // Drive local network traffic between network_injector and network_ejector  
  wire                                      local_network_traffic_valid;
  wire                                      local_network_traffic_ready;
  wire [NetworkIfFlitWidth-1:0]             local_network_traffic_flit;
  wire [NetworkIfFlitTypeWidth-1:0]         local_network_traffic_flit_type;
  wire [NetworkIfBroadcastWidth-1:0]        local_network_traffic_broadcast;
  wire [NetworkIfVirtualNetworkIdWidth-1:0] local_network_traffic_virtual_network_id;


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

        .network_valid_o             (tlp_valid),
        .network_ready_i             (tlp_ready),
        .network_flit_o              (tlp_flit),
        .network_flit_type_o         (tlp_flit_type),
        .network_broadcast_o         (tlp_broadcast),
        .network_virtual_channel_id_o(tlp_virtual_channel_id)
      );
    end else begin
      assign s_axis_tready = 1'b1;  // perfect sink, although it is an invalid path actually
      assign tlp_valid              = 1'b0;
      assign tlp_flit               = {NetworkIfFlitWidth{1'b0}};
      assign tlp_flit_type          = {NetworkIfFlitTypeWidth{1'b0}};
      assign tlp_broadcast          = {NetworkIfBroadcastWidth{1'b0}};
      assign tlp_virtual_channel_id = {NetworkIfVirtualChannelIdWidth{1'b0}};
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

        .network_valid_i(network_ejector_demux_valid[1]),
        .network_ready_o(network_ejector_demux_ready[1]),
        .network_data_i (data_from_network)
      );
    end else begin
      assign network_ejector_demux_ready[1] = 1'b1;  // perfect sink, although is an invalid path actually
      assign m_axis_tvalid = 1'b0;
      assign m_axis_tlast  = 1'b0;
      assign m_axis_tdata  = {AxiStreamInitiatorIfTDataWidth{1'b0}};
      assign m_axis_tid    = {AxiStreamInitiatorIfTIdWidth{1'b0}};
      assign m_axis_tdest  = {AxiStreamInitiatorIfTDestWidth{1'b0}};
    end
  endgenerate


//  // Adapt standard valid/ready handshake to Router custom handshake
//  validready2noc_handshake_adapter #(
//    .NumberOfVirtualChannels(NetworkIfNumberOfVirtualChannels),
//    .VirtualChannelIdWidth  (NetworkIfVirtualChannelIdWidth)
//  ) traffic_injector_inst (
//    .valid_i             (axi2noc_valid),
//    .ready_o             (axi2noc_ready),
//    .virtual_channel_id_i(network_virtual_channel_id),
//
//    .valid_o(network_valid),
//    .avail_i(network_ready_i)
//  );
  

  // It receives the Transport layer interface signals from the tonets
  // and generates the network layer interface signals consisting of
  // network packets and flits
  network_injector #(
    .NetworkIfAddressId              (NetworkIfAddressId),
    .NetworkIfFlitWidth              (NetworkIfFlitWidth),
    .NetworkIfFlitTypeWidth          (NetworkIfFlitTypeWidth),
    .NetworkIfBroadcastWidth         (NetworkIfBroadcastWidth),
    .NetworkIfVirtualNetworkIdWidth  (NetworkIfVirtualNetworkIdWidth),  
    .NetworkIfVirtualChannelIdWidth  (NetworkIfVirtualChannelIdWidth),  
    .NetworkIfNumberOfVirtualChannels(NetworkIfNumberOfVirtualChannels),
    .NetworkIfNumberOfVirtualNetworks(NetworkIfNumberOfVirtualNetworks)
  ) injector_inst (
    .clk_i(clk_network_i),
    .rst_i(rst_network_i), 
 
    // Transport layer packet interface coming from tonet
    .tlp_valid_i             (tlp_valid),
    .tlp_ready_o             (tlp_ready),
    .tlp_flit_i              (tlp_flit),
    .tlp_flit_type_i         (tlp_flit_type),
    .tlp_broadcast_i         (tlp_broadcast),
    .tlp_virtual_channel_id_i(tlp_virtual_channel_id),
   
    // Network interface with the router
    .network_valid_o             (network_valid_o),
    .network_avail_i             (network_ready_i),
    .network_flit_o              (network_flit_o),
    .network_flit_type_o         (network_flit_type_o),
    .network_broadcast_o         (network_broadcast_o),
    .network_virtual_channel_id_o(network_virtual_channel_id_o),
  
    // Network interface with the local ejector
    .local_valid_o             (local_network_traffic_valid),
    .local_ready_i             (local_network_traffic_ready),
    .local_flit_o              (local_network_traffic_flit),
    .local_flit_type_o         (local_network_traffic_flit_type),
    .local_broadcast_o         (local_network_traffic_broadcast),
    .local_virtual_network_id_o(local_network_traffic_virtual_network_id)
  ); 

  generate
    if (FileRegTargetIfEnable != 0) begin : filereg_target_if
  // TODO Not need by now, but instance here when required
  // FileReg target (Subordinate) interface part
  // (the manager part is the filereg entity)
  // It drives into the NoC responses to filereg access requests
    end else begin
      assign filereg_s_tready_o = 1'b1; // perfect sink by the moment
    end
  endgenerate

  // FileReg initiator (Manager) interface part
  // (The subordinate part is the filereg entity)
  // It attends access requests to router register file
  generate
    if (FileRegInitiatorIfEnable != 0) begin : filereg_initiator_if
      filereg_fromnet #(
        .FileRegIfDataWidth(FileRegInitiatorIfTDataWidth),

        .NetworkIfFlitWidth            (NetworkIfFlitWidth),
        .NetworkIfFlitTypeWidth        (NetworkIfFlitTypeWidth),
        .NetworkIfBroadcastWidth       (NetworkIfBroadcastWidth),
        .NetworkIfVirtualNetworkIdWidth(NetworkIfVirtualNetworkIdWidth)      
      ) network2filereg_decoupler_inst (
        .clk_i(clk_network_i),
        .rst_i(rst_network_i),

        .filereg_m_tvalid_o(filereg_m_tvalid_o),
        .filereg_m_tready_i(filereg_m_tready_i),
        .filereg_m_tdata_o (filereg_m_tdata_o),
        .filereg_m_tlast_o (filereg_m_tlast_o),

        .network_valid_i(network_ejector_demux_valid[0]),
        .network_ready_o(network_ejector_demux_ready[0]),
        .network_data_i (data_from_network)
      );

      // network_ejector_demux
      // Demultiplexor from Network Ejector Output interface
      // to different fromnets
      always @(*) begin
        data_from_network_ready = 0;
        network_ejector_demux_valid = 0;

        if (network_ejector_demux_select == 0) begin
          network_ejector_demux_valid[0] = data_from_network_valid;
          data_from_network_ready = network_ejector_demux_ready[0];
        end

        if (network_ejector_demux_select != 0) begin
          network_ejector_demux_valid[1] = data_from_network_valid;
          data_from_network_ready = network_ejector_demux_ready[1];
        end
      end

      // Unpack network signals for getting virtual network id,
      // which is required by network_ejector_demux
      network_signal_converter #(
        .NetworkIfFlitWidth            (NetworkIfFlitWidth),
        .NetworkIfFlitTypeWidth        (NetworkIfFlitTypeWidth),
        .NetworkIfBroadcastWidth       (NetworkIfBroadcastWidth),
        .NetworkIfVirtualNetworkIdWidth(NetworkIfVirtualNetworkIdWidth)
      ) network_signal_unpacker_inst (
        .network_valid_i(1'b0),
        .network_ready_o(),
        .network_data_i (data_from_network),
 
        .network_valid_o             (),
        .network_ready_i             (1'b0),
        .network_flit_o              (),
        .network_flit_type_o         (),
        .network_broadcast_o         (),
        .network_virtual_network_id_o(network_ejector_demux_select)
      );
    end else begin
      assign network_ejector_demux_ready[0] = 1'b1;  // perfect sink, although is an invalid path actually
      always @(*) network_ejector_demux_valid[0] = 1'b0;

      assign filereg_m_tvalid_o = 1'b0;
      assign filereg_m_tlast_o  = 1'b0;
      assign filereg_m_tdata_o  = {FileRegInitiatorIfTDataWidth{1'b0}};

      // In case reg file access is not enabled,
      // all networks will be for data, even Virtual Network 0
      always @(*) data_from_network_ready = network_ejector_demux_ready[1];
      always @(*) network_ejector_demux_valid[1] = data_from_network_valid;
    end
  endgenerate


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

    // Network interface for local traffic
    .local_valid_i             (local_network_traffic_valid),
    .local_ready_o             (local_network_traffic_ready),
    .local_flit_i              (local_network_traffic_flit),
    .local_flit_type_i         (local_network_traffic_flit_type),
    .local_broadcast_i         (local_network_traffic_broadcast),
    .local_virtual_network_id_i(local_network_traffic_virtual_network_id),

    // Network interface with the router
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

