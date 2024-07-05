// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file single_unit_network_interface_env.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 04th, 2024


class single_unit_network_interface_env;
  
  axi4stream_vip_m_mst_t m_axis_manager_agent;
  axi4stream_vip_s_slv_t m_axis_subordinate_agent;
  
  single_unit_network_interface_generator generator;
  
  single_unit_network_interface_driver driver;
  
  single_unit_network_interface_monitor monitor;
  
  single_unit_network_interface_scoreboard scoreboard;
  
  // TODO add m_axis interface
  network_vif_t network_manager_vif;
  network_vif_t network_subordinate_vif;
  
  mailbox m_axis_manager_generator2driver_mbx;
  mailbox m_axis_subordinate_generator2driver_mbx;
  mailbox m_network_if_subordinate_generator2driver_mbx;
  mailbox m_network_if_manager_generator2driver_mbx;
  
  mailbox m_axis_manager_driver2scoreboard_mbx;
  mailbox m_network_if_manager_driver2scoreboard_mbx;
  
  mailbox m_axis_manager_monitor2scoreboard_mbx;
  mailbox m_axis_subordinate_monitor2scoreboard_mbx;
  mailbox m_network_if_manager_monitor2scoreboard_mbx;
  mailbox m_network_if_subordinate_monitor2scoreboard_mbx;
  
  event generator_done;
  
  // USe 400 for maximum verbosity on M_AXIS_VIP/S_AXIS_VIP
  int m_axis_manager_verbosity = 0;
  int m_axis_subordinate_verbosity = 0;
  
  function new(network_vif_t network_manager_vif,
               network_vif_t network_subordinate_vif,
               axi4stream_manager_vip_vif_t m_axis_vip_vif,
               axi4stream_subordinate_vip_vif_t s_axis_vip_vif);
    this.network_manager_vif = network_manager_vif;
    this.network_subordinate_vif = network_subordinate_vif;
    
    m_axis_manager_agent     = new("axi4stream_vip_m", m_axis_vip_vif);
    m_axis_subordinate_agent = new("axi4stream_vip_s", s_axis_vip_vif);
    
    m_axis_manager_agent.vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);
    m_axis_subordinate_agent.vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);
    
    m_axis_manager_agent.set_agent_tag("M_AXIS_VIP");
    m_axis_subordinate_agent.set_agent_tag("S_AXIS_VIP");
    m_axis_manager_agent.set_verbosity(m_axis_manager_verbosity);
    m_axis_subordinate_agent.set_verbosity(m_axis_subordinate_verbosity);         
    
    m_axis_manager_generator2driver_mbx           = new();
    m_axis_subordinate_generator2driver_mbx       = new();
    m_network_if_subordinate_generator2driver_mbx = new();
    m_network_if_manager_generator2driver_mbx     = new();
    
    m_axis_manager_driver2scoreboard_mbx       = new();
    m_network_if_manager_driver2scoreboard_mbx = new();
    
    m_axis_manager_monitor2scoreboard_mbx           = new();
    m_axis_subordinate_monitor2scoreboard_mbx       = new();
    m_network_if_manager_monitor2scoreboard_mbx     = new();
    m_network_if_subordinate_monitor2scoreboard_mbx = new();
    
    generator = new(m_axis_manager_agent,
                    m_axis_subordinate_agent,
                    m_axis_manager_generator2driver_mbx,
                    m_axis_subordinate_generator2driver_mbx,
                    m_network_if_subordinate_generator2driver_mbx,
                    m_network_if_manager_generator2driver_mbx,
                    generator_done);
    
    driver = new(m_axis_manager_agent,
                 m_axis_subordinate_agent,
                 m_axis_manager_generator2driver_mbx,
                 m_axis_subordinate_generator2driver_mbx,
                 m_network_if_subordinate_generator2driver_mbx,
                 m_network_if_manager_generator2driver_mbx,
                 m_axis_manager_driver2scoreboard_mbx,
                 m_network_if_manager_driver2scoreboard_mbx,
                 network_manager_vif,
                 network_subordinate_vif);
    
    monitor = new(m_axis_manager_agent,
                  m_axis_subordinate_agent,
                  m_axis_manager_monitor2scoreboard_mbx,
                  m_axis_subordinate_monitor2scoreboard_mbx,
                  m_network_if_manager_monitor2scoreboard_mbx,
                  m_network_if_subordinate_monitor2scoreboard_mbx,
                  network_manager_vif,
                  network_subordinate_vif);
    
    scoreboard = new(m_axis_manager_driver2scoreboard_mbx,
                     m_axis_manager_monitor2scoreboard_mbx,
                     m_axis_subordinate_monitor2scoreboard_mbx,
                     m_network_if_manager_monitor2scoreboard_mbx,
                     m_network_if_subordinate_monitor2scoreboard_mbx,
                     m_network_if_manager_driver2scoreboard_mbx);
  endfunction
  
  virtual task pre_test();
    driver.reset();
  endtask
  
  virtual task post_test();
    wait(generator_done.triggered);
    
    $display("[T=%0t] [Environment] waiting driver to complete", $time);
    
    if (generator.get_axis_manager_mode() == 1) begin
      wait(generator.numberof_m_axis_frames_generated == driver.numberof_m_axis_frames_transmitted);
      $display("[T=%0t] [Environment] waiting scoreboard to complete for axis_manager_mode", $time);
      wait(driver.numberof_m_axis_frames_transmitted == scoreboard.numberof_m_axis_frames_processed);
    end
    
    if (generator.get_axis_subordinate_mode() == 1) begin
      wait(generator.numberof_network_valid_transactions == driver.network_if_manager_numberof_valid_network_transactions);
      $display("[T=%0t] [Environment] waiting scoreboard to complete for axis_subordinate_mode", $time);      
      wait(generator.numberof_network_packet_generated == scoreboard.numberof_s_axis_frames_processed);    
    end
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
