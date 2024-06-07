// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file native_fifo_2_axi.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date March 11th, 2024
//
// @title Native flow control to AXI4-Stream handshake adapter
//
// SIMPLE Flow Control module to adapt signals from native flow control FIFO to
// (a very lite approximation of) AXI 4 Stream native flow control.
//
// Empty signal will arrive with a delay of one cycle compared to axi protocol behavior, 
// because axi assumes that data is read and processed since it triggers the flag, but 
// native flow control waits for "read" signal to remove the value from the fifo, so
// we need to register the data and synchronize it with "current" empty(s_native_tvalid) signal
//

`timescale 1 ns / 1 ps

//`define  DEBUG_DISPLAY_N2A_ENABLE 1

module native_fifo_2_axi #(
  parameter STDataWidth  = 32,  // Width of  data port in bits
  parameter TidWidth     =  8,
  parameter TdestWidth   =  8,
  parameter FirstWordFallThrough = "true" 
) (
  input                          aclk,    // Input: clock signal
  input                          arstn,   // Input: reset signal, active low
  
  // Data input from native flow control FIFO
  input  [TidWidth-1:0]          s_native_tid,     // Input: Data Stream Idenfitifier 
  input  [TdestWidth-1:0]        s_native_tdest,   // Input: routing information for the data stream. Destination.
  input  [STDataWidth-1:0]       s_native_tdata,   // Input: primary payload. Data to cross the interface
  input                          s_native_tvalid,  // Input: indicates that the transmitter is driving a valid transfer
  input                          s_native_tlast,   // Input: indicates the boundary of a packet
  output                         s_native_tready,  // Output:  indicates that the module can accept data
  
  // Data output: to next module with (reduced subset) AXI interface  
  output  [TidWidth-1:0]         m_axis_tid,     // Input: Data Stream Idenfitifier 
  output  [TdestWidth-1:0]       m_axis_tdest,   // Input: routing information for the data stream. Destination.
  output  [STDataWidth-1:0]      m_axis_tdata,   // Input: primary payload. Data to cross the interface
  output                         m_axis_tvalid,  // Input: indicates that the transmitter is driving a valid transfer
  output                         m_axis_tlast,   // Input: indicates the boundary of a packet
  input                          m_axis_tready   // Output: indicates that the module can accept data
);

  wire rst = !arstn;
  
  //enable read data from fifo when : (not in reset) & (next axi module can accept data) & (data is valid)
  //   data must be inmediately removed when possible to prevent "duplicated" valid data transmission
  assign s_native_tready = !rst & m_axis_tready & s_native_tvalid; 
  
  //assign m_axis_tvalid   = !rst & tvalid;
  assign m_axis_tvalid   = !rst & s_native_tvalid;
    
  generate
   if ( (FirstWordFallThrough == "true") || (FirstWordFallThrough == "TRUE") ) begin
     //synthesis translate_off
    initial begin
      $display("%m : Compile native_fifo_2_axi module for FirstWordFallThrough FIFO type: yes ");
    end
  //synthesis translate_on
    assign m_axis_tid    = s_native_tid;
    assign m_axis_tdest  = s_native_tdest;
    assign m_axis_tdata  = s_native_tdata;
    assign m_axis_tlast  = s_native_tlast;
    assign m_axis_tvalid = s_native_tvalid;
  end else begin 
       //synthesis translate_off
    initial begin
      $display("%m : Compile native_fifo_2_axi module for FirstWordFallThrough FIFO type: NO ");
    end
    //synthesis translate_on
    reg  [TidWidth-1:0]          tid;     // Input: Data Stream Idenfitifier 
    reg  [TdestWidth-1:0]        tdest;   // Input: routing information for the data stream. Destination.
    reg  [STDataWidth-1:0]       tdata;   // Input: primary payload. Data to cross the interface
    reg                          tvalid;  // Input: indicates that the transmitter is driving a valid transfer
    reg                          tlast;   // Input: indicates the boundary of a packet
    //reg                          tready;  // Output:  indicates that the module can accept data, combinational logic of reset and next module, bypassed
      assign m_axis_tid   = tid;
      assign m_axis_tdest = tdest;
      assign m_axis_tdata = tdata;
      assign m_axis_tlast = tlast;
      
      always @(posedge aclk) begin
        if (rst) begin
          tid    <=  'bX;
          tdest  <=  'bX;
          tdata  <=  'bX;
          tlast  <= 1'bX;
          tvalid <= 1'b0;
         end else begin
          tid    <= s_native_tid;
          tdest  <= s_native_tdest;
          tdata  <= s_native_tdata;
          tlast  <= s_native_tlast;
          tvalid <= s_native_tvalid;
        end
      end
  end
  endgenerate

endmodule
