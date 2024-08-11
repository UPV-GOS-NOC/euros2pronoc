// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_config_filereg_access_scoreboard.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 22th, 2024
//
// The scoreboard checks that the configuration filereg transactions,
// encapsulated into AXIS
// frames injected by the M_AXIS_VIP driver into the NoC,
// equals to the configuration regiter file transactions  received by the
// config file reg monitor at the other end of the NoC, which is monitoring
// the filereg access port of the routers.

class noc_config_filereg_access_scoreboard #(
  int NumberOfTiles = 0
);
 
  // Counter of errors
  int error_counter = 0;
  semaphore sem_error_counter;
  
  // Counts for the number of configuration file accesses processed
  int numberof_config_filereg_transactions_processed = 0;
  semaphore sem_transaction_processed;

  // Mailboxes for IPC with monitor and driver
  mailbox m_config_filereg_transaction_driver_mbx[0:NumberOfTiles-1];
  mailbox m_config_filereg_transaction_monitor_mbx[0:NumberOfTiles-1];
  mailbox m_config_filereg_response_transaction_monitor_mbx[0:NumberOfTiles-1];
  
  int verbosity = 0;

  function new(input mailbox config_filereg_transaction_driver2scoreboard_mbx[0:NumberOfTiles-1],
               input mailbox config_filereg_transaction_monitor2scoreboard_mbx[0:NumberOfTiles-1],
               input mailbox config_filereg_response_transaction_monitor2scoreboard_mbx[0:NumberOfTiles-1]);      
      for (int i = 0; i < NumberOfTiles; i++) begin
        m_config_filereg_transaction_driver_mbx[i]  = config_filereg_transaction_driver2scoreboard_mbx[i];
        m_config_filereg_transaction_monitor_mbx[i] = config_filereg_transaction_monitor2scoreboard_mbx[i];
        m_config_filereg_response_transaction_monitor_mbx[i] = config_filereg_response_transaction_monitor2scoreboard_mbx[i];
      end

    // argument 1 is the number of resources that can access the critical
    // section at a time 
    sem_error_counter = new(1);
    sem_transaction_processed = new(1);
  endfunction
  
  task check_config_filereg_access(input int tile);
    forever begin
      request_filereg_item_t reference_model;
      request_filereg_item_t cfg_transaction;
      
      m_config_filereg_transaction_driver_mbx[tile].get(reference_model);
      m_config_filereg_transaction_monitor_mbx[tile].get(cfg_transaction);
      cfg_transaction.module_address = tile;

      if (cfg_transaction.compare(reference_model) != 0) begin
        $display("[T=%0t] [Scoreboard] Error! Transaction mismatch actual_transaction(%0s); reference(%0s)", 
          $time,
          cfg_transaction.toString(),
          reference_model.toString());

        
        sem_error_counter.get(1);
        error_counter++;
        sem_error_counter.put(1);
      end
      
      // This should be got with coverage (not here)
      if (cfg_transaction.get_command() != 1) begin
        $display("[T=%0t] [Scoreboard] Error! Command must be WR (1), but found %0d", 
          $time,
          cfg_transaction.get_command());

        
        sem_error_counter.get(1);
        error_counter++;
        sem_error_counter.put(1);      
      end
      
      // This should be got with coverage (not here)
      if (cfg_transaction.get_register_address() == 0) begin
        $display("[T=%0t] [Scoreboard] Error! Register address must be greater than 0, but found %0d", 
          $time,
          cfg_transaction.get_register_address());

        
        sem_error_counter.get(1);
        error_counter++;
        sem_error_counter.put(1);      
        
        // Force $finish, since we could block VN0
        sem_transaction_processed.get(1);
        numberof_config_filereg_transactions_processed = 9999999;
        sem_transaction_processed.put(1);      
      end      
      
      sem_transaction_processed.get(1);
      numberof_config_filereg_transactions_processed++;
      if (verbosity != 0) begin
        $display("[T=%0t] [Scoreboard %0d] numberof_config_filereg_transactions_processed=%0d",
                 $time, tile, numberof_config_filereg_transactions_processed);
      end
      sem_transaction_processed.put(1);
    end
  endtask
  
  task check_response_config_filereg_access(input int tile);
    int counter = 1; // reference model equals to the number of register read
    forever begin
      response_filereg_item_t cfg_transaction;
      
      m_config_filereg_response_transaction_monitor_mbx[tile].get(cfg_transaction);
      
      if (cfg_transaction.get_value() != counter) begin
        $display("[T=%0t] [Scoreboard] Error! Transaction Response mismatch actual=%0d; reference=%0d", 
          $time,
          cfg_transaction.get_value(),
          counter);

        sem_error_counter.get(1);
        error_counter++;
        sem_error_counter.put(1);
      end
      
      sem_transaction_processed.get(1);
      numberof_config_filereg_transactions_processed++;
      if (verbosity != 0) begin
        $display("[T=%0t] [Scoreboard %0d] numberof_config_filereg_transactions_processed=%0d",
                 $time, tile, numberof_config_filereg_transactions_processed);
      end
      sem_transaction_processed.put(1);      
      
      counter++;      
    end
  endtask
  
  task run();
    for (int tile = 0; tile < NumberOfTiles; tile++) begin
      automatic int k = tile;
      fork        
        check_config_filereg_access(k);
        check_response_config_filereg_access(k);
      join_none
    end    
  endtask
  
endclass
