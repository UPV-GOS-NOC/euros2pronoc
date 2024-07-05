// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file single_unit_network_interface_scoreboard.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 04th, 2024


class single_unit_network_interface_scoreboard;
 
  // Counter of errors
  int error_counter = 0;
  
  // Counts for the number of AXI-Stream (Manager) frames processed
  int numberof_m_axis_frames_processed = 0;
  
  // Counts for the number of AXI-Stream (Subordinate) frames processed
  int numberof_s_axis_frames_processed = 0;  
 
  bit [7:0] network_message [$];
  bit [7:0] reference_model [$];
  
  // Mailboxes for IPC with monitor and driver
  mailbox m_axis_manager_monitor_mbx;
  mailbox m_axis_subordinate_monitor_mbx;
  mailbox m_network_if_manager_monitor_mbx;
  mailbox m_network_if_subordinate_monitor_mbx;
  mailbox m_network_if_manager_driver_mbx;
  mailbox m_axis_manager_driver_mbx;
  
  function new(mailbox axis_manager_driver2scoreboard_mbx,
               mailbox axis_manager_monitor2scoreboard_mbx,
               mailbox axis_subordinate_monitor2scoreboard_mbx,
               mailbox network_if_manager_monitor2scoreboard_mbx,
               mailbox network_if_subordinate_monitor2scoreboard_mbx,
               mailbox network_if_manager_driver2scoreboard_mbx);
    m_axis_manager_driver_mbx = axis_manager_driver2scoreboard_mbx;
    m_axis_manager_monitor_mbx = axis_manager_monitor2scoreboard_mbx;
    m_axis_subordinate_monitor_mbx = axis_subordinate_monitor2scoreboard_mbx;
    m_network_if_manager_monitor_mbx = network_if_manager_monitor2scoreboard_mbx;
    m_network_if_subordinate_monitor_mbx = network_if_subordinate_monitor2scoreboard_mbx;
    m_network_if_manager_driver_mbx = network_if_manager_driver2scoreboard_mbx;
  endfunction
  
  // checks the tonet path: an AXI-Stream manager stream must be
  // converted into network flits. Use m_network_if_subordinate_monitor_mbx to receive flits from DUV
  // and m_axis_manager_driver_mbx to build the reference model
  task tx_channel_scoreboard();
    network_flit_item_t item;
    int flit_on_fly = 0;
    int flit_on_fly_previous = 0;
    int numberof_received_bytes = 0;
    int axis_tid;
    bit [6:0] padding;
    bit [7:0] network_message_byte;
    int numberof_flits_in_packet = 0;
    int numberof_flits_in_packet_expected = 0;
    
    axi4stream_transaction m_axis_transaction;
    bit [4:0] axis_tid_reference_model;
    bit [7:0] reference_model_byte;
    logic [7:0] data[3:0];
    int first_transfer_of_frame = 0;
    int numberof_words_in_axiframe = 0;
    
    forever begin
      m_network_if_subordinate_monitor_mbx.get(item);
      
      // It does not take into account TKEEP
      if (item.valid) begin
        if (item.broadcast == 1) begin
          $error("[T=%0t] [Scoreboard] Error! broadcast == 1", $time);
          error_counter++;
        end
        
        if (item.flit_type == FLIT_TYPE_HEADER) begin
          flit_on_fly_previous = flit_on_fly;
          flit_on_fly = 1;
          axis_tid = item.flit[41:37];
          padding = item.flit[35:32];
          numberof_flits_in_packet++;
          for (int i = 0; i < 4; i++) begin
            if (padding[i] == 0) begin
              network_message.push_back(item.flit[i*8 +: 8]);
            end
          end
        end else if (item.flit_type == FLIT_TYPE_BODY) begin
          flit_on_fly_previous = flit_on_fly;
          flit_on_fly = 2;
          numberof_flits_in_packet++;
          for (int i = 0; i < 8; i++) begin
            network_message.push_back(item.flit[i*8 +: 8]);
          end
        end else if (item.flit_type == FLIT_TYPE_TAIL) begin
          flit_on_fly_previous = flit_on_fly;
          flit_on_fly = 3;
          numberof_flits_in_packet++;
          padding = item.flit[62:56];
          for (int i = 0; i < 7; i++) begin
            if (padding[i] == 0) begin
              network_message.push_back(item.flit[i*8 +: 8]);
            end
          end
        end else if (item.flit_type == FLIT_TYPE_HEADER_TAIL) begin
          flit_on_fly_previous = flit_on_fly;
          flit_on_fly = 4;
          axis_tid = item.flit[41:37];
          padding = item.flit[35:32];
          numberof_flits_in_packet++;
          for (int i = 0; i < 4; i++) begin
            if (padding[i] == 0) begin
              network_message.push_back(item.flit[i*8 +: 8]);
            end
          end // for
        end // else flit_type_header_and_tail
        
        if ((flit_on_fly == 2) && ((flit_on_fly_previous != 1) && (flit_on_fly_previous != 2))) begin
          $error("[T=%0t] [Scoreboard] Error! Flit received is BODY, but previous flit is distinct of (header || body) previous_flit=%0d", $time, flit_on_fly_previous);
                 error_counter++;        
        end
        
        if ((flit_on_fly == 3) && ((flit_on_fly_previous != 1) && (flit_on_fly_previous != 2))) begin
          $error("[T=%0t] [Scoreboard] Error! Flit received is TAIL, but previous flit is distinct of (header || body)", $time);
                 error_counter++;        
        end
        
        if ((flit_on_fly == 1) && (flit_on_fly_previous != 0)) begin
          $error("[T=%0t] [Scoreboard] Error! Flit received is HEADER, but previous flit is distinct of (header_tail || tail)", $time);
                 error_counter++;        
        end           
        
        if ((flit_on_fly == 4) && (flit_on_fly_previous != 0)) begin
          $error("[T=%0t] [Scoreboard] Error! Flit received is HEADER_TAIL, but previous flit is distinct of (header_tail || tail)", $time);
                 error_counter++;        
        end               
      end
      
      if ((flit_on_fly == 3) || (flit_on_fly == 4)) begin
        // Packet completed. Do the check
        flit_on_fly = 0;
        numberof_words_in_axiframe = 0;
        // Get the reference model send to the scoreboard by the driver
        // to check the content to be transmitted to the network by
        // the NI
        first_transfer_of_frame = 1;
        do begin
          m_axis_manager_driver_mbx.get(m_axis_transaction);
          m_axis_transaction.get_data(data);
          numberof_words_in_axiframe++;
          for (int i = 0; i < 4; i++) begin
            reference_model.push_back(data[i]);
          end
          
          if (first_transfer_of_frame == 1) begin
            axis_tid_reference_model = m_axis_transaction.get_id();
            first_transfer_of_frame = 0;
            numberof_flits_in_packet_expected++;
          end
          if (axis_tid_reference_model != m_axis_transaction.get_id()) begin
            $error("[T=%0t] [Scoreboard] Error! Tid interleft in a frame", $time);
            error_counter++;
          end
        end while(m_axis_transaction.get_last() != 1);
       
        // tlast asserted means frame completed. 
        // Check received network packet w.rt. m_axis frame  
       
        if (item.virtual_identifier != axis_tid_reference_model % NUMBEROF_VIRTUAL_NETWORKS) begin
          $error("[T=%0t] [Scoreboard] Error! virtual_network=%0d != virtual_network_expected=%0d", 
                 $time, item.virtual_identifier,
                 axis_tid % NUMBEROF_VIRTUAL_NETWORKS);
          error_counter++;
        end
        
        if (axis_tid != axis_tid_reference_model) begin
          $error("[T=%0t] [Scoreboard] Error! Tid=%0d != Tid_expected=%0d", 
                 $time,
                 axis_tid,
                 axis_tid_reference_model);
          error_counter++;
        end
        
        while ((network_message.size() > 0) && (reference_model.size() > 0)) begin
          network_message_byte = network_message.pop_front();
          reference_model_byte = reference_model.pop_front();
          
          if (network_message_byte != reference_model_byte) begin
            $error("[T=%0t] [Scoreboard] Error! network_message_byte=%0x != reference_model_byte=%0x",
                   $time,
                   network_message_byte,
                   reference_model_byte);
            error_counter++;
          end
        end
        
        if ((network_message.size() > 0) || (reference_model.size() > 0)) begin
          $error("[T=%0t] [Scoreboard] Error! Network Message size differs w.r.t. reference model frame size", $time);
          error_counter++;
        end
        
        if (numberof_words_in_axiframe == 1) begin
          numberof_flits_in_packet_expected = 1;
        end else begin
          numberof_flits_in_packet_expected = (numberof_words_in_axiframe-1) * 4 / 8 + 2;
        end
        
        if (numberof_flits_in_packet != numberof_flits_in_packet_expected) begin
          $error("[T=%0t] [Scoreboard] Error! numberof_flits_in_packet=%0d != numberof_flits_in_packet_expected=%0d", 
                 $time,
                 numberof_flits_in_packet,
                 numberof_flits_in_packet_expected);
          error_counter++;        
        end
        
        // Reset the counter for the next packet, since this is already checked
        numberof_flits_in_packet = 0;
        
        numberof_m_axis_frames_processed++;
        $display("[T=%0t] [Scoreboard] numberof_axi_manager_frames_processed=%0d", $time,
        numberof_m_axis_frames_processed);         
      end
    end
  endtask
  
  task rx_channel_scoreboard();
    axi4stream_monitor_transaction axis_item;
    bit [7:0] axis_data [$];
    bit [4:0] axis_tid;
    bit [10:0] axis_tdest;
    bit [7:0] axis_byte;
    logic [7:0] data[3:0];    
    int first_transfer_of_frame = 0;
    int numberof_words_in_axiframe = 0;    
      
    network_flit_ejection_item_t network_item;
    int numberof_flits_in_packet = 0;
    int flit_with_only_tlast = 0;
    bit [7:0]  network_data [$];
    bit [11:0] network_dest;
    bit [4:0]  network_tid;
    bit [6:0]  padding;
    bit [7:0]  network_byte;
    bit [VIRTUAL_NETWORK_ID_WIDTH-1:0] network_virtual_network;    
       
    int numberof_flits_in_packet_expected;
       
    forever begin
      // Get an axi frame using the axis_subordinate_monitor
      numberof_words_in_axiframe = 0;
      first_transfer_of_frame = 1;
      do begin
        m_axis_subordinate_monitor_mbx.get(axis_item);
        axis_item.get_data(data);
        numberof_words_in_axiframe++;
        for (int i = 0; i < 4; i++) begin
          axis_data.push_back(data[i]);
        end
      
        if (first_transfer_of_frame == 1) begin
          axis_tid = axis_item.get_id();
          axis_tdest = axis_item.get_dest();
          first_transfer_of_frame = 0;
        end
        
        // check that tid is equal in every transfer of frame
        if (axis_tid != axis_item.get_id()) begin
          $error("[T=%0t] [Scoreboard] Error! Tid interleft in a frame", $time);
          error_counter++;
        end
        
        // check that tdest is equal in every transfer of frame
        if (axis_tdest != axis_item.get_dest()) begin
          $error("[T=%0t] [Scoreboard] Error! dest interleft in a frame", $time);
          error_counter++;
        end        
      end while(axis_item.get_last() != 1);
      
      // Get the network packet (reference model) from the driver
      // through m_network_if_manager_scoreboard_mbx
      numberof_flits_in_packet = 0;
      flit_with_only_tlast = 0;
      do begin
        m_network_if_manager_driver_mbx.get(network_item);

        if (network_item.valid == 0) begin
          continue;
        end
        
        // First flit of packet
        if ((network_item.flit_type == FLIT_TYPE_HEADER) || (network_item.flit_type == FLIT_TYPE_HEADER_TAIL)) begin
          network_dest = network_item.flit[63:53];
          network_virtual_network = network_item.virtual_identifier;
          network_tid = network_item.flit[41:37];
          padding = network_item.flit[35:32];
          for (int i = 0; i < 4; i++) begin
            if (padding[i] == 0) begin
              network_data.push_back(network_item.flit[i*8 +: 8]);
            end
          end          
        end else if (network_item.flit_type == FLIT_TYPE_BODY) begin
          for (int i = 0; i < 8; i++) begin
            network_data.push_back(network_item.flit[i*8 +: 8]);
          end        
        end else if (network_item.flit_type == FLIT_TYPE_TAIL) begin
          padding = network_item.flit[62:56];
          if (padding == 7'b1111111) begin
            // tail flit carry out tlast only
            flit_with_only_tlast = 1;
          end
          for (int i = 0; i < 7; i++) begin
            if (padding[i] == 0) begin
              network_data.push_back(network_item.flit[i*8 +: 8]);
            end
          end        
        end
        
        // broadcast not checked
        
        // check virtual network
        if (network_virtual_network != network_item.virtual_identifier) begin
          $error("[T=%0t] [Scoreboard] Error! VN changed inside a flit", $time);
          error_counter++;
        end        
        
        if (network_virtual_network != network_tid % NUMBEROF_VIRTUAL_NETWORKS) begin
          $error("[T=%0t] [Scoreboard] Error! virtual_network=%0d != virtual_network_expected=%0d", 
                 $time, network_virtual_network,
                 network_tid % NUMBEROF_VIRTUAL_NETWORKS);
          error_counter++;
        end
        
        numberof_flits_in_packet++;
      end while((network_item.flit_type != FLIT_TYPE_TAIL) && (network_item.flit_type != FLIT_TYPE_HEADER_TAIL));
      
      // Check Packet (reference model) vs AXI Frame
      if (network_virtual_network != axis_tid % NUMBEROF_VIRTUAL_NETWORKS) begin
        $error("[T=%0t] [Scoreboard] Error! TID and VN does not match", 
               $time, network_virtual_network,
               axis_tid % NUMBEROF_VIRTUAL_NETWORKS);
        error_counter++;
      end
      
      if (network_dest != axis_tdest) begin
        $error("[T=%0t] [Scoreboard] Error! AXIS_TDEST=%0d != NETWORK_DEST=%0d", 
               $time, axis_tdest,
               network_dest);
        error_counter++;
      end
      
      while ((network_data.size() > 0) && (axis_data.size() > 0)) begin
        network_byte = network_data.pop_front();
        axis_byte = axis_data.pop_front();
      
        if (network_byte != axis_byte) begin
          $error("[T=%0t] [Scoreboard] Error! network_message_byte=%0x != reference_model_byte=%0x",
                 $time,
                 network_byte,
                 axis_byte);
          error_counter++;
        end
      end
        
      if ((network_data.size() > 0) || (axis_data.size() > 0)) begin
        $error("[T=%0t] [Scoreboard] Error! Network Message size differs w.r.t. reference model frame size", $time);
        error_counter++;
      end
        
      if ((numberof_words_in_axiframe == 1) && (flit_with_only_tlast == 0)) begin
        numberof_flits_in_packet_expected = 1;
      end else begin
        numberof_flits_in_packet_expected = (numberof_words_in_axiframe-1) * 4 / 8 + 2;
      end
        
      if (numberof_flits_in_packet != numberof_flits_in_packet_expected) begin
        $error("[T=%0t] [Scoreboard] Error! numberof_flits_in_packet=%0d != numberof_flits_in_packet_expected=%0d", 
               $time,
               numberof_flits_in_packet,
               numberof_flits_in_packet_expected);
        error_counter++;        
      end      
      
      numberof_s_axis_frames_processed++;
      $display("[T=%0t] [Scoreboard] numberof_axi_manager_frames_processed=%0d", $time,
      numberof_s_axis_frames_processed);   
    end
  endtask
  
  task run();
    fork
      tx_channel_scoreboard();
      rx_channel_scoreboard();
    join_none
  endtask
  
endclass
