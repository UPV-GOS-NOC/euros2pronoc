// SPDX-License-Identifier: MIT
//
// @copyright (c) 2024 Universitat Politecnica de Valencia (UPV)
// All right reserved
//
// @file filereg_fromnet.v
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 24th, 2024
//
// @title NoC protocol to Router register file access converter. 
//
// This module receives network packets and convert them into
// requests to the router register file
//
// see router-vc/filereg.v for more information on the type
// of requests
//

module filereg_fromnet #(
  parameter integer FileRegIfDataWidth = 0,  // FileReg interface configuration. Size (in bits) of the data signal

  parameter  integer NetworkIfFlitWidth             = 0,  // Network interface configuration. Size (in bits) of the data flit signal
  parameter  integer NetworkIfFlitTypeWidth         = 0,  // Network interface configuration. Size (in bits) of the Flit Type signal
  parameter  integer NetworkIfBroadcastWidth        = 0,  // Network interface configuration. Size (in bits) of the broadcast signal
  parameter  integer NetworkIfVirtualNetworkIdWidth = 0,  // Network interface configuration. Size (in bits) of the Virtual Network identifier
  localparam integer NetworkIfDataWidth = NetworkIfFlitWidth +
                                          NetworkIfFlitTypeWidth +
                                          NetworkIfBroadcastWidth +
                                          NetworkIfVirtualNetworkIdWidth  // Network configuration. Size (in bits) to pack the network signals
) (
  // Clocks and resets
  input clk_i,
  input rst_i,

  // AXI Stream Initiator interface 
  output                          filereg_m_tvalid_o,
  input                           filereg_m_tready_i,
  output [FileRegIfDataWidth-1:0] filereg_m_tdata_o,
  output                          filereg_m_tlast_o,

  // Network interface with packed data signals
  input                          network_valid_i,
  output                         network_ready_o,
  input [NetworkIfDataWidth-1:0] network_data_i
);

  // An access request to the filereg is composed of two flits
  // The first incoming flit contains the MSB word of the request
  // the second flit contains the LSB word of the request
  localparam integer NUMBEROF_FLITS_PER_REQUEST = 2;

  // Number of bits required for counting the number of words per request
  // 1-bit counter for two words
  localparam integer WORD_COUNTER_WIDTH = 1;

  reg [WORD_COUNTER_WIDTH-1:0] word_counter;


  // Drive signals between the network signal unpacker and the downsizer
  wire                                      network_valid;
  wire                                      network_ready;
  wire [NetworkIfFlitWidth-1:0]             network_flit;
  wire [NetworkIfFlitTypeWidth-1:0]         network_flit_type;
  wire [NetworkIfBroadcastWidth-1:0]        network_broadcast;
  wire [NetworkIfVirtualNetworkIdWidth-1:0] network_virtual_network_id;

  // Stores the request until next module can accept it
  // A request is composed of NUMBEROF_FLITS_PER_REQUEST flits
  reg [FileRegIfDataWidth-1:0] request_data_q;
  reg                          request_valid_q;
  reg                          request_last_q;
  reg                          request_ready_q;
  wire                         request_handshake_complete;

  wire filereg_handshake_complete;
 
  assign filereg_handshake_complete = (request_valid_q == 1) && (filereg_m_tready_i == 1);
  assign request_handshake_complete = (network_valid == 1) && (request_ready_q == 1); 

  assign filereg_m_tvalid_o = request_valid_q;
  assign filereg_m_tdata_o  = request_data_q;
  assign filereg_m_tlast_o  = request_last_q;

  assign network_ready = (request_ready_q == 1) || (filereg_handshake_complete == 1);

  // Unpack network signals
  network_signal_converter #(
    .NetworkIfFlitWidth            (NetworkIfFlitWidth),
    .NetworkIfFlitTypeWidth        (NetworkIfFlitTypeWidth),
    .NetworkIfBroadcastWidth       (NetworkIfBroadcastWidth),
    .NetworkIfVirtualNetworkIdWidth(NetworkIfVirtualNetworkIdWidth)
  ) network_signal_unpacker_inst (
    .network_valid_i(network_valid_i),
    .network_ready_o(network_ready_o),
    .network_data_i (network_data_i),
 
    .network_valid_o             (network_valid),
    .network_ready_i             (network_ready),
    .network_flit_o              (network_flit),
    .network_flit_type_o         (network_flit_type),
    .network_broadcast_o         (network_broadcast),
    .network_virtual_network_id_o(network_virtual_network_id)
  );

  // word counter request logic
  // Every time the counter wraps a request becomes valid for the filereg
  always @(posedge clk_i) begin
    if (rst_i == 1) begin
      word_counter <= 0;
    end else if ((request_handshake_complete == 1) || ((filereg_handshake_complete == 1) && (network_valid_i == 1))) begin
      word_counter <= word_counter + 1;
    end
  end

  // Convert network packet into request
  always @(posedge clk_i) begin
    // Always set
    request_last_q <= 1'b1;

    if ((request_handshake_complete == 1) || ((request_valid_q == 0) && (word_counter == 0)) || ((filereg_handshake_complete == 1) && (network_valid_i == 1))) begin
      request_data_q <= {request_data_q[FileRegIfDataWidth-32:0], network_flit[31:0]};
    end
  end

  // handle request_valid logic
  always @(posedge clk_i) begin
    if (rst_i == 1) begin
      request_valid_q <= 0;
    end else begin
      if ((word_counter == NUMBEROF_FLITS_PER_REQUEST-1) && (request_handshake_complete == 1)) begin
        // Capturing last word of request and handshake for that word
        // completes. Then, the request is completed and can be forwarded to
        // next module (filereg)
        request_valid_q <= 1;
      end else if (filereg_handshake_complete == 1) begin
        // There is a request to the filereg and it can be accepted
        // No need to keep valid asserted, since a request requires two clocks
        // to get the two words of the request
        request_valid_q <= 0;
      end
    end
  end

  // handle request_ready logic
  always @(posedge clk_i) begin
    if (rst_i == 1) begin
      request_ready_q <= 1;
    end else begin
      if ((word_counter == NUMBEROF_FLITS_PER_REQUEST-1) && (request_handshake_complete == 1) && (filereg_m_tready_i == 0)) begin
        // Receiving last word of the request, and handshake completes (means
        // accepted last word), but filereg cannot accept the request
        request_ready_q <= 0;
      end else if ((filereg_handshake_complete == 1) || (request_valid_q == 0)) begin
        request_ready_q <= 1;
      end
    end
  end

endmodule
