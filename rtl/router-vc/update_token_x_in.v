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
`include "macro_functions.h"

// This module keeps track of the token used in a generic arbiter.
//
// <br>
module UPDATE_TOKEN_X_IN #(
parameter IO_SIZE            = 5, // size in bits of input array
parameter IO_w               = 3  // size in bits of output array
)(
    input clk,             // clock signal
    input rst_p,           // reset signal. Positive edge triggered.
    input [IO_SIZE-1:0] vector_in, // data in array
    output reg [IO_w-1:0] token    // output data array. TODO:: @jflich add description
    );
 wire [IO_w-1:0] vector_id;
encoder #(
     .lenght_in(IO_SIZE),
     .lenght_out(IO_w)       
     ) encoder_64 (
        .vector_in(vector_in),
        .vector_id(vector_id)
    );

always @(posedge clk)
begin
    if(rst_p) 
    begin
        token <= `V_ZERO(IO_w);
    end
    else
    begin
        if(|vector_in)begin
            token <= (vector_id == (IO_SIZE-1)) ? `V_ZERO(IO_w) : vector_id + 1;
        end
    end
end
    
    
endmodule
