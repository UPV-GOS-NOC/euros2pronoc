// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_agent_pkg.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 20th, 2024

package network_on_chip_agent_pkg;
 
 import axi4stream_vip_pkg::*;
 import axi4stream_vip_m_pkg::*;
 import axi4stream_vip_s_pkg::*; 

  parameter integer FLIT_WIDTH                = 64;
  parameter integer FLIT_TYPE_WIDTH           = 2;
  parameter integer BROADCAST_WIDTH           = 1;
  parameter integer VIRTUAL_CHANNEL_ID_WIDTH  = 2;
  parameter integer NUMBEROF_VIRTUAL_CHANNELS = 4;
  parameter integer NUMBEROF_VIRTUAL_NETWORKS = 4;
  parameter integer VIRTUAL_NETWORK_ID_WIDTH  = 2;
  
  `include "network_on_chip_generator.sv"
  `include "network_on_chip_driver.sv"
  `include "network_on_chip_monitor.sv"
  
endpackage
