`timescale 1ns / 1ps
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
// Engineer: J. Flich (jflich@disca.upv.es)
// 
// Create Date: 09/03/2013
// Design Name: 
// Module Name: 
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "macro_functions.h"
`include "net_common.h"

//! Routing module with VC and VN support. This module performs the routing of the switch. A routing module is instantiated on every input queue 
//! of a switch's input port. Each VC of each VN has its own ROUTING_VC module (and its own IBUFFER module). 
//! The module takes as an input flits from the input buffer ready to be routed. The information from the flit is extracted and the module
//! requests either a virtual channel (from the VA module) or the output port (from the SA module). 
//!
//! Output ports) are computed following the XY routing algorithm and only for header flits. Notice that broadcast flits can be received for 
//! routing and in this case several outputs are computed.
//!
//! Once router, if the incoming flit is a header flit, then 
//! the module request a valid free VC (within the set of VCs assigned to the flit's VN). When granted, the module request access to the output port for every
//! message flits. The assigned VC to the message is not provided to the module. The VA module forwards this information to the OUTPUT_VC module.
//! 
//! For all the body flits of the message the module requests access to the output port via the SA module (VA module is not requested any more).
//!
//! Once an SA grant is accepted the module asumes that the flit has been forwarded. Thus, flits are received in the input buffer, then forwarded to the 
//! routing module and then sent to the output ports by the 
//! routing module. Multi-flit messages are taken into account, by storing the selected output ports for non-header flits. Routing decisions are taken only for
//! header flits. Tail flits are taken into acount in order to be ready for the next header flit. (TODO: Mirar tail_flit para que se usa).
//!
//! This module is only valid for a network with VC/VN support. For a network with no VCs the VA stage is not needed and the module to use for routing is ROUTING instead of this one.

module ROUTING_VC #(
  parameter ID                 = 1,             //! Tile id 
  parameter GLBL_DIMX          = 2,             //! Global number of tiles in X-dimension
  parameter GLBL_DIMY          = 1,             //! Global number of Tiles in Y-dimension 
  parameter GLBL_N_NxT         = 1,             //! Global number of Nodes per tile
  parameter GLBL_N_Nodes       = 2,             //! Global number of Total nodes in the topology
  parameter GLBL_DIMX_w        = 1,             //! Global  X-Dim width
  parameter GLBL_DIMY_w        = 0,             //! Global  Y-Dim width
  parameter GLBL_N_NxT_w       = 0,             //! Global Nodes per tile width
  parameter GLBL_N_Nodes_w     = 1,             //! Total nodes width   
  parameter GLBL_SWITCH_ID_w   = 1,             //! ID width for switches
  parameter PORT               = 0,             //! Port identifier (can be PORT_N, PORT_E, PORT_W, PORT_S, PORT_L)
  parameter FLIT_SIZE          = 64,            //! flit size in bits
  parameter FLIT_TYPE_SIZE     = 2,             //! flit type size in bits
  parameter BROADCAST_SIZE     = 5,             //! broadcast info size in bits
  parameter DATA_NET_FLIT_DST_UNIT_ID_LSB = 1,  //! LSB bit for the dst_unit_id field in the flit   
  parameter DATA_NET_FLIT_DST_UNIT_ID_MSB = 1   //! MSB bit for the dst_unit_id field in the flit
)(
    input                       Req,            //! BUF interface: request
	input [FLIT_SIZE-1:0]       Flit,           //! BUF interface: flit
    input [FLIT_TYPE_SIZE-1:0]  FlitType,       //! BUF interface: flit type
    input                       BroadcastFlit,  //! BUF interface: broadcast bit
    output                      Avail,          //! BUF interface: available signal
    //
    output                      Request_VA_N,   //! NORTH interface: request to VA
    input                       Grant_VA_FromN, //! NORTH interface: grant from VA
    output                      Request_SA_N,   //! NORTH interface: request to SA
    input                       Grant_SA_FromN, //! NORTH interface: grant from SA
    //
    output                      Request_VA_E,   //! EAST interface: request to VA
    input                       Grant_VA_FromE, //! EAST interface: grant from VA
    output                      Request_SA_E,   //! EAST interface: request to SA
    input                       Grant_SA_FromE, //! EAST interface: grant from SA
    //
    output                      Request_VA_W,   //! WEST interface: request to VA
    input                       Grant_VA_FromW, //! WEST interface: grant from VA
    output                      Request_SA_W,   //! WEST interface: request to SA
    input                       Grant_SA_FromW, //! WEST interface: grant from SA
    //
    output                      Request_VA_S,   //! SOUTH interface: request to VA
    input                       Grant_VA_FromS, //! SOUTH interface: grant from VA
    output                      Request_SA_S,   //! SOUTH interface: request to SA
    input                       Grant_SA_FromS, //! SOUTH interface: grant from SA
    //
    output                      Request_VA_L,   //! LOCAL interface: request to VA
    input                       Grant_VA_FromL, //! LOCAL interface: grant from VA
    output                      Request_SA_L,   //! LOCAL interface: request to SA
    input                       Grant_SA_FromL, //! LOCAL interface: grant from SA
    //
	output [FLIT_SIZE-1:0]      FlitOut,        //! OUT interface: flit
	output [FLIT_TYPE_SIZE-1:0] FlitTypeOut,    //! OUT interface: flit type
    output                      TailFlit,       //! OUT interface: tail flit
	output                      BroadcastFlitN, //! OUT interface: broadcast bit to north direction  TODO: Como funciona realmente el broadcast?
    output                      BroadcastFlitE, //! OUT interface: broadcast bit to east direction
    output                      BroadcastFlitW, //! OUT interface: broadcast bit to west direction
    output                      BroadcastFlitS,	//! OUT interface: broadcast bit to south direction
    output                      BroadcastFlitL, //! OUT interface: broadcast bit to local direction
    //
    input                       clk,            //! clock signal
    input                       rst_p           //! reset signal
);

localparam DIMX = GLBL_DIMX;                            //! Number of tiles in X-dimension of the NoC
localparam DIMY = GLBL_DIMY;                            //! Number of tiles in Y-dimension of the NoC
localparam DIMX_w = GLBL_DIMX_w > 0 ? GLBL_DIMX_w : 1;  //! DIMX width
localparam DIMY_w = GLBL_DIMY_w > 0 ? GLBL_DIMY_w : 1;  //! DIMY width
localparam ID_SIZE = GLBL_SWITCH_ID_w;                  //! ID width

	//they store the output ports requested by a header flit for the rest of the flits of the packet
    reg Nant, Sant, Eant, Want, Lant;

    //they store if VC of each port needs more requests
    reg VC_req_N,VC_req_S,VC_req_E,VC_req_W,VC_req_L;
    //they store if there is VC assigned for each port
    reg VC_assigned_N, VC_assigned_S, VC_assigned_E, VC_assigned_W, VC_assigned_L;
    //there is any grant form VA module?
    wire Grant_VA = Grant_VA_FromN | Grant_VA_FromS | Grant_VA_FromE | Grant_VA_FromW | Grant_VA_FromL;
    wire VC_assigned = Grant_VA | VC_assigned_N | VC_assigned_S | VC_assigned_E | VC_assigned_W | VC_assigned_L /*| 
    (((ftype_buf==`header | ftype_buf==`header_tail) `ifdef VC_SUPPORT & Grant_VA `endif) & (((N1 & ~bc) | bc_n) | ((S1 & ~bc) | bc_s) | ((E1 & ~bc) | bc_e) | ((W1 & ~bc) | bc_w) | ((L1 & ~bc) | bc_l)))*/;

    reg buf_bc_n, buf_bc_s, buf_bc_e, buf_bc_w, buf_bc_l;
    
    reg [FLIT_SIZE-1      : 0] flit_buf;
    reg [FLIT_TYPE_SIZE-1 : 0] ftype_buf;

    reg buf_free;

     /*When a header flit arrives, it requests VA for a channel. Once it has a grant, for each flit in each packet if makes a request for output port to VA.
     Only when it flit achieves two grants (each from VA and SA) it is granted to leave ROUTING module
	*/
    wire grantedN = Grant_SA_FromN;
	wire grantedE = Grant_SA_FromE;
	wire grantedW = Grant_SA_FromW;
	wire grantedS = Grant_SA_FromS;
	wire grantedL = Grant_SA_FromL;

    wire granted = (Grant_SA_FromN) | (Grant_SA_FromE) | (Grant_SA_FromW) | (Grant_SA_FromS) | (Grant_SA_FromL);

    //let's get info for routing output computation
    wire [ID_SIZE-1:0] Dst = Req ? Flit[DATA_NET_FLIT_DST_UNIT_ID_MSB:DATA_NET_FLIT_DST_UNIT_ID_LSB] : `V_ZERO(ID_SIZE);
    wire               bc  = Req ? BroadcastFlit                       :  1'b0;    
    
    //unicast outport computation
    wire [DIMX_w-1 : 0] x_cur;
    wire [DIMY_w-1 : 0] y_cur;
    wire [DIMX_w-1 : 0] x_dst;
    wire [DIMY_w-1 : 0] y_dst;


    if (GLBL_DIMX_w > 0) begin
      assign x_cur = ID[DIMX_w-1:0];
      assign x_dst = Dst[DIMX_w-1:0];
    end else begin
      assign x_cur = 1'b0;
      assign x_dst = 1'b0;
    end
        
    if (GLBL_DIMY_w > 0) begin
      assign y_cur = ID[DIMY_w+DIMX_w-1:DIMX_w];
      assign y_dst = Dst[DIMY_w+DIMX_w-1:DIMX_w];
    end else begin
      assign y_cur = 1'b0;
      assign y_dst = 1'b0;
    end 

    wire N1 = (x_cur == x_dst) & (y_cur > y_dst)  & ~bc;
    wire E1 = (x_cur < x_dst)                     & ~bc;
    wire W1 = (x_cur > x_dst)                     & ~bc;
    wire S1 = (x_cur == x_dst) & (y_cur < y_dst)  & ~bc;
    wire L1 = (x_cur == x_dst) & (y_cur == y_dst) & ~bc;
    //end unicast

    //broadcast output port computation
    wire bc_n = (y_cur > 0)       & bc & (PORT != `PORT_N);
    wire bc_s = (y_cur < DIMY-1) & bc & (PORT != `PORT_S);
    wire bc_e = (x_cur < DIMX-1) & bc & ((PORT == `PORT_W) || (PORT == `PORT_L));
    wire bc_w = (x_cur > 0)       & bc & ((PORT == `PORT_E) || (PORT == `PORT_L));
    wire bc_l = (PORT != `PORT_L) & bc;
    
    //available to ibuffer
    assign Avail = granted | buf_free;

    wire Request_VA = (Req) & (FlitType==`header | FlitType==`header_tail);
    assign Request_VA_N = ((Request_VA & ((N1 & ~bc) | bc_n)) | VC_req_N) & ~Grant_VA_FromN;
    assign Request_VA_S = ((Request_VA & ((S1 & ~bc) | bc_s)) | VC_req_S) & ~Grant_VA_FromS;
    assign Request_VA_E = ((Request_VA & ((E1 & ~bc) | bc_e)) | VC_req_E) & ~Grant_VA_FromE;
    assign Request_VA_W = ((Request_VA & ((W1 & ~bc) | bc_w)) | VC_req_W) & ~Grant_VA_FromW;
    assign Request_VA_L = ((Request_VA & ((L1 & ~bc) | bc_l)) | VC_req_L) & ~Grant_VA_FromL;

    //output request to sa signals (Frist of all we need a Grant from VA)
    wire TailFlit_granted = (ftype_buf==`tail | ftype_buf==`header_tail) & granted;

    wire forward_buf_free = (~Req & granted) | buf_free;

    wire pre_Request_SA_N = ((Grant_VA_FromN | VC_assigned_N) & (Req | (~forward_buf_free & ~buf_free))) | (~forward_buf_free & Grant_VA_FromN);
    wire pre_Request_SA_S = ((Grant_VA_FromS | VC_assigned_S) & (Req | (~forward_buf_free & ~buf_free))) | (~forward_buf_free & Grant_VA_FromS);
    wire pre_Request_SA_E = ((Grant_VA_FromE | VC_assigned_E) & (Req | (~forward_buf_free & ~buf_free))) | (~forward_buf_free & Grant_VA_FromE);
    wire pre_Request_SA_W = ((Grant_VA_FromW | VC_assigned_W) & (Req | (~forward_buf_free & ~buf_free))) | (~forward_buf_free & Grant_VA_FromW);
    wire pre_Request_SA_L = ((Grant_VA_FromL | VC_assigned_L) & (Req | (~forward_buf_free & ~buf_free))) | (~forward_buf_free & Grant_VA_FromL);
    
    assign Request_SA_N = pre_Request_SA_N & (~TailFlit_granted);
    assign Request_SA_S = pre_Request_SA_S & (~TailFlit_granted);
    assign Request_SA_E = pre_Request_SA_E & (~TailFlit_granted);
    assign Request_SA_W = pre_Request_SA_W & (~TailFlit_granted);
    assign Request_SA_L = pre_Request_SA_L & (~TailFlit_granted);

    //tail flit to SA
    assign TailFlit = (ftype_buf == `tail) | (ftype_buf == `header_tail);

    //output broadcast signals  
    assign BroadcastFlitN =  buf_bc_n;
    assign BroadcastFlitE =  buf_bc_e;
    assign BroadcastFlitW =  buf_bc_w;
    assign BroadcastFlitS =  buf_bc_s; 
    assign BroadcastFlitL =  buf_bc_l;

    assign FlitOut     =  flit_buf;
    assign FlitTypeOut =  ftype_buf;
    
always @ (posedge clk)
    if (rst_p) begin
        Nant     <= 1'b0; 
        Eant     <= 1'b0; 
        Want     <= 1'b0; 
        Sant     <= 1'b0; 
        Lant     <= 1'b0;
        
        buf_free <= 1'b1;
        
        buf_bc_n <= 1'b0;
        buf_bc_s <= 1'b0;
        buf_bc_e <= 1'b0;
        buf_bc_w <= 1'b0;
        buf_bc_l <= 1'b0;

        VC_req_N <= 1'b0;
        VC_req_E <= 1'b0;
        VC_req_W <= 1'b0;
        VC_req_S <= 1'b0;
        VC_req_L <= 1'b0;

        VC_assigned_N <= 1'b0;
        VC_assigned_E <= 1'b0;
        VC_assigned_W <= 1'b0;
        VC_assigned_S <= 1'b0;
        VC_assigned_L <= 1'b0;

        flit_buf    <= `V_ZERO(FLIT_SIZE);   
        ftype_buf   <= `V_ZERO(FLIT_TYPE_SIZE);

    end else begin
        
        VC_req_N <= Request_VA_N & ~Grant_VA_FromN;
        VC_req_E <= Request_VA_E & ~Grant_VA_FromE;
        VC_req_W <= Request_VA_W & ~Grant_VA_FromW;
        VC_req_S <= Request_VA_S & ~Grant_VA_FromS;
        VC_req_L <= Request_VA_L & ~Grant_VA_FromL;

        if (Req) begin
            flit_buf  <= Flit;
            ftype_buf <= FlitType;
                       
            buf_bc_n <= bc_n;
            buf_bc_s <= bc_s;
            buf_bc_e <= bc_e;
            buf_bc_w <= bc_w;
            buf_bc_l <= bc_l;

            buf_free  <= 1'b0;

        end else begin
            if (~buf_free & granted) begin
                buf_free <= 1'b1;
            end
            if (VC_assigned | Grant_VA)begin
                if (Grant_VA_FromN) VC_req_N <= 1'b0;
                if (Grant_VA_FromE) VC_req_E <= 1'b0;
                if (Grant_VA_FromW) VC_req_W <= 1'b0;
                if (Grant_VA_FromS) VC_req_S <= 1'b0;
                if (Grant_VA_FromL) VC_req_L <= 1'b0;
    
                 VC_assigned_N <= (Grant_VA_FromN | Nant);
                 VC_assigned_E <= (Grant_VA_FromE | Eant);
                 VC_assigned_W <= (Grant_VA_FromW | Want);
                 VC_assigned_S <= (Grant_VA_FromS | Sant);
                 VC_assigned_L <= (Grant_VA_FromL | Lant);

                 Nant <= (Grant_VA_FromN | VC_assigned_N);
                 Eant <= (Grant_VA_FromE | VC_assigned_E);
                 Want <= (Grant_VA_FromW | VC_assigned_W);
                 Sant <= (Grant_VA_FromS | VC_assigned_S);
                 Lant <= (Grant_VA_FromL | VC_assigned_L);
            end
        end

        if ( Grant_SA_FromN & TailFlit) begin Nant <= 1'b0; VC_assigned_N <= 1'b0; end 
        if ( Grant_SA_FromS & TailFlit) begin Sant <= 1'b0; VC_assigned_S <= 1'b0; end 
        if ( Grant_SA_FromE & TailFlit) begin Eant <= 1'b0; VC_assigned_E <= 1'b0; end 
        if ( Grant_SA_FromW & TailFlit) begin Want <= 1'b0; VC_assigned_W <= 1'b0; end 
        if ( Grant_SA_FromL & TailFlit) begin Lant <= 1'b0; VC_assigned_L <= 1'b0; end          
    end
endmodule
