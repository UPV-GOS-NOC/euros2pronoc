// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file validready2noc_handshake_adapter_base_test.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title validready2noc_handshake_adapter base test
//

import validready2noc_handshake_adapter_test_pkg::*;
import validready2noc_handshake_adapter_env_pkg::*;

program validready2noc_handshake_adapter_base_test #(
  int VirtualChannelIdWidth   = 0,
  int NumberOfVirtualChannels = 0 
) (valid_ready_if a_valid_ready_if, avail_valid_if a_avail_valid_if, clk_mockup_if clk_if);


  validready2noc_handshake_adapter_env #(
    .VirtualChannelIdWidth  (VirtualChannelIdWidth),
    .NumberOfVirtualChannels(NumberOfVirtualChannels)  
  ) env;
  
  covergroup validready2noc_handshake_adapter_coverage (
    int VirtualChannelsMask = 0
  ) @(posedge clk_if.clk);
  
    c_valid: coverpoint a_valid_ready_if.valid {
      bins atleast_four_ones_in_a_row = (1[*4]);
      bins atleast_four_zeros_in_a_row = (0[*4]);        
      bins four_toggles_1_0 = (1=>0=>1=>0=>1=>0=>1=>0);
      bins four_toggles_0_1 = (0=>1=>0=>1=>0=>1=>0=>1);         
      bins allothers = default sequence;
    }
 
    c_ready: coverpoint a_valid_ready_if.ready {
      bins atleast_four_ones_in_a_row = (1[*4:8]);
      bins atleast_four_zeros_in_a_row = (0[*4:8]);        
      bins four_toggles_1_0 = (1=>0=>1=>0=>1=>0=>1=>0);
      bins four_toggles_0_1 = (0=>1=>0=>1=>0=>1=>0=>1);     
    }
    
    c_avail: coverpoint a_avail_valid_if.avail {
      bins atleast_four_zeros_in_a_row = (0[*4]);
      bins atleast_four_ones_in_a_row = (VirtualChannelsMask[*4]);
      bins allothers = default sequence;
    }
    
    cross_valid_ready: cross c_valid, c_ready {
      illegal_bins toggles_1_0_with_four_zeros_in_a_row = binsof(c_valid.four_toggles_1_0) &&
        (binsof(c_ready.atleast_four_zeros_in_a_row) ||
         binsof(c_ready.four_toggles_0_1));
      illegal_bins toggles_0_1_with_others = binsof(c_valid.four_toggles_0_1) &&
        (binsof(c_ready.atleast_four_zeros_in_a_row) ||
         binsof(c_ready.four_toggles_1_0));      
    }
  
  endgroup
    
  initial begin
    // Other way to connect interfaces is this, but we need
    // to declare inside of the program as virtual
    //m_network_vif = network_ejector_testbench.m_network_if;
    //m_data_vif = network_ejector_testbench.m_data_if;
    
    validready2noc_handshake_adapter_coverage net_cov = new({NumberOfVirtualChannels{1'b1}});
    
    env = new(a_valid_ready_if, a_avail_valid_if, clk_if);
    env.generator.total_transactions = 50000;
    env.run();
    if (env.scoreboard.error_valid_ready_if + env.scoreboard.error_avail_valid_if > 0) begin
      $display("TEST FAIL (%0d errors)", env.scoreboard.error_valid_ready_if + env.scoreboard.error_avail_valid_if);
    end else begin 
      $display("TEST PASSED");
    end
    
    $display("Coverage = %0.2f %%", net_cov.get_coverage());
    
    $finish;
  end
endprogram

