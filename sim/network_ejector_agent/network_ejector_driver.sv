// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_ejector_driver.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network Ejector driver
//
//Drive transactions from the generator to the DUV through DUV interfaces
class network_ejector_driver #(
  int FlitWidth               = 0,
  int FlitTypeWidth           = 0,
  int BroadcastWidth          = 0,
  int VirtualNetworkIdWidth   = 0,
  int NumberOfVirtualNetworks = 0
);

  int numberof_processed_transactions = 0;
  int numberof_valid_network_transactions = 0;

  localparam int DataWidth = FlitWidth +
                             FlitTypeWidth +
                             BroadcastWidth +
                             VirtualNetworkIdWidth;
  
  virtual valid_ready_data_if #(
    .DataWidth(DataWidth)
  ) data_vif;  
  
  virtual network_if #(
    .FlitWidth                        (FlitWidth),
    .FlitTypeWidth                    (FlitTypeWidth),
    .BroadcastWidth                   (BroadcastWidth),
    .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
    .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)
  ) network_vif;   

  mailbox m_flit_mbx;
  mailbox m_data_mbx;
  
  mailbox m_scoreboard_mbx;

  function new(virtual network_if #(
                   .FlitWidth                        (FlitWidth),
                   .FlitTypeWidth                    (FlitTypeWidth),
                   .BroadcastWidth                   (BroadcastWidth),
                   .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
                   .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)
               ) network_vif, 
               virtual valid_ready_data_if #(
                   .DataWidth(DataWidth)
               ) data_vif,
               mailbox flit_mbx,
               mailbox data_mbx,
               scoreboard_mbx
  );
    this.network_vif = network_vif;
    this.data_vif = data_vif;
    m_flit_mbx = flit_mbx;
    m_data_mbx = data_mbx;
    m_scoreboard_mbx = scoreboard_mbx;
  endfunction

  // Reset the interface signals
  task reset();
    wait(network_vif.rst);
    $display("[T=%0t] [Driver] Reset started...", $time);
     
    data_vif.driver.driver_clock_block.ready <= 1;
          
    network_vif.driver.driver_clock_block.valid <= 0;
    network_vif.driver.driver_clock_block.flit <= 0;
    network_vif.driver.driver_clock_block.flit_type <= 0;
    network_vif.driver.driver_clock_block.broadcast <= 0;
    network_vif.driver.driver_clock_block.virtual_identifier <= 0;
    
    wait(!network_vif.rst);
    $display("[T=%0t] [Driver] Reset completed...", $time);    
  endtask

  task run();
    fork
      data_if_driver();
      network_if_driver();
    join_none
  endtask
  
  task data_if_driver();
    int transaction_id = 0;
    forever begin
      valid_ready_data_item #(
        .DataWidth(DataWidth)
      ) data_item;
      
      m_data_mbx.get(data_item);          
      
      // drive interface      
      @(posedge data_vif.clk);
      data_vif.driver.driver_clock_block.ready <= data_item.ready;
      
      $display("[T=%0t] [Driver] Received and driven Transaction %0d for data_if: ready=%x; data_if state: data_if.ready=%b; data_if.valid=%b; data_if.data=%x", 
               $time, ++transaction_id, data_item.ready, 
               data_vif.monitor.monitor_clock_block.ready, 
               data_vif.monitor.monitor_clock_block.valid, 
               data_vif.monitor.monitor_clock_block.data);                                       
    end
  endtask
  
  task network_if_driver();
  
    wait(network_vif.driver.driver_clock_block.ready == {NumberOfVirtualNetworks{1'b1}});
          
    forever begin
      network_flit_item #(
        .FlitWidth                        (FlitWidth),
        .FlitTypeWidth                    (FlitTypeWidth),
        .BroadcastWidth                   (BroadcastWidth),
        .VirtualNetworkOrChannelIdWidth   (VirtualNetworkIdWidth),
        .NumberOfVirtualNetworksOrChannels(NumberOfVirtualNetworks)        
      ) item;
      
      bit transfer;
      
      m_flit_mbx.get(item);            
      
      // drive network_if according to network handshake avail/valid protocol
      // so, valid can only be asserted when ready is asserted and there is
      // a valid flit       
      @(posedge network_vif.clk);
      
      item.ready = network_vif.driver.driver_clock_block.ready;
      
      $display("[T=%0t] [Driver] Received Transaction %0d for network_if. network_if.ready=%b; network_if.valid=%b; flit_valid=%b; flit=%x; flit_type=%x, broadcast=%b, virtual_channel=%x (%x);", 
               $time, numberof_processed_transactions+1, 
               network_vif.driver.driver_clock_block.ready, network_vif.monitor.monitor_clock_block.valid, 
               item.valid,
               item.flit, item.flit_type, item.broadcast, item.virtual_identifier, 
               {item.virtual_identifier, item.broadcast, item.flit_type, item.flit});        
      
      transfer = &(item.ready) & item.valid;
      network_vif.driver.driver_clock_block.valid <= transfer;
      
      if (transfer) begin
        m_scoreboard_mbx.put(item);
        numberof_valid_network_transactions++; 

        network_vif.driver.driver_clock_block.flit               <= item.flit;
        network_vif.driver.driver_clock_block.flit_type          <= item.flit_type;      
        network_vif.driver.driver_clock_block.broadcast          <= item.broadcast;
        network_vif.driver.driver_clock_block.virtual_identifier <= item.virtual_identifier;

        $display("[T=%0t] [Driver] Transaction %0d for network_if driven --> network_if.ready=%b && flit_valid=%b", 
                 $time, numberof_processed_transactions+1, 
                 network_vif.driver.driver_clock_block.ready, item.valid);              
      end else if (item.valid == 1) begin
        $display("[T=%0t] [Driver] Transaction %0d for network_if rescheduled --> network_if.ready=%b && flit_valid=%b", 
                $time, numberof_processed_transactions+1, network_vif.driver.driver_clock_block.ready, item.valid);   
        
        wait(network_vif.driver.driver_clock_block.ready == {NumberOfVirtualNetworks{1'b1}});
        //@(posedge network_vif.clk);
        network_vif.driver.driver_clock_block.valid <= 1;
        network_vif.driver.driver_clock_block.flit               <= item.flit;
        network_vif.driver.driver_clock_block.flit_type          <= item.flit_type;      
        network_vif.driver.driver_clock_block.broadcast          <= item.broadcast;
        network_vif.driver.driver_clock_block.virtual_identifier <= item.virtual_identifier;     
        
        m_scoreboard_mbx.put(item);
        numberof_valid_network_transactions++;        
        
        $display("[T=%0t] [Driver] Transaction %0d for network_if driven --> network_if.ready=%b && flit_valid=%b", 
                 $time, numberof_processed_transactions+1, 
                 network_vif.driver.driver_clock_block.ready, item.valid);                      
      end             
      
      numberof_processed_transactions++;
    end  // forever
  endtask
endclass

