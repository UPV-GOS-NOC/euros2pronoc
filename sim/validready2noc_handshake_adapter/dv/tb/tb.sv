// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file tb.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title validready2noc_handshake_adapter Testbench
//

`timescale 1ns/1ns

module tb();

  localparam int CLK_PERIOD = 5; 

  parameter int NumberOfVirtualChannels = 3;
  parameter int VirtualChannelIdWidth = 2;

  bit clk = 0;
  bit rst = 1;

  valid_ready_if #(
    .VirtualChannelIdWidth(VirtualChannelIdWidth) 
  ) m_valid_ready_if();
  
  avail_valid_if #(
    .NumberOfVirtualChannels(NumberOfVirtualChannels) 
  ) m_avail_valid_if();

  clk_mockup_if m_clk_if(clk, rst);

  validready2noc_handshake_adapter #(
    .VirtualChannelIdWidth  (VirtualChannelIdWidth),
    .NumberOfVirtualChannels(NumberOfVirtualChannels) 
  ) validready2noc_handshake_adapter_inst (    
    .valid_i             (m_valid_ready_if.valid),
    .ready_o             (m_valid_ready_if.ready),
    .virtual_channel_id_i(m_valid_ready_if.virtual_channel_id),

    .valid_o(m_avail_valid_if.valid),
    .avail_i(m_avail_valid_if.avail)
  );

  validready2noc_handshake_adapter_base_test #(
    .VirtualChannelIdWidth  (VirtualChannelIdWidth),
    .NumberOfVirtualChannels(NumberOfVirtualChannels)   
   ) t0(m_valid_ready_if, m_avail_valid_if, m_clk_if);

  always #CLK_PERIOD clk <= ~clk;
  
  initial begin
    #(10*2*CLK_PERIOD+CLK_PERIOD) rst = 0;
  end


endmodule

