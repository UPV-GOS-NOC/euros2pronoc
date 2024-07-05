// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_ejector_env_pkg.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network ejector environment package
//

package network_ejector_env_pkg;
  
  import network_ejector_agent_pkg::*;
  
  `include "network_ejector_scoreboard.sv"
  `include "network_ejector_env.sv"
  
endpackage
