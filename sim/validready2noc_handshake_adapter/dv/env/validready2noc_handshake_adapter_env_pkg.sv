// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file validready2noc_handshake_adapter_env_pkg.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
//

package validready2noc_handshake_adapter_env_pkg;

  import validready2noc_handshake_adapter_agent_pkg::*;
  
  `include "validready2noc_handshake_adapter_scoreboard.sv"
  `include "validready2noc_handshake_adapter_env.sv"
  
endpackage