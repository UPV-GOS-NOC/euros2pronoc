
//////////////////////////////////////////////////////////////////////////////////
// (c) Copyright 2012 - 2017  Parallel Architectures Group (GAP)
// Department of Computing Engineering (DISCA)
// Universitat Politecnica de Valencia (UPV)
// Valencia, Spain
// All rights reserved.
//
// All code contained herein is, and remains the property of
// Parallel Architectures Group. The intellectual and technical concepts
// contained herein are proprietary to Parallel Architectures Group and
// are protected by trade secret or copyright law.
// Dissemination of this code or reproduction of this material is
// strictly forbidden unless prior written permission is obtained
// from Parallel Architectures Group.
//
// THIS SOFTWARE IS MADE AVAILABLE "AS IS" AND IT IS NOT INTENDED FOR USE
// IN WHICH THE FAILURE OF THE SOFTWARE COULD LEAD TO DEATH, PERSONAL INJURY,
// OR SEVERE PHYSICAL OR ENVIRONMENTAL DAMAGE.
//
// contact: jflich@disca.upv.es
//-----------------------------------------------------------------------------
//
// Company:  GAP (UPV)
// Engineer: jomarm10 (jomarm10@gap.upv.es)
// Description: This module is an interface handshake adapter between data
// leaving the NoC towards the next module, the processing element or a FIFO.
// The endpoint module interface is an standard rtl valid/ready interface.
// 
//  -------     -----------------------------      ----------------------
//  |  NoC | --> | noc_out_handshake_adapter | --> | processing element |
//  -------     -----------------------------      ----------------------
//
// Some modules on this NoC generate data with a flight-time of two cycles. 
// This could lead to data loss when interfacing regular ready/valid handshake
// interfaces. So, this module deals with inflight data temporal buffering, and
// control signlas handshake between NoC output modules and the destination 
// input ports (regular rtl ready/valid handshake).
//
// To avoid data loss, this module implements:
//  an intermediate buffer for in-flight data
//  a handshake signals adapter 
//
// Revision:
// Revision 1.0 - File Created by V.Scotti (vinc94@gmail.com)  
// Revision 1.1 - Fix some fsm loops (replace concurrent assignments)

`timescale 1ns / 1ps
//`default_nettype none

module noc_outport_handshake_adapter #(
  parameter DataWidth = 0
) (
  input wire                  clk,
  input wire                  rst,
  // signals from NoC Local module interface to noc_outport_handshake_adapter
  input wire [DataWidth-1:0]  data_i,
  input wire                  data_valid_i,
  output reg                  avail_o,
  // signals from noc_outport_handshake_adapter to 
  //   RTL standard ready/valid interface (e.g. Xilinx native FIFO)
  output reg [DataWidth-1:0]  data_o,
  output reg                  data_valid_o,
  input  wire                 full_i
);

  //  fsm_state_e state, next_state;
  localparam IDLE = 1'b0;
  localparam MEM  = 1'b1;
  reg state;
  reg next_state;


  // Memory to store the valid data that could come in 
  // in same cycle full is asserted
  reg [DataWidth-1:0] data_i_buff = 0;
  reg                 data_valid_i_buff;
 
  
  // these are combinational paths
  reg                 data_valid_from_mux;
  reg [DataWidth-1:0] data_from_mux;
  reg                 buff_en;
  reg                 handshake_complete;

  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    next_state = IDLE;

    case (state)
      IDLE: begin
        if (buff_en) begin
          next_state = MEM;
        end
      end

      MEM: begin
        if (~handshake_complete) begin
          next_state = MEM;
        end
      end
    endcase
  end

  // It cannot be ~full_i because of in Valid/Ready handshake ready could be
  // asserted only when valid is asserted, but
  // in the network handshake valid cannot be asserted
  // upto avail_o is asserted, so the ejector would not receive valids
  // from network if the other end (Valid/Ready handshake) 
  // waits for valid before asserting ready since avaail_o = ~full_i
  // means propagate ready.
  always @(*) begin
    avail_o = (data_valid_o == 1'b0) || (handshake_complete == 1'b1); //~full_i;
  end
  
  always @(*) begin
    buff_en = (full_i == 1'b1) && (data_valid_i == 1'b1) && (data_valid_o == 1'b1);
  end
  
  always @(*) begin
    handshake_complete = (full_i == 1'b0) && (data_valid_o == 1'b1);
  end
  
  always @(posedge clk) begin
    if (rst) begin
      data_valid_i_buff <= 0;
      //data_i_buff <= 0;
    end else if (buff_en) begin 
      data_valid_i_buff <= data_valid_i;
      data_i_buff <= data_i;
    end
  end
  
  // Mux to select what goes to the data Valid/Ready interface
  //  Select==0: data coming from input
  //  Select==1: data coming from internal memory
  always @(*) begin
    data_valid_from_mux = data_valid_i;
    data_from_mux = data_i;
    
    if (state == MEM) begin
      data_valid_from_mux = data_valid_i_buff;
      data_from_mux       = data_i_buff;
    end
  end
  
  // Output data Valid/Ready interface
  always @(posedge clk) begin
    if (rst) begin
      data_valid_o <= 0;
      //data_o <= 0
   end else if ((handshake_complete) || (data_valid_o == 1'b0)) begin
      data_valid_o <= data_valid_from_mux;
      data_o       <= data_from_mux;
    end
  end

//  always @(posedge clk) begin
//    if (rst) begin
//      buff_en <= 1'b0;
//      data_valid_o <= data_valid_i;
//      data_o <= data_i;
//    end else begin
//      case (state)
//        IDLE: begin
//          buff_en <= 1'b1;
//          data_o <= data_i;
//          data_valid_o <= data_valid_i;
//        end
//        MEM: begin
//          buff_en <= 1'b0;
//          data_o <= data_i_buff;
//          data_valid_o <= data_valid_i_buff;
//        end
//        default: begin
//          buff_en <= 1'b0;
//          data_o <= data_i;
//          data_valid_o <= data_valid_i;
//        end
//      endcase
//    end
//  end
  
endmodule
