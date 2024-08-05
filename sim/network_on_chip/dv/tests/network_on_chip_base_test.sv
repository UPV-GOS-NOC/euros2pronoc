// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_base_test.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 08th, 2024
//
// @title Network-on-Chip base test
//

import axi4stream_vip_pkg::*;
import network_on_chip_env_pkg::*;

program network_on_chip_base_test
(
  axi4stream_vip_if m_axis_vip_if,
  axi4stream_vip_if s_axis_vip_if
);
  
//  covergroup network_if_coverage () @(posedge tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.clk_network_i);
  
//    c_network_packet_size: coverpoint tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.network_flit_type_i iff (tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.network_valid_i) {
//      bins single_flit_packet = (2'b11[*2:3]);
//      bins short_packet = (2'b00 => 2'b01[*0:5] => 2'b10);
//      bins long_packet = (2'b00 => 2'b01[*5:20] => 2'b10);
//      bins switch_packet[] = (2'b10, 2'b11 => 2'b00, 2'b11);
//      illegal_bins body_after_tail[] = (2'b11, 2'b10 => 2'b01);
//      illegal_bins ht_after_body_or_header[] = (2'b01, 2'b00 => 2'b11);
//    }
    
//    c_flit_content: coverpoint tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.network_flit_i iff (tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.network_valid_i) {
//      bins padding_tail_flit  = { 64'hFF000000_00000000 };
//      wildcard bins tail_flit = { 64'hF0000000_XXXXXXXX };
//      bins allothers = default;
//    }
       
//    c_virtual_network_used: coverpoint tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.network_virtual_network_id_i iff (tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.network_valid_i) { 
//      bins virtual_netword_id[] = {0, 1, 2};
//      illegal_bins allothers = default;
//    }
//  endgroup
  
//  covergroup axis_upsizer_coverage () @(posedge tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.clk_upsizer_i);
    
//    c_capture_bytes_in_word: coverpoint tb.duv_inst.\tile[0].s_axis.vip_inst .network_interface_inst.\axis_initiator_if.network_unit_decoupler_inst .upsizer_inst.s_axis_tvalid {
//      bins correct_transitions[] = (0 => 1 => 1 => 1 => 1 => 0), (0 => 1 => 1 => 1 => 0), (0 => 1 => 0);
//    }
     
//  endgroup
  
  network_on_chip_env env;  
    
  initial begin
    
    //network_if_coverage net_cov = new();
    //axis_upsizer_coverage axis_cov = new();
    
    env = new(m_axis_vip_if, s_axis_vip_if);
    env.generator.total_transactions = 5000;
    env.driver.verbosity = 0; // 1 for full verbosity

    $display("[T=%0t] [Test] NoC Verification", $time);
    
    //env.m_axis_manager_agent.set_verbosity(400);
    env.m_axis_manager_agent.start_master();
    env.m_axis_subordinate_agent.start_slave();

    env.run();
    if (env.scoreboard.error_counter > 0) begin
      $display("TEST FAIL (%0d errors)", env.scoreboard.error_counter);
    end else begin 
      $display("TEST PASSED");
    end
    
    env.m_axis_manager_agent.stop_master();
    env.m_axis_subordinate_agent.stop_slave();    
    
    //$display("NET Coverage = %0.2f %%", net_cov.get_coverage());
    //$display("AXIS Coverage = %0.2f %%", axis_cov.get_coverage());    
    
    $finish;
  end
endprogram
