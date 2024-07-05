// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file validready2noc_handshake_adapter_agent_pkg.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
//

package validready2noc_handshake_adapter_agent_pkg;

  `include "valid_ready_item.sv"
  `include "avail_valid_item.sv"
  `include "validready2noc_handshake_adapter_generator.sv"
  `include "validready2noc_handshake_adapter_driver.sv"
  `include "validready2noc_handshake_adapter_monitor.sv"

endpackage