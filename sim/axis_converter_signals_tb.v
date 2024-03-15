// SPDX-License-Identifier: MIT
//
// @copyright (c) 2024 Universitat Politecnica de Valencia (UPV)
// All right reserved
//
// @file axis_converter_signals_tb.v 
// @author Jose Manuel ROcher Gonzalez (jorocgon@disca.upv.es)
// @date April 18th, 2024
// @title AXI STREAM converter signals
//
// @description  
//  Test module for the AXI STREAM converter signals. 
//  XEnable parameters are set to 0 when the inputs of these AXIS signals are not
//  connected.


`timescale 1ns / 1ps

module axis_converter_signals_tb;
    
  // Parameters
  localparam KeepEnable = 1;
  localparam DataWidth = 32;
  localparam KeepWidth = DataWidth/8;
  localparam StrbWidth = DataWidth/8;
  localparam TidWidth = 8;
  localparam DestWidth = 8;
  localparam UserWidthPerByte = 1;
  localparam UserWidth = UserWidthPerByte * (DataWidth/8);

  // Instantiate the module under test
  axis_converter_signals dut (
    .s_axis_tdata(),
    .s_axis_tkeep(),
    .s_axis_tstrb(),
    .s_axis_tvalid(),
    .s_axis_tready(),
    .s_axis_tlast(),
    .s_axis_tid(),
    .s_axis_tdest(),
    .s_axis_tuser(),
    .s_axis_twakeup(),
    
    .m_axis_tdata(),
    .m_axis_tkeep(),
    .m_axis_tstrb(),
    .m_axis_tvalid(),
    .m_axis_tready(),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),
    .m_axis_twakeup()
  );

  // Clock generation
  reg clk = 0;
  always #5 clk = ~clk;
  
  // Reset generation
  reg rst = 1;
  initial begin
      #10;
      rst = 0;
  end

  // Stimulus generation
  reg [DataWidth-1:0] data;
  reg [KeepWidth-1:0] keep;
  reg [StrbWidth-1:0] strb;
  reg valid;
  reg ready;
  reg last;
  reg [TidWidth-1:0] id;
  reg [DestWidth-1:0] dest;
  reg [UserWidth-1:0] user;
  reg  wakeup;
  integer i;
  
  always #20 begin
    valid = 1'b1;
    for (i = 0; i < 10; i = i + 1) begin
      data = i;
      keep = i % KeepWidth;
      strb = i % StrbWidth;
      last = (i == 9) ? 1 : 0;
      id = i % TidWidth;
      dest = i % DestWidth;
      user = i % UserWidth;
      wakeup = i % 2;
      ready = (i % 2)+1;
      #10;
    end
    $finish;
  end

  // Connect testbench signals to DUT
  assign dut.s_axis_tdata = data;
  assign dut.s_axis_tkeep = keep;
  assign dut.s_axis_tstrb = strb;
  assign dut.s_axis_tvalid = valid;
  assign dut.s_axis_tlast = last;
  assign dut.s_axis_tid = id;
  assign dut.s_axis_tdest = dest;
  assign dut.s_axis_tuser = user;
  assign dut.s_axis_twakeup = wakeup;
  assign dut.m_axis_tready = ready;
  
  // Monitor
  always @(posedge clk) begin
    if (dut.m_axis_tvalid) begin
      $display("Received: data=%d, keep=%d, strb=%d, id=%d, dest=%d, user=%d, wakeup=%d",
                dut.m_axis_tdata, dut.m_axis_tkeep, dut.m_axis_tstrb,
                dut.m_axis_tid, dut.m_axis_tdest, dut.m_axis_tuser, dut.m_axis_twakeup);
    end
  end
  
endmodule
