// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_env.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 08th, 2024


class network_on_chip_env #(
  parameter int NumberOfTiles = 0
);

  // Helper classes to drive the AXI-Stream interfaces through
  // Xilinx AXI-Stream VIP Cores
  axi4stream_vip_m_mst_t m_axis_agent[NumberOfTiles];
  axi4stream_vip_s_slv_t s_axis_agent[NumberOfTiles];

  // There will be a maximum of one generator of access requests
  // to the register file of the routers.
  router_filereg_access_request_generator rfar_generator;

  // Generates AXI transactions for the data networks
  network_on_chip_generator generator[NumberOfTiles];

  network_on_chip_driver driver[NumberOfTiles];

  network_on_chip_monitor monitor[NumberOfTiles];

  // Single scoreboard to check against the reference model
  // all the transactions captured by monitors
  network_on_chip_scoreboard scoreboard;

  // Random environment configuration to apply for the test
  rand network_on_chip_env_cfg cfg;

  // Functional coverage for the environment configuration
  network_on_chip_env_cov cov;

  // types of tiles reported by the randomized config environment
  protected bit tile_types[];

  // Mailboxes for communication among components
  protected mailbox generator2driver_mbx[NumberOfTiles];

  // This is for sync between generator and driver
  protected event driver2generator[NumberOfTiles];

  // Every generator notifies to the environment when its done
  protected event generator2env[NumberOfTiles];

  // Verbosity
  // USe 400 for maximum verbosity on M_AXIS_VIP/S_AXIS_VIP agents
  protected int generator_verbosity = 0;
  protected int driver_verbosity = 0;
  protected int monitor_verbosity = 0;
  protected int scoreboard_verbosity = 0;
  protected int m_axis_agent_verbosity = 0;
  protected int s_axis_agent_verbosity = 0;

  protected int simulation_seed = 0;

  protected int verbosity = 0;
  //
  // Constructor
  //

  function new(m_axis_vip_vif_t m_axis_vip_vif[0:NumberOfTiles-1],
               s_axis_vip_vif_t s_axis_vip_vif[0:NumberOfTiles-1]);

    for (int i = 0; i < NumberOfTiles; i++) begin
      m_axis_agent[i] = new("axi4stream_vip_m", m_axis_vip_vif[i]);
      s_axis_agent[i] = new("axi4stream_vip_s", s_axis_vip_vif[i]);

      m_axis_agent[i].vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);
      s_axis_agent[i].vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);

      m_axis_agent[i].set_agent_tag("M_AXIS_VIP");
      s_axis_agent[i].set_agent_tag("S_AXIS_VIP");
      m_axis_agent[i].set_verbosity(m_axis_agent_verbosity);
      s_axis_agent[i].set_verbosity(s_axis_agent_verbosity);
    end

    cfg = new(NumberOfTiles, NETWORK_NUMBEROF_VIRTUAL_NETWORKS);

    // init simulation seed (if applicable)
    //$srandom(simulation_seed);

  endfunction : new

  //
  // Configuration and building methods
  //

  virtual function void generate_configuration();
    assert(cfg.randomize());
    cfg.display("Environment");
  endfunction : generate_configuration

  virtual function void build();
    cfg.get_tile_types(tile_types);
    
    cov = new(NumberOfTiles, NETWORK_NUMBEROF_VIRTUAL_NETWORKS);

    scoreboard = new(NumberOfTiles, cfg);

    // Generator and driver
    foreach(generator[i]) begin
      generator2driver_mbx[i] = new();

      if (i == cfg.get_noc_controller_tile()) begin
        rfar_generator = new(m_axis_agent[i], s_axis_agent[i],
                           generator2driver_mbx[i],
                           driver2generator[i],
                           generator2env[i],
                           cfg.get_numberof_messages(i),
                           cfg.get_ready_policy(i),
                           cfg.get_control_and_status_virtual_network(),
                           tile_types,
                           i);
        generator[i] = rfar_generator;
      end else begin
        generator[i] = new(m_axis_agent[i], s_axis_agent[i],
                           generator2driver_mbx[i],
                           driver2generator[i],
                           generator2env[i],
                           cfg.get_numberof_messages(i),
                           cfg.get_ready_policy(i),
                           cfg.get_control_and_status_virtual_network(),
                           tile_types,
                           i);
      end
      driver[i] = new(m_axis_agent[i],
                      generator2driver_mbx[i],
                      driver2generator[i],
                      cfg.get_noc_controller_tile(),
                      i);
    end

    // Monitors
    foreach(monitor[i]) begin
      monitor[i] = new(s_axis_agent[i], i);
    end

    // Connect scoreboard to drivers and monitors using callbacks function classes
    begin
      network_on_chip_scoreboard_monitor_callback smc = new(scoreboard);
      network_on_chip_scoreboard_driver_callback sdc = new(scoreboard);      
      foreach(driver[i]) begin
        if (i != cfg.get_noc_controller_tile()) begin
          driver[i].callback_sequence.push_back(sdc);
        end
      end
      foreach(monitor[i]) monitor[i].callback_sequence.push_back(smc);
    end

    // Connect coverage to monitor with callbacks
    begin
      network_on_chip_coverage_monitor_callback cmc = new(cov);
      foreach(monitor[i]) monitor[i].callback_sequence.push_back(cmc);
    end
  endfunction : build




  //
  // Getter and setter methods
  //

  virtual function int get_simulation_seed();
    return simulation_seed;
  endfunction

  virtual function void set_simulation_seed(int seed);
    this.simulation_seed = seed;
  endfunction

  virtual function void set_generator_verbosity(int verbosity);
    foreach(generator[i]) generator[i].set_verbosity(verbosity);
  endfunction

  virtual function void set_driver_verbosity(int verbosity);
    foreach(driver[i]) driver[i].set_verbosity(verbosity);
  endfunction

  virtual function void set_monitor_verbosity(int verbosity);
    foreach(monitor[i]) monitor[i].set_verbosity(verbosity);
  endfunction

  virtual function void set_scoreboard_verbosity(int verbosity);
    this.scoreboard.set_verbosity(verbosity);
  endfunction

  function void set_verbosity(int verbosity);
    this.verbosity = verbosity;
  endfunction  

  //
  // Run and wrap-up functions
  //

  virtual task pre_test();
    foreach(m_axis_agent[i])
      m_axis_agent[i].start_master();  
    
    foreach(s_axis_agent[i])
      s_axis_agent[i].start_slave();      
    
    foreach(driver[i]) driver[i].reset();
  endtask

  task wait_generators_done();
    fork
      begin : thread_1
        for (int i = 0; i < NumberOfTiles; i++) begin : for_loop_i
          fork
            automatic int tile = i;
            begin : subthread_i
              wait(generator2env[tile].triggered);
              if (verbosity != 0) begin
                $display("[T=%0t] [Environment] Generator of Tile %0d DONE!!!", $time, tile);
              end
            end : subthread_i
          join_none
        end : for_loop_i
        wait fork;
      end : thread_1
    join
  endtask

  virtual task post_test();
    int total_messages = cfg.get_total_messages();
        
    wait_generators_done();

    if (verbosity != 0)  begin
      $display("[T=%0t] [Environment] waiting driver to complete", $time);
    end

    foreach(driver[i]) begin
      if (i != cfg.get_noc_controller_tile()) begin
        wait(generator[i].numberof_m_axis_frames_generated == driver[i].numberof_m_axis_frames_transmitted);
      end
    end

    if (verbosity != 0) begin
      $display("[T=%0t] [Environment] waiting scoreboard to complete", $time);
    end

    wait(total_messages == scoreboard.iactual);

    foreach(m_axis_agent[i])
      m_axis_agent[i].stop_master();  
    
    foreach(s_axis_agent[i])
      s_axis_agent[i].stop_slave();      

    if (scoreboard.get_error_counter() > 0) begin
      $display("TEST FAIL (%0d errors)", scoreboard.get_error_counter());
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
      for (int tile = 0; tile < NumberOfTiles; tile++) begin
        automatic int i = tile;
        driver[i].run();
        generator[i].run();
        monitor[i].run();
      end
    join_none
  endtask

  task run();
    pre_test();
    test();
    post_test();
  endtask

  virtual function wrap_up();
    // TODO
  endfunction

endclass
