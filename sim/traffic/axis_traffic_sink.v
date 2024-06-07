// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file axis_traffic_sink.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date March 1st, 024
//
// @title AXI 4 stream traffic sink
//
//  Very SIMPLE sink for AXI 4 Stream transfers.
//  Only for other modules testbenching purposes
//

`timescale 1 ns / 1 ps

//`define  DEBUG_DISPLAY_TRAFFIC_SINK_ENABLE 1

module axis_traffic_sink #(
  parameter TDataWidth =  32,  // Width of (output) master data port in bits
  parameter TidWidth    =  8,
  parameter TdestWidth  =  8,
  parameter Tid         =  55,
  parameter Tdest       =  22
  ) (
  // testbench traffic and control ports
  input                           tb_ena, // module enable signal from testbench
  output [TDataWidth-1:0]         tb_tdata,
  output                          tb_tvalid,

  // slave interface (data input from Device Under Test)
  input                           s_axis_aclk,    // Input: clock signal of slave domain
  input                           s_axis_arstn,   // Input: reset signal of slave main
  input  [TidWidth-1:0]           s_axis_tid,     // Input: Data Stream Idenfitifier 
  input  [TdestWidth-1:0]         s_axis_tdest,   // Input: routing information for the data stream. Destination.
  input  [TDataWidth-1:0]         s_axis_tdata,   // Input: primary payload. Data to cross the interface
  input                           s_axis_tvalid,  // Input: indicates that the transmitter is driving a valid transfer
  input                           s_axis_tlast,   // Input: indicates the boundary of a packet
  output                          s_axis_tready   // Output: indicates that the module can accept data
  );

  reg [TDataWidth-1:0] tdata;
  reg tready;
  reg tvalid;

  wire tdata_in_valid_enabled = tb_ena && s_axis_tvalid;
  
  assign s_axis_tready = tready;
  
  assign tb_tdata  = tdata;
  assign tb_tvalid = tvalid;

  always @(posedge s_axis_aclk) begin
    if (!s_axis_arstn) begin
      tready <= 1'b0;
    end else begin
      if (tb_ena) begin
        tready <= 1'b1;
      end else begin
        tready <= 1'b0;
      end
    end
  end
      
  always @(posedge s_axis_aclk) begin
    if (!s_axis_arstn) begin
      tvalid = 0;
      tdata <= 'bX;
    end else begin
      tvalid <= s_axis_tvalid;
      tdata <= s_axis_tdata;
      if ((s_axis_tvalid) && (s_axis_tready)) begin  
        `ifdef DEBUG_DISPLAY_TRAFFIC_SINK_ENABLE
        $display("@traffic_sink: receive Data : 0x%02h", s_axis_tdata);
        `endif
      end
      // DO NOT modify valid signal or 
      // KEEP last value and valid signal until the other side 
      //  the master side of an axi module, but the tb_ena in this case for testbench
      //is available again, 
    end
  end

endmodule
