// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_ejector_agent_pkg.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024

package network_ejector_agent_pkg;
  
  `include "network_flit_item.sv"
  `include "valid_ready_data_item.sv"
  `include "network_flit_generator.sv"
  `include "network_ejector_driver.sv"
  `include "network_ejector_monitor.sv"
  
endpackage