// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file axis_traffic_gen.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date March 1st, 2024
//
// @title AXI 4 stream traffic generator
//
//  Very SIMPLE generator for AXI 4 Stream transfers.
//  This module will generate simple axi transfers containing fields 
//   - tdata
//   - tvalid
//   - tlast
//   - tid
//  where tdata will be the only field with variable content.
//  This generator can generate transfers with tlast field enabled upon request of the top module when the tb_enable_req input port is set to one.
//  Only for other modules testbenching purposes
//

`define TDATA_INITIAL_VALUE 8'hA0
`define TDATA_INCR 8'h01

//`define  DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE 1

module axis_traffic_gen #(
  parameter integer TDataWidth =  32,  // Width of (output) master data port in bits
  parameter integer TidWidth   =  8,
  parameter integer TdestWidth =  8,
  parameter integer Tid        =  55,
  parameter integer Tdest      =  22
  ) (
  // testbench traffic control ports
  //input                           tb_tid,
  //input                           tb_tdest,
  input                           tb_ena, // module enable signal from testbench
  input                           tb_tlast_req,
  // master interface (data output to Device Under Test)
  input                           m_axis_aclk,    // Input: clock signal of slave domain
  input                           m_axis_arstn,   // Input: reset signal of slave main
  output  [TidWidth-1:0]          m_axis_tid,     // Output: Data Stream Idenfitifier 
  output  [TdestWidth-1:0]        m_axis_tdest,   // Output: routing information for the data stream. Destination.
  output  [TDataWidth-1:0]        m_axis_tdata,   // Output: primary payload. Data to cross the interface
  output                          m_axis_tvalid,  // Output: indicates that the transmitter is driving a valid transfer
  output                          m_axis_tlast,   // Output: indicates the boundary of a packet
  input                           m_axis_tready   // Output: indicates that the module can accept data
  );
  
  // local parameters
  localparam count_width = 32;
   
  reg [TDataWidth-1:0] tdata;
  reg [TDataWidth-1:0] tdata_prev;
  reg tvalid;
  reg tlast;
  reg keep_value_one_cycle_to_resume;
  
  reg tlast_already_sent;
  reg tb_tlast_send_prev;
  
  assign m_axis_tdata  = tdata;
  assign m_axis_tvalid = tvalid;
  assign m_axis_tlast  = tlast;
  assign m_axis_tid    = Tid;
  assign m_axis_tdest  = Tdest;
  
  
  always @(posedge m_axis_aclk) begin
    tdata_prev         <= tdata;
    tb_tlast_send_prev <= tb_tlast_req;
  end
  
  // enable one single tlast on tb_tlast_send port enable detection
  // to send another tlast frame, it is required to lower and then rise the tb_tlast_send inport again
  always @(posedge m_axis_aclk) begin
    if (!m_axis_arstn) begin
      tlast  <= 1'b0;
      tlast_already_sent <= 1'b0;
    end else begin
      if (tlast_already_sent == 1'b1) begin
        tlast <= 1'b0;
      end else  begin
        if ((tb_tlast_send_prev == 1'b0) && (tb_tlast_req == 1'b1)) begin
          tlast <= 1'b1;
          tlast_already_sent = 1'b1;
        end else begin
          tlast <= 1'b0;
          if (tb_tlast_req == 1'b0) begin
            tlast_already_sent <= 1'b0;
          end
        end
      end
    end
  end
   
  always @(posedge m_axis_aclk) begin
    if (!m_axis_arstn) begin
      tvalid <= 1'b0;
      tdata  <= `TDATA_INITIAL_VALUE;
      tdata_prev <= `TDATA_INITIAL_VALUE;
      keep_value_one_cycle_to_resume = 1'b1;
      tlast_already_sent <= 1'b0;
      `ifdef DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE
      $display("@axis_traffic_gen  on reset, prepare Initial value  0x%08h", `TDATA_INITIAL_VALUE);
      `endif
    end else begin
      `ifdef DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE
      $display("@axis_traffic_gen  tb_ena = %d   m_axis_tready = %d", tb_ena, m_axis_tready );
      `endif
      if (tb_ena == 1'b1) begin
        `ifdef DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE
        $display("@axis_traffic_gen  tb_ena is set, checking m_axis_tready ");
        `endif
        tvalid <= 1'b1;
        if (m_axis_tready == 1'b1) begin
          `ifdef DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE
          $display("@axis_traffic_gen  previous tdata value was read, prepare next value  0x%08h -->> 0x%08h", tdata, tdata + `TDATA_INCR);
          `endif
          tdata  <= tdata + `TDATA_INCR;;
        end else begin
          // next module did not read data, keep old value
        end
      end else begin
        tvalid <= 1'b0;
      end
    end
  end  

endmodule
