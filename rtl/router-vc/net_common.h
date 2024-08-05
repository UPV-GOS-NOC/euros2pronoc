`ifndef __NET_COMMON_H__
`define __NET_COMMON_H__
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
// Create Date: 04.11.2016
// Design Name: 
// Module Name: global_includes.h
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
//  This file provides common definitions for the network switches
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////



//****************************************************************************
//
// * PORTS
//
//**************************************************************************** 
`define NUM_PORTS               5
`define PORT_L                  3'b000      // Local port id code
`define PORT_E                  3'b001      // East port id code
`define PORT_W                  3'b011      // West port id code
`define PORT_N                  3'b101      // Nort port id code
`define PORT_S                  3'b111      // South port id code

// number of bit necessary to encode the DIRECTION text string (each char requires 8 bits)
`define AXIS_DIRECTION_WIDTH 120

`define DIRECTION_NORTH "DIRECTION_NORTH"
`define DIRECTION_EAST  "DIRECTION_EAST"
`define DIRECTION_WEST  "DIRECTION_WEST"
`define DIRECTION_SOUTH "DIRECTION_SOUTH"


//****************************************************************************
//
// * Flit types
//
//**************************************************************************** 
`define payload                 2'd1  //2'd0        // Flit type: payload      
`define tail                    2'd2  //2'd1        // Flit type: tail          
`define header_tail             2'd3 //2'd2        // Flit type: header_tail (single flit message)
`define header                  2'd0  //2'd3        // Flit type: header


`endif // header file
