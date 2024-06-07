// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//   
// @file rd_ptr_empty.v
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date March 5th, 2024
//
// @title Read pointer address handler and memory empty flag generator
//
//  This module encloses the logic to:
//    generate the read address pointer for memory module
//    generate the fifo empty signal
//
//  The read pointer is a dual n-bit Gray code counter. 
//  The read pointer is passed to the write clock domain through the <synch_r2w: synch_r2w> module.
//  The FIFO empty output is registered and is asserted on the next rising read clk edge when the next rd_ptr value equals the synchronized write pointer value.
//  The (n-1)-bit pointer ( rd_addr ) is used to address the FIFO buffer.
//
//  
//   This module is based on the rptr_empty.v module described in 
//     <Asynchronous dual clock FIFO: https://github.com/dpretet/async_fifo>
//   and
//     <Simulation and Synthesis Techniques for Asynchronous FIFO Design: http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf>, by Clifford E. Cummings 
//

`timescale 1 ns / 1 ps

module rd_ptr_empty #(
  parameter AddressWidth = 16 // Number of bits required to represent a memory address
) (
  input wire                         rd_clk,     // Input: clock signal of read domain 
  input wire                         rd_rst,     // Input: reset signal of read doman
  input wire                         rd_req,     // Input: request to increase read counter and pointer
  input wire      [AddressWidth  :0] rd_q_wptr,  // Input: write pointer address from cross clock domain synchronizer (registered and debounced)
  output reg                         rd_empty,   // Output: Flag to signal fifo is empty
  output wire     [AddressWidth-1:0] rd_addr,    // Output: address to read. output for memory module
  output reg      [AddressWidth  :0] rd_ptr      // Output: next read pointer, grey counter value
);

  reg  [AddressWidth:0] rd_bin;       // binary value of grey current count
  wire [AddressWidth:0] rd_gray_next; // next value for gray counter
  wire [AddressWidth:0] rd_bin_next;  // bin value for rd_gray_next
  wire                  rd_empty_val; // internal wire to flag when fifo is empty (grey counter and write address pointer match)

  // Memory read-address pointer (okay to use binary to address memory)
  assign rd_addr      = rd_bin[AddressWidth-1:0];
  
  // Set next values for gray counter and binary address
  assign rd_bin_next  = rd_bin + (rd_req & ~rd_empty);
  assign rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;

  //-------------------
  // GRAYSTYLE2 counter pointer
  //-------------------
  always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst) begin
      rd_bin <= 'b0;
      rd_ptr <= 'b0;
    end else begin 
      rd_bin <= rd_bin_next;
      rd_ptr <= rd_gray_next;
    end
  end

  // Set FIFO empty when the next rptr == synchronized wptr or on reset
  // Early detection, comparing with next read address pointer so walue will be correct on next cycle 
  // (to deal with the one clock delay introduced by registering the empty singal"
  assign rd_empty_val = (rd_gray_next == rd_q_wptr);

  always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst) begin
      rd_empty <= 1'b1;
    end else begin
      rd_empty <= rd_empty_val;
    end
  end

endmodule
