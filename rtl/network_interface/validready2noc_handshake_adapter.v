// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file validready2noc_handshake_adapter.v
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Nov 12th, 2023
//
// @title  Valid/Ready to NoC Handshake adapter
//
// Adapts 'Standard' Valid/Ready handshake to
// the custom valid/avail NoC handshake
//
// In the NoC handshake, valid can only be
// asserted if avail is already asserted
//
// This module should be deprecated once we update
// the Router local port handshake protocol to
// Valid/Ready

`timescale 1ns/1ns

module validready2noc_handshake_adapter #(
  parameter integer NumberOfVirtualChannels = 0,
  parameter integer VirtualChannelIdWidth   = 0
) (
  // Valid/Ready handshake
  input  wire valid_i,
  output wire ready_o,
  input  wire [VirtualChannelIdWidth-1:0] virtual_channel_id_i,
  
  // NoC handshake
  output wire                               valid_o,
  input  wire [NumberOfVirtualChannels-1:0] avail_i
);

  reg noc_valid;

  // TODO this approach of handling ready_o produces
  //      HoL blocking. Improve this module with
  //      a FIFO per Virtual Channel
  assign valid_o = noc_valid;
  assign ready_o = avail_i[virtual_channel_id_i];

  always @(*) begin
    noc_valid = 0;
    
    if (valid_i & avail_i[virtual_channel_id_i]) begin
      noc_valid = 1;
    end
  end
endmodule