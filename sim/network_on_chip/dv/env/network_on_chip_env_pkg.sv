// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_env_pkg.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 08th, 2024
//
// @title Network-on-Chip environment package
//

package network_on_chip_env_pkg;
  
  import axi4stream_vip_pkg::*;  
  import axi4stream_vip_m_pkg::*;
  import axi4stream_vip_s_pkg::*;
  import network_on_chip_agent_pkg::*;
  
  typedef virtual axi4stream_vip_if #(
    .C_AXI4STREAM_SIGNAL_SET(axi4stream_vip_m_VIP_SIGNAL_SET),
    .C_AXI4STREAM_DEST_WIDTH(axi4stream_vip_m_VIP_DEST_WIDTH),
    .C_AXI4STREAM_DATA_WIDTH(axi4stream_vip_m_VIP_DATA_WIDTH),
    .C_AXI4STREAM_ID_WIDTH  (axi4stream_vip_m_VIP_ID_WIDTH),
    .C_AXI4STREAM_USER_WIDTH(axi4stream_vip_m_VIP_USER_WIDTH),
    .C_AXI4STREAM_USER_BITS_PER_BYTE(axi4stream_vip_m_VIP_USER_BITS_PER_BYTE),
    .C_AXI4STREAM_HAS_ARESETN(axi4stream_vip_m_VIP_HAS_ARESETN)
  ) axi4stream_manager_vip_vif_t;
  
  typedef virtual axi4stream_vip_if #(
    .C_AXI4STREAM_SIGNAL_SET(axi4stream_vip_s_VIP_SIGNAL_SET),
    .C_AXI4STREAM_DEST_WIDTH(axi4stream_vip_s_VIP_DEST_WIDTH),
    .C_AXI4STREAM_DATA_WIDTH(axi4stream_vip_s_VIP_DATA_WIDTH),
    .C_AXI4STREAM_ID_WIDTH  (axi4stream_vip_s_VIP_ID_WIDTH),
    .C_AXI4STREAM_USER_WIDTH(axi4stream_vip_s_VIP_USER_WIDTH),
    .C_AXI4STREAM_USER_BITS_PER_BYTE(axi4stream_vip_s_VIP_USER_BITS_PER_BYTE),
    .C_AXI4STREAM_HAS_ARESETN(axi4stream_vip_s_VIP_HAS_ARESETN)
  ) axi4stream_subordinate_vip_vif_t;  
  
  
  `include "network_on_chip_scoreboard.sv"
  `include "network_on_chip_env.sv"
  
endpackage
