// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file valid_ready_data_if.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Valid/Ready with data interface
//
// It represents a simple interface with:
// - Valid/Ready signals for handshaking
// - Single data packed vector signal
interface valid_ready_data_if #(
  int DataWidth = 0
) (
  input bit clk,
  input bit rst
);
  
  logic [DataWidth-1:0] data;
  logic                 valid;
  logic                 ready;
  
  clocking driver_clock_block @(posedge clk);
    //default input #1ns output #2ns;
    output ready;
    input  valid;
    input  data;
  endclocking
  
  clocking monitor_clock_block @(posedge clk);
    //default input #1ns output #2ns;
    input ready;
    input valid;
    input data;    
  endclocking
  
  modport driver (clocking driver_clock_block, 
                  input clk, rst);
  
  modport monitor (clocking monitor_clock_block, 
                   input clk, rst);

endinterface
