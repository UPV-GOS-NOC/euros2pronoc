// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file single_unit_network_interface_base_test.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 05th, 2024
//
// @title Single Unit Interface base test
//

import axi4stream_vip_pkg::*;
import single_unit_network_interface_env_pkg::*;

program single_unit_network_interface_base_test
(
  network_if network_manager_if, 
  network_if network_subordinate_if,
  axi4stream_vip_if m_axis_vip_if,
  axi4stream_vip_if s_axis_vip_if
);

  single_unit_network_interface_env env;
  
  covergroup network_if_coverage @(posedge network_subordinate_if.clk);
  
    c_network_packet_size: coverpoint network_subordinate_if.flit_type iff (network_subordinate_if.valid) {
      bins single_flit_packet = (2'b11[*2:3]);
      bins short_packet = (2'b00 => 2'b01[*0:5] => 2'b10);
      bins long_packet = (2'b00 => 2'b01[*5:20] => 2'b10);
      bins switch_packet[] = (2'b10, 2'b11 => 2'b00, 2'b11);
      illegal_bins body_after_tail[] = (2'b11, 2'b10 => 2'b01);
      illegal_bins ht_after_body_or_header[] = (2'b01, 2'b00 => 2'b11);
    }
       
    c_virtual_channel_id: coverpoint network_subordinate_if.virtual_identifier iff (network_subordinate_if.valid);
  
  
  endgroup
    
  initial begin
    
    network_if_coverage net_cov = new();
    
    env = new(network_manager_if, network_subordinate_if, m_axis_vip_if, s_axis_vip_if);
    env.generator.total_transactions = 10000;
    env.driver.verbosity = 0; // 1 for full verbosity
    $display("[T=%0t] [Test] Full tonet path verification", $time);
    env.generator.set_axis_manager_mode();
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
    
    $display("Coverage = %0.2f %%", net_cov.get_coverage());
    
    $finish;
  end
endprogram
