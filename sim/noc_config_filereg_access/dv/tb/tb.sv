// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file tb.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 23th, 2024
//
// @title Network Config FileReg Access testbench
//
// This module is used for verifying the access to the configuration
// filereg held at each router. 
//
// For that purpose, AXI-Stream frames, that encapsulate filereg messages,
// are generated at the source and injected into the network through
// the Single Unit Network Interface. After traverse
// the network from the source to the destination, the
// AXI-Stream frames are decapsulated and routed to the configuration
// port of the targeted router.
//
// It uses the Xilinx M_AXIS_VIP, as source, to generate AXI-Stream
// transfers and frames to feed the NI module
//
// This testbench and the whole simulation
// environment created can be used as reference to connect TinyCo
// in the system for filereg access.
//
// The AXIS VIP core allow us to generate/monitor 
// well formed AXI-Stream transfers, but constraint the
// simulation environments to simulators that can work
// with Xilinx Vivado libraries
//

`timescale 1ns/1ns

import noc_config_filereg_access_env_pkg::*;

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
  bit clk_upsizer   = 0;
  bit rst_upsizer   = 1;
  bit clk_downsizer = 0;
  bit rst_downsizer = 1;

  // Interfaces of the Router Register File
  // This interface generates responses to read requests
  filereg_if #(.DataSize(43)) router_m_mgt_if[0:NumberOfTiles-1](clk_network, rst_network);

  // This interface receives requests
  filereg_if #(.DataSize(39)) router_s_mgt_if[0:NumberOfTiles-1](clk_network, rst_network);

  duv #(
    .AXIStreamTDataWidth(AXISTREAM_TDATA_WIDTH),
    .AXIStreamTIdWidth  (AXISTREAM_TID_WIDTH),
    .AXIStreamTDestWidth(AXISTREAM_TDEST_WIDTH),

    .NoCControllerTile(TILE_WITH_CONTROLLER),

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
    .rst_downsizer_i(rst_downsizer),

    // Reg file Interfaces for request and response
    .m_filereg_if(router_m_mgt_if),
    .s_filereg_if(router_s_mgt_if)
  );
  
  noc_config_filereg_access_base_test #(
    .NumberOfTiles(NumberOfTiles)
  ) t0(duv_inst.\tile[0].noc_controller.m_axis_vip_inst .\m_axis_vip.inst .inst.IF,
       router_m_mgt_if,
       router_s_mgt_if
  ); 
  
  
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
