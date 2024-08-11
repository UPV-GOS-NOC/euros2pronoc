// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_config_filereg_access_base_test.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 22th, 2024
//
// @title NoC configuration file access base test
//

import axi4stream_vip_pkg::*;
import noc_config_filereg_access_env_pkg::*;

program automatic noc_config_filereg_access_base_test #(
  parameter int NumberOfTiles = 0
) (
  axi4stream_vip_if m_axis_vip_if,
  filereg_if m_mgt_if[0:NumberOfTiles-1],
  filereg_if s_mgt_if[0:NumberOfTiles-1]
);
    
  noc_config_filereg_access_env #(.NumberOfTiles(NumberOfTiles)) env;  
    
  initial begin;
   
    env = new(m_axis_vip_if, m_mgt_if, s_mgt_if, CONFIG_FILEREG_VIRTUAL_NETWORK);
    // env.generate_configuration();
    // env.build();
    env.generator.total_config_filereg_accesses = 1000;
    env.generator.test_read = 0;
    env.driver.verbosity = 0; // 1 for full verbosity
    env.scoreboard.verbosity = 0; // 1 for full verbosity
    //env.m_axis_manager_agent.set_verbosity(400);    

    $display("[T=%0t] [Test] NoC Configuration File Access Write Verification", $time);
    
    env.run();
    
    $finish;
  end

endprogram
