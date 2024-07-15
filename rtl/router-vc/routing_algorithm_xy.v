// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file routing_algorithm_xy.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date March 11th, 2024
//
// @title XY routing algorithm
//
//  This module implements the logic for XY routing algorithm
//

`timescale 1ns / 1ps
//`default_nettype none

`include "net_common.h"
`include "routing_algorithm_xy.h"

module routing_algorithm_xy #(
  parameter integer NodeId          = 0, //! Node Identifier
  parameter integer DimensionXWidth = 0, //! Number of bits required to represent the coordinates of a node in X-axis
  parameter integer DimensionYWidth = 0, //! Number of bits required to represent the coordinates of a node in Y-axis
  parameter [`AXIS_DIRECTION_WIDTH-1:0]  NodeIdIncreaseXAxis = `DIRECTION_EAST,   //! Node ID increment direction in X axis  Supported values: EASTWARDS WESTWARDS
  parameter [`AXIS_DIRECTION_WIDTH-1:0]  NodeIdIncreaseYAxis = `DIRECTION_SOUTH,  //! Node ID increment direction in Y axis. Supported values: NORTHWARDS SOUTHWARDS
  parameter integer NumberOfPorts   = 0
  ) (
  input [DimensionXWidth-1 : 0]  x_cur_i,
  input [DimensionYWidth-1 : 0]  y_cur_i, 
  input [DimensionXWidth-1 : 0]  x_dst_i,
  input [DimensionYWidth-1 : 0]  y_dst_i,
  output [NumberOfPorts-1 : 0]   valid_ports_out_o
  );
 
  // output port assignment
//  assign valid_ports_out_o[`PORT_N] = (x_cur_i == x_dst_i) & (y_cur_i > y_dst_i);
//  assign valid_ports_out_o[`PORT_E] = (x_cur_i < x_dst_i)                     ;
//  assign valid_ports_out_o[`PORT_W] = (x_cur_i > x_dst_i)                     ;
//  assign valid_ports_out_o[`PORT_S] = (x_cur_i == x_dst_i) & (y_cur_i < y_dst_i);
//  assign valid_ports_out_o[`PORT_L] = (x_cur_i == x_dst_i) & (y_cur_i == y_dst_i);
  
//  assign valid_ports_out_o[`XY_PORT_DIRECTION_INDEX_NORTH] = (x_cur_i == x_dst_i) & (y_cur_i > y_dst_i);
//  assign valid_ports_out_o[`XY_PORT_DIRECTION_INDEX_EAST]  = (x_cur_i < x_dst_i)                     ;
//  assign valid_ports_out_o[`XY_PORT_DIRECTION_INDEX_WEST]  = (x_cur_i > x_dst_i)                     ;
//  assign valid_ports_out_o[`XY_PORT_DIRECTION_INDEX_SOUTH] = (x_cur_i == x_dst_i) & (y_cur_i < y_dst_i);
//  assign valid_ports_out_o[`XY_PORT_DIRECTION_INDEX_LOCAL] = (x_cur_i == x_dst_i) & (y_cur_i == y_dst_i);

  wire stage_1_n;
  wire stage_1_e;
  wire stage_1_w;
  wire stage_1_s;

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
    end else if (NodeIdIncreaseXAxis == `DIRECTION_WEST) begin : node_id_grows_westwards
      assign stage_1_e = (x_dst_i < x_cur_i);
      assign stage_1_w = (x_dst_i > x_cur_i);
    end
  endgenerate
    
  assign valid_ports_out_o[`XY_PORT_DIRECTION_INDEX_NORTH] = (x_cur_i == x_dst_i) & stage_1_n;
  assign valid_ports_out_o[`XY_PORT_DIRECTION_INDEX_EAST]  = stage_1_e;
  assign valid_ports_out_o[`XY_PORT_DIRECTION_INDEX_WEST]  = stage_1_w;
  assign valid_ports_out_o[`XY_PORT_DIRECTION_INDEX_SOUTH] = (x_cur_i == x_dst_i) & stage_1_s;
  assign valid_ports_out_o[`XY_PORT_DIRECTION_INDEX_LOCAL] = (x_cur_i == x_dst_i) & (y_cur_i == y_dst_i);    

endmodule
