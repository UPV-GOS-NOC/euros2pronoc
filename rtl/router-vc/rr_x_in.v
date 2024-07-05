`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
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
// Engineer: T. Piconell (tompic@gap.upv.es)
// 
// Create Date: 
// Design Name: 
// Module Name: 
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
//  
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////

/*
//Example using generic round-robin with suffle and id functions
RR_X_IN #(
//
.IO_SIZE(NUM_VN_X_VC),
.IO_w(bits_VN_X_VC),
.OUTPUT_ID("yes"),
.SHUFFLE("yes"),
.SUFFLE_DIM_1(NUM_VN),
.SUFFLE_DIM_2(NUM_VC)

)round_robin_VN(
.vector_in(vector_in),
.clk(clk),
.rst_p(rst_p),
.GRANTS_IN(GRANTS_IN_RR),
.vector_out(grants_in),
.grant_id(grants_in_id));*/

`include "macro_functions.h"

//
// Generic round-robin with shuffle and id functions
//
//
// TODO:: @jflich @ratorga add description
//
module RR_X_IN #(
parameter IO_SIZE            = 5, // size in bits of input, output and GRANTS_in arrays
parameter IO_w               = 3, // size in bits of grants_id array
parameter OUTPUT_ID          = "no",
parameter SHUFFLE            = "no",
parameter SUFFLE_DIM_1       = 1,
parameter SUFFLE_DIM_2       = 1
)(
    input [IO_SIZE-1:0] vector_in,
    input clk,                            // clock 
    input rst_p,                          // reset signal
    input [IO_SIZE-1:0] GRANTS_IN,        //
    output [IO_w-1:0] grant_id,           //Grant identifier Zero means non active then [bits_VC_AND_PORTS:1]
    output [IO_SIZE-1:0] vector_out       //
    );

wire [IO_w-1:0] w_token;

wire [IO_SIZE-1:0] w_right_to_FPA;
wire [IO_SIZE-1:0] w_FPA_to_left;
wire [IO_SIZE-1:0] vector_out_left;

localparam OUTPUT_ID_SUPPORT = (OUTPUT_ID == "yes") ? 1 : 0;
localparam SHUFFLE_SUPPORT = (SHUFFLE == "yes") ? 1 : 0;


  //Shuffle function for vector_in vector************************************
  genvar i,j;
  wire [IO_SIZE-1:0] vector_in_shuffle;
  generate
  if (SHUFFLE_SUPPORT) begin
    for(j=0; j<SUFFLE_DIM_1;j = j+1)begin : DIM_1_v
        wire [SUFFLE_DIM_2-1:0] sub_vector_in = vector_in[(j * SUFFLE_DIM_2) + (SUFFLE_DIM_2 - 1)-:SUFFLE_DIM_2];
    end

    for(i=0; i<SUFFLE_DIM_2;i = i+1)begin
        for(j=0; j<SUFFLE_DIM_1;j = j+1)begin
            assign vector_in_shuffle[((i*SUFFLE_DIM_1)+j)] = DIM_1_v[j].sub_vector_in[i];
        end
    end
  end// SHUFFLE_SUPPORT
  endgenerate
  //------------------------------------------------------------------------

  //Shuffle function for GRANTS_IN vector***********************************
  wire [IO_SIZE-1:0] GRANTS_IN_shuffle;
  generate
  if (SHUFFLE_SUPPORT) begin  
    for(j=0; j<SUFFLE_DIM_1;j = j+1)begin : DIM_1_G
        wire [SUFFLE_DIM_2-1:0] sub_GRANTS_IN = GRANTS_IN[(j * SUFFLE_DIM_2) + (SUFFLE_DIM_2 - 1)-:SUFFLE_DIM_2];
    end

    for(i=0; i<SUFFLE_DIM_2;i = i+1)begin
        for(j=0; j<SUFFLE_DIM_1;j = j+1)begin
            assign GRANTS_IN_shuffle[(i*SUFFLE_DIM_1)+j] = DIM_1_G[j].sub_GRANTS_IN[i];
        end
    end
  end// SHUFFLE_SUPPORT
  endgenerate
  //------------------------------------------------------------------------

  //Unshuffle function for vector_out_left vector******************************
  wire [IO_SIZE-1:0] vector_out_left_unshuffle;
  generate
  if (SHUFFLE_SUPPORT) begin  
    for(i=0; i<SUFFLE_DIM_2;i = i+1)begin : VECTOR
        wire [SUFFLE_DIM_1-1:0] v_out_left;
    end

    for(i=0; i<SUFFLE_DIM_2;i = i+1)begin
        assign VECTOR[i].v_out_left = vector_out_left[(i * SUFFLE_DIM_1) + (SUFFLE_DIM_1 - 1)-:SUFFLE_DIM_1];
    end


    for(j=0; j<SUFFLE_DIM_1;j = j+1)begin
        for(i=0; i<SUFFLE_DIM_2;i = i+1)begin
            assign vector_out_left_unshuffle[(j*SUFFLE_DIM_2)+i] = VECTOR[i].v_out_left[j];
        end
    end
  end// SHUFFLE_SUPPORT
  endgenerate  
  //------------------------------------------------------------------------


wire [IO_w-1:0] vector_id;
if (OUTPUT_ID_SUPPORT) begin
  encoder #(
       .lenght_in(IO_SIZE),
       .lenght_out(IO_w)       
       ) encoder_64 (
          .vector_in((SHUFFLE == "yes") ? vector_out_left_unshuffle:vector_out_left),
          .vector_id(vector_id)
      );  
end// end OUTPUT_ID_SUPPORT

if (OUTPUT_ID_SUPPORT) begin
  assign grant_id = (rst_p) ? `V_ZERO(IO_w) : vector_id;    //Log_base2 of (vector_out_left) it will get the right position 
end else begin
  assign grant_id = `V_ZERO(IO_w);    //Log_base2 of (vector_out_left) it will get the right position 
end

assign vector_out = (rst_p) ? `V_ZERO(IO_SIZE) : ((SHUFFLE == "yes") ? vector_out_left_unshuffle:vector_out_left);

ROT_RIGHT_X_IN  #(
  .IO_SIZE            ( IO_SIZE                  ),
  .IO_w               ( IO_w                     )

)rot_right_inst0(
    .vector_in((SHUFFLE == "yes") ? vector_in_shuffle:vector_in),
    .shift(w_token),
    .vector_out(w_right_to_FPA)
);

FPA_X_IN  #(
  .IO_SIZE            ( IO_SIZE                  ),
  .IO_w               ( IO_w                     )

)FPA_inst0(
    .vector_in(w_right_to_FPA),
    .vector_out(w_FPA_to_left)
    );
    
ROT_LEFT_X_IN  #(
  .IO_SIZE            ( IO_SIZE                  ),
  .IO_w               ( IO_w                     )

)rot_left_inst0(
    .vector_in(w_FPA_to_left),
    .shift(w_token),
    .vector_out(vector_out_left)
    );
    
UPDATE_TOKEN_X_IN  #(
  .IO_SIZE            ( IO_SIZE                  ),
  .IO_w               ( IO_w                     )

)update_token_inst0(
    .clk(clk),
    .rst_p(rst_p),
    .vector_in((SHUFFLE == "yes") ? GRANTS_IN_shuffle:GRANTS_IN),
    .token(w_token)
    );
    
 endmodule
     
