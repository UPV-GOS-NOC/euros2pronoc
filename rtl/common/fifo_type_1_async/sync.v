// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//   
// @file fifo_sync.v
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date March 4th, 2024
//
// @title Asynchronous Clock Domain Data Synchronizer 
//
//  This module implements a serial shift register for synchronizing registers across two asynchronouss clock domains.
//  The sync module is fully configurable in data width, number of stages and initial data value after reset.
// 
//  
//   This module is based on the synchronizer.v module described in 
//     <verilog-basics/synchronizer.v: https://github.com/s-bear/verilog-basics/blob/master/synchronizer.v
//

`timescale 1 ns / 1 ps

module sync #(
  parameter AddressWidth = 16,
  parameter Stages    = 2,   // number of stages for data synchronization, cycles in out clk domain that out port will delay to reflect in port changes
  parameter InitValue = 0    // initial value during and after reset signal. empty/full may require different init value
) (
  input wire            clk, // Input: output domain clock
  input wire            rst, // Input: output domain reset, active high
  input wire [AddressWidth:0]  din,  // data input (source domain clk)
  output wire [AddressWidth:0] dout  // data output (target domain clk)
);
  localparam Width     = AddressWidth + 1;  // Width of data to pass from one clock domain to the other

  generate
    if (Stages <= 0) begin : sync_zero_stages
      assign dout = din;
    end else begin : sync_multi_stages
      reg [(Width*Stages)-1:0] shift_reg = {Stages{InitValue[Width-1:0]}}; // set initial value the same as for reset
      //assign out = shift_reg[(Width*Stages)-1:Width*(Stages-1)];
      assign dout = shift_reg[Width-1:0];

      always @(posedge clk or posedge rst) begin
        if(rst) begin
        //shift_reg <= {Stages{InitValue[Width-1:0]}};
          shift_reg <= {Stages{InitValue[Width-1:0]}};
        end else begin
        //shift_reg <= {shift_reg[Width*Stages-1:Width], in};
          shift_reg <= {din, shift_reg[Width*Stages-1:Width]};
        end
      end
    end
  endgenerate
endmodule
