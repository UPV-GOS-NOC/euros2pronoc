// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file filereg_if.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 23th, 2024
//
// @title FileReg interface
//
// FileReg interface is composed of the follwing signals:
// - Valid/Ready handshake signals
// - data signal
// - last signal

interface filereg_if #(
  int DataSize = 0
) (
  input bit clk,
  // input bit clk_m,
  // input bit clk_s,
  // input bit rst_m,
  // input bit rst_s
  input bit rst
);

  logic valid;
  logic ready;

  logic [DataSize-1:0] data;
  logic                last;

  clocking manager_clock_block @(posedge clk);
    //default input #1ns output #2ns;
    output valid;
    output data;
    output last;
    input  ready;
  endclocking

  clocking subordinate_clock_block @(posedge clk);
    //default input #1ns output #2ns;
    output ready;
    input  valid;
    input  data;
    input  last;
  endclocking

  clocking monitor_clock_block @(posedge clk);
    //default input #1ns output #2ns;
    input valid;
    input ready;
    input data;
    input last;
  endclocking

  modport manager(clocking manager_clock_block,
                  input clk, rst);

  modport subordinate(clocking subordinate_clock_block,
                      input clk, rst);

  modport monitor(clocking monitor_clock_block,
                  input clk, rst);

  modport manager_dut(input clk, rst, ready,
                      output valid, data, last);
                      
  modport subordinate_dut(input clk, rst, valid, data, last,
                          output ready);
endinterface

