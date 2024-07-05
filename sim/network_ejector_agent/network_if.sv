// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_if.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Jan 17th, 2024
//
// @title Network interface
//
// Network interface is composed of the follwing signals:
// - Ready/Valid NoC handshaking
// - Flit data signal
// - Flit type data signal
// - Broadcast data signal
// - Virtual Network/Channel identifier
interface network_if #(
  int FlitWidth                         = 0,
  int FlitTypeWidth                     = 0,
  int BroadcastWidth                    = 0,
  int VirtualNetworkOrChannelIdWidth    = 0,
  int NumberOfVirtualNetworksOrChannels = 0
) (
  input bit clk,
  input bit rst
);

  logic [NumberOfVirtualNetworksOrChannels-1:0] ready;
  logic                                         valid;
  logic [FlitWidth-1:0]                         flit;
  logic [FlitTypeWidth-1:0]                     flit_type;
  logic [BroadcastWidth-1:0]                    broadcast;
  logic [VirtualNetworkOrChannelIdWidth-1:0]    virtual_identifier;

  // Legacy code used for Network Ejector Testbench
  clocking driver_clock_block @(posedge clk);
    //default input #1ns output #2ns;
    output valid;
    output flit;
    output flit_type;
    output broadcast;
    output virtual_identifier;
    input  ready;
  endclocking

  clocking manager_clock_block @(posedge clk);
    //default input #1ns output #2ns;
    output valid;
    output flit;
    output flit_type;
    output broadcast;
    output virtual_identifier;
    input  ready;
  endclocking

  clocking subordinate_clock_block @(posedge clk);
    //default input #1ns output #2ns;
    output ready;
    input  valid;
    input  flit_type;
    input  broadcast;
    input  virtual_identifier;
  endclocking

  clocking monitor_clock_block @(posedge clk);
    //default input #1ns output #2ns;
    input valid;
    input flit;
    input flit_type;
    input broadcast;
    input virtual_identifier;
    input ready;
  endclocking

  modport driver(clocking driver_clock_block,
                 input clk, rst);

  modport manager_driver(clocking manager_clock_block,
                         input clk, rst);

  modport subordinate_driver(clocking subordinate_clock_block,
                             input clk, rst);

  modport monitor(clocking monitor_clock_block,
                  input clk, rst);

endinterface

