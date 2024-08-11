// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_config_filereg_access_env.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 22th, 2024
//
// Simulation environment for the tests
//
// It uses the M_AXIS VIP core to generate
// AXI-Stream transactions in the generator

class noc_config_filereg_access_env #(
  int NumberOfTiles = 0
);
 
  // AXIS VIP helper agent to generate AXI-Stream transactions
  // and drive the AXI-Stream interface of the NI
  axi4stream_vip_m_mst_t m_axis_manager_agent;

  // Generate transaction items consisting of
  // AXI-Stream transfers with the required
  // data format
  noc_config_filereg_access_generator generator;
  
  // Drive the transaction into the NI 
  noc_config_filereg_access_driver #(.NumberOfTiles(NumberOfTiles)) driver;
  
  // Monitor the filereg interface at the router
  noc_config_filereg_access_monitor #(.NumberOfTiles(NumberOfTiles)) monitor;
  
  // Check result to determine success or failure
  noc_config_filereg_access_scoreboard #(.NumberOfTiles(NumberOfTiles)) scoreboard;
  
  // Configurations. Not used. They are applied at runtime, not elaboration
  // time. I was looking for changing things (Topology) at elab. time
  //rand noc_config_filereg_access_env_cfg cfg;
  //rand noc_config_filereg_access_agent_cfg m_agent_cfg;
  
  noc_config_filereg_access_agent_cov cov;

  // IPC mailbox to send AXI transaction
  mailbox m_axis_transaction_generator2driver_mbx;
  
  // IPC mailboxes to send config_filereg_transactions
  mailbox m_config_filereg_transaction_driver2scoreboard_mbx[0:NumberOfTiles-1];
  mailbox m_config_filereg_transaction_monitor2scoreboard_mbx[0:NumberOfTiles-1];
  mailbox m_config_filereg_response_transaction_monitor2scoreboard_mbx[0:NumberOfTiles-1];
  
  event generator_done;

  // 400 for axis manager full verbosity
  int m_axis_manager_verbosity = 0;
  
  function new(input axi4stream_manager_vip_vif_t m_axis_vip_vif,
               input filereg_m_vif_t filereg_m_vif[0:NumberOfTiles-1],
               input filereg_vif_t config_filereg_vif[0:NumberOfTiles-1],
               input int control_and_status_virtual_network);
    m_axis_manager_agent     = new("axi4stream_vip_m", m_axis_vip_vif);
    m_axis_manager_agent.vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);
    m_axis_manager_agent.set_agent_tag("M_AXIS_VIP");
    m_axis_manager_agent.set_verbosity(m_axis_manager_verbosity);

    // Not implemented. But it would be the place in case using
    // configurations to build the environment and configure the DUV    
    //cfg = new(...);
    //m_agent_cfg = new(...);
 
    cov = new();
    
    // Next could be done in build function, instead of here
    m_axis_transaction_generator2driver_mbx  = new();

    for (int i = 0; i < NumberOfTiles; i++) begin
      m_config_filereg_transaction_driver2scoreboard_mbx[i] = new();
      m_config_filereg_transaction_monitor2scoreboard_mbx[i] = new();
      m_config_filereg_response_transaction_monitor2scoreboard_mbx[i] = new();
    end
    
    generator = new(m_axis_manager_agent,
                    m_axis_transaction_generator2driver_mbx,
                    control_and_status_virtual_network,
                    generator_done);
    
    driver = new(m_axis_manager_agent,
                 m_axis_transaction_generator2driver_mbx,
                 m_config_filereg_transaction_driver2scoreboard_mbx);

    monitor = new(config_filereg_vif, filereg_m_vif,
                  m_config_filereg_transaction_monitor2scoreboard_mbx,
                  m_config_filereg_response_transaction_monitor2scoreboard_mbx, cov);
    
    scoreboard = new(m_config_filereg_transaction_driver2scoreboard_mbx,
                     m_config_filereg_transaction_monitor2scoreboard_mbx,
                     m_config_filereg_response_transaction_monitor2scoreboard_mbx);
  endfunction
  
  function int get_control_and_status_virtual_network();
    return generator.control_and_status_virtual_network;
  endfunction

  function void set_control_and_status_virtual_network(input int vn);
    generator.control_and_status_virtual_network = vn;
  endfunction

  virtual function void generate_configuration();
    //assert(cfg.randomize());
    //assert(m_agent_cfg.randomize());
    //cfg.display();
    //m_agent_cfg.display();
    //m_agent_cfg.display();
  endfunction

  virtual function void build();
    // Generate and connect objects using the randomized configurations
    // In case of using it, there would be a generator and driver per tile
    // (generator/driver[0:NumberOfTiles-1]),
    // Then, depending on configuration randomized variable ControllerTile
    // the corresponding generator and driver (driver[ControllerTile]) would
    // drive the DUV.
    // To monitor interfaces a number of monitors would exist
    // (mon[0:NumberOfTiles-1]), each one monitoring the filereg_if interface
    // of the corresponding tile. Anyway, I follow a similar approach for
    // that, but there is a single monitor class with N threads, each one
    // monitoring a tile filereg_if
  endfunction

  virtual task pre_test();
    driver.reset();
    
    m_axis_manager_agent.start_master();    
  endtask
  
  virtual task post_test();
    wait(generator_done.triggered);
    
    $display("[T=%0t] [Environment] waiting driver to complete", $time);
    
    wait(generator.total_config_filereg_accesses == driver.numberof_m_axis_frames_transmitted);

    $display("[T=%0t] [Environment] waiting scoreboard to complete", $time);      

    wait(driver.numberof_m_axis_frames_transmitted == scoreboard.numberof_config_filereg_transactions_processed);
    
    m_axis_manager_agent.stop_master();    
    
    if (scoreboard.error_counter > 0) begin
      $display("TEST FAIL (%0d errors)", scoreboard.error_counter);
    end else begin 
      $display("TEST PASSED");
    end    
    
    $display("Coverage = %0.2f %%", cov.get_functional_coverage());
        
  endtask
  
  virtual task test();   
    // Run the different components of the environment in different processes
    // The processes are running forever, except the generator that must
    // finish at some point, and the join_any will force the other processes
    // to finish as well 
    fork
      driver.run();
      generator.run();
      monitor.run();      
      scoreboard.run();
    join_any
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask  

endclass
