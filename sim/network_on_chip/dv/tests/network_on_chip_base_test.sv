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

import network_on_chip_env_pkg::*;

program network_on_chip_base_test #(
  parameter int NumberOfTiles = 0
) (
);
  

  // These arrays contains the interfaces of the VIP cores
  // and are used by the Driver and monitor to drive transaction
  // into the cores, which will convert into AXI-Stream transfers
  // for driving the NI.
  m_axis_vip_vif_t m_axis_vip_vif[0:NumberOfTiles-1];  
  s_axis_vip_vif_t s_axis_vip_vif[0:NumberOfTiles-1];
  
  network_on_chip_controller_tile_is_zero_env_cfg env_cfg;
  
  network_on_chip_env #(
    .NumberOfTiles(NumberOfTiles)
  ) env;  
    
    
  generate
    for (genvar i = 0; i < NumberOfTiles; i++) begin
      initial begin
        m_axis_vip_vif[i] = tb.duv_inst.tile[i].axis_vip_inst.network_m_axis_vip.inst.inst.IF;
        s_axis_vip_vif[i] = tb.duv_inst.tile[i].axis_vip_inst.network_s_axis_vip.inst.inst.IF;
      end
    end
  endgenerate
  
    
  initial begin
    #10;
    
    env = new(m_axis_vip_vif, s_axis_vip_vif);
    
    // Constraint the noc controller tile to tile 0 and avoid as initiator and target
    // of data streams tiles 0 and 4 in a 4x2 mesh. This is a wraparound solution
    // to test the reconfiguration algorithm from XY to YX. Currently the controller tile
    // cannot be reconfigured itself,so the traffic in its column must be suprimed.  
    env_cfg = new(NumberOfTiles, NETWORK_NUMBEROF_VIRTUAL_NETWORKS);
    env.cfg = env_cfg;
    //env.cfg.c_at_least_one_message_per_manager_tile.constraint_mode(0);
    
    env.generate_configuration();
    //  1. Total Number of transactions and per tile
    //  2. NoC Controller tile
    //  3. Control and status virtual network
    //  5. Tiles with M_AXIS_VIP enabled
    //  6. Tiles with S_AXIS_VIP enabled
    //
    env.build();
    //
    env.set_generator_verbosity(200);
    env.set_driver_verbosity(1);
    env.set_monitor_verbosity(0);
    env.set_scoreboard_verbosity(1);
    env.set_verbosity(1);
    
    $display("[T=%0t] [Test] NoC Verification with seed=N/A", $time);
    
    env.run();
    
    $finish;
  end
endprogram
