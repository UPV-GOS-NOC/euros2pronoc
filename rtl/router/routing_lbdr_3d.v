// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file routing_lbdr_3d.v
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date: April 16th, 2024
//
// @title Logic Based Distributed Routing (LBDR) algorithm for 3D (cube) NoCs
//
//  This module implements the LBDR algorithm stage of the 5-stage pipelined router.
//  The routing logic is divided in two parts
//  The first part computes the relative position, compared to current router, of the packet’s destination from the current router
//  The algorithm provides all candidate output ports capable to route the packet as per 
//    lbdr and connectivity bits values. Thus, the module requires external tool to calculate 
//    lbdr and connectivity bits.
//
//  Node IDs for this router are expeted to be consecutive for each layer/dimension/... 
//  starting from 0 at coordinate x=0, y=0, z=0 and accounting following the next equation
//  NODE_ID = (current_layer * number_of_columns * number_of_rows) +
//            (current_row * number_of_cols ) +
//             current_col
//
// Layer 0 (z = 0)                                                    Layer 1 (z = 1)
//  +-----+     +-----+     +-----+     +-----+     +-----+           +-----+     +-----+     +-----+     +-----+     +-----+
//  | 10  | --- | 11  | --- | 12  | --- | 13  | --- | 14  |           | 25  | --- | 26  | --- | 27  | --- | 28  | --- | 29  |
//  +-----+     +-----+     +-----+     +-----+     +-----+           +-----+     +-----+     +-----+     +-----+     +-----+
//     |           |           |           |           |                 |           |           |           |           |
//     |           |           |           |           |                 |           |           |           |           |
//  +-----+     +-----+     +-----+     +-----+     +-----+           +-----+     +-----+     +-----+     +-----+     +-----+
//  |  5  | --- |  6  | --- |  7  | --- |  8  | --- |  9  |           | 20  | --- | 21  | --- | 22  | --- | 23  | --- | 24  |      ...
//  +-----+     +-----+     +-----+     +-----+     +-----+           +-----+     +-----+     +-----+     +-----+     +-----+
//     |           |           |           |           |                 |           |           |           |           |
//     |           |           |           |           |                 |           |           |           |           |
//  +-----+     +-----+     +-----+     +-----+     +-----+           +-----+     +-----+     +-----+     +-----+     +-----+
//  |  0  | --- |  1  | --- |  2  | --- |  3  | --- |  4  |           | 15  | --- | 16  | --- | 17  | --- | 18  | --- | 19  |
//  +-----+     +-----+     +-----+     +-----+     +-----+           +-----+     +-----+     +-----+     +-----+     +-----+
//
//
//  
// LBDR is was introduced and is described in :
// Logic-Based Distributed Routing for NoCs
//  IEEE COMPUTER ARCHITECTURE LETTERS, VOL. 7, NO. 1, JANUARY-JUNE 2008
//  https://ieeexplore.ieee.org/document/4407676
//

// `define DEBUG_DISPLAY_ROUTING_LBDR_3D_ENABLE 1

// Following macros MUST be moved to global ROUTING/ROUTER macros files

 // LBDR 3D Routing bits 
/*
`define LBDR_BIT_RNN 5'd29
`define LBDR_BIT_RNE 5'd28
`define LBDR_BIT_RNW 5'd27
`define LBDR_BIT_RNU 5'd26
`define LBDR_BIT_RND 5'd25
`define LBDR_BIT_REE 5'd24
`define LBDR_BIT_REN 5'd23
`define LBDR_BIT_RES 5'd22
`define LBDR_BIT_REU 5'd21
`define LBDR_BIT_RED 5'd20
`define LBDR_BIT_RWW 5'd19
`define LBDR_BIT_RWN 5'd18
`define LBDR_BIT_RWS 5'd17
`define LBDR_BIT_RWU 5'd16
`define LBDR_BIT_RWD 5'd15
`define LBDR_BIT_RSS 5'd14
`define LBDR_BIT_RSE 5'd13
`define LBDR_BIT_RSW 5'd12
`define LBDR_BIT_RSU 5'd11
`define LBDR_BIT_RSD 5'd10
`define LBDR_BIT_RUU 5'd9
`define LBDR_BIT_RUE 5'd8
`define LBDR_BIT_RUW 5'd7
`define LBDR_BIT_RUN 5'd6
`define LBDR_BIT_RUS 5'd5
`define LBDR_BIT_RDD 5'd4
`define LBDR_BIT_RDE 5'd3
`define LBDR_BIT_RDW 5'd2
`define LBDR_BIT_RDN 5'd1
`define LBDR_BIT_RDS 5'd0
*/

`define LBDR_BIT_RNE 5'd23
`define LBDR_BIT_RNW 5'd22
`define LBDR_BIT_RNU 5'd21
`define LBDR_BIT_RND 5'd20
`define LBDR_BIT_REN 5'd19
`define LBDR_BIT_RES 5'd18
`define LBDR_BIT_REU 5'd17
`define LBDR_BIT_RED 5'd16
`define LBDR_BIT_RWN 5'd15
`define LBDR_BIT_RWS 5'd14
`define LBDR_BIT_RWU 5'd13
`define LBDR_BIT_RWD 5'd12
`define LBDR_BIT_RSE 5'd11
`define LBDR_BIT_RSW 5'd10
`define LBDR_BIT_RSU 5'd9
`define LBDR_BIT_RSD 5'd8
`define LBDR_BIT_RUE 5'd7
`define LBDR_BIT_RUW 5'd6
`define LBDR_BIT_RUN 5'd5
`define LBDR_BIT_RUS 5'd4
`define LBDR_BIT_RDE 5'd3
`define LBDR_BIT_RDW 5'd2
`define LBDR_BIT_RDN 5'd1
`define LBDR_BIT_RDS 5'd0
// LBDR 3D connenctivity bits
`define LBDR_BIT_CN 3'd5
`define LBDR_BIT_CE 3'd4
`define LBDR_BIT_CW 3'd3
`define LBDR_BIT_CS 3'd2
`define LBDR_BIT_CU 3'd1
`define LBDR_BIT_CD 3'd0
// LBDR 3D dimension Turn bits
`define LBDR_BIT_TYX 3'd5
`define LBDR_BIT_TZX 3'd4
`define LBDR_BIT_TXY 3'd3
`define LBDR_BIT_TZY 3'd2
`define LBDR_BIT_TXZ 3'd1
`define LBDR_BIT_TYZ 3'd0


module routing_lbdr_3d #(
    parameter integer NodeId = 0,
    parameter integer NodeIdWidth = 0,
    parameter integer NumberOfRows = 0,
    parameter integer NumberOfColumns = 0,
    parameter integer NumberOfLayers = 0,
    parameter integer NumberOfLBDRRoutingBits = 0,
    parameter integer NumberOfLBDRConnectivityBits = 0,
    parameter integer NumberOfLBDRTurnBits = 0,
    // parameter NumberOfPorts = 6,  // not made available since the number of ports cannot be modified without changing the code
    localparam NumberOfOutputPorts = 6,
    // paramenterNumberOfCoresPerNode = 1, currently only one supported and number of node matches destination id
    localparam NumberOfRowsWidth = num_bits(NumberOfRows - 1),
    localparam NumberOfColumnsWidth =num_bits(NumberOfColumns - 1),
    localparam NumberOfLayersWidth = num_bits(NumberOfLayers - 1),
    //localparam NumberOfNodes = (NumberOfRows * NumberOfColumns * NumberOfLayers),
    localparam NumberOfNodesPerLayer = (NumberOfRows * NumberOfColumns),
    //localparam NumberOfNodesPerRow = ,
    //localparam NumberOfNodesPerColumn
    //localparam NodeIdWidth = num_bits(NumberOfNodes-1),
    localparam NumberOfLBDRRoutingBitsWidth = NumberOfLBDRRoutingBits, // Note that LBDR algorithm requires one bit per RoutingBit, so the number of bits matches the bus witdh
    localparam NumberOfLBDRConnectivityBitsWidth = NumberOfLBDRConnectivityBits,
    localparam NumberOfLBDRTurnBitsWidth =  NumberOfLBDRTurnBits
  ) (
  // clocks and resets
//  input  clk_i,
//  input  rst_i,

  input  [NumberOfLBDRRoutingBitsWidth-1:0]       lbdr_routing_bits_i,      // Input: LBDR algorithm routing bits (Rxy). Values stored in external table. Indicates whether turning from direction x to direction y is allowed in the next swith
  input  [NumberOfLBDRConnectivityBitsWidth-1:0]  lbdr_connectivity_bits_i, // Input: LBDR algorithm connectivity bit (Cx). Values stored in external table. Indicates the presence of a switch conneted at the Port X of current swith
  input  [NumberOfLBDRTurnBitsWidth-1:0]          lbdr_turn_bits_i,         // Input: LBDR algorithm turn bits (Txy).

  // input                          request_routing_o, // @ratorga @jorocgon previous modules had request signal.... but, since the module is pure combinational, is it necessary ?
  input  [NodeIdWidth-1:0]          destination_node_id_i,
  output [NumberOfOutputPorts-1:0]  valid_ports_out_o    // Output: Array indicating whether port is valid for routing the packet. Ports order in array is N-E-W-S-U-D
  );

  //---------------------------------------------------------------------------
  // Functions Definitions
  // returns the required number of bits to represent the "value" passed as input parameter
  function integer num_bits;
    input integer value;
    begin
      num_bits = 0;
      for (num_bits = 0; value > 0; num_bits = num_bits+1) begin
        value = value >> 1;
      end
    end
  endfunction

  //---------------------------------------------------------------------------
  //wires and registers
  // LBDR bits
  wire /*Rnn, */Rne, Rnw, Rnu, Rnd; 
  wire /*Ree, */Ren, Res, Reu, Red;  
  wire /*Rww, */Rwn, Rws, Rwu, Rwd; 
  wire /*Rss, */Rse, Rsw, Rsu, Rsd;
  wire /*Ruu, */Rue, Ruw, Run, Rus;
  wire /*Rdd, */Rde, Rdw, Rdn, Rds;
  wire Cn, Ce, Cw, Cs, Cu, Cd;
  wire Txy, Txz, Tyx, Tyz, Tzx, Tzy;

  // output ports
  wire candidate_outport_n;
  wire candidate_outport_e;
  wire candidate_outport_w;
  wire candidate_outport_s;
  wire candidate_outport_u;
  wire candidate_outport_d;

  // position of current node (xyz coordinates)
  wire [NumberOfColumnsWidth-1:0] x_cur;
  wire [NumberOfRowsWidth-1:0]    y_cur;
  wire [NumberOfLayersWidth-1:0]  z_cur;
  // relative position of destination node (xyz coordinate)
  wire [NumberOfColumnsWidth-1:0] x_dst;
  wire [NumberOfRowsWidth-1:0]    y_dst;
  wire [NumberOfLayersWidth-1:0]  z_dst;

  // first stage values. Relative position of the packet’s destination
  wire stage_1_n;
  wire stage_1_e;
  wire stage_1_w;
  wire stage_1_s;
  wire stage_1_u;
  wire stage_1_d;

  // second stage values. Determines whether an output port is considered for routing the incoming packet when
  //   either one of the required conditions is met: the packet goes to a node in the required quadrant and 
  //   the turn is allowed by the bits connfiguration (see lbdr link for conditions details):
  wire stage_2_n;
  wire stage_2_e;
  wire stage_2_w;
  wire stage_2_s;
  wire stage_2_u;
  wire stage_2_d;

  //set current node coordinates
  assign x_cur = NodeId % NumberOfColumns; // Current Node location x_coordinate: column number 
  assign y_cur = (NodeId % NumberOfNodesPerLayer) / NumberOfColumns; // Current node location y_coordinate: row number . It requires removing the layer offset
  assign z_cur = NodeId / NumberOfNodesPerLayer;

  // target node coordinates
  assign x_dst = destination_node_id_i % NumberOfColumns; 
  assign y_dst = (destination_node_id_i % NumberOfNodesPerLayer) / NumberOfColumns;
  assign z_dst = destination_node_id_i / NumberOfNodesPerLayer;


  initial begin
    $display("This is LBDR routing for NODE id = %2d    x = %2d   y = %2d   z = %2d", NodeId, x_cur, y_cur, z_cur);
  end

  //assign Rnn = lbdr_routing_bits_i[`LBDR_BIT_RNN];
  assign Rne = lbdr_routing_bits_i[`LBDR_BIT_RNE];
  assign Rnw = lbdr_routing_bits_i[`LBDR_BIT_RNW];
  assign Rnu = lbdr_routing_bits_i[`LBDR_BIT_RNU];
  assign Rnd = lbdr_routing_bits_i[`LBDR_BIT_RND];
  //assign Ree = lbdr_routing_bits_i[`LBDR_BIT_EER];
  assign Ren = lbdr_routing_bits_i[`LBDR_BIT_REN];
  assign Res = lbdr_routing_bits_i[`LBDR_BIT_RES];
  assign Reu = lbdr_routing_bits_i[`LBDR_BIT_REU];
  assign Red = lbdr_routing_bits_i[`LBDR_BIT_RED];
  //assign Rww = lbdr_routing_bits_i[`LBDR_BIT_RWW];
  assign Rwn = lbdr_routing_bits_i[`LBDR_BIT_RWN];
  assign Rws = lbdr_routing_bits_i[`LBDR_BIT_RWS];
  assign Rwu = lbdr_routing_bits_i[`LBDR_BIT_RWU];
  assign Rwd = lbdr_routing_bits_i[`LBDR_BIT_RWD];
  //assign Rss = lbdr_routing_bits_i[`LBDR_BIT_RSS];
  assign Rse = lbdr_routing_bits_i[`LBDR_BIT_RSE];
  assign Rsw = lbdr_routing_bits_i[`LBDR_BIT_RSW];
  assign Rsu = lbdr_routing_bits_i[`LBDR_BIT_RSU];
  assign Rsd = lbdr_routing_bits_i[`LBDR_BIT_RSD];
  //assign Ruu = lbdr_routing_bits_i[`LBDR_BIT_RUU];
  assign Rue = lbdr_routing_bits_i[`LBDR_BIT_RUE];
  assign Ruw = lbdr_routing_bits_i[`LBDR_BIT_RUW];
  assign Run = lbdr_routing_bits_i[`LBDR_BIT_RUN];
  assign Rus = lbdr_routing_bits_i[`LBDR_BIT_RUS];
  //assign Rdd = lbdr_routing_bits_i[`LBDR_BIT_RDD];
  assign Rde = lbdr_routing_bits_i[`LBDR_BIT_RDE];
  assign Rdw = lbdr_routing_bits_i[`LBDR_BIT_RDW];
  assign Rdn = lbdr_routing_bits_i[`LBDR_BIT_RDN];
  assign Rds = lbdr_routing_bits_i[`LBDR_BIT_RDS];
  assign Cn = lbdr_connectivity_bits_i[`LBDR_BIT_CN];
  assign Ce = lbdr_connectivity_bits_i[`LBDR_BIT_CE];
  assign Cw = lbdr_connectivity_bits_i[`LBDR_BIT_CW];
  assign Cs = lbdr_connectivity_bits_i[`LBDR_BIT_CS];
  assign Cu = lbdr_connectivity_bits_i[`LBDR_BIT_CU];
  assign Cd = lbdr_connectivity_bits_i[`LBDR_BIT_CD];
  assign Txy = lbdr_turn_bits_i[`LBDR_BIT_TXY];
  assign Txz = lbdr_turn_bits_i[`LBDR_BIT_TXZ];
  assign Tyx = lbdr_turn_bits_i[`LBDR_BIT_TYX];
  assign Tyz = lbdr_turn_bits_i[`LBDR_BIT_TYZ];
  assign Tzx = lbdr_turn_bits_i[`LBDR_BIT_TZX];
  assign Tzy = lbdr_turn_bits_i[`LBDR_BIT_TZY];

  // stage 1 assinments
  assign stage_1_n = y_dst > y_cur;
  assign stage_1_e = x_dst > x_cur;
  assign stage_1_w = x_dst < x_cur;
  assign stage_1_s = y_dst < y_cur;
  assign stage_1_u = z_dst > z_cur;
  assign stage_1_d = z_dst < z_cur;
 
  // stage 2 assignments
  assign stage_2_n = (stage_1_n & (~stage_1_e) & (~stage_1_w) & (~stage_1_u) & (~stage_1_d)) |

                     (stage_1_n &   stage_1_e  & (~stage_1_u) & (~stage_1_d) &   Rne) | 
                     (stage_1_n &   stage_1_e  &  stage_1_u   &   Txy & Tzy  &   Rne) |  // north east and up, can go north when more hops must be done in x & can go north when more hops must be done in z
                     (stage_1_n &   stage_1_e  &  stage_1_u   &   Txy & Tzy  &   Rnu) |                    // north up and east, can go north when more hops must be done in z & can go north when more hops must be done in x
                     (stage_1_n &   stage_1_e  &  stage_1_d   &   Txy & Tzy  &   Rne) |
                     (stage_1_n &   stage_1_e  &  stage_1_d   &   Txy & Tzy  &   Rnd) |
                     |
                     (stage_1_n &   stage_1_w  & (~stage_1_u) & (~stage_1_d) &   Rnw) |
                     (stage_1_n &   stage_1_w  &  stage_1_u   &   Txy & Tzy  &   Rnw) |  // north east and up, can go north when more hops must be done in x & can go north when more hops must be done in z
                     (stage_1_n &   stage_1_w  &  stage_1_u   &   Txy & Tzy  &   Rnu) |                    // north up and east, can go north when more hops must be done in z & can go north when more hops must be done in x
                     (stage_1_n &   stage_1_w  &  stage_1_d   &   Txy & Tzy  &   Rnw) |
                     (stage_1_n &   stage_1_w  &  stage_1_d   &   Txy & Tzy  &   Rnd) |
                     |
                     (stage_1_n &   stage_1_u  & (~stage_1_e) & (~stage_1_w) &   Rnu) |
                     //(stage_1_n &   stage_1_u  &  e     already authorized
                     //(stage_1_n &   stage_1_u  &  w     already authorized
                     |
                     (stage_1_n &   stage_1_d  & (~stage_1_e) & (~stage_1_w) &   Rnd) //|
                     //(stage_1_n &   stage_1_d  & e     already authorized
                     //(stage_1_n &   stage_1_d  & w      already authorized
                     ;
  assign stage_2_e = (stage_1_e & (~stage_1_n) & (~stage_1_s) & (~stage_1_u) & (~stage_1_d)) |  //1
                     | 
                     (stage_1_e &   stage_1_n  & (~stage_1_u) & (~stage_1_d) &   Ren) |    // 8
                     (stage_1_e &   stage_1_n  &   stage_1_d  &   Tzx & Tyx  &   Ren) |    // 9
                     (stage_1_e &   stage_1_n  &   stage_1_d  &   Tzx & Tyx  &   Red) |    //10
                     |
                     (stage_1_e &   stage_1_s  & (~stage_1_u) & (~stage_1_d) &   Res) |   // 2
                     (stage_1_e &   stage_1_s  &   stage_1_u  &   Tzx & Tyx  &   Reu) |   // 3
                     (stage_1_e &   stage_1_s  &   stage_1_u  &   Tzx & Tyx  &   Res) |   // 4
                     |
                     (stage_1_e &   stage_1_u  & (~stage_1_n) & (~stage_1_s) &   Reu ) |  // 5
                     (stage_1_e &   stage_1_n  &   stage_1_u  &   Tzx & Tyx  &   Ren ) |  // 6
                     (stage_1_e &   stage_1_n  &   stage_1_u  &   Tzx & Tyx  &   Reu ) |  // 7
                     |
                     (stage_1_e &   stage_1_d  & (~stage_1_n) & (~stage_1_s) &   Red) |   //11
                     (stage_1_e &   stage_1_s  &   stage_1_d  &   Tzx & Tyx  &   Res) |   //12
                     (stage_1_e &   stage_1_s  &   stage_1_d  &   Tzx & Tyx  &   Red) ;   //13

  assign stage_2_w = (stage_1_w & (~stage_1_n) & (~stage_1_s) & (~stage_1_u) & (~stage_1_d)) |  // 1
                     |
                     (stage_1_w &   stage_1_n  & (~stage_1_u) & (~stage_1_d) &   Rwn) | // 2
                     (stage_1_w &   stage_1_n  &   stage_1_u  &   Tzx & Tyx  &   Rwn) | // 3
                     (stage_1_w &   stage_1_n  &   stage_1_u  &   Tzx & Tyx  &   Rwu) | // 4
                     |
                     (stage_1_w &   stage_1_s  & (~stage_1_u) & (~stage_1_d) &   Rws) | // 8
                     (stage_1_w &   stage_1_s  &   stage_1_d  &   Tzx & Tyx  &   Rsd) | // 9
                     (stage_1_w &   stage_1_s  &   stage_1_d  &   Tzx & Tyx  &   Rds) | //10
                     |
                     (stage_1_w &   stage_1_u  & (~stage_1_n) & (~stage_1_s) &   Rwu) | // 5
                     (stage_1_w &   stage_1_u  &   stage_1_s  &   Tzx & Tyx  &   Rwu) | // 6
                     (stage_1_w &   stage_1_u  &   stage_1_s  &   Tzx & Tyx  &   Rws) | // 7
                     |
                     (stage_1_w &   stage_1_d  & (~stage_1_n) & (~stage_1_s) &   Rwd) | //11
                     (stage_1_w &   stage_1_d  &   stage_1_n  &   Tzx & Tyx  &   Rwd) | //12
                     (stage_1_w &   stage_1_d  &   stage_1_n  &   Tzx & Tyx  &   Rwn);  //13


  assign stage_2_s = (stage_1_s & (~stage_1_e) & (~stage_1_w) & (~stage_1_u) & (~stage_1_d)) | // 1
                     |
                     (stage_1_s &   stage_1_e  & (~stage_1_u) & (~stage_1_d) &   Rse) | // 2
                     (stage_1_s &   stage_1_e  &   stage_1_u  &   Tzy & Txy  &   Rse) | // 3
                     (stage_1_s &   stage_1_e  &   stage_1_u  &   Tzy & Txy  &   Rsu) | // 4
                     |
                     (stage_1_s &   stage_1_w  & (~stage_1_u) & (~stage_1_d) &   Rsw) | // 8
                     (stage_1_s &   stage_1_w  &   stage_1_d  &   Tzy & Txy  &   Rsw) | // 9
                     (stage_1_s &   stage_1_w  &   stage_1_d  &   Tzy & Txy  &   Rsd) | //10
                     |
                     (stage_1_s &   stage_1_u  & (~stage_1_e) & (~stage_1_w) &   Rsu) | // 5
                     (stage_1_s &   stage_1_u  &   stage_1_w  &   Tzy & Txy  &   Rsu) | // 6
                     (stage_1_s &   stage_1_u  &   stage_1_w  &   Tzy & Txy  &   Rsw) | // 7
                     |
                     (stage_1_s &   stage_1_d  & (~stage_1_e) & (~stage_1_w) &   Rsd) | //11
                     (stage_1_s &   stage_1_d  &   stage_1_e  &   Tzy & Txy  &   Rsd) | //12
                     (stage_1_s &   stage_1_d  &   stage_1_e  &   Tzy & Txy  &   Rse);  //13


  assign stage_2_u = (stage_1_u & (~stage_1_e) & (~stage_1_w) & (~stage_1_n) & (~stage_1_s)) | // 1
                     |
                     (stage_1_u &   stage_1_n  & (~stage_1_e) & (~stage_1_w) &   Run) | //11
                     (stage_1_u &   stage_1_n  &   stage_1_e  &   Txz & Tyz  &   Run) | //12
                     (stage_1_u &   stage_1_n  &   stage_1_e  &   Txz & Tyz  &   Rue) | //13
                     |
                     (stage_1_u &   stage_1_e  & (~stage_1_n) & (~stage_1_s) &   Rue) | // 2
                     (stage_1_u &   stage_1_e  &   stage_1_s  &   Txz & Tyz  &   Rus) | // 3
                     (stage_1_u &   stage_1_e  &   stage_1_s  &   Txz & Tyz  &   Rue) | // 4
                     |
                     (stage_1_u &   stage_1_w  & (~stage_1_n) & (~stage_1_s) &   Ruw) | // 8
                     (stage_1_u &   stage_1_w  &   stage_1_n  &   Txz & Tyz  &   Ruw) | // 9
                     (stage_1_u &   stage_1_w  &   stage_1_n  &   Txz & Tyz  &   Run) | //10
                     |
                     (stage_1_u &   stage_1_s  & (~stage_1_e) & (~stage_1_w) &   Rus) | // 5
                     (stage_1_u &   stage_1_s  &   stage_1_w  &   Txz & Tyz  &   Rus) | // 6
                     (stage_1_u &   stage_1_s  &   stage_1_w  &   Txz & Tyz  &   Ruw);  // 7      

  assign stage_2_d = (stage_1_d & (~stage_1_e) & (~stage_1_w) & (~stage_1_n) & (~stage_1_s)) | // 1
                     |
                     (stage_1_d &   stage_1_n  & (~stage_1_e) & (~stage_1_w) &   Rdn) | // 5
                     (stage_1_d &   stage_1_n  &   stage_1_w  &   Txz & Tyz  &   Rdn) | // 6
                     (stage_1_d &   stage_1_n  &   stage_1_w  &   Txz & Tyz  &   Rdw) | // 7
                     |
                     (stage_1_d &   stage_1_e  & (~stage_1_n) & (~stage_1_s) &   Rde) | // 2
                     (stage_1_d &   stage_1_e  &   stage_1_n  &   Txz & Tyz  &   Rde) | // 3
                     (stage_1_d &   stage_1_e  &   stage_1_n  &   Txz & Tyz  &   Rdn) | // 4
                     |
                     (stage_1_d &   stage_1_w  & (~stage_1_n) & (~stage_1_s) &   Rdw) | // 8
                     (stage_1_d &   stage_1_w  &   stage_1_s  &   Txz & Tyz  &   Rdw) | // 9
                     (stage_1_d &   stage_1_w  &   stage_1_s  &   Txz & Tyz  &   Rds) | //10
                     |
                     (stage_1_d &   stage_1_s  & (~stage_1_e) & (~stage_1_w) &   Rds) | //11
                     (stage_1_d &   stage_1_s  &   stage_1_e  &   Txz & Tyz  &   Rds) | //12
                     (stage_1_d &   stage_1_s  &   stage_1_e  &   Txz & Tyz  &   Rde);  //13

  assign candidate_outport_n = stage_2_n & Cn;
  assign candidate_outport_e = stage_2_e & Ce;
  assign candidate_outport_w = stage_2_w & Cw;
  assign candidate_outport_s = stage_2_s & Cs;
  assign candidate_outport_u = stage_2_u & Cu;
  assign candidate_outport_d = stage_2_d & Cd;

  assign valid_ports_out_o = {candidate_outport_n, candidate_outport_e, candidate_outport_w, candidate_outport_s, candidate_outport_u, candidate_outport_d};

endmodule
