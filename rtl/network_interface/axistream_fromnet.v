// SPDX-License-Identifier: MIT
//
// @copyright (c) 2024 Universitat Politecnica de Valencia (UPV)
// All right reserved
//
// @file axistream_fromnet.v
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date February 12th, 2024
//
// @title NoC protocol to AXI-Stream converter. 
//
// This module allows an application IP that uses the AXI Stream interface to connect to
// the network and receive data from other application IPs.
// 
// The module receives network packets, segmented in flits, and wraps them into
// AXI-Stream transfers
//
// In this module, we use 'm_axis' prefix to refer to the AXI-Stream Manager (Initiator) interface 
//
// Originally, the AXI Stream Specification contained terms that could be offensive. 
// However, UPV values inclusive communities, thus we have replaced these terms.
// We (as part of the UPV) have decided
// to use the terms Initiator for the entity which generates requests of some type, and Target for the
// entity the request is addressed to.
// If you find offensive terms in this module, please contact carles@upv.es
//

`timescale 1ns/1ns

module axistream_fromnet #(
  parameter integer AxiStreamIfTDataWidth = 0,  // AXI Stream interface configuration. Size (in bits) of the data signal
  parameter integer AxiStreamIfTIdWidth   = 0,  // AXI Stream interface configuration. Size (in bits) of the stream identifier signal
  parameter integer AxiStreamIfTDestWidth = 0,  // AXI Stream interface configuration. Size (in bits) of the stream destination signal

  parameter  integer NetworkIfFlitWidth             = 0,  // Network interface configuration. Size (in bits) of the data flit signal
  parameter  integer NetworkIfFlitTypeWidth         = 0,  // Network interface configuration. Size (in bits) of the Flit Type signal
  parameter  integer NetworkIfBroadcastWidth        = 0,  // Network interface configuration. Size (in bits) of the broadcast signal
  parameter  integer NetworkIfVirtualNetworkIdWidth = 0,  // Network interface configuration. Size (in bits) of the Virtual Network identifier
  localparam integer NetworkIfDataWidth = NetworkIfFlitWidth +
                                          NetworkIfFlitTypeWidth +
                                          NetworkIfBroadcastWidth +
                                          NetworkIfVirtualNetworkIdWidth  // Network configuration. Size (in bits) to pack the network signals
) (
  // Clocks and resets
  input clk_axis_i,
  input clk_network_i,
  input clk_upsizer_i,

  input rst_axis_ni,
  input rst_network_i,
  input rst_upsizer_i,

  // AXI Stream Initiator interface 
  output                             m_axis_tvalid_o,
  input                              m_axis_tready_i,
  output [AxiStreamIfTDataWidth-1:0] m_axis_tdata_o,
  output                             m_axis_tlast_o,
  output [AxiStreamIfTIdWidth-1:0]   m_axis_tid_o,
  output [AxiStreamIfTDestWidth-1:0] m_axis_tdest_o,

  // Network interface with packed data signals
  input                          network_valid_i,
  output                         network_ready_o,
  input [NetworkIfDataWidth-1:0] network_data_i
);

  wire rst_upsizer_n;

  // Drive signals between the network signal unpacker and the downsizer
  wire                                      network_valid;
  wire                                      network_ready;
  wire [NetworkIfFlitWidth-1:0]             network_flit;
  wire [NetworkIfFlitTypeWidth-1:0]         network_flit_type;
  wire [NetworkIfBroadcastWidth-1:0]        network_broadcast;
  wire [NetworkIfVirtualNetworkIdWidth-1:0] network_virtual_network_id;

  // Drive signals between the downsizer and upsizer
  wire                             axis_tvalid;
  wire                             axis_tready;
  wire [7:0]                       axis_tdata;
  wire                             axis_tlast;
  wire [AxiStreamIfTIdWidth-1:0]   axis_tid;
  wire [AxiStreamIfTDestWidth-1:0] axis_tdest;


  assign rst_upsizer_n = ~rst_upsizer_i;

  // Unpack network signals
  network_signal_converter #(
    .NetworkIfFlitWidth            (NetworkIfFlitWidth),
    .NetworkIfFlitTypeWidth        (NetworkIfFlitTypeWidth),
    .NetworkIfBroadcastWidth       (NetworkIfBroadcastWidth),
    .NetworkIfVirtualNetworkIdWidth(NetworkIfVirtualNetworkIdWidth)
  ) network_signal_unpacker_inst (
    .network_valid_i(network_valid_i),
    .network_ready_o(network_ready_o),
    .network_data_i (network_data_i),
 
    .network_valid_o             (network_valid),
    .network_ready_i             (network_ready),
    .network_flit_o              (network_flit),
    .network_flit_type_o         (network_flit_type),
    .network_broadcast_o         (network_broadcast),
    .network_virtual_network_id_o(network_virtual_network_id)
  );

  // Downsize incomming data to one byte
  network_data_axis_downsizer #(
    .AxisDataWidth(8),
    .TIdWidth     (AxiStreamIfTIdWidth),
    .TDestWidth   (AxiStreamIfTDestWidth),
    .KeepEnable   (0),

    .NocDataWidth(NetworkIfFlitWidth),
    .flitTypeSize(NetworkIfFlitTypeWidth)
  ) downsizer_to_onebyte_inst (
    .clk_noc    (clk_network_i),
    .m_axis_aclk(clk_upsizer_i),

    .rst_noc     (rst_network_i),
    .m_axis_arstn(rst_upsizer_n),

    // Network clock domain
    .network_valid_i             (network_valid),
    .network_ready_o             (network_ready),
    .network_flit_i              (network_flit),
    .network_flit_type_i         (network_flit_type),

    // Axi-Stream Upsizer clock domain
    .m_axis_tvalid(axis_tvalid),
    .m_axis_tready(axis_tready),
    .m_axis_tdata (axis_tdata),
    .m_axis_tid   (axis_tid),
    .m_axis_tdest (axis_tdest),
    .m_axis_tlast (axis_tlast),
    .m_axis_tkeep ()
    //.m_axis_tstrb_o  (),
    //.m_axis_tuser_o  (),
    //.m_axis_twakeup_o()
  );


  // Upsize incomming data (1byte) to the AXI-Stream data width
  // clk_upsizer = 4xclk_axis
  axis_data_upsizer #(
    .STDataWidth(8),
    .MTDataWidth(AxiStreamIfTDataWidth),
    .TidWidth   (AxiStreamIfTIdWidth),
    .TdestWidth (AxiStreamIfTDestWidth),
    .FifoDepth  (8)
  ) upsizer_inst (
    // Subordinate or Target AXI Stream Interface
    .s_axis_aclk  (clk_upsizer_i),
    .s_axis_arstn (rst_upsizer_n),
    .s_axis_tid   (axis_tid),
    .s_axis_tdest (axis_tdest),
    .s_axis_tdata (axis_tdata),
    .s_axis_tvalid(axis_tvalid),
    .s_axis_tlast (axis_tlast),
    .s_axis_tready(axis_tready),
    
    // Manger or Initiator AXI Stream interface
    .m_axis_aclk  (clk_axis_i),
    .m_axis_arstn (rst_axis_ni),
    .m_axis_tid   (m_axis_tid_o),
    .m_axis_tdest (m_axis_tdest_o),
    .m_axis_tdata (m_axis_tdata_o),
    .m_axis_tvalid(m_axis_tvalid_o),
    .m_axis_tlast (m_axis_tlast_o),
    .m_axis_tready(m_axis_tready_i)
  );


endmodule
