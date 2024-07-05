// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file tb.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 05th, 2024
//
// @title Single Unit Network Interface testbench
//
// This module is used for testing the path from
// the axistream_tonet to the local input port of the router
// and from the local output port of the router to
// the axistream_fromnet.
//
// It uses the M_AXIS_VIP to generate AXI-Stream
// transfers and frames to feed the axistream_tonet module
//
// It uses the S_AXIS_VIP to generate ready signal and
// feed the axistream_fromnet module.
//
// In addition, these VIP allow us to generate/monitor AXI-Stream
// well formed AXI-Stream transfers.
//
// Notice that both the tonet and fromnet paths cannot tested
// concurrently and there is a parameter TEST_TO_NET_PATH that must
// be set to one to test the tonet path and zero to test the fromnet
// path. 
//

import axi4stream_vip_pkg::*;
import axi4stream_vip_m_pkg::*;
import axi4stream_vip_s_pkg::*;

import single_unit_network_interface_test_pkg::*;
import single_unit_network_interface_env_pkg::*;
import single_unit_network_interface_agent_pkg::*;

module tb();

  localparam int TEST_TONET_PATH = 1;
  localparam int TEST_FROMNET_PATH = (TEST_TONET_PATH == 1) ? 0 : 1;

  localparam int CLK_NETWORK_PERIOD   = 20;
  localparam int CLK_M_AXIS_PERIOD    = 40;
  localparam int CLK_S_AXIS_PERIOD    = 40; 
  localparam int CLK_DOWNSIZER_PERIOD = CLK_NETWORK_PERIOD / 4;
  localparam int CLK_UPSIZER_PERIOD   = CLK_S_AXIS_PERIOD / 4; 

  bit clk_m_axis    = 0;
  bit rst_m_axis_n  = 0;
  bit clk_s_axis    = 0;
  bit rst_s_axis_n  = 0;  
  bit clk_network   = 0;
  bit rst_network   = 1;
  bit clk_upsizer   = 1;
  bit rst_upsizer   = 1;
  bit clk_downsizer = 1;
  bit rst_downsizer = 1;

  network_if #(
    .FlitWidth                        (FLIT_WIDTH),
    .FlitTypeWidth                    (FLIT_TYPE_WIDTH),
    .BroadcastWidth                   (BROADCAST_WIDTH),
    .VirtualNetworkOrChannelIdWidth   (VIRTUAL_CHANNEL_ID_WIDTH),
    .NumberOfVirtualNetworksOrChannels(NUMBEROF_VIRTUAL_CHANNELS)  
  ) m_network_manager_if(clk_network, rst_network);

  network_if #(
    .FlitWidth                        (FLIT_WIDTH),
    .FlitTypeWidth                    (FLIT_TYPE_WIDTH),
    .BroadcastWidth                   (BROADCAST_WIDTH),
    .VirtualNetworkOrChannelIdWidth   (VIRTUAL_NETWORK_ID_WIDTH),
    .NumberOfVirtualNetworksOrChannels(NUMBEROF_VIRTUAL_NETWORKS)
  ) m_network_subordinate_if(clk_network, rst_network);

  duv #(
    .NetworkIfAddressId              (0),
    .NetworkIfFlitWidth              (FLIT_WIDTH),
    .NetworkIfFlitTypeWidth          (FLIT_TYPE_WIDTH),
    .NetworkIfBroadcastWidth         (BROADCAST_WIDTH),
    .NetworkIfVirtualNetworkIdWidth  (VIRTUAL_NETWORK_ID_WIDTH),
    .NetworkIfVirtualChannelIdWidth  (VIRTUAL_CHANNEL_ID_WIDTH),
    .NetworkIfNumberOfVirtualChannels(NUMBEROF_VIRTUAL_CHANNELS),
    .NetworkIfNumberOfVirtualNetworks(NUMBEROF_VIRTUAL_NETWORKS),

    .AxiStreamTargetIfEnable    (1),
    .AxiStreamTargetIfTDataWidth(axi4stream_vip_m_VIP_DATA_WIDTH),
    .AxiStreamTargetIfTIdWidth  (axi4stream_vip_m_VIP_ID_WIDTH),
    .AxiStreamTargetIfTDestWidth(axi4stream_vip_m_VIP_DEST_WIDTH),

    .AxiStreamInitiatorIfEnable    (1),
    .AxiStreamInitiatorIfTDataWidth(axi4stream_vip_s_VIP_DATA_WIDTH),
    .AxiStreamInitiatorIfTIdWidth  (axi4stream_vip_s_VIP_ID_WIDTH),
    .AxiStreamInitiatorIfTDestWidth(axi4stream_vip_s_VIP_DEST_WIDTH)  
  ) duv_inst (
     // clocks and resets
    .clk_s_axis_i   (clk_s_axis),
    .clk_m_axis_i   (clk_m_axis),
    .clk_network_i  (m_network_manager_if.clk),
    .clk_upsizer_i  (clk_upsizer),
    .clk_downsizer_i(clk_downsizer),
  
    .rst_s_axis_ni  (rst_s_axis_n),
    .rst_m_axis_ni  (rst_m_axis_n),
    .rst_network_i  (m_network_manager_if.rst),
    .rst_upsizer_i  (rst_upsizer),
    .rst_downsizer_i(rst_downsizer),
  
    // Custom interface for NoC Router connection.
    .network_valid_o             (m_network_subordinate_if.valid),               
    .network_ready_i             (m_network_subordinate_if.ready),               
    .network_flit_o              (m_network_subordinate_if.flit),                
    .network_flit_type_o         (m_network_subordinate_if.flit_type),           
    .network_broadcast_o         (m_network_subordinate_if.broadcast),           
    .network_virtual_channel_id_o(m_network_subordinate_if.virtual_identifier),  
    .network_valid_i             (m_network_manager_if.valid),               
    .network_ready_o             (m_network_manager_if.ready),   
    .network_flit_i              (m_network_manager_if.flit),   
    .network_flit_type_i         (m_network_manager_if.flit_type),   
    .network_broadcast_i         (m_network_manager_if.broadcast),
    .network_virtual_network_id_i(m_network_manager_if.virtual_identifier)     
  );
  
  generate
    if (TEST_TONET_PATH == 1) begin : test_tonet
      single_unit_network_interface_base_test #(
      ) t0(m_network_manager_if, m_network_subordinate_if, duv_inst.m_axis_vip_inst.inst.IF, duv_inst.s_axis_vip_inst.inst.IF);  
    end else begin : test_fromnet
      single_unit_network_interface_ejection_test #(
      ) t1(m_network_manager_if, m_network_subordinate_if, duv_inst.m_axis_vip_inst.inst.IF, duv_inst.s_axis_vip_inst.inst.IF);    
    end
  endgenerate
  
  always #CLK_NETWORK_PERIOD clk_network <= ~clk_network;
  
  initial begin
    #(10*2*CLK_NETWORK_PERIOD+CLK_NETWORK_PERIOD) rst_network = 0;
  end    
  
  always #CLK_M_AXIS_PERIOD clk_m_axis <= ~clk_m_axis;  
  
  initial begin
    #(20*2*CLK_M_AXIS_PERIOD+CLK_M_AXIS_PERIOD) rst_m_axis_n = 1;
  end 
  
  always #CLK_S_AXIS_PERIOD clk_s_axis <= ~clk_s_axis;  
  
  initial begin
    #(20*2*CLK_S_AXIS_PERIOD+CLK_S_AXIS_PERIOD) rst_s_axis_n = 1;
  end   
  
  always #CLK_UPSIZER_PERIOD clk_upsizer <= ~clk_upsizer;    
  
  initial begin
    #(5*2*CLK_UPSIZER_PERIOD+CLK_UPSIZER_PERIOD) rst_upsizer = 0;
  end
  
  always #CLK_DOWNSIZER_PERIOD clk_downsizer <= ~clk_downsizer;    
  
  initial begin
    #(5*2*CLK_DOWNSIZER_PERIOD+CLK_DOWNSIZER_PERIOD) rst_downsizer = 0;
  end    
  
///////////////////////////////////////////////////////////////////////////
// How to start the verification component
///////////////////////////////////////////////////////////////////////////
//      axi4stream_vip_m_mst_t  axi4stream_vip_m_mst;
//      axi4stream_transaction item;
//      initial begin : START_axi4stream_vip_m_MASTER
//        axi4stream_vip_m_mst = new("axi4stream_vip_m_mst", duv_inst.m_axis_vip_inst.inst.IF);
//        item = axi4stream_vip_m_mst.driver.create_transaction("hola");
//        axi4stream_vip_m_mst.start_master();
//      end    
  
endmodule