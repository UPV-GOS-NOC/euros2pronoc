// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//   
// @file fifo_type_1_async.v
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date March 5th, 2024
//
// @title Fifo Memory Module, type 1, Asynchronous clock domains, Native Flow Control
//
//  This module implements a dual clock fifo, to buffer and move data between modules across asynchronous clock domains.
//  Output of fifo can be configured as:
//   Registerd
//   First Word Fall Through
//
//  
//   This module is based on the async_fifo.v module described in 
//     <Asynchronous dual clock FIFO: https://github.com/dpretet/async_fifo>
//   and
//     <Simulation and Synthesis Techniques for Asynchronous FIFO Design: http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf>, by Clifford E. Cummings 
//
// TODO: add asymetric data width for write/read domains
//

`timescale 1 ns / 1 ps

//`define DEBUG_DISPLAY_FIFO_TYPE_1_ASYNC_ENABLE 1
//`define DEBUG_SIMULATION_BEHAVIOURAL_RESET_MEM 1

module fifo_type_1_async #(
  parameter AddressWidth = 16, // Number of bits required to represent memory address
  parameter DataWidth = 64,  // Width of input / output data ports in bits 
  parameter SynchStages = 2, // Number of stages for control signals synchronization across clock domains 
  parameter FirstWordFallThrough = "true" // First Word Fall Through, When set to one, data in ouptut port is available at the same time that empty signal is set to zero. When set to zero, fifo output is registered, thus updated upon rd_req signal is set to one, one cycle delay
) (
  input wire                    rd_clk,   // Input: clock signal from read domain
  input wire                    rd_rst,   // Input: reset signal from read doman
  input wire                    rd_req,   // Input: request to read data from fifo (increase counter/pointer)
  output wire   [DataWidth-1:0] rd_data,  // Output: data read from fifo
  output wire                   rd_empty, // Output: Flag to signal fifo is empty
  input wire                    wr_clk,   // Input: clock signal from write domain 
  input wire                    wr_rst,   // Input: reset signal from write doman
  input wire                    wr_req,   // Input: request to write data into fifo (increase write counter and pointer)
  input wire    [DataWidth-1:0] wr_data,  // Input: data to store in fifo
  output wire                   wr_full   //Output: Flag to signal fifo is full
);
  wire [AddressWidth-1:0] wr_addr;
  wire [AddressWidth-1:0] rd_addr;
  
  wire [AddressWidth:0]   rd_ptr;    //                read address pointer in  read clock domain
  wire [AddressWidth:0]   wr_q_rptr; // sync value of  read address pointer in write clock domain
  wire [AddressWidth:0]   wr_ptr;    //               write address pointer in write clock domain
  wire [AddressWidth:0]   rd_q_wptr; // sync value of write address pointer in  read clock domain  
  
  //synthesis translate_off
  initial begin
    if(AddressWidth < 1) $display("%m : Warning: AddressWidth set to %d and must be > 0.", AddressWidth);
    if(DataWidth < 1) $display("%m : Warning: DataWidth set to %d and must be > 0.", DataWidth);
    if(SynchStages < 2) $display("%m : Warning: SynchStages set to %d and must be > 0.", SynchStages);
  end
  //synthesis translate_on
  
    // read address pointer synchronizer to write clock domain
  sync #(
    .AddressWidth (AddressWidth),
    .Stages (SynchStages),
    .InitValue (0)
  ) sync_r2w_i (
    .clk   (wr_clk),
    .rst   (wr_rst),
    .din   (rd_ptr),
    .dout  (wr_q_rptr)
  );
  
  // write address pointer synchronizer to read clock domain
  sync #(
    .AddressWidth (AddressWidth),
    .Stages (SynchStages),
    .InitValue (0)
  ) sync_w2r_i (
    .clk   (rd_clk),
    .rst   (rd_rst),
    .din   (wr_ptr),
    .dout  (rd_q_wptr)
  );
  
  
  `ifdef DEBUG_DISPLAY_FIFO_TYPE_1_ASYNC_ENABLE
  always @(posedge wr_clk) begin
    if (wr_req) begin
      $display("@fifo_type_1_asing wr_req %d   data = 0x%08h", wr_req, wr_data);
    end
  end
  always @(posedge rd_clk) begin
    if (rd_req) begin
      $display ("@fifo_type_1_async rd_req %d   data= 0x%08h", rd_req, rd_data);
    end
  end
  `endif
  // fifo_mem module instance
  fifo_mem #(
    .AddressWidth (AddressWidth),                // Number of bits required to represent memory address
    .DataWidth (DataWidth),
    .FirstWordFallThrough (FirstWordFallThrough)     // First Word Fall Through, When set to one, data in ouptut port is updated upong rd_req signal is set to one, one cycle delay 
  ) fifo_mem_i(
    `ifdef DEBUG_SIMULATION_BEHAVIOURAL_RESET_MEM
    .wr_rst    (wr_rst),
    `endif
    .wr_clk    (wr_clk),    // Input: clock signal from write domain
    .wr_req    (wr_req),    // Input: request to write data into memory (in wr_addr)
    .wr_addr   (wr_addr),   // Input: address where data will be stored
    .wr_data   (wr_data),   // Input: data to write in memory
    .wr_full   (wr_full),   // Input: mem full flag, it prevents to write data into memory address when mem is full to avoid data loss 
    .rd_clk    (rd_clk),    // Input: clock signal for read domain
    .rd_req    (rd_req),    // Input: request to read data from memory address. If FWFT is set to true, output data is present in outport after rd_addr update 
    .rd_addr   (rd_addr),   // Input: address to get the data from 
    .rd_data   (rd_data)    // Output: data from memory rd_addr 
  ); 
  
  // module instance to handle memory read address pointer and empty_memory flag
  rd_ptr_empty #(
    .AddressWidth (AddressWidth)
  )rd_ptr_empty_i (
    .rd_clk    (rd_clk),     // Input: clock signal from read domain 
    .rd_rst    (rd_rst),     // Input: reset signal from read doman
    .rd_req    (rd_req),     // Input: request to increase read counter and pointer
    .rd_q_wptr (rd_q_wptr),  // Input: write pointer address from cross clock domain synchronizer (registered and debounced)
    .rd_empty  (rd_empty),   // Output: Flag to signal fifo is empty
    .rd_addr   (rd_addr),    // Output: address to read. output for memory module
    .rd_ptr    (rd_ptr)      // Output: next read pointer, grey counter value
  ); 
  
  // module instance to handle memory write address pointer and full_memory flag
  wr_ptr_full #(
    .AddressWidth (AddressWidth)
  ) wr_ptr_full_i ( 
    .wr_clk     (wr_clk),     // Input: clock signal of fifo write domain 
    .wr_rst     (wr_rst),     // Input: reset signal of fifo write doman
    .wr_req     (wr_req),     // Input: request to increase write counter and pointer
    .wr_q_rptr  (wr_q_rptr),  // Input: read pointer address from cross clock domain synchronizer (registered and debounced)
    .wr_full    (wr_full),    // Output: Flag to signal fifo is full
    .wr_addr    (wr_addr),    // Output: address to write data in memory. output for memory module
    .wr_ptr     (wr_ptr)      // Output: next write pointer, grey counter value
  );
  
endmodule
