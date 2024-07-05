// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file valid_ready_if.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Valid/Ready standard handshake interface for 
//        validready2noc_handshake_dapter Testbench
//
//

// It represents a simple interface with:
// - Valid/Ready signals for handshaking
interface valid_ready_if #(
  int VirtualChannelIdWidth = 0
);
  
  logic                             valid;
  logic                             ready;
  logic [VirtualChannelIdWidth-1:0] virtual_channel_id;  
  
    
  modport driver(input ready,
                 output valid, virtual_channel_id);
  
  modport monitor(input valid, ready, virtual_channel_id);
  
  modport duv(input valid, virtual_channel_id,
              output ready);

endinterface
