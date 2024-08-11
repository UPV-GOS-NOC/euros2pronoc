// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_config_filereg_access_env_pkg.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 22th, 2024
//
// @title Network-on-Chip Configuration File Register access environment package
//

package noc_config_filereg_access_env_pkg;
  
  import axi4stream_vip_pkg::*;
  import axi4stream_vip_m_pkg::*;
  import noc_config_filereg_access_agent_pkg::*;

  // AXI-Stream channel configuration
  parameter integer AXISTREAM_TDATA_WIDTH = 32;
  parameter integer AXISTREAM_TID_WIDTH   = 5;
  parameter integer AXISTREAM_TDEST_WIDTH = 11;

  // Tile that will issue filereg accesses
  parameter integer TILE_WITH_CONTROLLER = 0;
  
  // Virtual network used for control and status register access
  parameter integer CONFIG_FILEREG_VIRTUAL_NETWORK = 0;

  // NoC topology parameters
  parameter integer MESH2D_TOPOLOGY_DIMENSIONX = 4;
  parameter integer MESH2D_TOPOLOGY_DIMENSIONY = 2;
  parameter integer NUMBEROF_TILES = MESH2D_TOPOLOGY_DIMENSIONX * MESH2D_TOPOLOGY_DIMENSIONY;

  // NoC configuration parameters
  parameter integer NETWORK_SWITCH_ADDRESS_ID_WIDTH   = 11;
  parameter integer NETWORK_FLIT_WIDTH                = 64;
  parameter integer NETWORK_FLIT_TYPE_WIDTH           = 2;
  parameter integer NETWORK_BROADCAST_WIDTH           = 1;
  parameter integer NETWORK_NUMBEROF_VIRTUAL_CHANNELS = 4;
  parameter integer NETWORK_NUMBEROF_VIRTUAL_NETWORKS = 4;
  parameter integer NETWORK_VIRTUAL_CHANNEL_ID_WIDTH  = 3;
  parameter integer NETWORK_VIRTUAL_NETWORK_ID_WIDTH  = 3;

  typedef virtual axi4stream_vip_if #(
    .C_AXI4STREAM_SIGNAL_SET(axi4stream_vip_m_VIP_SIGNAL_SET),
    .C_AXI4STREAM_DEST_WIDTH(axi4stream_vip_m_VIP_DEST_WIDTH),
    .C_AXI4STREAM_DATA_WIDTH(axi4stream_vip_m_VIP_DATA_WIDTH),
    .C_AXI4STREAM_ID_WIDTH  (axi4stream_vip_m_VIP_ID_WIDTH),
    .C_AXI4STREAM_USER_WIDTH(axi4stream_vip_m_VIP_USER_WIDTH),
    .C_AXI4STREAM_USER_BITS_PER_BYTE(axi4stream_vip_m_VIP_USER_BITS_PER_BYTE),
    .C_AXI4STREAM_HAS_ARESETN(axi4stream_vip_m_VIP_HAS_ARESETN)
  ) axi4stream_manager_vip_vif_t;

  `include "noc_config_filereg_access_scoreboard.sv"
  `include "noc_config_filereg_access_env.sv"
  
endpackage
