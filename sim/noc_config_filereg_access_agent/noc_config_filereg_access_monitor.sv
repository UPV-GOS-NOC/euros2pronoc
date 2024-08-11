// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_config_filereg_access_monitor.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 23th, 2024
//
// @title Network Configuration FileReg Access Monitor
//
// Monitors the FileReg Router interfaces to generate
// config_filereg transactions for the scoreboard to check them
// against the reference model.
//

class noc_config_filereg_access_monitor #(
  int NumberOfTiles = 0
);

  // Interfaces to monitor
  filereg_vif_t   config_filereg_vif[0:NumberOfTiles-1];
  filereg_m_vif_t config_filereg_m_vif[0:NumberOfTiles-1];

  // Mailbox for IPC between monitor and scoreboard
  mailbox m_config_filereg_transaction_scoreboard_mbx[0:NumberOfTiles-1];
  mailbox m_config_filereg_response_transaction_scoreboard_mbx[0:NumberOfTiles-1];
  
  // For filereg interface Coverage
  noc_config_filereg_access_agent_cov cov;
  semaphore sem;

  function new(input filereg_vif_t config_filereg_vif[0:NumberOfTiles-1],
               input filereg_m_vif_t config_filereg_m_vif[0:NumberOfTiles-1],
               ref mailbox config_filereg_transaction_monitor2scoreboard_mbx[0:NumberOfTiles-1],
               ref mailbox config_filereg_response_transaction_monitor2scoreboard_mbx[0:NumberOfTiles-1],
               ref noc_config_filereg_access_agent_cov cov);
               
    this.cov = cov;
    sem = new(1);
               
    m_config_filereg_transaction_scoreboard_mbx = config_filereg_transaction_monitor2scoreboard_mbx;
    m_config_filereg_response_transaction_scoreboard_mbx = config_filereg_response_transaction_monitor2scoreboard_mbx;           
    for (int i = 0; i < NumberOfTiles; i++) begin
      this.config_filereg_vif[i] = config_filereg_vif[i];
      this.config_filereg_m_vif[i] = config_filereg_m_vif[i];
    end
  endfunction
 
  // Gets the filereg port signals state and send it to the scoreboard
  // through the corresponding mailbox mailbox
  task capture_transactions(input int tile);
    filereg_vif_t filereg_vif = config_filereg_vif[tile];
    request_filereg_item_t cfg_transaction = new();
    
    forever begin
      bit [64:0] message;

      @(posedge filereg_vif.clk);

      cfg_transaction.valid = filereg_vif.monitor.monitor_clock_block.valid;
      cfg_transaction.ready = filereg_vif.monitor.monitor_clock_block.ready;
      message               = filereg_vif.monitor.monitor_clock_block.data;
      cfg_transaction.set_message(message);
      cfg_transaction.module_address = tile;
      
      sem.get(1);
      cov.sample(cfg_transaction);
      sem.put(1);
      
      if ((cfg_transaction.valid == 1) && (cfg_transaction.ready == 1)) begin 
        m_config_filereg_transaction_scoreboard_mbx[tile].put(cfg_transaction);
      end
    end
  endtask
  
  // Gets the filereg port signals state and send it to the scoreboard
  // through the corresponding mailbox mailbox
  task capture_response_transactions(input int tile);
    filereg_m_vif_t filereg_vif = config_filereg_m_vif[tile];
    response_filereg_item_t cfg_transaction = new();
    
    forever begin
      bit [64:0] message;

      @(posedge filereg_vif.clk);

      cfg_transaction.valid = filereg_vif.monitor.monitor_clock_block.valid;
      cfg_transaction.ready = filereg_vif.monitor.monitor_clock_block.ready;
      message               = filereg_vif.monitor.monitor_clock_block.data;
      cfg_transaction.set_response_message(message);
      
      //sem.get(1);
      //cov.sample(cfg_transaction);
      //sem.put(1);
      
      if ((cfg_transaction.valid == 1) && (cfg_transaction.ready == 1)) begin 
        m_config_filereg_response_transaction_scoreboard_mbx[tile].put(cfg_transaction);
      end
    end
  endtask  
  
  task run();
    for (int tile = 0; tile < NumberOfTiles; tile++) begin
      automatic int k = tile;
      fork        
        capture_transactions(k);
        capture_response_transactions(k);
      join_none
    end
  endtask
  
endclass
