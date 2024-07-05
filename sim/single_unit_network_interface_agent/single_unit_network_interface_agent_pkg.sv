// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file single_unit_network_interface_agent_pkg.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 04th, 2024

package single_unit_network_interface_agent_pkg;
 
 import axi4stream_vip_pkg::*;
 import axi4stream_vip_m_pkg::*;
 import axi4stream_vip_s_pkg::*; 

  parameter integer FLIT_WIDTH                = 64;
  parameter integer FLIT_TYPE_WIDTH           = 2;
  parameter integer BROADCAST_WIDTH           = 1;
  parameter integer VIRTUAL_CHANNEL_ID_WIDTH  = 2;
  parameter integer NUMBEROF_VIRTUAL_CHANNELS = 4;
  parameter integer NUMBEROF_VIRTUAL_NETWORKS = 4;
  parameter integer VIRTUAL_NETWORK_ID_WIDTH  = 2;
  
  // TODO set the right values for the parameters
  parameter integer FLIT_TYPE_HEADER      = 2'd0;
  parameter integer FLIT_TYPE_BODY        = 2'd1;
  parameter integer FLIT_TYPE_TAIL        = 2'd2;
  parameter integer FLIT_TYPE_HEADER_TAIL = 2'd3;

  class network_packet;
  
    bit [FLIT_WIDTH-1:0]               flit [$];
    bit [FLIT_TYPE_WIDTH-1:0]          flit_type [$];
    bit [BROADCAST_WIDTH-1:0]          broadcast;
    bit [VIRTUAL_NETWORK_ID_WIDTH-1:0] virtual_identifier;    
  
  endclass
  
  typedef network_packet network_packet_t;

  class network_flit_item #(
    int FlitWidth                         = 0,
    int FlitTypeWidth                     = 0,
    int BroadcastWidth                    = 0,
    int VirtualNetworkOrChannelIdWidth    = 0,
    int NumberOfVirtualNetworksOrChannels = 0  
  );
     
    rand bit [NumberOfVirtualNetworksOrChannels-1:0] ready;
    rand bit                                         valid;
    bit [FlitWidth-1:0]                         flit;
    bit [FlitTypeWidth-1:0]                     flit_type;
    bit [BroadcastWidth-1:0]                    broadcast;
    bit [VirtualNetworkOrChannelIdWidth-1:0]    virtual_identifier;
      
    function void display(string str = "");
      $display("[T=%0t] %s network_if --> (%x) flit=%x; flit_type=%x, broadcast=%b, virtual_identifier=%x, valid=%b, ready=%b",
               $time, str,
               {this.virtual_identifier, this.broadcast, this.flit_type, this.flit},
               flit, flit_type, broadcast, virtual_identifier, this.valid, this.ready);
    endfunction
      
    // TODO now it is limited to 64-bit flits
    function network_packet_t generate_network_packet();
      int num_body_flits = $urandom_range(25);     
      network_packet_t p = new();
        
      p.broadcast = 0;
      p.virtual_identifier = $urandom_range(NumberOfVirtualNetworksOrChannels-1);
                  
      if ($urandom_range(99) < 70) begin
        // generate multi flit packet      
        
        // header flit
        p.flit_type.push_back(0);
        flit = { $urandom, $urandom };
        flit[36] = 0;
        flit[35:32] = 0;
        flit[41:37] = p.virtual_identifier;
        p.flit.push_back(flit);
          
        // body flits
        for(int i = 0; i < num_body_flits; i++) begin
          p.flit_type.push_back(1);
          flit = { $urandom, $urandom };
          p.flit.push_back(flit);           
        end
           
        // tail flit
        if ($urandom_range(99) < 65) begin 
          p.flit_type.push_back(2);
          flit = { $urandom, $urandom };
          flit[63] = 1;
          flit[62:56] = 7'b1110000;
          p.flit.push_back(flit);
        end else begin
          // tail flit to mark only tlast
          p.flit_type.push_back(2);
          flit = 64'hFF00_0000_0000_0000;
          p.flit.push_back(flit);
        end       
      end else begin
        // generate single flit packet
        p.flit_type.push_back(3);
        flit = { $urandom, $urandom };
        flit[36] = 1;
        flit[35:32] = 0;
        flit[41:37] = p.virtual_identifier;
        p.flit.push_back(flit);
      end
       
      return p;
    endfunction
  
  endclass
    
  typedef network_flit_item #(
    .FlitWidth                        (FLIT_WIDTH),
    .FlitTypeWidth                    (FLIT_TYPE_WIDTH),
    .BroadcastWidth                   (BROADCAST_WIDTH),
    .VirtualNetworkOrChannelIdWidth   (VIRTUAL_CHANNEL_ID_WIDTH),
    .NumberOfVirtualNetworksOrChannels(NUMBEROF_VIRTUAL_CHANNELS)     
  ) network_flit_item_t;
  
  typedef network_flit_item #(
    .FlitWidth                        (FLIT_WIDTH),
    .FlitTypeWidth                    (FLIT_TYPE_WIDTH),
    .BroadcastWidth                   (BROADCAST_WIDTH),
    .VirtualNetworkOrChannelIdWidth   (VIRTUAL_NETWORK_ID_WIDTH),
    .NumberOfVirtualNetworksOrChannels(NUMBEROF_VIRTUAL_NETWORKS)     
  ) network_flit_ejection_item_t;  

  // Network Virtual interface
  typedef virtual network_if #(
    .FlitWidth                        (FLIT_WIDTH),
    .FlitTypeWidth                    (FLIT_TYPE_WIDTH),
    .BroadcastWidth                   (BROADCAST_WIDTH),
    .VirtualNetworkOrChannelIdWidth   (VIRTUAL_CHANNEL_ID_WIDTH),
    .NumberOfVirtualNetworksOrChannels(NUMBEROF_VIRTUAL_CHANNELS)
  ) network_vif_t;


  `include "single_unit_network_interface_generator.sv"
  `include "single_unit_network_interface_driver.sv"
  `include "single_unit_network_interface_monitor.sv"
  
endpackage
