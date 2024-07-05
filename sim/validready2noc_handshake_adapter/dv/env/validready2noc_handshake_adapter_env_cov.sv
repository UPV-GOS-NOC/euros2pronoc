// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file validready2noc_handshake_adapter_env_cov.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Coverage model for validready2noc_handshake_adapter
//

covergroup validready2noc_handshake_adapter_env_cov (
  int VirtualChannelIdWidth = 0,
  int NumberOfVirtualChannels = 0,
  virtual clk_mockup_if clk_vif,
  virtual valid_ready_if #(
            .VirtualChannelIdWidth(VirtualChannelIdWidth)
          ) valid_ready_vif, 
  virtual avail_valid_if #(
            .NumberOfVirtualChannels(NumberOfVirtualChannels)
          ) avail_valid_vif,
  int VirtualChannelsMask = 0
) @(posedge clk_vif.clk);


  c_valid: coverpoint valid_ready_vif.valid {
    bins atleast_four_ones_in_a_row = (1[*4]);
    bins atleast_four_zeros_in_a_row = (0[*4]);        
    bins four_toggles_1_0 = (1=>0=>1=>0=>1=>0=>1=>0);
    bins four_toggles_0_1 = (0=>1=>0=>1=>0=>1=>0=>1);         
    bins allothers = default sequence;
  }
    c_ready: coverpoint valid_ready_vif.ready {
    bins atleast_four_ones_in_a_row = (1[*4:8]);
    bins atleast_four_zeros_in_a_row = (0[*4:8]);        
    bins four_toggles_1_0 = (1=>0=>1=>0=>1=>0=>1=>0);
    bins four_toggles_0_1 = (0=>1=>0=>1=>0=>1=>0=>1);     
  }
  
  c_avail: coverpoint avail_valid_vif.avail {
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