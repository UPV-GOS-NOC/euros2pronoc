// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file tb.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 05th, 2024
//
// @title Network on Chip testbench
//
// This module is used for verifying the NoC. 
// For that purpose, AXI-Stream frames are generated
// at the source and injected into the network through
// the Single Unit Network Interface. After traverse
// the network from the source to the destination, the
// AXI-Stream frames are delivered to a sink.
//
// It uses the Xilinx M_AXIS_VIP, as source, to generate AXI-Stream
// transfers and frames to feed the NI module
//
// It uses the Xilinx S_AXIS_VIP, as sink, so it generates the ready signal
// and to extract from the network the AXI-Stream frames injected
// at the source
//
// In addition, these VIPs allow us to generate/monitor 
// well formed AXI-Stream transfers.
//
//

`timescale 1ns/1ns

import network_on_chip_env_pkg::*;

module tb();
  
  parameter int NumberOfTiles = NUMBEROF_TILES; 

  localparam int CLK_NETWORK_PERIOD   = 20;
  localparam int CLK_M_AXIS_PERIOD    = 40;
  localparam int CLK_S_AXIS_PERIOD    = 40; 
  localparam int CLK_DOWNSIZER_PERIOD = CLK_NETWORK_PERIOD / 4;
  localparam int CLK_UPSIZER_PERIOD   = CLK_S_AXIS_PERIOD / 4; 

  bit clk_m_axis    = 0;
  bit rst_m_axis_n  = 0;
  bit clk_s_axis    = 0;
  bit rst_s_axis_n  = 0;  
  bit clk_network   = 0;
  bit rst_network   = 1;
  bit clk_upsizer   = 1;
  bit rst_upsizer   = 1;
  bit clk_downsizer = 1;
  bit rst_downsizer = 1;

  duv #(
    .AXIStreamTDataWidth(AXISTREAM_TDATA_WIDTH),
    .AXIStreamTIdWidth  (AXISTREAM_TID_WIDTH),
    .AXIStreamTDestWidth(AXISTREAM_TDEST_WIDTH),

    .Mesh2DTopologyDimensionX(MESH2D_TOPOLOGY_DIMENSIONX),
    .Mesh2DTopologyDimensionY(MESH2D_TOPOLOGY_DIMENSIONY),

    .NetworkSwitchAddressIdWidth   (NETWORK_SWITCH_ADDRESS_ID_WIDTH),
    .NetworkFlitWidth              (NETWORK_FLIT_WIDTH),
    .NetworkFlitTypeWidth          (NETWORK_FLIT_TYPE_WIDTH),
    .NetworkBroadcastWidth         (NETWORK_BROADCAST_WIDTH),
    .NetworkNumberOfVirtualNetworks(NETWORK_NUMBEROF_VIRTUAL_NETWORKS),
    .NetworkNumberOfVirtualChannels(NETWORK_NUMBEROF_VIRTUAL_CHANNELS),
    .NetworkVirtualNetworkIdWidth  (NETWORK_VIRTUAL_NETWORK_ID_WIDTH),
    .NetworkVirtualChannelIdWidth  (NETWORK_VIRTUAL_CHANNEL_ID_WIDTH)
  ) duv_inst (
     // clocks and resets
    .clk_s_axis_i   (clk_s_axis),
    .clk_m_axis_i   (clk_m_axis),
    .clk_network_i  (clk_network),
    .clk_upsizer_i  (clk_upsizer),
    .clk_downsizer_i(clk_downsizer),
  
    .rst_s_axis_ni  (rst_s_axis_n),
    .rst_m_axis_ni  (rst_m_axis_n),
    .rst_network_i  (rst_network),
    .rst_upsizer_i  (rst_upsizer),
    .rst_downsizer_i(rst_downsizer)
  );    

  network_on_chip_base_test #(
    .NumberOfTiles(NumberOfTiles)
  ) t0();

  
  always begin
    #CLK_NETWORK_PERIOD clk_network <= ~clk_network;
  end
  
  initial begin
    #(10*2*CLK_NETWORK_PERIOD+CLK_NETWORK_PERIOD) rst_network = 0;
  end    
  
  always #CLK_M_AXIS_PERIOD clk_m_axis <= ~clk_m_axis;  
  
  initial begin
    #(20*2*CLK_M_AXIS_PERIOD+CLK_M_AXIS_PERIOD) rst_m_axis_n = 1;
  end 
  
  always #CLK_S_AXIS_PERIOD clk_s_axis <= ~clk_s_axis;  
  
  initial begin
    #(20*2*CLK_S_AXIS_PERIOD+CLK_S_AXIS_PERIOD) rst_s_axis_n = 1;
  end   
  
  always #CLK_UPSIZER_PERIOD clk_upsizer <= ~clk_upsizer;    
  
  initial begin
    #(5*2*CLK_UPSIZER_PERIOD+CLK_UPSIZER_PERIOD) rst_upsizer = 0;
  end
  
  always #CLK_DOWNSIZER_PERIOD clk_downsizer <= ~clk_downsizer;    
  
  initial begin
    #(5*2*CLK_DOWNSIZER_PERIOD+CLK_DOWNSIZER_PERIOD) rst_downsizer = 0;
  end    
  
endmodule
