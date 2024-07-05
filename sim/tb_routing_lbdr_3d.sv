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

`define DEBUG_DISPLAY_TB_ROUTING_LBDR_3D_ENABLE 1
//                     NEWSUD
`define PORT_NORTH (6'b100000)
`define PORT_EAST  (6'b010000)
`define PORT_WEST  (6'b001000)
`define PORT_SOUTH (6'b000100)
`define PORT_UP    (6'b000010)
`define PORT_DOWN  (6'b000001)
`define PORT_NONE  (6'b000000)

`define RT_XYZ(xd,yd,zd,xc,yc,zc) ((xd<xc)?(`PORT_WEST) :  \
                                   (xd>xc)?(`PORT_EAST) :  \
                                   (yd<yc)?(`PORT_SOUTH) : \
                                   (yd>yc)?(`PORT_NORTH) : \
                                   (zd<zc)?(`PORT_DOWN) : \
                                   (zd>zc)?(`PORT_UP) : \
                                   `PORT_NONE);

`include "svut_h.sv"
`timescale 1 ns / 1 ps

module tb_routing_lbdr_3d;

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
  localparam NumberOfLayers  = 5;   // z dim
  localparam NumberOfNodes = NumberOfColumns * NumberOfRows * NumberOfLayers;
  localparam NodeIdWidth   = num_bits(NumberOfNodes);
 
  localparam NumberOfRowsWidth    = num_bits(NumberOfRows - 1);
  localparam NumberOfColumnsWidth = num_bits(NumberOfColumns - 1);
  localparam NumberOfLayersWidth  = num_bits(NumberOfLayers - 1);
  localparam NumberOfNodesPerLayer = (NumberOfRows * NumberOfColumns);

  // this is the source node for the routing algorithm
  // The NodeId is a parameter set at the initialization of the module, so cannot be modified during the tests
  // x=1, y=1, z=2
  localparam NodeIdX = 1;
  localparam NodeIdY = 1;
  localparam NodeIdZ = 2;
  localparam [NodeIdWidth-1:0] NodeId = (NodeIdX + NodeIdY*NumberOfColumns + NodeIdZ*NumberOfColumns*NumberOfRows);
  
  // LBDR 3D parameters
  localparam NumberOfLBDRRoutingBits = 24;
  localparam NumberOfLBDRConnectivityBits = 6;
  localparam NumberOfLBDRTurnBits  = 6;
  localparam NumberOfOutputPorts   = 6;

  // miscelaneous variables
  integer x = 0;
  integer y = 0;
  integer z = 0;

  integer id = 0;
  integer i = 0;
  integer j = 0; 
  integer k = 0;
  
  // Registers and wires
  // clocks and resets 
  reg  clk;
  reg  rst;
  
  // NoC
  // 
  // reg  [NodeIdWidth-1:0] source_node_id;    // THIS register is replaced by NodeId since the value is fixed for the testbench  
  reg  [NodeIdWidth-1:0] destination_node_id;  //  this value will be variable during the tests
  wire [NumberOfOutputPorts-1:0] valid_ports;  // candidate port to route the packet returned by routing moulde
  reg  [NumberOfOutputPorts-1:0] destination_node_id_expected_direction; // output port calculated with xyz routing algorithm. 
  
  // position of message src node NodeID (xyz coordinates), "THIS" node coordinates for routing algorithm
  reg [NumberOfColumnsWidth-1:0] x_src = NodeIdX;
  reg [NumberOfRowsWidth-1:0]    y_src = NodeIdY;// relative position of destination node (xyz coordinate)
  reg [NumberOfLayersWidth-1:0]  z_src = NodeIdZ;
  
  // xyz coordinates of destination node
  reg [NumberOfColumnsWidth-1:0] x_dst;
  reg [NumberOfRowsWidth-1:0]    y_dst;
  reg [NumberOfLayersWidth-1:0]  z_dst;

  // LBDR 3D
  reg Rne, Rnw, Rnu, Rnd;
  reg Ren, Res, Reu, Red;
  reg Rwn, Rws, Rwu, Rwd;
  reg Rse, Rsw, Rsu, Rsd;
  reg Rue, Ruw, Run, Rus;
  reg Rde, Rdw, Rdn, Rds;
  reg Cn, Ce, Cw, Cs, Cu, Cd;
  reg Tyx, Tzx, Txy, Tzy, Txz, Tyz;
  
  reg [NumberOfLBDRRoutingBits-1:0]      lbdr_routing_bits[NumberOfNodes-1:0];
  reg [NumberOfLBDRConnectivityBits-1:0] lbdr_connectivity_bits[NumberOfNodes-1:0];
  reg [NumberOfLBDRTurnBits-1:0]         lbdr_turn_bits[NumberOfNodes-1:0];
  
  wire [NumberOfLBDRRoutingBits-1:0]      lbdr_rxy = lbdr_routing_bits[NodeId];
  wire [NumberOfLBDRConnectivityBits-1:0] lbdr_cxy = lbdr_connectivity_bits[NodeId]; 
  wire [NumberOfLBDRTurnBits-1:0]         lbdr_txy = lbdr_turn_bits[NodeId];
  
  //---------------------------------------------------------------------------
  // Initialization of LBDR 3D registers
  //  Implementing XYZ algorithm    
  initial begin
    // Initialize LBDR tables

    // routing bits for LBDR XYZ
    // allowed dimension changes:
    //  x -> y    y -> z    x -> z
    // forbidden dimension changes (reverse):
    //  y -> x    z -> y    z -> x
    //
    //  x {e,w}  y {n,s}  z {u,d}
    id = 0;
    for (z = 0; z < NumberOfLayers; z++) begin
      for (y = 0; y < NumberOfRows; y++) begin
        for (x = 0; x < NumberOfColumns ; x++) begin
          Rne = 1'b0;
          Rnw = 1'b0;
      
          Rnu = 1'b1;
          Rnd = 1'b1;
      
          Ren = 1'b1;
          Res = 1'b1;
      
          Reu = 1'b1;
          Red = 1'b1;
      
          Rwn = 1'b1;
          Rws = 1'b1;
      
          Rwu = 1'b1;
          Rwd = 1'b1;
      
          Rse = 1'b0;
          Rsw = 1'b0;
      
          Rsu = 1'b1;
          Rsd = 1'b1;
      
          Rue = 1'b0;
          Ruw = 1'b0;
      
          Run = 1'b0;
          Rus = 1'b0;
      
          Rde = 1'b0;
          Rdw = 1'b0;
      
          Rdn = 1'b0;
          Rds = 1'b0;
          
          Tyx = 1'b1; // packet can    be routed via dimension x while there are are hops to be done in dimension y
          Tzx = 1'b1; // packet can    be routed via dimension x while there are are hops to be done in dimension z
          
          Txy = 1'b0; // packet CANNOT be routed via dimension y while there are are hops to be done in dimension x
          Tzy = 1'b1; // packet can    be routed via dimension y while there are are hops to be done in dimension z
                    
          Txz = 1'b0; // packet CANNOT be routed via dimension z while there are are hops to be done in dimension x
          Tyz = 1'b0; // packet CANNOT be routed via dimension z while there are are hops to be done in dimension y
          
          id = z * (NumberOfColumns * NumberOfRows) + y * NumberOfColumns + x;
          lbdr_routing_bits[id] = { Rne, Rnw, Rnu, Rnd, Ren, Res, Reu, Red, Rwn, Rws, Rwu, Rwd, 
                                    Rse, Rsw, Rsu, Rsd, Rue, Ruw, Run, Rus, Rde, Rdw, Rdn, Rds 
          };
          lbdr_turn_bits[id] = {Tyx, Tzx, Txy, Tzy, Txz, Tyz};
        end
      end
    end

    // connectivity bits
    id = 0;
    for (z = 0; z < NumberOfLayers; z++) begin
      for (y = 0; y < NumberOfRows; y++) begin
        for (x = 0; x < NumberOfColumns ; x++) begin
          // x dim -> Ce, Cw
          if (x <= 0) Cw = 1'b0;
          else        Cw = 1'b1;
          if (x >= (NumberOfColumns - 1)) Ce = 1'b0;
          else                            Ce = 1'b1;
          // y dim -> Cn, Cs
          if (y <= 0) Cs = 1'b0;
          else        Cs = 1'b1;
          if (y >= (NumberOfRows - 1))   Cn = 1'b0;
          else                           Cn = 1'b1;
          // z dim -> Cu, Cd
          if (z <= 0) Cd = 1'b0;
          else        Cd = 1'b1;
          if (z >= (NumberOfLayers - 1)) Cu = 1'b0;
          else                           Cu = 1'b1;
 
          id = z * (NumberOfColumns * NumberOfRows) + y * NumberOfColumns + x;
          lbdr_connectivity_bits[id] = {Cn, Ce, Cw, Cs, Cu, Cd};
          if (id == 'd29) begin
            $display ("Cx   id = %2d   x = %2d   y = %2d   z= %2d", id, x, y ,z);
          end
        end
      end
    end
  end
  
  //---------------------------------------------------------------------------
  // Modules instantiation
  routing_lbdr_3d #(
    .NodeId       (NodeId),
    .NodeIdWidth  (NodeIdWidth),
    .NumberOfRows (NumberOfRows),
    .NumberOfColumns (NumberOfColumns),
    .NumberOfLayers  (NumberOfLayers),
    .NumberOfLBDRRoutingBits      (NumberOfLBDRRoutingBits),
    .NumberOfLBDRConnectivityBits (NumberOfLBDRConnectivityBits),
    .NumberOfLBDRTurnBits         (NumberOfLBDRTurnBits)
  ) routing_lbdr_3d_inst (
    .lbdr_routing_bits_i      (lbdr_rxy),
    .lbdr_connectivity_bits_i (lbdr_cxy),
    .lbdr_turn_bits_i         (lbdr_txy),
    .destination_node_id_i  (destination_node_id),
    .valid_ports_out_o      (valid_ports)
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
//  // source node node in   x = 1     y = 1      z = 2  
//  //                     col   1  row    1   layer  2

    //set current node coordinates
    //x_cur = NodeId % NumberOfColumns; // Current Node location x_coordinate: column number 
    //y_cur = (NodeId % NumberOfNodesPerLayer) / NumberOfColumns; // Current node location y_coordinate: row number . It requires removing the layer offset
    //z_cur = NodeId / NumberOfNodesPerLayer;
  
    for (k = 0; k < NumberOfLayers; k = k + 1) begin
      for (j = 0; j < NumberOfRows; j = j + 1) begin
        for(i = 0; i < NumberOfColumns; i = i + 1) begin
          destination_node_id = (i + j*NumberOfColumns + k*NumberOfColumns*NumberOfRows);
          
          @(posedge clk);
          x_dst = i;      
          y_dst = j;
          z_dst = k;          
          
          destination_node_id_expected_direction = `RT_XYZ(x_dst,y_dst,z_dst, x_src,y_src,z_src);
          @(posedge clk);
          
          `FAIL_IF_NOT_EQUAL(destination_node_id_expected_direction, valid_ports, "Unexpected rt output port");

          //if(destination_node_id_expected_direction[i] != valid_ports) begin
            $display("DEBUG: dst_node %2d   src_node %2d", destination_node_id,NodeId);
            $display("       dst x = %d  y = %d  z = %d   src x = %d  y = %d  z = %d", x_dst, y_dst, z_dst, x_src, y_src, z_src);
            $display("                  N  E  W  S  U  D");
            $display("       expected %3d%3d%3d%3d%3d%3d", destination_node_id_expected_direction[5], destination_node_id_expected_direction[4], destination_node_id_expected_direction[3], destination_node_id_expected_direction[2], destination_node_id_expected_direction[1], destination_node_id_expected_direction[0]);
            $display("       granted  %3d%3d%3d%3d%3d%3d", valid_ports[5], valid_ports[4], valid_ports[3], valid_ports[2], valid_ports[1], valid_ports[0]);
            $display("");
          //end
        end
      end
    end
     
  `UNIT_TEST_END

  `TEST_SUITE_END

endmodule
