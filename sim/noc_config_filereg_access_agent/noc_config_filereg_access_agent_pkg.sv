// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_config_filereg_access_agent_pkg.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 23th, 2024
//
// Agent package to generate Configuration FileReg access transactions
// and encapsulate them into AXI-Stream single-transfer
// frames that the driver send to the AXIS Manager VIP
// core and then, to the AXIS Target interface of the NI
//
// Next, a network single-flit packet is generated
// by the NI and sent to a Target tile through 
// Configuration virtual network. In that tile,
// the NI receives the configuration message and
// drive the configuration port of the router in
// the target tile to write the register with the
// data coming in the configuration message

package noc_config_filereg_access_agent_pkg;
 
  import axi4stream_vip_pkg::*;
  import axi4stream_vip_m_pkg::*;
  import axi4stream_vip_s_pkg::*;

  typedef virtual filereg_if #(.DataSize(39))             filereg_vif_t;
  typedef virtual filereg_if #(.DataSize(43))             filereg_m_vif_t;
  typedef virtual filereg_if #(.DataSize(43)).manager     m_filereg_vif_t;
  typedef virtual filereg_if #(.DataSize(39)).subordinate s_filereg_vif_t;
  
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
  
  typedef config_filereg_item #(
    .ModuleAddressSize(11),

    .CommandFieldSize        (1),
    .RegisterAddressFieldSize(1),
    .PayloadFieldSize        (32),

    .NumberOfModules  (8),
    .NumberOfRegisters(16),
    .NumberOfCommands (2),

    .MessageSize(43)
  ) response_filereg_item_t;  

  `include "noc_config_filereg_access_agent_cov.sv"
  `include "noc_config_filereg_access_generator.sv"
  `include "noc_config_filereg_access_driver.sv"
  `include "noc_config_filereg_access_monitor.sv"
  
endpackage
