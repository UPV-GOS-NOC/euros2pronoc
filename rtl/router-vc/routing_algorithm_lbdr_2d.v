// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file routing_algorithm_xy.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date March 11th, 2024
//
// @title Logic Based Distributed Routing (LBDR) algorithm for 2D NoCs
//
//  This module implements the LBDR algorithm stage of the 5-stage pipelined router.
//  The routing logic is divided in two parts
//  The first part computes the relative position, compared to current router, of the packet’s destination from the current router
//  The algorithm provides all candidate output ports capable to route the packet as per 
//    lbdr and connectivity bits values. Thus, the module requires external tool to calculate 
//    lbdr and connectivity bits.
//
//  Node coordinates are encoded in the NodeID parameter and passed to this module
//    wire [num_bits_col-1:0] node_x;
//    wire [num_bits_row-1:0] node_y;
//    assign node_x = id[col_msb:col_lsb];
//    assign node_y = id[row_msb:row_lsb];
//
//  Generally, Node IDs for this router are expeted to be consecutive 
//  starting from 0 at coordinate x=0, y=0 and accounting following the next equation
//  NODE_ID = (current_row * number_of_cols ) + current_col
//
//
// ID grow direction EASTWARDS and NORTHWARDS
//  +-----+     +-----+     +-----+     +-----+     +-----+ 
//  | 10  | --- | 11  | --- | 12  | --- | 13  | --- | 14  |
//  +-----+     +-----+     +-----+     +-----+     +-----+
//     |           |           |           |           |  
//     |           |           |           |           |  
//  +-----+     +-----+     +-----+     +-----+     +-----+
//  |  5  | --- |  6  | --- |  7  | --- |  8  | --- |  9  |
//  +-----+     +-----+     +-----+     +-----+     +-----+
//     |           |           |           |           |  
//     |           |           |           |           |  
//  +-----+     +-----+     +-----+     +-----+     +-----+
//  |  0  | --- |  1  | --- |  2  | --- |  3  | --- |  4  |
//  +-----+     +-----+     +-----+     +-----+     +-----+
//

`timescale 1ns / 1ps
//`default_nettype none

`include "net_common.h"
`include "routing_algorithm_lbdr_2d.h"

module routing_algorithm_lbdr_2d #(
  parameter integer NodeId          = 0, //! Node Identifier
  parameter integer DimensionXWidth = 0, //! Number of bits required to represent the coordinates of a node in X-axis
  parameter integer DimensionYWidth = 0, //! Number of bits required to represent the coordinates of a node in Y-axis
  parameter [`AXIS_DIRECTION_WIDTH-1:0]  NodeIdIncreaseXAxis = `DIRECTION_EAST,   //! Node ID increment direction in X axis  Supported values: EASTWARDS WESTWARDS
  parameter [`AXIS_DIRECTION_WIDTH-1:0]  NodeIdIncreaseYAxis = `DIRECTION_NORTH,  //! Node ID increment direction in Y axis. Supported values: NORTHWARDS SOUTHWARDS 
  parameter integer NumberOfLBDRBits  = 0,
  parameter integer NumberOfPorts   = 0, //! number of ports in the router N-E-W-S-L
  parameter integer NumberOfPortsWidth = num_bits(NumberOfPorts)
  ) (
  input  [DimensionXWidth-1 : 0]  x_cur_i,
  input  [DimensionYWidth-1 : 0]  y_cur_i, 
  input  [DimensionXWidth-1 : 0]  x_dst_i,
  input  [DimensionYWidth-1 : 0]  y_dst_i,
  input  [NumberOfLBDRBits-1:0]   lbdr_bits_i, 
  output [NumberOfPorts-1:0]      valid_ports_out_o
  );

  // --------------------------------------------------------------------------
  // Functions Definition
  function integer num_bits;
    input integer value;
    begin
      num_bits = 0;
      for (num_bits = 0; value > 0; num_bits = num_bits+1) begin
        value = value >> 1;
      end
    end
  endfunction
  
  // --------------------------------------------------------------------------
  // LBDR bits
  wire Rne, Rnw; 
  wire Ren, Res;  
  wire Rwn, Rws; 
  wire Rse, Rsw;
  wire Cn, Ce, Cw, Cs;

  // output ports
  wire candidate_outport_n;
  wire candidate_outport_e;
  wire candidate_outport_w;
  wire candidate_outport_s;
  wire candidate_outport_l;
 
  // first stage values. Relative position of the packet’s destination
  wire stage_1_n;
  wire stage_1_e;
  wire stage_1_w;
  wire stage_1_s;

  // second stage values. Determines whether an output port is considered for routing the incoming packet when
  //   either one of the required conditions is met: the packet goes to a node in the required quadrant and 
  //   the turn is allowed by the bits connfiguration (see lbdr link for conditions details):
  wire stage_2_n;
  wire stage_2_e;
  wire stage_2_w;
  wire stage_2_s;

  // LBDR routing bits assignments
  assign Rne = lbdr_bits_i[`LBDR_2D_BIT_RNE];
  assign Rnw = lbdr_bits_i[`LBDR_2D_BIT_RNW];
  assign Ren = lbdr_bits_i[`LBDR_2D_BIT_REN];
  assign Res = lbdr_bits_i[`LBDR_2D_BIT_RES];
  assign Rwn = lbdr_bits_i[`LBDR_2D_BIT_RWN];
  assign Rws = lbdr_bits_i[`LBDR_2D_BIT_RWS];
  assign Rse = lbdr_bits_i[`LBDR_2D_BIT_RSE];
  assign Rsw = lbdr_bits_i[`LBDR_2D_BIT_RSW];

  // LBDR connectivity bits assignments
  assign Cn = lbdr_bits_i[`LBDR_2D_BIT_CN];
  assign Ce = lbdr_bits_i[`LBDR_2D_BIT_CE];
  assign Cw = lbdr_bits_i[`LBDR_2D_BIT_CW];
  assign Cs = lbdr_bits_i[`LBDR_2D_BIT_CS];

  // stage 1 assinments
  generate
    if (NodeIdIncreaseYAxis == `DIRECTION_NORTH) begin : node_id_grows_northwards
      assign stage_1_n = (y_dst_i > y_cur_i);
      assign stage_1_s = (y_dst_i < y_cur_i);
    end else if (NodeIdIncreaseYAxis == `DIRECTION_SOUTH) begin : node_id_grows_southwards
      assign stage_1_n = (y_dst_i < y_cur_i);
      assign stage_1_s = (y_dst_i > y_cur_i);
    end

    if (NodeIdIncreaseXAxis == `DIRECTION_EAST) begin : node_id_grows_eastwards
      assign stage_1_e = (x_dst_i > x_cur_i);
      assign stage_1_w = (x_dst_i < x_cur_i);
    end else if (NodeIdIncreaseXAxis == `DIRECTION_WEST) begin : node_id_grows_westtwards
      assign stage_1_e = (x_dst_i < x_cur_i);
      assign stage_1_w = (x_dst_i > x_cur_i);
    end
  endgenerate
  
  // stage 2 assignments
  assign stage_2_n = (stage_1_n & (~stage_1_e) & (~stage_1_w)) |
                     (stage_1_n &   stage_1_e  &   Rne) |
                     (stage_1_n &   stage_1_w  &   Rnw);
  assign stage_2_e = (stage_1_e & (~stage_1_n) & (~stage_1_s)) |
                     (stage_1_e &   stage_1_n  &   Ren) |
                     (stage_1_e &   stage_1_s  &   Res);
  assign stage_2_w = (stage_1_w & (~stage_1_n) & (~stage_1_s)) |
                     (stage_1_w &   stage_1_n  &   Rwn) |
                     (stage_1_w &   stage_1_s  &   Rws);
  assign stage_2_s = (stage_1_s & (~stage_1_e) & (~stage_1_w)) |
                     (stage_1_s &   stage_1_e  &   Rse) |
                     (stage_1_s &   stage_1_w  &   Rsw);

  // routing results, candidate output ports
  assign candidate_outport_n = stage_2_n & Cn;
  assign candidate_outport_e = stage_2_e & Ce;
  assign candidate_outport_w = stage_2_w & Cw;
  assign candidate_outport_s = stage_2_s & Cs;
  assign candidate_outport_l = (~stage_1_n) & (~stage_1_e) & (~stage_1_w) & (~stage_1_s);

//  initial begin
//    $display ("JM10  valores de las macros de los puertos  N  %d   E  %d   %d   %d    %d  ");
//  end
  
  // output port assignment
  assign valid_ports_out_o[`LBDR_2D_PORT_DIRECTION_INDEX_NORTH] = candidate_outport_n;
  assign valid_ports_out_o[`LBDR_2D_PORT_DIRECTION_INDEX_EAST]  = candidate_outport_e;
  assign valid_ports_out_o[`LBDR_2D_PORT_DIRECTION_INDEX_WEST]  = candidate_outport_w;
  assign valid_ports_out_o[`LBDR_2D_PORT_DIRECTION_INDEX_SOUTH] = candidate_outport_s;
  assign valid_ports_out_o[`LBDR_2D_PORT_DIRECTION_INDEX_LOCAL] = candidate_outport_l;

endmodule
