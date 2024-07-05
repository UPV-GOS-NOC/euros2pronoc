// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_ejector_scoreboard.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network ejector scoreboard
//
// It receives transaction items from the monitor
// and checks them against the reference model
// to determine whether the test passes or fails
class network_ejector_scoreboard #(
  int FlitWidth               = 0,
  int FlitTypeWidth           = 0,
  int BroadcastWidth          = 0,
  int VirtualNetworkIdWidth   = 0,
  int NumberOfVirtualNetworks = 0 
);

  localparam int DataWidth = FlitWidth +
                             FlitTypeWidth +
                             BroadcastWidth +
                             VirtualNetworkIdWidth;         
   int error_data_if = 0;      
   int error_network_if = 0;
         
   int numberof_transactions_processed = 0;
   
   bit [NumberOfVirtualNetworks-1:0] network_ready_prev = 0;
                             
   mailbox m_data_mbx;
   mailbox m_flit_mbx;
   
   mailbox m_driver_mbx;

  function new(mailbox flit_mbx, mailbox data_mbx, mailbox driver_mbx);
    m_flit_mbx = flit_mbx;
    m_data_mbx = data_mbx;
    m_driver_mbx = driver_mbx;
  endfunction
  
  task data_if_scoreboard();
    valid_ready_data_item #(
      .DataWidth(DataWidth)
    ) data_item;     
    
    forever begin
      network_flit_item #(
        .FlitWidth                        (FlitWidth),
        .FlitTypeWidth                    (FlitTypeWidth),
        .BroadcastWidth                   (BroadcastWidth),
        .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
        .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)        
      ) flit_item;      
      
      bit [DataWidth-1:0] packed_flit;
      
      m_data_mbx.get(data_item);  
     
     //data_item.display("[Scoreboard]");    
      
      if ((data_item.valid == 1) && (data_item.ready == 1)) begin
        m_driver_mbx.get(flit_item);

        packed_flit = {
            flit_item.virtual_identifier,
            flit_item.broadcast,
            flit_item.flit_type,
            flit_item.flit
        }; 

        if (packed_flit != data_item.data) begin
          $error("[T=%0t] [Scoreboard] Error! data_expected=%x; data_if.data=%x; data_if.valid=%b; data_if.ready=%b", 
                 $time,
                 packed_flit,
                 data_item.data, 
                 data_item.valid,
                 data_item.ready);
          error_data_if++;
        end
        
        numberof_transactions_processed++;
        
        $display("[T=%0t] [Scoreboard] %0d transaction(s) completed. data_if.data=%x; data_if.valid=1; data_if.ready=1", 
                 $time, numberof_transactions_processed, data_item.data);        
      end else begin
        $display("[T=%0t] [Scoreboard] data_if.ready=%b data_if.valid=%b; data_if.data=%x", 
                 $time,
                 data_item.ready,
                 data_item.valid, 
                 data_item.data);      
      end          
    end
  endtask
  
  task network_if_scoreboard();
    network_flit_item #(
      .FlitWidth                        (FlitWidth),
      .FlitTypeWidth                    (FlitTypeWidth),
      .BroadcastWidth                   (BroadcastWidth),
      .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
      .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)        
    ) flit_item;   
    
    bit [DataWidth-1:0] packed_flit;
    
    forever begin
      m_flit_mbx.get(flit_item);  
      
      // valid from network_if can be asserted even if ready from network_if is deasserted
      // since valid could react up to one cycle after ready is deasserted 
      if (((&flit_item.ready == 0) && (&network_ready_prev == 0)) && (flit_item.valid == 1)) begin
        $error("[T=%0t] [Scoreboard] Error! (network_if.ready = %b && network_if.ready_prev = %b) && network_if.valid = 1 => network handshake protocol violated",
               $time,
               &flit_item.ready,
               &network_ready_prev);
        error_network_if++;
      end
      network_ready_prev = flit_item.ready;
    end // forever      
  endtask
  
  task run();
    fork
      data_if_scoreboard();
      network_if_scoreboard();
    join_none
  endtask
endclass

