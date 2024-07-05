`ifndef __MACRO_FUNCTIONS_H__
`define __MACRO_FUNCTIONS_H__
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
// Company:   GAP (UPV)  
// Engineer:  R. Tornero (ratorga@disca.upv.es)
// 
// Create Date: February 25, 2016
// Design Name: 
// Module Name: macro_functions.h
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//  This file defines some useful macro functions
//
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////

// * CONCAT_STRING concat the arguments as string
`define CONCAT_STRING(a,b) `"a``b`"
 
// * CONCAT concat the arguments, the same macro can be used as argument
`define CONCAT(a,b) a``b

// * WIDTH macro returns the log2 of a given number N. For using in other macros for instance
`define WIDTH(N) ( \
     N <=  1 ? 0 : \
     N <=  2 ? 1 : \
     N <=  4 ? 2 : \
     N <=  8 ? 3 : \
     N <= 16 ? 4 : \
     N <= 32 ? 5 : \
     N <= 64 ? 6 : \
     N <= 128 ? 7 : \
     N <= 256 ? 8 : \
     N <= 512 ? 9 : \
     N <= 1024 ? 10 : \
     N <= 2048 ? 11 : \
     N <= 4096 ? 12 : \
     N <= 8192 ? 13 : \
     N <= 16384 ? 14 : \
     N <= 32768 ? 15 : \
     N <= 65536 ? 16 : \
     N <= 131072 ? 17 : \
     N <= 262144 ? 18 : \
     N <= 524288 ? 19 : \
     N <= 1048576 ? 20 : \
     N <= 2097152 ? 21 : \
     N <= 4194304 ? 22 : \
     N <= 8388608 ? 23 : \
     N <= 16777216 ? 24 : \
     N <= 33554432 ? 25 : \
     N <= 67108864 ? 26 : \
     N <= 134217728 ? 27 : \
     N <= 268435456 ? 28 : \
     N <= 536870912 ? 29 : \
     N <= 1073741824 ? 30 : \
     N <= 2147483648 ? 31 : 32)                


// * MAX macro returns the maximum of two values 
`define MAX(A,B) (A > B ? A : B)           


// * V_ZERO makes a zero vector signal of LENGTH size. ZERO(3) = {000}
// * Usefull in concatenations using as argument a parameter or local parameter
`define V_ZERO(LENGTH)  {(LENGTH){1'b0}}     


// * V_ONE makes a vector signal with value 1. V_ONE(3) = {001} 
`define V_ONE(LENGTH) {`V_ZERO(LENGTH-1), 1'b1}


// * V_ALLX makes a vector signal with all values x 
`define V_ALLX(LENGTH)   {(LENGTH){1'bx}}

// * V_ALL1 makes a vector signal with all values x 
`define V_ALL1(LENGTH)   {(LENGTH){1'b1}}


// * OFFSET returns the offset of the desired bit in a vector signal given a base and the length of the field
// *       Ex.:  signal 0011100110. BIT(2, 3) --> 0, BIT(2,4) --> 1
`define OFFSET(BASE, LENGTH) (BASE+LENGTH-1)      


// * TRUNCATE(id, length) truncates the first argument to the given length. ID width must be greater than length 
`define TRUNCATE(ID, LENGTH) ID[LENGTH-1:0]

// * Truncates a literal (a macro without specifing bit size) to another with the bit size specified 
`define TRUNCATE_LITERAL(ID, LENGTH) `CONCAT(LENGTH, `CONCAT('d, ID))


// * Truncates a literal (a macro without specifing bit size) to another with the bit size specified 
`define TRUNCATE_LITERAL_BASE(ID, LENGTH, BASE) `CONCAT(LENGTH, `CONCAT(', `CONCAT(BASE, ID)))

// * VZERO compatibility
`define VZERO(LENGTH)  {(LENGTH){1'b0}}

// * VONE compatibility
`define VONE(LENGTH)  {`V_ZERO(LENGTH-1), 1'b1}

// * returns the offset of the desired bit in a vector signal given a base and the length of the field
// *       Ex.:  signal 0011100110. BIT(2, 3) --> 0, BIT(2,4) --> 1
`define BIT(BASE, LENGTH) (BASE+LENGTH-1)   


`endif  // ifdef MACRO_FUNCTIONS_H
 
