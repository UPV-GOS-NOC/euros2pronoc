// SPDX-License-Identifier: MIT
//
// @copyright (c) 2024 Universitat Politecnica de Valencia (UPV)
// All right reserved
//
// @file network_signal_converter.v
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date February 12th, 2024
//
// @title Network Signals Unpacker. 
//
// This module unpacks the network signals
//

`timescale 1ns/1ns

module network_signal_converter #(
  parameter  integer NetworkIfFlitWidth             = 0,  // Network interface configuration. Size (in bits) of the data flit signal
  parameter  integer NetworkIfFlitTypeWidth         = 0,  // Network interface configuration. Size (in bits) of the Flit Type signal
  parameter  integer NetworkIfBroadcastWidth        = 0,  // Network interface configuration. Size (in bits) of the broadcast signal
  parameter  integer NetworkIfVirtualNetworkIdWidth = 0,  // Network interface configuration. Size (in bits) of the Virtual Network identifier
  localparam integer NetworkIfDataWidth = NetworkIfFlitWidth +
                                          NetworkIfFlitTypeWidth +
                                          NetworkIfBroadcastWidth +
                                          NetworkIfVirtualNetworkIdWidth  // Network configuration. Size (in bits) to pack the network signals
) (
  // Network packed signals  
  input                          network_valid_i,
  output                         network_ready_o,
  input [NetworkIfDataWidth-1:0] network_data_i,

  // Network unpacked signals
  output                                      network_valid_o,
  input                                       network_ready_i,
  output [NetworkIfFlitWidth-1:0]             network_flit_o,
  output [NetworkIfFlitTypeWidth-1:0]         network_flit_type_o,
  output [NetworkIfBroadcastWidth-1:0]        network_broadcast_o,
  output [NetworkIfVirtualNetworkIdWidth-1:0] network_virtual_network_id_o
);

  // Let's use Constant convention here since both Constant and Parameters are mixed here
  localparam integer NETWORK_FLIT_LSB = 0;
  localparam integer NETWORK_FLIT_MSB = NETWORK_FLIT_LSB + NetworkIfFlitWidth - 1;
  localparam integer NETWORK_FLIT_TYPE_LSB = NETWORK_FLIT_MSB + 1;
  localparam integer NETWORK_FLIT_TYPE_MSB = NETWORK_FLIT_TYPE_LSB + NetworkIfFlitTypeWidth - 1;
  localparam integer NETWORK_BROADCAST_LSB = NETWORK_FLIT_TYPE_MSB + 1;
  localparam integer NETWORK_BROADCAST_MSB = NETWORK_BROADCAST_LSB + NetworkIfBroadcastWidth - 1;
  localparam integer NETWORK_VIRTUAL_NETWORK_ID_LSB = NETWORK_BROADCAST_MSB + 1;
  localparam integer NETWORK_VIRTUAL_NETWORK_ID_MSB = NETWORK_VIRTUAL_NETWORK_ID_LSB + NetworkIfVirtualNetworkIdWidth - 1;

  assign network_valid_o              = network_valid_i;
  assign network_ready_o              = network_ready_i;
  assign network_flit_o               = network_data_i[NETWORK_FLIT_MSB:NETWORK_FLIT_LSB];
  assign network_flit_type_o          = network_data_i[NETWORK_FLIT_TYPE_MSB:NETWORK_FLIT_TYPE_LSB];
  assign network_broadcast_o          = network_data_i[NETWORK_BROADCAST_MSB:NETWORK_BROADCAST_LSB];
  assign network_virtual_network_id_o = network_data_i[NETWORK_VIRTUAL_NETWORK_ID_MSB:NETWORK_VIRTUAL_NETWORK_ID_LSB];

endmodule
