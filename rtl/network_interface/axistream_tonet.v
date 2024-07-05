// SPDX-License-Identifier: MIT
//
// @copyright (c) 2024 Universitat Politecnica de Valencia (UPV)
// All right reserved
//
// @file axistream_tonet.v
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Nov 23th, 2023
//
// @title AXI Stream interface to NoC protocol converter. 
//
// This module allows an application IP that uses the AXI Stream interface to connect to
// the network and send data to other application IPs.
// 
// The module receives AXI Stream transfers and wrap them up in network packets, that are
// segmented in flits, to be injected into the network
//
// In this module, we use 's_axis' prefix to refer to the AXI-Stream Subordinate (Target) interface 
//
// Originally, the AXI Stream Specification contained terms that could be offensive. 
// However, UPV values inclusive communities, thus we have replaced these terms.
// We (as part of the UPV) have decided
// to use the terms Initiator for the entity which generates requests of some type, and Target for the
// entity the request is addressed to.
// If you find offensive terms in this module, please contact carles@upv.es
//

`timescale 1ns/1ns

module axistream_tonet #(  
  parameter  integer AxiStreamIfTDataWidth   = 0,  // AXI Stream interface configuration. Size (in bits) of the data signal
  parameter  integer AxiStreamIfTIdWidth     = 0,  // AXI Stream interface configuration. Size (in bits) of the stream identifier signal
  parameter  integer AxiStreamIfTDestWidth   = 0,  // AXI Stream interface configuration. Size (in bits) of the stream destination signaly
  localparam integer AxiStreamIfTKeepWidth   = AxiStreamIfTDataWidth/8,  // AXI Stream interface configuration. Size (in bits) of TKEEP signal
  localparam integer AxiStreamIfTStrobeWidth = AxiStreamIfTDataWidth/8,  // AXI Stream interface configuration. Size (in bits) of Strobe signal
   
  parameter integer NetworkIfAddressId               = 0,  // Network interface configuration. Address identifier for this network interface   
  parameter integer NetworkIfNumberOfVirtualNetworks = 0,  // Network interface configuration. Number of Virtual networks
  parameter integer NetworkIfFlitWidth               = 0,  // Network interface configuration. Size (in bits) of the data flit signal
  parameter integer NetworkIfFlitTypeWidth           = 0,  // Network interface configuration. Size (in bits) of the Flit Type signal
  parameter integer NetworkIfBroadcastWidth          = 0,  // Network interface configuration. Size (in bits) of the broadcast signal
  parameter integer NetworkIfVirtualChannelIdWidth   = 0   // Network interface configuration. Size (in bits) of the Virtual Channel identifier
) (
  // Clocks and resets  
  input wire clk_axis_i,
  input wire clk_network_i,
  input wire clk_downsizer_i,

  input wire rst_axis_ni,
  input wire rst_network_i,
  input wire rst_downsizer_i,

  // AXI Stream Target interface 
  input  wire                             s_axis_tvalid_i,
  output wire                             s_axis_tready_o,
  input  wire [AxiStreamIfTDataWidth-1:0] s_axis_tdata_i,
  input  wire                             s_axis_tlast_i,
  input  wire [AxiStreamIfTIdWidth-1:0]   s_axis_tid_i,
  input  wire [AxiStreamIfTDestWidth-1:0] s_axis_tdest_i,

  // Network interface
  output wire                                      network_valid_o,
  input  wire                                      network_ready_i,
  output wire [NetworkIfFlitWidth-1:0]             network_flit_o,
  output wire [NetworkIfFlitTypeWidth-1:0]         network_flit_type_o,
  output wire [NetworkIfBroadcastWidth-1:0]        network_broadcast_o,
  output wire [NetworkIfVirtualChannelIdWidth-1:0] network_virtual_channel_id_o
);

  wire rst_downsizer_n;

  wire [AxiStreamIfTDataWidth-1:0] targetif_tdata;
  wire                             targetif_tvalid;
  wire                             targetif_tready;
  wire                             targetif_tlast;
  wire [AxiStreamIfTIdWidth-1:0]   targetif_tid;
  wire [AxiStreamIfTDestWidth-1:0] targetif_tdest;
 
  wire                                      network_valid;
  wire                                      network_ready;
  wire [NetworkIfFlitWidth-1:0]             network_flit;
  wire [NetworkIfFlitTypeWidth-1:0]         network_flit_type;
  wire [NetworkIfBroadcastWidth-1:0]        network_broadcast;
  wire [NetworkIfVirtualChannelIdWidth-1:0] network_virtual_channel_id;
 
 
  wire [AxiStreamIfTDataWidth-1:0]   signal_homogeneizator_tdata;
  wire [AxiStreamIfTKeepWidth-1:0]   signal_homogeneizator_tkeep;
  wire [AxiStreamIfTStrobeWidth-1:0] signal_homogeneizator_tstrb;
  wire                               signal_homogeneizator_tvalid;
  wire                               signal_homogeneizator_tready;
  wire                               signal_homogeneizator_tlast;
  wire [AxiStreamIfTIdWidth-1:0]     signal_homogeneizator_tid;
  wire [AxiStreamIfTDestWidth-1:0]   signal_homogeneizator_tdest;
  wire [AxiStreamIfTDataWidth/8-1:0] signal_homogeneizator_tuser;
  wire                               signal_homogeneizator_twakeup;

  wire [7:0]                       downsizer_tdata;
  wire                             downsizer_tvalid;
  wire                             downsizer_tready;
  wire                             downsizer_tlast;
  wire [AxiStreamIfTIdWidth-1:0]   downsizer_tid;
  wire [AxiStreamIfTDestWidth-1:0] downsizer_tdest;
 
  assign rst_downsizer_n = ~rst_downsizer_i;

  assign targetif_tdata  = s_axis_tdata_i;
  assign targetif_tvalid = s_axis_tvalid_i;
  assign s_axis_tready_o = targetif_tready;
  assign targetif_tlast  = s_axis_tlast_i;
  assign targetif_tid    = s_axis_tid_i;
  assign targetif_tdest  = s_axis_tdest_i;
  
 
  assign network_valid_o              = network_valid;
  assign network_ready                = network_ready_i;
  assign network_flit_o               = network_flit;
  assign network_flit_type_o          = network_flit_type;
  assign network_broadcast_o          = network_broadcast;
  assign network_virtual_channel_id_o = network_virtual_channel_id;


  // Provides all the signals of the AXI Stream specification
  // when some of them are not used to keep compatibility
  // among AXI stream modules that use different subsets
  axis_converter_signals #(
    .DataWidth(AxiStreamIfTDataWidth),
    
    .KeepEnable(0),
    
    .StrbEnable(0),
    
    .IdEnable(1),
    .TidWidth (AxiStreamIfTIdWidth),
    
    .DestEnable(1),
    .DestWidth (AxiStreamIfTDestWidth),
    
    .UserEnable(0),
    
    .LastEnable(1),
    
    .WakeupEnable(0),
    
    .ReadyEnable(1)
  ) axis_spec_signal_homogeneizator_inst (
    .s_axis_tdata  (targetif_tdata),
    .s_axis_tvalid (targetif_tvalid),
    .s_axis_tready (targetif_tready),
    .s_axis_tlast  (targetif_tlast),
    .s_axis_tid    (targetif_tid),
    .s_axis_tdest  (targetif_tdest),
    .s_axis_tkeep  (0),
    .s_axis_tstrb  (0),
    .s_axis_tuser  (0),
    .s_axis_twakeup(0),
    
    
    .m_axis_tdata  (signal_homogeneizator_tdata),
    .m_axis_tkeep  (signal_homogeneizator_tkeep),
    .m_axis_tstrb  (signal_homogeneizator_tstrb),
    .m_axis_tvalid (signal_homogeneizator_tvalid),
    .m_axis_tready (signal_homogeneizator_tready),
    .m_axis_tlast  (signal_homogeneizator_tlast),
    .m_axis_tid    (signal_homogeneizator_tid),
    .m_axis_tdest  (signal_homogeneizator_tdest),
    .m_axis_tuser  (signal_homogeneizator_tuser),
    .m_axis_twakeup(signal_homogeneizator_twakeup)
  );

  // Downsize the AXI-Stream incoming transfer to bytes
  // to facilitate the creation of flits
  axis_data_downsizer #(
    .STDataWidth(AxiStreamIfTDataWidth),
    .MTDataWidth(8),
    .TidWidth   (AxiStreamIfTIdWidth),
    .TdestWidth (AxiStreamIfTDestWidth),
    
    .FifoDepth(16)  
  ) onebyte_downsizer_inst (
    .s_axis_aclk  (clk_axis_i), 
    .s_axis_arstn (rst_axis_ni),
    .s_axis_tid   (signal_homogeneizator_tid), 
    .s_axis_tdest (signal_homogeneizator_tdest),
    .s_axis_tdata (signal_homogeneizator_tdata),
    .s_axis_tvalid(signal_homogeneizator_tvalid),
    .s_axis_tlast (signal_homogeneizator_tlast),
    .s_axis_tready(signal_homogeneizator_tready),

    .m_axis_aclk  (clk_downsizer_i),
    .m_axis_arstn (rst_downsizer_n),
    .m_axis_tid   (downsizer_tid),
    .m_axis_tdest (downsizer_tdest),
    .m_axis_tdata (downsizer_tdata),
    .m_axis_tvalid(downsizer_tvalid),
    .m_axis_tlast (downsizer_tlast),
    .m_axis_tready(downsizer_tready)
  );

  // Creates network packets & flits
  noc_packet_creator #(
    .AxisDataWidth(8),

    .NocDataWidth(NetworkIfFlitWidth),

    .NumVn(NetworkIfNumberOfVirtualNetworks),
    .NocVirtualChannelIdWidth(NetworkIfVirtualChannelIdWidth),
    
     // We expect that this is always 1 for now
    .NumVc(1),
    
    .flitTypeSize(NetworkIfFlitTypeWidth),
    
    .KeepEnable(0),
    
    .TIdWidth(AxiStreamIfTIdWidth),
    
    .TDestWidth(AxiStreamIfTDestWidth),
    
    .MaxPacketsEnable(0),
    
    //.MaxPackets(20),
    .source_id(NetworkIfAddressId)
  ) packet_creator_inst (
    .s_axis_aclk (clk_downsizer_i),
    .s_axis_arstn(rst_downsizer_n),
    
    .clk_noc(clk_network_i),
    .rst_noc(rst_network_i),
    
    .s_axis_tdata  (downsizer_tdata),
    .s_axis_tvalid (downsizer_tvalid),
    .s_axis_tready (downsizer_tready),
    .s_axis_tlast  (downsizer_tlast),
    .s_axis_tid    (downsizer_tid),
    .s_axis_tdest  (downsizer_tdest),
    .s_axis_tkeep  (0),
    .s_axis_tstrb  (0),
    .s_axis_user   (0),
    .s_axis_twakeup(0),
    
    
    .network_flit_o     (network_flit),
    .network_broadcast_o(network_broadcast),
    .network_vc_o       (network_virtual_channel_id),
    .network_valid_o    (network_valid),
    .network_ready_i    (network_ready),
    .network_flit_type_o(network_flit_type)
  );
endmodule
