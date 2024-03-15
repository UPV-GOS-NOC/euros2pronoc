// SPDX-License-Identifier: MIT
//
// @copyright (c) 2024 Universitat Politecnica de Valencia (UPV)
// All right reserved
//
// @file axis_converter_signals.v 
// @author Jose Manuel ROcher Gonzalez (jorocgon@disca.upv.es)
// @date April 18th, 2024
// @title AXI STREAM converter signals
//
// @description  
//  This module forwards AXIS signals when X_Enable parameters are set to 1.
//  If X_Enable parameters are set to 0 the module generates default AXIS values for these signals.
//  The USER configures X_Enable parameters.


module axis_converter_signals #
  (
  // Width of AXI stream int unsignederfaces in bits
  parameter integer DataWidth = 32,
  
  // Propagate tkeep signal
  parameter KeepEnable = 1,
  localparam integer KeepWidth  = DataWidth/8,
  
  // Propagate tstrb signal
  parameter StrbEnable = 1,
  localparam integer StrbWidth  = DataWidth/8,
  
  // Propagate tid signal
  parameter IdEnable = 1,
  parameter integer TidWidth  = 8,
  
  // Propagate tdest signal
  parameter DestEnable = 1,
  parameter integer DestWidth = 8,
  
  // Propagate tuser signal
  parameter UserEnable       = 1,
  parameter UserWidthPerByte = 1,
  localparam integer UserWidth = UserWidthPerByte * (DataWidth/8),
  
  // Propagate tlast signal
  parameter integer LastEnable = 1,
  
  // Propagate twakeup signal
  parameter integer WakeupEnable = 1,
  
  // Propagate tready signal
  parameter integer ReadyEnable = 1
)
(
  // AXIS input
  input   [DataWidth-1:0]  s_axis_tdata,
  input   [KeepWidth-1:0]  s_axis_tkeep,
  input   [StrbWidth-1:0]  s_axis_tstrb,
  input                    s_axis_tvalid,
  output                   s_axis_tready,
  input                    s_axis_tlast,
  input   [TidWidth-1:0]   s_axis_tid,
  input   [DestWidth-1:0]  s_axis_tdest,
  input   [UserWidth-1:0]  s_axis_tuser,
  input                    s_axis_twakeup,
  
  // AXIS output
  output  [DataWidth-1:0]  m_axis_tdata,
  output  [KeepWidth-1:0]  m_axis_tkeep,
  output  [StrbWidth-1:0]  m_axis_tstrb,
  output                   m_axis_tvalid,
  input                    m_axis_tready,
  output                   m_axis_tlast,
  output  [TidWidth-1:0]   m_axis_tid,
  output  [DestWidth-1:0]  m_axis_tdest,
  output  [UserWidth-1:0]  m_axis_tuser,
  output                   m_axis_twakeup
);

  assign m_axis_tkeep   = KeepEnable   ? s_axis_tkeep   : {KeepWidth{1'b1}};
  assign m_axis_tstrb   = StrbEnable   ? s_axis_tstrb   : {StrbWidth{1'b0}};
  assign m_axis_tvalid  = s_axis_tvalid;
  assign m_axis_tlast   = LastEnable   ? s_axis_tlast   : 1'b1;
  assign m_axis_tid     = IdEnable     ? s_axis_tid     : {TidWidth{1'b0}};
  assign m_axis_tdest   = DestEnable   ? s_axis_tdest   : {DestWidth{1'b0}};
  assign m_axis_tuser   = UserEnable   ? s_axis_tuser   : {UserWidth{1'b0}};
  assign m_axis_tdata   = s_axis_tdata;
  assign s_axis_tready   = ReadyEnable  ? m_axis_tready  : 1'b1;
  assign m_axis_twakeup  = WakeupEnable ? s_axis_twakeup : 1'b0;

endmodule
