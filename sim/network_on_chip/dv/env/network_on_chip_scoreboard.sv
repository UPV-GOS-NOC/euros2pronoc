// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_on_chip_scoreboard.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 08th, 2024
//
// The scoreboard checks that the AXI-Stream
// frames injected by the M_AXIS_VIP driver into the NoC
// equals to the frames received by the
// S_AXIS_VIP monitor at the other end of the NoC
//
// Checkings: TID, TDEST, DATA CONTENT for every frame

class expected_transactions_t;

  axi4stream_transaction q[$];
  int iexpect, iactual;

endclass

class network_on_chip_scoreboard;
 
  protected network_on_chip_env_cfg cfg;
  
  // This structure maintains transaction expecting
  // to be checked against actual ones. 
  protected expected_transactions_t expected_transactions[];
 
  protected int verbosity = 0;
  
  // Counter of errors
  protected int error_counter = 0;
  
  // Access to critical section when saving expected transaction, since
  // several drivers could send to same destination at a time
  protected semaphore sem;
  
  // Counts for the number of AXI-Stream (Subordinate) frames processed
  int numberof_s_axis_frames_processed = 0;  
 
  int iexpect = 0;
  int iactual = 0;
  
  function new(input int numberof_tiles, input network_on_chip_env_cfg cfg);
    this.cfg = cfg;
    
    expected_transactions = new[numberof_tiles];
    foreach(expected_transactions[i]) begin
      expected_transactions[i] = new();
    end
    
    sem = new(1);
  endfunction
  
  //
  // Getters and setters
  //
  function void set_verbosity(int verbosity);
    this.verbosity = verbosity;
  endfunction  
  
  function int get_error_counter();
    return error_counter;
  endfunction
  
  //
  // Run and test methods
  //
  
  function void check_actual_item(input int tile, input axi4stream_transaction item);
    axi4stream_transaction expected_item;  
    int found = 0;
    int got_access = 0;
    
    do begin
      got_access = sem.try_get(1);
    end while (got_access != 1);
    
    iactual++;
    expected_transactions[tile].iactual++;        
    if (verbosity > 0) begin
      $display("[T=%0t] [Scoreboard] Received actual transaction. global_transaction=%0d, local_transaction=%0d, dst_tile=%0d. queue[%0d].size=%0d item=(%s)",
               $time, iactual, expected_transactions[tile].iactual, tile,
               tile, expected_transactions[tile].q.size(), display_item(item));
    end
    
    if (tile != item.get_dest()) begin
      $error("[T=%0t] [Scoreboard] Error! Received actual transaction. global_transaction=%0d, local_transaction=%0d, dst_tile=%0d. tile=%0d != dest=%0d",
             $time, iactual, expected_transactions[tile].iactual, tile, tile, item.get_dest());
    end      
    
    if (expected_transactions[tile].q.size() == 0) begin
      $error("[T=%0t] [Scoreboard] Error! Received actual transaction. global_transaction=%0d, local_transaction=%0d, dst_tile=%0d. but queue_size=0. received_item=%s", 
               $time, iactual, expected_transactions[tile].iactual, tile, display_item(item));
      error_counter++;     
    end else begin : expected_items_to_check
      // There is expected items to check.
      // They could be in different order since several tiles could be sending to the same target one at the same time

  
      foreach(expected_transactions[tile].q[i]) begin : loop_foreach
        expected_item = expected_transactions[tile].q[i];
        if (this.compare(expected_item, item) != 0) begin : if_expected
          found = 1;
          expected_transactions[tile].q.delete(i);
          if (verbosity != 0) begin
            $display("[T=%0t] [Scoreboard] Received actual transaction. global_transaction=%0d, local_transaction=%0d, dst_tile=%0d. found match for index %0d. Deleting it found_item=%s. new_queue[%0d]_size=%0d", 
                     $time, iactual, expected_transactions[tile].iactual, tile, i, display_item(item), tile, expected_transactions[tile].q.size());
          end
          break;
        end : if_expected
      end : loop_foreach
    
      if (found == 0) begin
        $error("[T=%0t] [Scoreboard] Error! Received actual transaction.global_transaction=%0d, local_transaction=%0d, dst_tile=%0d. but there is not a match. queue[%0d].size=%0d. received_item=%s", 
                $time, iactual, expected_transactions[tile].iactual, tile, tile, expected_transactions[tile].q.size(), display_item(item));
        error_counter++;
      end
    end : expected_items_to_check
        
    sem.put(1);
  
  endfunction
  
  function void save_expected_item(input int tile, input axi4stream_transaction item);
    int dest = item.get_dest();
    int got_access = 0;
    
    do begin
       got_access = sem.try_get(1);
    end while(got_access != 1);
    
    expected_transactions[dest].q.push_back(item);
    expected_transactions[dest].iexpect++;
    iexpect++;
        
    if (verbosity != 0) begin
      $display("[T=%0t] [Scoreboard] Reference model. global_transaction=%0d, local_transaction=%0d, src_tile=%0d, target_queue=%0d, expected_item=(%s)",
               $time, iexpect, expected_transactions[dest].iexpect,
               tile, dest, display_item(item));
    end

    sem.put(1);

  endfunction
  
  function int compare(input axi4stream_transaction lhs, input axi4stream_transaction rhs);
    int res = 0;    
    
    if ((lhs.get_dest() == rhs.get_dest()) &&
        (lhs.get_id() == rhs.get_id()) &&
        (lhs.get_last() == rhs.get_last()) &&
        (get_data(lhs) == get_data(rhs))) begin
        res = 1; 
    end
    
    return res;
  endfunction
  
  function bit [31:0] get_data(input axi4stream_transaction item);
    logic [7:0] data[4];
        
    item.get_data(data);
    return {data[3], data[2], data[1], data[0]};
  endfunction
  
  function string display_item(input axi4stream_transaction item, string prefix = "");
    return $sformatf("%s tid=%0d, tdest=%0d, tlast=%0d, value=%0x",
              prefix, item.get_id(), item.get_dest(), item.get_last(), get_data(item));
  endfunction
  
endclass
