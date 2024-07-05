// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_flit_item.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network Flit transaction (data) item
//
// It represents a transaction for network interfaces of the NoC
//
class network_flit_item #(
  int FlitWidth                         = 0,
  int FlitTypeWidth                     = 0,
  int BroadcastWidth                    = 0,
  int VirtualNetworkOrChannelIdWidth    = 0,
  int NumberOfVirtualNetworksOrChannels = 0  
);
 
  rand bit [NumberOfVirtualNetworksOrChannels-1:0] ready;
  rand bit                                         valid;
  rand bit [FlitWidth-1:0]                         flit;
  rand bit [FlitTypeWidth-1:0]                     flit_type;
  rand bit [BroadcastWidth-1:0]                    broadcast;
  rand bit [VirtualNetworkOrChannelIdWidth-1:0]    virtual_identifier;
  
  function void display(string str = "");
    $display("[T=%0t] %s network_if --> (%x) flit=%x; flit_type=%x, broadcast=%b, virtual_identifier=%x, valid=%b, ready=%b",
             $time, str,
             {this.virtual_identifier, this.broadcast, this.flit_type, this.flit},
             flit, flit_type, broadcast, virtual_identifier, this.valid, this.ready);
  endfunction

  constraint virtual_id_limit_c { 
    virtual_identifier < NumberOfVirtualNetworksOrChannels; 
  }

endclass
