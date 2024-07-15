// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file axis_data_downsizer.v
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date: April 16th, 2024
//
// @title Testbench for Logic Based Distributed Routing (LBDR) algorithm for 3D (cube) NoCs
//
//  Work in Progress
//  Currently used to check whether calculated positions are correct
//

`define DEBUG_DISPLAY_TB_ROUTING_LBDR_2D_ENABLE 1
//                     NEWSUD
//`define ROUTING_PORT_NORTH (5'b10000)
//`define ROUTING_PORT_EAST  (5'b01000)
//`define ROUTING_PORT_WEST  (5'b00100)
//`define ROUTING_PORT_SOUTH (5'b00010)
//`define ROUTING_PORT_LOCAL (5'b00000)



`include "svut_h.sv"
`include "net_common.h"
`include "routing_algorithm_lbdr_2d.h"
`include "routing_algorithm_xy.h"

`timescale 1 ns / 1 ps

// RT_XY grows eastwards-southwards
`define RT_XY_GROW_EAST_SOUTH(xd,yd,xc,yc) ((xd<xc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_WEST ){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_WEST ){1'b0}}}) : \
                                            (xd>xc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_EAST ){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_EAST ){1'b0}}}) : \
                                            (yd<yc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_SOUTH){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_NORTH){1'b0}}}) : \
                                            (yd>yc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_NORTH){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_SOUTH){1'b0}}}) : \
                                                    ({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_LOCAL){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_LOCAL){1'b0}}}));

`define RT_XY_GROW_EAST_NORTH(xd,yd,xc,yc) ((xd<xc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_WEST ){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_WEST ){1'b0}}}) : \
                                            (xd>xc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_EAST ){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_EAST ){1'b0}}}) : \
                                            (yd>yc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_SOUTH){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_NORTH){1'b0}}}) : \
                                            (yd<yc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_NORTH){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_SOUTH){1'b0}}}) : \
                                                    ({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_LOCAL){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_LOCAL){1'b0}}}));
                                    
`define RT_XY_GROW_WEST_SOUTH(xd,yd,xc,yc) ((xd>xc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_WEST ){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_WEST ){1'b0}}}) : \
                                            (xd<xc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_EAST ){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_EAST ){1'b0}}}) : \
                                            (yd<yc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_SOUTH){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_NORTH){1'b0}}}) : \
                                            (yd>yc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_NORTH){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_SOUTH){1'b0}}}) : \
                                                    ({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_LOCAL){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_LOCAL){1'b0}}}));

`define RT_XY_GROW_WEST_NORTH(xd,yd,xc,yc) ((xd>xc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_WEST ){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_WEST ){1'b0}}}) : \
                                            (xd<xc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_EAST ){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_EAST ){1'b0}}}) : \
                                            (yd>yc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_SOUTH){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_NORTH){1'b0}}}) : \
                                            (yd<yc)?({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_NORTH){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_SOUTH){1'b0}}}) : \
                                                    ({{(`XY_NUM_PORT_DIRECTIONS - 1 - `XY_PORT_DIRECTION_INDEX_LOCAL){1'b0}}, {1'b1}, {(`XY_PORT_DIRECTION_INDEX_LOCAL){1'b0}}}));
                                   

module tb_routing_lbdr_2d;

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
  
  `SVUT_SETUP

  // --------------------------------------------------------------------------
  // Testbench Configuration Parameters
  
  // clocks and resets
  localparam ClockHalfPeriod = 5; // write domain clock half period in ticks set by timescale parameter value in this source file
  
  // NoC configuration Parameters
  localparam NumberOfColumns = 4;  // X dim
  localparam NumberOfRows    = 3;     // y dim
  localparam NumberOfNodes = NumberOfColumns * NumberOfRows;
  localparam NodeIdWidth   = num_bits(NumberOfNodes);
 
  localparam NumberOfRowsWidth    = num_bits(NumberOfRows - 1);
  localparam NumberOfColumnsWidth = num_bits(NumberOfColumns - 1);

  // LBDR 3D parameters
  localparam NumberOfLBDRRoutingBits = 8;
  localparam NumberOfLBDRConnectivityBits = 4;
  localparam [`AXIS_DIRECTION_WIDTH-1:0] NodeIdIncreaseXAxis = `DIRECTION_EAST;   //! Node ID increment direction in X axis  Supported values: EASTWARDS WESTWARDS
  localparam [`AXIS_DIRECTION_WIDTH-1:0] NodeIdIncreaseYAxis = `DIRECTION_SOUTH;  //! Node ID increment direction in Y axis. Supported values: NORTHWARDS SOUTHW
  localparam LBDRNumBits = NumberOfLBDRRoutingBits + NumberOfLBDRConnectivityBits;
  localparam NumberOfOutputPorts   = 5; // NEWS-Local

  // this is the source node for the routing algorithm
  // The NodeId is a parameter set at the initialization of the module, so cannot be modified during the tests
  // x=1, y=1,
  localparam NodeIdX = 1;
  localparam NodeIdY = 1;
  localparam [NodeIdWidth-1:0] NodeId = (NodeIdX + NodeIdY*NumberOfColumns);
  //localparam NodeIdOffsetXAxis = (NodeIdIncreaseXAxis == `DIRECTION_EAST) ? NodeIdX : (NumberOfColumns - 1 - NodeIdX);
  //localparam NodeIdOffsetYAxis = (NodeIdIncreaseYAxis == `DIRECTION_NORTH)?(NodeIdY*NumberOfColumns) : (NumberOfRows - 1 - NodeIdY) * NumberOfColumns;  
  //localparam [NodeIdWidth-1:0] NodeId = NodeIdOffsetYAxis + NodeIdOffsetXAxis;
  
  // miscelaneous variables
  integer x = 0;
  integer y = 0;

  integer id = 0;
  integer i = 0;
  integer j = 0; 
  
  // Registers and wires
  // clocks and resets 
  reg  clk;
  reg  rst;
  
  // NoC
  // 
  // reg  [NodeIdWidth-1:0] source_node_id;    // THIS register is replaced by NodeId since the value is fixed for the testbench  
  reg  [NodeIdWidth-1:0] destination_node_id;  //  this value will be variable during the tests
  wire [NumberOfOutputPorts-1:0] valid_ports_lbdr;  // candidate port to route the packet returned by lbdr routing moulde
  wire [NumberOfOutputPorts-1:0] valid_ports_xy;    // candidate port to route the packet returned by xy   routing moulde
  reg  [NumberOfOutputPorts-1:0] destination_node_id_expected_direction; // output port calculated with xy routing algorithm hardcoded at the top of this testbench. 
  
  // position of message src node NodeID (xyz coordinates), "THIS" node coordinates for routing algorithm
  reg [NumberOfColumnsWidth-1:0] x_src;
  reg [NumberOfRowsWidth-1:0]    y_src;// relative position of destination node (xyz coordinate)
  
  // xyz coordinates of destination node
  reg [NumberOfColumnsWidth-1:0] x_dst;
  reg [NumberOfRowsWidth-1:0]    y_dst;

  // LBDR 2D
  reg Rne, Rnw;
  reg Ren, Res;
  reg Rwn, Rws;
  reg Rse, Rsw;
  reg Cn, Ce, Cw, Cs;
  
  localparam NumberOfLBDRBits = NumberOfLBDRRoutingBits +  NumberOfLBDRConnectivityBits;
  //reg [NumberOfLBDRRoutingBits-1:0]      lbdr_routing_bits[NumberOfNodes-1:0];
  //reg [NumberOfLBDRConnectivityBits-1:0] lbdr_connectivity_bits[NumberOfNodes-1:0];
  
  //wire [NumberOfLBDRRoutingBits-1:0]      lbdr_rxy = lbdr_routing_bits[NodeId];
  //wire [NumberOfLBDRConnectivityBits-1:0] lbdr_cxy = lbdr_connectivity_bits[NodeId]; 
  reg  [NumberOfLBDRBits-1:0]             lbdr_bits[NumberOfNodes-1:0];

  //---------------------------------------------------------------------------
  // Initialization of LBDR 2D registers
  //  Implementing XY algorithm  
  
  
  integer node_id_offset_x_axis;
  integer node_id_offset_y_axis;  
  
//  wire loop_lbdr_id_x_offset     = (NodeIdIncreaseXAxis == `DIRECTION_EAST)   ? 0 : NumberOfColumns;
//  wire loop_lbdr_id_x_increment  = (NodeIdIncreaseXAxis == `DIRECTION_EAST)   ? 1 : (-1);
//  wire loop_lbdr_id_y_offset     = (NodeIdIncreaseYAxis == "NORTHTWARDS") ? 0 : NumberOfRows;
//  wire loop_lbdr_id_y_increment  = (NodeIdIncreaseYAxis == "NORTHTWARDS") ? 1 : (-1);
  initial begin
    // Initialize LBDR tables

    // routing bits for LBDR XY
    // allowed dimension changes:
    //  x -> y 
    // forbidden dimension changes (reverse):
    //  y -> x  
    //
    //  x {e,w}  y {n,s} 
    id = 0;
    
    // ID grow direction: eastwards and southwards
    for (y = 0; y < NumberOfRows; y++) begin
      for (x = 0; x < NumberOfColumns ; x++) begin
        id = y * NumberOfColumns + x;
        
        //node_id_offset_x_axis = (NodeIdIncreaseXAxis == `DIRECTION_EAST) ? x : (NumberOfColumns - 1 - x);
        //node_id_offset_y_axis = (NodeIdIncreaseYAxis == `DIRECTION_NORTH)?(y * NumberOfColumns) : (NumberOfRows - 1 - y) * NumberOfColumns;
        //id = node_id_offset_y_axis + node_id_offset_x_axis;
        
        
        $display("Initial. Assign LBDR bits.      x = %2d      y = %2d    node id = %2d", x, y, id);
        //$display("Initial. Assign LBDR bits.  off_x = %2d  off_y = %2d    node id = %2d", node_id_offset_x_axis, node_id_offset_y_axis, id);
      
        Rne = 1'b0;
        Rnw = 1'b0;
        
        Ren = 1'b1;
        Res = 1'b1;
    
        Rwn = 1'b1;
        Rws = 1'b1;
        
        Rse = 1'b0;
        Rsw = 1'b0;

        //lbdr_routing_bits[id] = { Rne, Rnw, Ren, Res,Rwn, Rws, Rse, Rsw };
        lbdr_bits[id][`LBDR_2D_BIT_RNE] = Rne;
        lbdr_bits[id][`LBDR_2D_BIT_RNW] = Rnw;
        lbdr_bits[id][`LBDR_2D_BIT_REN] = Ren;
        lbdr_bits[id][`LBDR_2D_BIT_RES] = Res;
        lbdr_bits[id][`LBDR_2D_BIT_RWN] = Rwn;
        lbdr_bits[id][`LBDR_2D_BIT_RWS] = Rws;
        lbdr_bits[id][`LBDR_2D_BIT_RSE] = Rse;
        lbdr_bits[id][`LBDR_2D_BIT_RSW] = Rsw;

        // x dim -> Ce, Cw
        // leftmost column
        if ( ((NodeIdIncreaseXAxis == `DIRECTION_EAST) && (x <= 0)) || ((NodeIdIncreaseXAxis == `DIRECTION_WEST) && (x >= (NumberOfColumns - 1))) )
          Cw = 1'b0;
        else
          Cw = 1'b1;
        // rightmost column
        if ( ((NodeIdIncreaseXAxis == `DIRECTION_EAST) && (x >= (NumberOfColumns - 1))) || ((NodeIdIncreaseXAxis == `DIRECTION_WEST) && (x <= 0)) )
          Ce = 1'b0;
        else
          Ce = 1'b1;
        
        // y dim -> Cn, Cs
        // lowermost
        if ( ((NodeIdIncreaseYAxis == `DIRECTION_NORTH) && (y <= 0)) || ((NodeIdIncreaseYAxis == `DIRECTION_SOUTH) && (y >= (NumberOfRows - 1))) )
          Cs = 1'b0;
        else
          Cs = 1'b1;
        
        // uppermost
        if ( ((NodeIdIncreaseYAxis == `DIRECTION_NORTH) && (y >= (NumberOfRows - 1))) || ((NodeIdIncreaseYAxis == `DIRECTION_SOUTH) && (y <= 0)) )
          Cn = 1'b0;
        else
          Cn = 1'b1;

        lbdr_bits[id][`LBDR_2D_BIT_CN] = Cn;
        lbdr_bits[id][`LBDR_2D_BIT_CE] = Ce;
        lbdr_bits[id][`LBDR_2D_BIT_CW] = Cw;
        lbdr_bits[id][`LBDR_2D_BIT_CS] = Cs;        
      end
    end
    
    
  end // end of initial
      
  //---------------------------------------------------------------------------
  // Modules instantiation
  wire [LBDRNumBits-1:0] lbdr_xy = lbdr_bits[NodeId];
  
  wire [NumberOfColumnsWidth-1:0] x_src_node;
  wire [NumberOfRowsWidth-1:0]    y_src_node;
  wire [NumberOfColumnsWidth-1:0] x_dst_node;
  wire [NumberOfRowsWidth-1:0]    y_dst_node;
  
  assign x_src_node = x_src;
  assign y_src_node = y_src;
  assign x_dst_node = x_dst;
  assign y_dst_node = y_dst;
  
  routing_algorithm_lbdr_2d #(
    .NodeId          (NodeId),
    .DimensionXWidth (NumberOfColumnsWidth),
    .DimensionYWidth (NumberOfRowsWidth),
    .NodeIdIncreaseXAxis (NodeIdIncreaseXAxis),
    .NodeIdIncreaseYAxis (NodeIdIncreaseYAxis),
    .NumberOfPorts   (NumberOfOutputPorts),
    .NumberOfLBDRBits    (NumberOfLBDRRoutingBits + NumberOfLBDRConnectivityBits)
  ) routing_algorithm_lbdr_2d_inst (
    .x_cur_i       (x_src_node),
    .y_cur_i       (y_src_node), 
    .x_dst_i       (x_dst_node),
    .y_dst_i       (y_dst_node),
    .lbdr_bits_i   (lbdr_xy),
    .valid_ports_out_o  (valid_ports_lbdr)
  );

  routing_algorithm_xy #(
    .NodeId          (NodeId),
    .DimensionXWidth (NumberOfColumnsWidth),
    .DimensionYWidth (NumberOfRowsWidth),
    .NodeIdIncreaseXAxis (NodeIdIncreaseXAxis),
    .NodeIdIncreaseYAxis (NodeIdIncreaseYAxis),
    .NumberOfPorts   (NumberOfOutputPorts)
  ) routing_algorithm_xy_inst (
    .x_cur_i       (x_src_node),
    .y_cur_i       (y_src_node), 
    .x_dst_i       (x_dst_node),
    .y_dst_i       (y_dst_node),
    .valid_ports_out_o  (valid_ports_xy)
  );


  // Testbench loops and tasks
  initial clk = 1'b0;
  always #(ClockHalfPeriod) clk = ~clk;

  task setup(string msg="Setup testcase");
  begin 
    rst = 1'b1;
  
    // exit reset status
    #(6 * ClockHalfPeriod);
    @(posedge clk);
    rst = 1'b0;

    // end of initialization task
    #(2 * ClockHalfPeriod);
    @(posedge clk);
    
  end
  endtask
  
  task teardown(msg="Tearing down");
  begin
     #(2 * ClockHalfPeriod);
  end
  endtask
  
  // 
  // Testbench 
  `TEST_SUITE("TESTBENCH LBDR_3D_XY")

  `UNIT_TEST("MULTI_TEST")
//  // fill source and destination registers for this unit test 
    //set current node coordinates
    //x_cur = NodeId % NumberOfColumns; // Current Node location x_coordinate: column number 
    //y_cur = (NodeId % NumberOfNodesPerLayer) / NumberOfColumns; // Current node location y_coordinate: row number . It requires removing the layer offset
    x_src = NodeIdX;
    y_src = NodeIdY;// relative position of destination node (xyz coordinate)
 
 
    for (j = 0; j < NumberOfRows; j = j + 1) begin
      for(i = 0; i < NumberOfColumns; i = i + 1) begin
        destination_node_id = (i + j*NumberOfColumns);
        destination_node_id = (i + (NumberOfRows -1 - j) * NumberOfColumns);
        
        //node_id_offset_x_axis = (NodeIdIncreaseXAxis == `DIRECTION_EAST) ? i : (NumberOfColumns - 1 - i);
        //node_id_offset_y_axis = (NodeIdIncreaseYAxis == `DIRECTION_NORTH)?(j*NumberOfColumns) : (NumberOfRows -1 - j) * NumberOfColumns;
        //destination_node_id = node_id_offset_y_axis + node_id_offset_x_axis;       
          
        @(posedge clk);
        x_dst = i;      
        y_dst = j;
        //x_dst = node_id_offset_x_axis;      
        //y_dst = node_id_offset_y_axis;
        
        if ((NodeIdIncreaseXAxis == `DIRECTION_EAST) && (NodeIdIncreaseYAxis == `DIRECTION_NORTH)) begin
          destination_node_id_expected_direction = `RT_XY_GROW_EAST_NORTH(x_dst,y_dst, x_src,y_src);
        end else if ((NodeIdIncreaseXAxis == `DIRECTION_EAST) && (NodeIdIncreaseYAxis == `DIRECTION_SOUTH)) begin
          destination_node_id_expected_direction = `RT_XY_GROW_EAST_SOUTH(x_dst,y_dst, x_src,y_src);
        end else if ((NodeIdIncreaseXAxis == `DIRECTION_WEST) && (NodeIdIncreaseYAxis == `DIRECTION_NORTH)) begin
          destination_node_id_expected_direction = `RT_XY_GROW_WEST_NORTH(x_dst,y_dst, x_src,y_src);
        end else if ((NodeIdIncreaseXAxis == `DIRECTION_WEST) && (NodeIdIncreaseYAxis == `DIRECTION_SOUTH)) begin
          destination_node_id_expected_direction = `RT_XY_GROW_WEST_SOUTH(x_dst,y_dst, x_src,y_src);
        end
        
        
        @(posedge clk);
          
        `FAIL_IF_NOT_EQUAL(destination_node_id_expected_direction, valid_ports_lbdr, "Unexpected rt output port");
         //if(destination_node_id_expected_direction != valid_ports_lbdr) begin
          $display("DEBUG: dst_node %2d   src_node %2d", destination_node_id,NodeId);
          $display(" LBDR  dst x = %d  y = %d   src x = %d  y = %d ", x_dst, y_dst, x_src, y_src);
          $display("                  N  E  W  S  L");
          $display("       expected %3d%3d%3d%3d%3d",
                           destination_node_id_expected_direction[`XY_PORT_DIRECTION_INDEX_NORTH],
                           destination_node_id_expected_direction[`XY_PORT_DIRECTION_INDEX_EAST],
                           destination_node_id_expected_direction[`XY_PORT_DIRECTION_INDEX_WEST],
                           destination_node_id_expected_direction[`XY_PORT_DIRECTION_INDEX_SOUTH],
                           destination_node_id_expected_direction[`XY_PORT_DIRECTION_INDEX_LOCAL]
                           );
          $display("       granted  %3d%3d%3d%3d%3d",  
                           valid_ports_lbdr[`LBDR_2D_PORT_DIRECTION_INDEX_NORTH],
                           valid_ports_lbdr[`LBDR_2D_PORT_DIRECTION_INDEX_EAST],
                           valid_ports_lbdr[`LBDR_2D_PORT_DIRECTION_INDEX_WEST],
                           valid_ports_lbdr[`LBDR_2D_PORT_DIRECTION_INDEX_SOUTH],
                           valid_ports_lbdr[`LBDR_2D_PORT_DIRECTION_INDEX_LOCAL]
                           );
          $display("");
          //end
          
        `FAIL_IF_NOT_EQUAL(destination_node_id_expected_direction, valid_ports_xy, "Unexpected rt output port");
         //if(destination_node_id_expected_direction != valid_ports_xy) begin
          $display("DEBUG: dst_node %2d   src_node %2d", destination_node_id,NodeId);
          $display("   XY  dst x = %d  y = %d   src x = %d  y = %d ", x_dst, y_dst, x_src, y_src);
          $display("                  N  E  W  S  L");
          $display("       expected %3d%3d%3d%3d%3d",
                           destination_node_id_expected_direction[`XY_PORT_DIRECTION_INDEX_NORTH],
                           destination_node_id_expected_direction[`XY_PORT_DIRECTION_INDEX_EAST],
                           destination_node_id_expected_direction[`XY_PORT_DIRECTION_INDEX_WEST],
                           destination_node_id_expected_direction[`XY_PORT_DIRECTION_INDEX_SOUTH],
                           destination_node_id_expected_direction[`XY_PORT_DIRECTION_INDEX_LOCAL]
                           );
          $display("       granted  %3d%3d%3d%3d%3d",  
                           valid_ports_xy[`XY_PORT_DIRECTION_INDEX_NORTH],
                           valid_ports_xy[`XY_PORT_DIRECTION_INDEX_EAST],
                           valid_ports_xy[`XY_PORT_DIRECTION_INDEX_WEST],
                           valid_ports_xy[`XY_PORT_DIRECTION_INDEX_SOUTH],
                           valid_ports_xy[`XY_PORT_DIRECTION_INDEX_LOCAL]
                           );
          $display("");
          //end
          
          
      end
    end    
  `UNIT_TEST_END

  `TEST_SUITE_END

endmodule