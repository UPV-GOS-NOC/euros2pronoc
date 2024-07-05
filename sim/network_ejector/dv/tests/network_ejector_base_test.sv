// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_ejector_base_test.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network ejector base test
//

import network_ejector_test_pkg::*;
import network_ejector_env_pkg::*;

program network_ejector_base_test #(
  int FlitWidth               = 0,
  int FlitTypeWidth           = 0,
  int BroadcastWidth          = 0,
  int VirtualNetworkIdWidth   = 0,
  int NumberOfVirtualNetworks = 0 
) (network_if a_network_if, valid_ready_data_if a_data_if);


  network_ejector_env #(
    .FlitWidth              (FlitWidth),
    .FlitTypeWidth          (FlitTypeWidth),
    .BroadcastWidth         (BroadcastWidth),
    .VirtualNetworkIdWidth  (VirtualNetworkIdWidth),
    .NumberOfVirtualNetworks(NumberOfVirtualNetworks)
  ) env;
  
  covergroup network_if_coverage @(posedge a_network_if.clk);
  
    c_valid: coverpoint a_network_if.valid {
      bins atleast_two_in_a_row_andthen_deasserted = (1[*2:6] => 0[*1:5]);        
      bins four_toggles_1_0 = (1=>0=>1=>0=>1=>0=>1=>0);
      bins four_toggles_0_1 = (0=>1=>0=>1=>0=>1=>0=>1);         
      bins allothers = default sequence;
    }
 
    
    c_ready: coverpoint a_network_if.ready {
      bins atleast_five_zeros_in_a_row = (0[*5:10]);
      bins atleast_five_ones_in_a_row = (3'b111[*5:10]);
      bins four_toggles_1_0 = (3'b111 => 0 => 3'b111 => 0=> 3'b111 => 0 => 3'b111 => 0);
      bins pseudo_toggle_keeping_value_atleast_5times = (3'b111[*5:10] => 0[*5:10] => 3'b111[*5:10]);
      bins toggle_keep_zero_atleast_1times = (3'b111[*1:10] => 0[*1:10] => 3'b111[*2:10]);
      bins allothers = default sequence;
    }
    
    cross_valid_ready: cross c_valid, c_ready {
      illegal_bins valid_set_atleast_two_in_a_row_when_ready_deasserted_first = 
        binsof(c_valid.atleast_two_in_a_row_andthen_deasserted) &&
        binsof(c_ready.atleast_five_zeros_in_a_row);      
      illegal_bins toggle_valid_when_ready_deasserted = 
        (binsof(c_valid.four_toggles_1_0) ||
        binsof(c_valid.four_toggles_0_1)) &&
        binsof(c_ready.atleast_five_zeros_in_a_row);
      illegal_bins both_toggle_1_0 = 
        binsof(c_valid.four_toggles_1_0) && 
        binsof(c_ready.four_toggles_1_0);      
      ignore_bins pseudo_toggle = binsof(c_ready.pseudo_toggle_keeping_value_atleast_5times);
    }
  
  endgroup
    
  initial begin
    // Other way to connect interfaces is this, but we need
    // to declare inside of the program as virtual
    //m_network_vif = network_ejector_testbench.m_network_if;
    //m_data_vif = network_ejector_testbench.m_data_if;
    
    network_if_coverage net_cov = new();
    
    env = new(a_network_if, a_data_if);
    env.generator.total_transactions = 50000;
    env.run();
    if (env.scoreboard.error_network_if + env.scoreboard.error_data_if > 0) begin
      $display("TEST FAIL (%0d errors)", env.scoreboard.error_network_if + env.scoreboard.error_data_if);
    end else begin 
      $display("TEST PASSED");
    end
    
    $display("Coverage = %0.2f %%", net_cov.get_coverage());
    
    $finish;
  end
endprogram
