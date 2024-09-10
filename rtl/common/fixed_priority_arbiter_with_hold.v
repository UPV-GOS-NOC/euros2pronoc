// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file fixed_priority_arbiter_with_hold.v
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date April 24th, 2024
//
// @title Fixed priority arbiter with hold
//
// Completely unfair arbiter that arbitrates the access to a 
// shared resource based on fixed priorities and keep access
// granted to same requester while it keeps hold signal asserted.
//
// Highest priority is given to requester 0. Then, priorities
// are given in linear order of increasing requester numbering.
// The lowest priority is given to requester N.
//
// The module uses two parameters
//   'NumberOfRequesters' to define the number of requesters.
//
// Implementation:
//  grant[i] = request[i] & carry[i]
//  carry[i+1] = ~request[i] & carry[i]

`timescale 1ns/1ns

module fixed_priority_arbiter_with_hold #(
  // Sets the number of requester to the shared resource
  parameter integer NumberOfRequesters = 2  
) (
  input clk_i,
  
  input  [NumberOfRequesters-1:0] request_i,
  input  [NumberOfRequesters-1:0] hold_i,
  output [NumberOfRequesters-1:0] grant_o    
);
  
  wire [NumberOfRequesters-1:0] carry; 
  wire [NumberOfRequesters-1:0] internal_grant;


  reg  [NumberOfRequesters-1:0] last_grant_q;
  wire [NumberOfRequesters-1:0] hold;
  wire                          anyhold;
  wire [NumberOfRequesters-1:0] grant;

  assign carry[0] = 1'b1;
  assign carry[NumberOfRequesters-1:1]          = ~request_i[NumberOfRequesters-2:0] & carry[NumberOfRequesters-2:0];
  assign internal_grant[NumberOfRequesters-1:0] = request_i[NumberOfRequesters-1:0] & carry[NumberOfRequesters-1:0];

  assign anyhold = |hold;
  assign hold = last_grant_q & hold_i;
  assign grant = anyhold ? hold : internal_grant;
  assign grant_o = grant;

  always @(posedge clk_i) begin
    last_grant_q <= grant;
  end

endmodule