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

//  parameter integer FLIT_WIDTH                = 64;
//  parameter integer FLIT_TYPE_WIDTH           = 2;
//  parameter integer BROADCAST_WIDTH           = 1;
//  parameter integer VIRTUAL_CHANNEL_ID_WIDTH  = 2;
//  parameter integer NUMBEROF_VIRTUAL_CHANNELS = 4;
//  parameter integer NUMBEROF_VIRTUAL_NETWORKS = 4;
//  parameter integer VIRTUAL_NETWORK_ID_WIDTH  = 2;


  `include "config_filereg_item.sv"

  typedef config_filereg_item #(
    .ModuleAddressSize(11),

    .CommandFieldSize        (2),
    .RegisterAddressFieldSize(5),
    .PayloadFieldSize        (32),

    .NumberOfModules  (8),
    .NumberOfRegisters(16),
    .NumberOfCommands (2),

    .MessageSize(39)
  ) request_filereg_item_t;

  `include "network_on_chip_driver_callback.sv"
  `include "network_on_chip_monitor_callback.sv"
  `include "network_on_chip_generator.sv"
  `include "router_filereg_access_request_generator.sv"
  `include "network_on_chip_driver.sv"
  `include "network_on_chip_monitor.sv"
  
endpackage
