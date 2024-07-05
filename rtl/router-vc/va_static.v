//`ifdef BEHAVIORAL
//	library UNISIM;
//	use UNISIM.Vcomponents.all;
//`endif

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

//! This module implements the virtual channel allocator stage in a switch with virtual channels at a given output port of the switch.
//!
//! The module performs the virtual channel allocation for the VCs of a single VN. Therefore, each VN on the switch will have its own VA_STATIC module. 
//! In a switch there will be VN modules on each output port.
//!
//! This module implements a static allocation strategy. With this strategy each input VC will request always the same downstream VC. The requested VC will be the 
//! one with the same id within the VN (e.g VCs with id 0 will request VC0, VCs with id 1 will request VC1). This simplifies the allocation process although
//! may impact switch's performance. 
//!
//! The module receives requests from all the input ports of the switch. Each request is made of a vector of size equal to the number of VCs in a VN. 
//! Several bits in the vector may be set meaning that more than one VC from the same input port is requesting a new VC in this VN and for the associated 
//! output port.
//!
//! The module implements a Round-Robin arbiter for each VC. All the incoming requests from VCs with the same local id will compete for the same VC in the same 
//! round-robin arbiter.
//!
//! Grant signals are grouped in an output port (GRANTS). This port has all the grant signals for all VCs for the same VN and for all input ports. For each VC a unique
//! grant bit is set. A vector of assignments is outputed by this module. This vector will be used by the SA_VC (switch allocator) module.

module VA_STATIC #(
  parameter FLIT_SIZE          = 64,                                   //! flit size in bits
  parameter FLIT_TYPE_SIZE     = 2,                                    //! flit type size in bits
  parameter BROADCAST_SIZE     = 5,                                    //! broadcast field size in bits
  parameter NUM_VC             = 1,                                    //! number of virtual channels supported for each virtual network
  parameter NUM_VN             = 3,                                    //! number of virtual networks supported
  parameter NUM_PORTS          = 5,                                    //! number of physical ports in the switch
  localparam VN_w              = Log2_w(NUM_VN),                       //! width of VN field
  localparam VN_X_VC           = NUM_VN * NUM_VC,                      //! Number of VN x VC
  localparam VN_X_VC_w         = Log2_w(NUM_VN * NUM_VC),              //! width of VN_X_VC field
  localparam VN_X_VC_X_PORTS_w = Log2_w(NUM_VN * NUM_VC * NUM_PORTS),  //! width of VN_X_VC_X_PORTS field
  localparam ASSIGNS_PER_VN_w  = (VN_X_VC_X_PORTS_w + 1) * NUM_VC,     //! width of assigns_per_vn field (TODO: porque + 1?)
  localparam VC_X_PORTS        = NUM_VC * NUM_PORTS,                   //! number of VCs x PORTS
  localparam VC_w              = Log2_w(NUM_VC),                       //! width of VC field
  localparam NUM_PORTS_w       = Log2_w(NUM_PORTS)                     //! width of NUM_PORTS field
)(  
  input [VN_w-1:0]                  id,			          //! id of this VN
  input                             clk,              //! clock signal
  input                             rst_p,            //! reset signal
  input [NUM_VC-1 : 0]              REQ_E,			      //! request vector (one bit per VC) from the east port
  input [NUM_VC-1 : 0]              REQ_S,            //! request vector (one bit per VC) from the south port
  input [NUM_VC-1 : 0]              REQ_W,            //! request vector (one bit per VC) from the west port
  input [NUM_VC-1 : 0]              REQ_N,            //! request vector (one bit per VC) from the north port
  input [NUM_VC-1 : 0]              REQ_L,            //! request vector (one bit per VC) from the local port
  input                             free_VC_in,       //! signal to release a VC
  input [VN_X_VC_w-1 : 0]           VC_released_in,   //! virtual channel to release
  output reg [ASSIGNS_PER_VN_w-1:0] VC_assigns_out,   //! VC assign vector
  output reg [VC_X_PORTS-1 : 0]     GRANTS            //! grant vector (includes VC grants for each input port)
);

`include "common_functions.vh"


  // logic for freeing a VC
  wire free_VC     = ((VC_released_in < ((id*NUM_VC) + (NUM_VC))) &  (VC_released_in >= (id*NUM_VC)) & free_VC_in);  //! asserted when the VC to release belongs to this VN
  wire [VC_w-1:0] VC_released = free_VC ? (VC_released_in-(id*NUM_VC)) : `V_ZERO(VC_w);                        //! VC id (within this VN) to release

  reg  [NUM_VC-1:0]                 VC_assigned;	              //! Assigned vector, one bit per VC
  wire [NUM_VC-1:0]                 non_zero_grants;            //! Vector flag to reflect each VC whether it has an active grant
  wire [ASSIGNS_PER_VN_w-1 : 0]     w_VC_assigns_out;	          //! VC assign vector (to register at the output port VC_assigns_out)
  wire [VC_X_PORTS-1 : 0]           w_grants;                   //! grant vector (to register at the GRANTS output port)
  wire [NUM_VC-1:0]                 w_released;                 //! released vector (one bit per VC)
  wire [(NUM_VC*3)-1:0]             w_grant_id;                 //! grant id vector (3 bits per VC) TODO: porque 3 bits y para que es esto?

genvar j;
   generate
    for (j=0; j<NUM_VC; j=j+1) begin : VC
      wire [4:0] GRANTS_IN_RR;
      wire [4:0] grants_in;                // Grants incomming from Arbiter
      wire [2:0] grants_in_id;             // Position of incomming grant
      wire stat_free;                      // This channel is free
      wire is_released;
      wire grants_in_not_zeros;            // There is one grant for this channel
      wire [4:0] grant_out;
	end 
endgenerate

genvar i;
   generate
    for (i=0; i<NUM_VC; i=i+1) begin

      RR_X_IN #(
        .IO_SIZE         ( NUM_PORTS                                          ),
        .IO_w            ( NUM_PORTS_w                                        ),
        .OUTPUT_ID       ( "yes"                                              ),
        .SHUFFLE         ( "no"                                               ),
        .SUFFLE_DIM_1    ( 1                                                  ),
        .SUFFLE_DIM_2    ( 1                                                  )
      ) round_robin_PORTS_IN (
        .vector_in       ( {REQ_E[i], REQ_S[i], REQ_W[i], REQ_N[i], REQ_L[i]} ),
        .clk             ( clk                                                ),
        .rst_p           ( rst_p                                              ),
        .GRANTS_IN       ( VC[i].GRANTS_IN_RR                                 ),
        .vector_out      ( VC[i].grants_in                                    ),
        .grant_id        ( VC[i].grants_in_id                                 )
      );

 		
    assign VC[i].stat_free = (~(VC_assigned[i]));	//This channel is free
    assign VC[i].is_released = (free_VC & VC_released == i);                  //This channel is released in this cycle
 		assign VC[i].grants_in_not_zeros = (|VC[i].grants_in);
 		assign VC[i].GRANTS_IN_RR = ((VC[i].stat_free | VC[i].is_released) & VC[i].grants_in_not_zeros) ? VC[i].grants_in : `V_ZERO(5);	//Realimentation of grants_out to update token in RR
 		assign VC[i].grant_out = ((VC[i].stat_free | VC[i].is_released) & VC[i].grants_in_not_zeros) ? VC[i].grants_in : `V_ZERO(5);

 		//Vectors
 		assign non_zero_grants[i]                    = VC[i].grants_in_not_zeros;
    assign w_released[i]                         = VC[i].is_released;  	                                                                                                                                          
    assign w_grant_id[((i*3)+(3-1))-:3]          = VC[i].grants_in_id;
                                                                                                                                                                                                          //Se pone a cero
    for (j=0; j<5; j=j+1) begin
	    assign w_grants[(j*NUM_VC) +i] = VC[i].grant_out[j];  //To translate in {REQ_E[i], REQ_S[i], REQ_W[i], REQ_N[i], REQ_L[i]} format.
	  end
	end 
endgenerate
                                                                                            
wire [NUM_VC-1:0] grant_and_assigned       = (non_zero_grants & (~VC_assigned | w_released));                 //! bit vector for granted and assigned VCs (one bit per VC)
wire [NUM_VC-1:0] no_grant_and_released    = (~non_zero_grants & w_released);                                 //! bit vector for no granted and released VCs (one bit per VC)
wire [NUM_VC-1:0] remains_in_the_same_stat = ~(grant_and_assigned | no_grant_and_released);                   //! bit vector for VCs which remain in the same state (one bit per VC)
wire [NUM_VC-1:0] w_VC_assigned            = (remains_in_the_same_stat & VC_assigned) | grant_and_assigned;   //! final state for each VC (bit vector, one bit per VC)

generate
    for (i=0; i<NUM_VC; i=i+1)begin
      assign w_VC_assigns_out[((i*(VN_X_VC_X_PORTS_w+1))+(VN_X_VC_X_PORTS_w))-:(VN_X_VC_X_PORTS_w+1)] = (grant_and_assigned[i]) ? ((w_grant_id[((i*3)+(3-1))-:3]*VN_X_VC) + ((id*NUM_VC)+i) ) :
                                                                                                                    (no_grant_and_released[i]) ? {(VN_X_VC_X_PORTS_w+1){1'b1}} : 
                                                                                                                    VC_assigns_out[((i*(VN_X_VC_X_PORTS_w+1))+(VN_X_VC_X_PORTS_w))-:(VN_X_VC_X_PORTS_w+1)];
    end
endgenerate

always @(posedge clk) begin
	if (rst_p) begin
		VC_assigned    <= `V_ZERO(NUM_VC);
		VC_assigns_out <= {ASSIGNS_PER_VN_w{1'b1}};
		GRANTS         <= `V_ZERO(VC_X_PORTS);
     end else begin 
		VC_assigned    <= w_VC_assigned;
    VC_assigns_out <= w_VC_assigns_out;
		GRANTS         <= w_grants;
	end 
end
endmodule


