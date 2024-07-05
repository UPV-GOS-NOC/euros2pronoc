// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file tb.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network ejector testbench 
//

import network_ejector_test_pkg::*;

module tb();

  localparam int CLK_PERIOD = 5; 

  parameter int FlitWidth = 64;
  parameter int FlitTypeWidth = 2;
  parameter int BroadcastWidth = 1;
  parameter int NumberOfVirtualNetworks = 3;
  parameter int VirtualNetworkIdWidth = 2; //$clog2(NumberOfVirtualNetworks);
  
  parameter int NetworkDataWidth = FlitWidth +
                                   FlitTypeWidth +
                                   BroadcastWidth +
                                   VirtualNetworkIdWidth;  

  bit clk = 0;
  bit rst = 1;

  network_if #(
    .FlitWidth                        (FlitWidth),
    .FlitTypeWidth                    (FlitTypeWidth),
    .BroadcastWidth                   (BroadcastWidth),
    .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
    .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)  
  ) m_network_if(clk, rst);
  
  valid_ready_data_if #(
    .DataWidth(NetworkDataWidth)
  ) m_data_if(clk, rst);


  network_ejector #(
    .NetworkIfFlitWidth              (FlitWidth),
    .NetworkIfFlitTypeWidth          (FlitTypeWidth),
    .NetworkIfBroadcastWidth         (BroadcastWidth),
    .NetworkIfVirtualNetworkIdWidth  (VirtualNetworkIdWidth),
    .NetworkIfNumberOfVirtualNetworks(NumberOfVirtualNetworks)
  ) traffic_ejector_inst (
    .clk_i(m_network_if.clk),
    .rst_i(m_network_if.rst),
    
    .valid_o(m_data_if.valid),
    .ready_i(m_data_if.ready),
    .data_o (m_data_if.data),

    .network_valid_i             (m_network_if.valid),
    .network_ready_o             (m_network_if.ready),
    .network_flit_i              (m_network_if.flit),
    .network_flit_type_i         (m_network_if.flit_type),
    .network_broadcast_i         (m_network_if.broadcast),
    .network_virtual_network_id_i(m_network_if.virtual_identifier)
  );

  network_ejector_base_test #(
    .FlitWidth              (FlitWidth),
    .FlitTypeWidth          (FlitTypeWidth),
    .BroadcastWidth         (BroadcastWidth),
    .VirtualNetworkIdWidth  (VirtualNetworkIdWidth),
    .NumberOfVirtualNetworks(NumberOfVirtualNetworks)       
   ) t0(m_network_if, m_data_if);

  always #CLK_PERIOD clk <= ~clk;
  
  initial begin
    #(10*2*CLK_PERIOD+CLK_PERIOD) rst = 0;
  end
  
endmodule
