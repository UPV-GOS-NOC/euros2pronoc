// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//   
// @file fifo_mem.v
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date March 4th, 2024
//
// @title Memory Module for FIFO
//
//  This module encloses the logic to generate the memory buffer of the fifo.
//
//  This memory module supports simulataneous read from and write to memory operations.
//  This memory operates in different clock domains for read and write signals.    
//  The control signals (read addr, write addr, full and empty) are generated and updated in <rd_ptr_empty: rd_ptr_empty.v> and <wr_ptr_full: wr_ptr_full.v> modules
//  to ensure propper values generation and stability after clock domain crossing. 
//
// 
//   This module is based on the fifomem.v module described in 
//     <Asynchronous dual clock FIFO: https://github.com/dpretet/async_fifo>
//   and
//     <Simulation and Synthesis Techniques for Asynchronous FIFO Design: http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf>, by Clifford E. Cummings
//
// TODO: add support for other memory types such as bram, or even vendor custom ip-cores 
//

`timescale 1 ns / 1 ps

//`define DEBUG_DISPLAY_FIFO_MEM_ENABLE 1
//`define DEBUG_SIMULATION_BEHAVIOURAL_RESET_MEM 1

module fifo_mem #(
  parameter AddressWidth = 16, // Number of bits required to represent memory address
  parameter DataWidth = 64,
  parameter FirstWordFallThrough = "true" // First Word Fall Through, When set to one, data in ouptut port is available at the same time that empty signal is set to zero. When set to zero, fifo output is registered, thus updated upon rd_req signal is set to one, one cycle delay 
) (
  `ifdef DEBUG_SIMULATION_BEHAVIOURAL_RESET_MEM
  input wire                    wr_rst,
  `endif
  input wire                    wr_clk,    // Input: clock signal of write domain
  input wire                    wr_req,    // Input: request to write data into memory (in wr_addr)
  input wire [AddressWidth-1:0] wr_addr,   // Input: address where data will be stored
  input wire [DataWidth-1:0]    wr_data,   // Input: data to write in memory
  input wire                    wr_full,   // Input: mem full flag, it prevents to write data into memory address when mem is full to avoid data loss 
  input wire                    rd_clk,    // Input: clock signal for read domain
  input wire                    rd_req,    // Input: request to read data from memory address. If FWFT is set to true, output data is present in outport after rd_addr update 
  input wire [AddressWidth-1:0] rd_addr,   // Input: address to read data
  output wire [DataWidth-1:0]   rd_data    // Output: requested data stored in address received in rd_addr 
); 
 
 wire ena_wr = !wr_full;
 
  // RTL Verilog memory model
  localparam Depth = 1 << AddressWidth;
  (* ram_style = "bram" *) reg [DataWidth-1:0] mem [0:Depth-1];

  //synthesis translate_off
  initial begin : mem_initialization_forsim
    integer d;
    for (d = 0; d < Depth; d = d + 1) begin
      mem[d] = 'b0;
    end
  end
  //synthesis translate_on
  
  `ifdef DEBUG_SIMULATION_BEHAVIOURAL_RESET_MEM
  integer loop_var_rst;
  reg     prev_wr_rst_val;
  `endif
  // write data logic  
  always @(posedge wr_clk) begin
    `ifdef DEBUG_SIMULATION_BEHAVIOURAL_RESET_MEM
    prev_wr_rst_val <= wr_rst;
    if ((prev_wr_rst_val == 1'b0) && (wr_rst == 1'b1) ) begin
      $display("@fifo_mem: SIMULATION ONLY -> reset memory array");
    end
    if(wr_rst) begin
      for (loop_var_rst = 0; loop_var_rst < Depth; loop_var_rst=loop_var_rst + 1) begin
        mem[loop_var_rst] <= 'b0;
      end
    end else begin
    `endif
      if (ena_wr) begin
        if (wr_req) begin
          mem[wr_addr] <= wr_data;
          `ifdef DEBUG_DISPLAY_FIFO_MEM_ENABLE
          $display ("@fifo_men: wr_req detected   mem[%2d] = 0x%08h", wr_addr, wr_data);
          `endif
        end
      end
  `ifdef DEBUG_SIMULATION_BEHAVIOURAL_RESET_MEM
    end
  `endif
  end
  
  //read data logic
  generate
  if ((FirstWordFallThrough == "true") || (FirstWordFallThrough == "TRUE")
    || (FirstWordFallThrough == "yes") || (FirstWordFallThrough == "YES")
  ) begin : fifo_mem_falltrhough // (FirstWordFallThrough == "TRUE") ) begin
    //synthesis translate_off
    initial begin
      $display ("fifo_mem: generating First Word Fall Thrugh memory type");
    end
    //synthesis translate_on
    assign rd_data = mem[rd_addr];
  end else begin : fifo_mem_registered_read
    //synthesis translate_off
    initial begin
      $display ("fifo_mem: generating registered memory type");
    end
    //synthesis translate_on
    reg [DataWidth-1:0] rd_data_r;
    assign rd_data = rd_data_r;
    always @(posedge rd_clk) begin
      if (rd_req) begin
        rd_data_r <= mem[rd_addr];
      end
    end
  end 
  
  `ifdef DEBUG_DISPLAY_FIFO_MEM_ENABLE
  always @(posedge rd_clk) begin
    if (rd_req) begin
      $display("@fifo_mem: rd_req detected   mem[%2d] = 0x%08h", rd_addr, mem[rd_addr]);
    end
  end
  `endif
  endgenerate

endmodule
