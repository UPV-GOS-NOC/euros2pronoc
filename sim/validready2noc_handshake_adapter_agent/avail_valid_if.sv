// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file avail_valid_if.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Avail/Valid NoC handshake interface for 
//        validready2noc_handshake_dapter Testbench
//

interface avail_valid_if #(
  int NumberOfVirtualChannels = 0
);
  
  logic                               valid;
  logic [NumberOfVirtualChannels-1:0] avail;  
  
    
  modport driver(input valid,
                 output avail);
  
  modport monitor(input valid, avail);
  
  modport duv(input avail,
              output valid);

endinterface
