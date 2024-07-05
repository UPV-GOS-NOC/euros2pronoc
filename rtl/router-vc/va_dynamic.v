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

//DYNAMIC IMPLEMENTATION
module BASIC_VA_DYNAMIC #(
  
parameter FLIT_SIZE          = 64,
parameter FLIT_TYPE_SIZE     = 2,
parameter BROADCAST_SIZE     = 5,
parameter NUM_VC             = 1,                 // Number of Virtual Channels supported for each Virtual Network
parameter NUM_VN             = 3,                  // Number of Virtual Networks supported
parameter VN_WEIGHT_VECTOR_w = 0
)(id,/*Port,*/
		  clk, 
          rst_p,
          REQ_E,        //request to allocate an output VC signal (from rt at east)
          REQ_S,
          REQ_W,           
          REQ_N, 
	      REQ_L,
		  free_VC_in,		// There is one VC released from output VC ?
		  VC_released_in,  // VC released from output VC
		  VC_assigns_out,	// VC assignations, each port is using one VC {E*NUM_VC, S*NUM_VC, W*NUM_VC, N*NUM_VC, L*NUM_VC}
          GRANTS); 		//Grant access to output VC signal
				

`include "common_functions.vh"
`include "data_net_virtual_channel.vh"
  
    input [bits_VN-1:0] id;							//Id of this VN
    //input [2:0] Port;
    input clk;
    input rst_p;
    input [NUM_VC-1:0] REQ_E;						//Request VC grant for east port
    input [NUM_VC-1:0] REQ_S;
    input [NUM_VC-1:0] REQ_W;
    input [NUM_VC-1:0] REQ_N;
    input [NUM_VC-1:0] REQ_L;
	input  free_VC_in;
	input [bits_VN_X_VC-1:0] VC_released_in;

	output reg [long_VC_assigns_per_VN-1:0] VC_assigns_out; 			//[bits_VN_X_VC_AND_PORTS-1:0] VC_assigns [NUM_VC-1:0] --> {E*NUM_VC, S*NUM_VC, W*NUM_VC, N*NUM_VC, L*NUM_VC}
    output [NUM_VC_AND_PORTS-1 : 0] GRANTS;

    wire free_VC = ((VC_released_in < ((id*NUM_VC) + (NUM_VC))) & 
    			   		 (VC_released_in >= (id*NUM_VC)) & free_VC_in);
    wire [bits_VC-1:0] VC_released = free_VC ? (VC_released_in-(id*NUM_VC)) : `V_ZERO(bits_VC);

  wire stat_free;
  wire [NUM_VC-1:0] STATS_selected;

wire [NUM_VC_AND_PORTS-1 : 0] REQ = {REQ_E, REQ_S, REQ_W, REQ_N, REQ_L};
wire [NUM_VC_AND_PORTS-1:0] grants_in;						//Grants incomming from Arbiter
wire [bits_VC_AND_PORTS-1:0] grants_in_id;					//Position of incomming grant
wire grants_in_not_zeros = (|grants_in); 

wire [NUM_VC_AND_PORTS-1:0] GRANTS_IN_RR = (grants_in_not_zeros & stat_free) ? grants_in : `V_ZERO(NUM_VC_AND_PORTS);

RR_X_IN #(
//
.IO_SIZE(NUM_VC_AND_PORTS),
.IO_w(bits_VC_AND_PORTS),
.OUTPUT_ID("yes"),
.SHUFFLE("yes"),
.SUFFLE_DIM_1(NUM_PORTS),
.SUFFLE_DIM_2(NUM_VC)

)round_robin_NUM_VC_AND_PORTS(
.vector_in(REQ),
.clk(clk),
.rst_p(rst_p),
.GRANTS_IN(GRANTS_IN_RR),
.vector_out(grants_in),
.grant_id(grants_in_id));

//----------------------------------------------------
reg [NUM_VC_AND_PORTS-1:0] grants_out;
reg [NUM_VC-1:0] STATS;
//wire req_in_not_zeros = (|REQ); 
wire [bits_VC-1:0] current_vc = grants_in_id % NUM_VC;
wire [2:0] current_port = grants_in_id / NUM_VC;
wire [bits_VC-1:0] pointer;// = `WIDTH(STATS_selected);		//It will get the corresponding VC to this grant
reg [bits_VC-1:0] last_pointer;
assign GRANTS = /*grants_in_not_zeros ?*/ grants_out /*: `V_ZERO(NUM_VC_AND_PORTS)*/;

wire [NUM_VC-1:0] STATS_free;
wire [NUM_VC-1:0] grant_in_id_already_assigned;
wire [NUM_VC-1:0] grant_released;

genvar j;
generate
    for( j=0; j<NUM_VC;j = j+1) begin : LOOP
    
	    assign STATS_free[j] = (~(STATS[j])); 	                                                   //It will get a vector with free stats = 1
	    assign grant_in_id_already_assigned[j] = ((VC_assigns_out[(j*(bits_VN_X_VC_AND_PORTS+1)+(bits_VN_X_VC_AND_PORTS))-:(bits_VN_X_VC_AND_PORTS+1)] == ((current_port*NUM_VN_X_VC)+(current_vc+(id*NUM_VC)))) & (STATS[j]) & grants_in_not_zeros & ~grant_released[j]);                                                                                           //There are any with the same id?    	
    	//assign grant_in_id_already_assigned[j] = ((VC_assigns_out[(((id*NUM_VC)+j)*bits_VN_X_VC_AND_PORTS+(bits_VN_X_VC_AND_PORTS-1))-:bits_VN_X_VC_AND_PORTS] == ((grants_in_id-((id*NUM_VC)+j)/NUM_VC)*NUM_VN_X_VC)) & (STATS[j]));
        assign grant_released[j] = (VC_released==j & free_VC);									   //Is released in this cycle
    end
 endgenerate

 wire [bits_VC-1:0] vector_id_already_assigned;
encoder #(
     .lenght_in(NUM_VC),
     .lenght_out(bits_VC)       
     ) encoder_64 (
        .enable(|(64'd0+grant_in_id_already_assigned)), 
        .vector_in(grant_in_id_already_assigned),
        .vector_id(vector_id_already_assigned)
    );

wire [NUM_VC-1:0] STATS_available = //(|grant_in_id_already_assigned) ? `V_ZERO(NUM_VC):					//This grant is already assigned
												  			free_VC ? (STATS_free | grant_released) :	//This grant is released in this cycle and it channel is ready to use
														 			   STATS_free;						//There is stats free and no assigned to the same id
assign stat_free = (free_VC | (|STATS_free) );	//There is one channel released in this cycle or there is one with free status.
wire [NUM_VC-1:0] GRANTS_IN_RR_STATS = (grants_in_not_zeros & stat_free & (|STATS_selected)) ? STATS_selected : `V_ZERO(NUM_VC);
/*//We use a FPA to fill up one channel if there are someone free.----------------------------------------------------------------------
for( j=0; j<NUM_VC;j = j+1) begin
  assign STATS_selected[j] = (j==0) ? STATS_available[0] : ((STATS_available[j]) & (~|STATS_available[(j-1) -: j]));
end*/

RR_X_IN #(
//
.IO_SIZE(NUM_VC),
.IO_w(bits_VC),
.OUTPUT_ID("yes"),
.SHUFFLE("no"),
.SUFFLE_DIM_1(1),
.SUFFLE_DIM_2(1)

)round_robin_NUM_VC(
.vector_in(STATS_available),
.clk(clk),
.rst_p(rst_p),
.GRANTS_IN(GRANTS_IN_RR_STATS),
.vector_out(STATS_selected),
.grant_id(pointer));
//-------------------------------------------------------------------------------------------------------------------------------------


always @(posedge clk) begin
	if (rst_p) begin
		STATS <= `V_ZERO(NUM_VC);
		VC_assigns_out <= {long_VC_assigns_per_VN{1'b1}}; //All entries bits to one
		grants_out <= `V_ZERO(NUM_VC_AND_PORTS);
	end
	else begin	
		if(grants_in_not_zeros & stat_free & (|STATS_selected)) begin
  		  	STATS <= (STATS_selected & STATS_available) | (~STATS_available);
			VC_assigns_out[((pointer)*(bits_VN_X_VC_AND_PORTS+1)+(bits_VN_X_VC_AND_PORTS))-:(bits_VN_X_VC_AND_PORTS+1)] <= ((current_port*NUM_VN_X_VC)+current_vc+(id*NUM_VC));
        	grants_out <= grants_in;
        	if(free_VC & ~(pointer==VC_released))begin
            	VC_assigns_out[((VC_released)*(bits_VN_X_VC_AND_PORTS+1)+(bits_VN_X_VC_AND_PORTS))-:(bits_VN_X_VC_AND_PORTS+1)] <= {(bits_VN_X_VC_AND_PORTS+1){1'b1}}; //Invalidate this entry
        	end
        	if(|grant_in_id_already_assigned & ~(((current_port*NUM_VN_X_VC)+(current_vc+(id*NUM_VC))) == 0) )begin
            	VC_assigns_out[(vector_id_already_assigned*(bits_VN_X_VC_AND_PORTS+1)+(bits_VN_X_VC_AND_PORTS))-:(bits_VN_X_VC_AND_PORTS+1)] <= {(bits_VN_X_VC_AND_PORTS+1){1'b1}}; //Invalidate this entry
        	end
		end else if(free_VC)begin
			STATS[VC_released] <= 1'b0;						//One channel released right now
            VC_assigns_out[((VC_released)*(bits_VN_X_VC_AND_PORTS+1)+(bits_VN_X_VC_AND_PORTS))-:(bits_VN_X_VC_AND_PORTS+1)] <= {(bits_VN_X_VC_AND_PORTS+1){1'b1}}; //Invalidate this entry
			grants_out <= `V_ZERO(NUM_VC_AND_PORTS);			//Grants in is zero or there is not vc free
		end else begin
			grants_out <= `V_ZERO(NUM_VC_AND_PORTS);			//Grants in is zero or there is not vc free
		end
	end//else
end

endmodule
