// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//   
// @file wr_ptr_full.v
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date March 5th, 2024
//
// @title Write pointer address handler and memory full flag generator
//
//  This module encloses the logic to:
//    generate the write address pointer for memory module
//    generate the fifo full signal
//
//  The write pointer is a dual n-bit Gray code counter. 
//  The write pointer is passed to the write clock domain through the <synch_w2r: synch_w2r> module.
//  The fifo full output is registered and is asserted on the next rising write clk edge when all the conditions to determine fifo .
//  The (n-1)-bit pointer ( wr_addr ) is used to address the memory buffer
// 
//  
//   This module is based on the rptr_empty.v module described in 
//     <Asynchronous dual clock FIFO: https://github.com/dpretet/async_fifo>
//   and
//     <Simulation and Synthesis Techniques for Asynchronous FIFO Design: http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf>, by Clifford E. Cummings 
//
// TODO: check that AddressWidth is at least 3 bits wide
//

`timescale 1 ns / 1 ps

module wr_ptr_full #(
  parameter AddressWidth = 16 // Number of bits required to represent a memory address
) (
  input wire                         wr_clk,     // Input: clock signal of fifo write domain 
  input wire                         wr_rst,     // Input: reset signal of fifo write doman
  input wire                         wr_req,     // Input: request to increase write counter and pointer
  input wire      [AddressWidth  :0] wr_q_rptr,  // Input: read pointer address from cross clock domain synchronizer (registered and debounced)
  output reg                         wr_full,    // Output: Flag to signal fifo is full
  output wire     [AddressWidth-1:0] wr_addr,    // Output: address to write data in memory. output for memory module
  output reg      [AddressWidth  :0] wr_ptr      // Output: next write pointer, grey counter value
);

  reg  [AddressWidth:0] wr_bin;       // binary value of grey current count
  wire [AddressWidth:0] wr_gray_next; // next value for gray counter
  wire [AddressWidth:0] wr_bin_next;  // bin value for rd_gray_next
  wire                  wr_full_val; // internal wire to flag when fifo is full (multiple conditions)

  // Memory read-address pointer (okay to use binary to address memory)
  assign wr_addr      = wr_bin[AddressWidth-1:0];
  
  // Set next values for gray counter and binary address
  assign wr_bin_next  = wr_bin + (wr_req & ~wr_full);
  assign wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;

  //-------------------
  // GRAYSTYLE2 counter pointer
  //-------------------
  always @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst) begin
      wr_bin <= 'b0;
      wr_ptr <= 'b0;
    end else begin 
      wr_bin <= wr_bin_next;
      wr_ptr <= wr_gray_next;
    end
  end

 // Set fifo full when the next gray counter matches condition or on reset
 // Early detection, comparing with next address pointer so walue will be correct on next cycle 
 //  to deal with the one clock delay introduced by registering the full singal
 //------------------------------------------------------------------
 // Simplified version of the three necessary full-tests:
 // assign wr_full_val = ((wr_gray_next[ADDRSIZE]     != wr_q_rptr[ADDRSIZE]) &&
 //                       (wr_gray_next[ADDRSIZE-1]   != wr_q_rptr[ADDRSIZE-1]) &&
 //                       (wr_gray_next[ADDRSIZE-2:0] == wr_q_rptr[ADDRSIZE-2:0]));
 //------------------------------------------------------------------
  assign wr_full_val = (wr_gray_next == {~wr_q_rptr[AddressWidth:AddressWidth-1], wr_q_rptr[AddressWidth-2:0]});

  always @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst) begin
      wr_full <= 1'b0;
    end else begin
      wr_full <= wr_full_val;
    end
  end

endmodule
