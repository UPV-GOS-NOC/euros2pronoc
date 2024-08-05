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

class network_on_chip_scoreboard;
 
  // Counter of errors
  int error_counter = 0;
  
  // Counts for the number of AXI-Stream (Subordinate) frames processed
  int numberof_s_axis_frames_processed = 0;  
 
  // Mailboxes for IPC with monitor and driver
  mailbox m_axis_manager_driver_mbx;
  mailbox m_axis_subordinate_monitor_mbx;
  
  function new(mailbox axis_manager_driver2scoreboard_mbx,
               mailbox axis_subordinate_monitor2scoreboard_mbx);
    m_axis_manager_driver_mbx = axis_manager_driver2scoreboard_mbx;
    m_axis_subordinate_monitor_mbx = axis_subordinate_monitor2scoreboard_mbx;
  endfunction
  
  task check_axiframes_scoreboard();
    axi4stream_monitor_transaction s_axis_item;
    bit [7:0] s_axis_data [$];
    bit [4:0] s_axis_tid;
    bit [10:0] s_axis_tdest;
    bit [7:0] s_axis_byte;
    int s_axis_first_transfer_of_frame = 0;
    int s_axis_numberof_words_in_axiframe = 0;    
      
    axi4stream_transaction m_axis_item;
    bit [7:0]  m_axis_data [$];
    bit [11:0] m_axis_tdest;
    bit [4:0]  m_axis_tid;
    bit [7:0]  m_axis_byte;
    int m_axis_numberof_words_in_axiframe = 0;
    int m_axis_first_transfer_of_frame = 0;
    
    logic [7:0] data[3:0];    

    forever begin
      // Get an s_axis frame using the axis_subordinate_monitor
      s_axis_numberof_words_in_axiframe = 0;
      s_axis_first_transfer_of_frame = 1;
      do begin
        m_axis_subordinate_monitor_mbx.get(s_axis_item);
        s_axis_item.get_data(data);
        s_axis_numberof_words_in_axiframe++;
        for (int i = 0; i < 4; i++) begin
          s_axis_data.push_back(data[i]);
        end
      
        if (s_axis_first_transfer_of_frame == 1) begin
          s_axis_tid = s_axis_item.get_id();
          s_axis_tdest = s_axis_item.get_dest();
          s_axis_first_transfer_of_frame = 0;
        end
        
        // check that tid is equal in every transfer of frame
        if (s_axis_tid != s_axis_item.get_id()) begin
          $error("[T=%0t] [Scoreboard] Error! Tid interleft in a frame", $time);
          error_counter++;
        end
        
        // check that tdest is equal in every transfer of frame
        if (s_axis_tdest != s_axis_item.get_dest()) begin
          $error("[T=%0t] [Scoreboard] Error! dest interleft in a frame", $time);
          error_counter++;
        end        
      end while(s_axis_item.get_last() != 1);
      
      // Get the m_axis frame (reference model) from the driver
      // through m_axis_manager_driver_mbx
      m_axis_numberof_words_in_axiframe = 0;
      m_axis_first_transfer_of_frame = 1;
      do begin
        m_axis_manager_driver_mbx.get(m_axis_item);

        m_axis_item.get_data(data);
        m_axis_numberof_words_in_axiframe++;
        for (int i = 0; i < 4; i++) begin
          m_axis_data.push_back(data[i]);
        end
      
        if (m_axis_first_transfer_of_frame == 1) begin
          m_axis_tid = m_axis_item.get_id();
          m_axis_tdest = m_axis_item.get_dest();
          m_axis_first_transfer_of_frame = 0;
        end
        
        // check that tid is equal in every transfer of frame
        if (m_axis_tid != m_axis_item.get_id()) begin
          $error("[T=%0t] [Scoreboard] Error! Tid interleft in reference model frame (check generator)", $time);
          error_counter++;
        end
        
        // check that tdest is equal in every transfer of frame
        if (m_axis_tdest != m_axis_item.get_dest()) begin
          $error("[T=%0t] [Scoreboard] Error! dest interleft in reference model frame (check generator)", $time);
          error_counter++;
        end        
      end while(m_axis_item.get_last() != 1);
       
      // Check AXI Frame (reference model) vs AXI Frame
      if (m_axis_tid != s_axis_tid) begin
        $error("[T=%0t] [Scoreboard] Error! s_axis_tid=%0d != m_axis_tid=%0d", 
               $time, s_axis_tid,
               m_axis_tid);
        error_counter++;
      end
      
      if (m_axis_tdest != s_axis_tdest) begin
        $error("[T=%0t] [Scoreboard] Error! s_axis_tdest=%0d != m_axis_tdest=%0d", 
               $time, s_axis_tdest,
               m_axis_tdest);
        error_counter++;
      end
      
      while ((s_axis_data.size() > 0) && (m_axis_data.size() > 0)) begin
        m_axis_byte = m_axis_data.pop_front();
        s_axis_byte = s_axis_data.pop_front();
      
        if (s_axis_byte != m_axis_byte) begin
          $error("[T=%0t] [Scoreboard] Error! s_axis_byte=%0x != m_axis_byte=%0x",
                 $time,
                 s_axis_byte,
                 m_axis_byte);
          error_counter++;
        end
      end
        
      if ((m_axis_data.size() > 0) || (s_axis_data.size() > 0)) begin
        $error("[T=%0t] [Scoreboard] Error! m_axis frame size differs w.r.t. s_axis frame size", $time);
        error_counter++;
      end
        
      if (s_axis_numberof_words_in_axiframe != m_axis_numberof_words_in_axiframe) begin
        $error("[T=%0t] [Scoreboard] Error! s_axis_numberof_words_in_axiframe=%0d != m_axis_numberof_words_in_axiframe=%0d", 
               $time,
               s_axis_numberof_words_in_axiframe,
               m_axis_numberof_words_in_axiframe);
        error_counter++;        
      end      
      
      numberof_s_axis_frames_processed++;
      $display("[T=%0t] [Scoreboard] numberof_s_axis_frames_processed=%0d", $time,
      numberof_s_axis_frames_processed);   
    end
  endtask
  
  task run();
    fork
      check_axiframes_scoreboard();
    join_none
  endtask
  
endclass
