// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file axis_2_native_fifo.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date March 11th, 2024
//
// @title AXI4-Stream to Native flow control handshake adapter
// 
//  SIMPLE Flow Control module to adapt handshake from AXI 4 Stream (very lite) to
//  native flow control.
//

`timescale 1 ns / 1 ps

//`define  DEBUG_DISPLAY_A2N_ENABLE 1

module axis_2_native_fifo #(
  parameter STDataWidth  = 32,  // Width of  data port in bits
  parameter TidWidth     =  8,
  parameter TdestWidth   =  8
  //parameter FifoDepth   = 16
  //parameter FirstWordFallThrough = "true" // First Word Fall Through, When set to one, data in ouptut port is available at the same time that empty signal is set to zero. When set to zero, fifo output is registered, thus updated upon rd_req signal is set to one, one cycle delay
) (
  input                           aclk,    // Input: clock signal
  input                           arstn,   // Input: reset signal, active low

  // Data input: (reduced subset) AXI slave interface 
  input  [TidWidth-1:0]           s_axis_tid,     // Input: Data Stream Idenfitifier 
  input  [TdestWidth-1:0]         s_axis_tdest,   // Input: routing information for the data stream. Destination.
  input  [STDataWidth-1:0]        s_axis_tdata,   // Input: primary payload. Data to cross the interface
  input                           s_axis_tvalid,  // Input: indicates that the transmitter is driving a valid transfer
  input                           s_axis_tlast,   // Input: indicates the boundary of a packet
  output                          s_axis_tready,  // Output: indicates that the module can accept data
  
  // Data output: Native flow control interface
  //input                           m_native aclk,    // Input:  clock signal of slave domain
  //input                           m_native_arstn,   // Input:  reset signal of slave main
  output  [TidWidth-1:0]          m_native_tid,     // Output: Data Stream Idenfitifier 
  output  [TdestWidth-1:0]        m_native_tdest,   // Output: routing information for the data stream. Destination.
  output  [STDataWidth-1:0]       m_native_tdata,   // Output: primary payload. Data to cross the interface
  output                          m_native_tvalid,  // Output: indicates that the transmitter is driving a valid transfer
  output                          m_native_tlast,   // Output: indicates the boundary of a packet
  input                           m_native_tready   // Input:  indicates that the module can accept data
);

  reg tvalid;  // Output: indicates that the transmitter is driving a valid transfer
  reg tread;   // register to notify axi slave that data has been forwarded, will cause data update on port

  wire rst = !arstn;
 
  assign s_axis_tready = tread & m_native_tready;

  assign m_native_tid     = s_axis_tid;
  assign m_native_tdest   = s_axis_tdest;
  assign m_native_tdata   = s_axis_tdata;
  assign m_native_tvalid  = s_axis_tvalid & tvalid;
  //assign m_native_tvalid  = tvalid;
  assign m_native_tlast   = s_axis_tlast;

  always @(posedge aclk) begin
    if (rst) begin
      tread <= 0;
      tvalid <= 1'b0;
    end else begin
      if ((s_axis_tvalid==1) && (m_native_tready==1)) begin
        tread <= 1'b1;
        tvalid <= 1'b1;
      end else begin
        tread <= 1'b0;
        tvalid <= 1'b0;
      end
    end
  end

endmodule
