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
// Company: GAP (UPV)  
// Engineer:  R. Tornero (ratorga@disca.upv.es)
// 
// Create Date: November 9, 2016
// Design Name: 
// Module Name: common_functions.vh
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
//   This file contains different funcions used by many modules
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////


//
// Gets the log2 of a given number, but for log2(1) = 1, and not 0 as it is the actual result
// Useful to, for example, get the number of necessary bits to represent a decimal number
//
function integer Log2_w;
  input integer value;
begin
  for (Log2_w=0; value>0; Log2_w=Log2_w+1)
    value = value>>1;
  end
endfunction

//
// Gets the log2 of a given number
//
function integer Log2;
  input integer value;
begin
  value = value-1;
  for (Log2=0; value>0; Log2=Log2+1)
    value = value>>1;
  end
endfunction

//
// As Log2_w function doesn't return the correct value for powers of two,
// Log2_w2 function has been added.
// It should be used from now on to calculate the log2 in the cases where we need log2(1)=0.
// Eventually it should replace completely the Log2_w function
//
function integer Log2_w2;
  input integer value;
begin
  if (value == 1)
    Log2_w2 = 1;
  else
    Log2_w2 = Log2(value);
end
endfunction

//
// Gets the first integer divisor of a number 'DIV' when
// the provided divisor 'DIVISOR' is not an integer divisor
//
function integer FIRST_INTEGER_DIVISOR;
  input integer DIV;
  input integer DIVISOR;
  
  integer j;
  integer found;
begin
  found = 0;
  if (DIVISOR <= 1) begin
    FIRST_INTEGER_DIVISOR = DIV;
    found = 1;
  end else begin
    //
    if (DIV <= DIVISOR) begin
      FIRST_INTEGER_DIVISOR = DIV;
      found = 1;
    end else begin
      //
      if (DIV % DIVISOR == 0) begin
        FIRST_INTEGER_DIVISOR = DIVISOR;
        found = 1;
      end else begin
        for (j = 4; j <= DIV; j = j + 1) begin
          if (DIV % j == 0 && found == 0) begin
            FIRST_INTEGER_DIVISOR = j;
            found = 1;
          end
        end
      end // if (DIV % DIVISOR... else ...
      // 
    end
    //
  end // if (DIVISOR <= 1) ... else ...
  
  if (found == 0) begin
    FIRST_INTEGER_DIVISOR = DIV;
  end
end
endfunction  

// This function returns the number of padding bits required for spliting a bus of ' num signals' wires
// into chuncks of 'payload_size'
function integer GET_NUM_PADDING_BITS;
  input integer num_signals;
  input integer payload_size;
  
  integer mod;
  integer res;
begin  
  mod = (num_signals % payload_size);
     
  if (mod == 0) begin
    res = 0;
  end else begin
    res = payload_size - mod;
  end
  
  GET_NUM_PADDING_BITS = res;
end  


endfunction


