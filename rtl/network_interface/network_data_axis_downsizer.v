// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_data_axis_downsizer.v  
// @author Jose Manuel Rocher Gonzalez (jorocgon@disca.upv.es)
// @date January 29th, 2024
// @title Network data converter to AXIS one byte width. 
//
// @description
//  This module receives a NoC packet and creates AXI Stream signals with 1 byte TDATA width.
//  HEADER contains the TID and TDEST AXI Stream signals.
//  HEADER and HEADER_TAIL NoC packets can contain the TLAST AXI Stream signal
//  and a padding field. Paddieng field is used when KeepEnable is set to 0,
//  otherwise the same packet fields are used to recreate TKEEP signals using tkeep
//  = 0 for padding bytes if necessary.
//  

`timescale 1 ns / 1 ps

module network_data_axis_downsizer #
(
  // Width of AXI stream TDATA signal in bits
  parameter integer AxisDataWidth = 8,

  // Width of NoC DATA signal in bits
  parameter integer NocDataWidth = 64,
 
  parameter integer flitTypeSize = 2,

  // Propagate tkeep signal
  parameter KeepEnable = 0,
  
  // Tid width
  parameter integer TIdWidth  = 8,
  
  // Tdest width
  parameter integer TDestWidth = 11 
)
(
  input                      m_axis_aclk,
  input                      m_axis_arstn,

  input                      clk_noc,
  input                      rst_noc,

  // Input interface
  input      [flitTypeSize-1:0]    network_flit_type_i,
  input      [NocDataWidth-1:0]    network_flit_i,
  input                            network_valid_i,
  output                           network_ready_o,

  // Output interface
  output     [AxisDataWidth-1:0]   m_axis_tdata,
  output                           m_axis_tvalid,
  input                            m_axis_tready,
  output                           m_axis_tlast,
  output                           m_axis_tkeep,
  output     [TIdWidth-1:0]        m_axis_tid,
  output     [TDestWidth-1:0]      m_axis_tdest
);

  //----------------------------------------------------------------------------------------------
  // Local parameters definition

  // Flit Types
  localparam HEADER          = 2'b00;
  localparam HEADER_TAIL     = 2'b11;
  localparam BODY            = 2'b01;
  localparam TAIL            = 2'b10;
  
  // Addresses of fields within the flit
  localparam padd_addr_header = 32;
  localparam padd_size_header = 4;
  localparam padd_addr_tail   = 56;
  localparam padd_size_tail   = 7;
  localparam last_addr_header = 36;
  localparam last_addr_tail   = 63;
  localparam tid_addr         = 37;
  localparam tid_size         = 5;
  localparam tdest_addr       = 53;
  localparam tdest_size       = 11;

  // fifo_type_1_async_axis_wrapper parameters
  localparam AddressWidth         = 3;
  localparam FirstWordFallThrough = "true";
  localparam SynchStages          = 2;
  localparam FifoDepth            = 2**AddressWidth;
  localparam MTDataWidth          = NocDataWidth + flitTypeSize;

  //----------------------------------------------------------------------------------------------
  // Wires and Regs definition  

  // Registers to save inputs
  reg [NocDataWidth-1:0]      flit;
  reg [flitTypeSize-1:0]      flit_type;
  reg [TIdWidth-1:0]          tid;
  reg [TDestWidth-1:0]        tdest;
  reg                         tkeep;
  reg [AxisDataWidth-1:0]     payload;

  // Control registers
  reg                         last_byte;
  reg                         empty_buffer; 
  reg [2:0]                   byte_counter;
  reg [2:0]                   padd_byte_index;
  
  // Wires
  wire                        last_no_tkeep;
  wire                        tlast_output;
  wire [MTDataWidth -1:0]     network_data;
  wire [MTDataWidth -1:0]     fsm_data;
  wire                        fsm_ready;
  wire                        fsm_valid;
  wire                        wrapper_ready;
  wire [NocDataWidth-1:0]     fsm_flit;
  wire [flitTypeSize-1:0]     fsm_flit_type;

  wire			                  wait_tlast;
  wire                        empty_tail_tlast;

  //----------------------------------------------------------------------------------------------
  // Assigns
  
  // m_axis signals
  assign m_axis_tkeep = tkeep;
  assign m_axis_tid = tid;
  assign m_axis_tdest = tdest;
  assign m_axis_tdata = payload;
  assign m_axis_tlast = tlast_output;
  assign m_axis_tvalid = !empty_buffer;


  // Control signals
  assign last_no_tkeep = ((flit_type == HEADER_TAIL) | (flit_type == TAIL) | (empty_tail_tlast)) 
                          & (last_byte); 
  assign tlast_output = last_no_tkeep;
  assign network_ready_o = wrapper_ready;
  assign fsm_ready = empty_buffer | (last_byte & m_axis_tready);

  // Wrapper input
  assign network_data = {network_flit_type_i, network_flit_i};

  // Wrapper output to fsm
  assign fsm_flit = fsm_data[NocDataWidth-1:0];
  assign fsm_flit_type = fsm_data[NocDataWidth+:flitTypeSize];

  // Tlast output forced when !KeepEnable and empty tail ( tail & flit == hff00_0000_0000_0000)
  assign wait_tlast = (byte_counter == 3'b111) & (flit_type == BODY) & !fsm_valid & !KeepEnable;
  assign empty_tail_tlast = (fsm_valid & fsm_flit_type == TAIL) & (fsm_flit == 64'hff00_0000_0000_0000);

  //----------------------------------------------------------------------------------------------
  // modules instantiation

  fifo_type_1_async_axis_wrapper #(
    .TDataWidth (MTDataWidth),
    .TidWidth (TIdWidth),
    .TdestWidth (TDestWidth),
    .SynchStages (SynchStages),
    .FifoDepth (FifoDepth),
    .FirstWordFallThrough (FirstWordFallThrough)
    ) fifo_type_1_async_axis_wrapper_i(
    //subordinate axi interface
    .s_axis_aclk     (clk_noc),         // Input: clock signal
    .s_axis_arstn    (!rst_noc),        // Input: reset signal, active low
    .s_axis_tid      (),                // Input: Data Stream Idenfitifier 
    .s_axis_tdest    (),                // Input: routing information for the data stream. Destination.
    .s_axis_tdata    (network_data),    // Input: primary payload. Data to cross the interface
    .s_axis_tvalid   (network_valid_i), // Input: indicates that the transmitter is driving a valid transfer
    .s_axis_tlast    (),                // Input: indicates the boundary of a packet
    .s_axis_tready   (wrapper_ready),   // Output: indicates that this module can accept data
    //manager axi interface
    .m_axis_aclk     (m_axis_aclk),     // Input: clock signal
    .m_axis_arstn    (m_axis_arstn),    // Input: reset signal, active low
    .m_axis_tid      (),                // Output: Data Stream Idenfitifier 
    .m_axis_tdest    (),                // Output: routing information for the data stream. Destination.
    .m_axis_tdata    (fsm_data),        // Output: primary payload. Data to cross the interface
    .m_axis_tvalid   (fsm_valid),       // Output: indicates that the transmitter is driving a valid transfer
    .m_axis_tlast    (),                // Output indicates the boundary of a packet
    .m_axis_tready   (fsm_ready)        // Input: indicates that the module can accept data
    );

  //----------------------------------------------------------------------------------------------
  // Store input data

  always @(posedge m_axis_aclk) begin

    if (!m_axis_arstn) begin
      flit <= {NocDataWidth{1'b0}};
      flit_type <= {flitTypeSize{1'b0}};
      tid <= {TIdWidth{1'b0}};
      tdest <= {TDestWidth{1'b0}};
      padd_byte_index <= 1'b0;
      empty_buffer <= 1'b1;
      

    end else if (fsm_valid & fsm_ready & !empty_tail_tlast) begin
      empty_buffer <= 1'b0;
      flit <= fsm_flit;
      flit_type <= fsm_flit_type;
      if (fsm_flit_type == HEADER) begin
        tid <= fsm_flit[tid_addr+:tid_size];
        tdest <= fsm_flit[tdest_addr+:tdest_size];
      end else if (fsm_flit_type == HEADER_TAIL) begin
        tid <= fsm_flit[tid_addr+:tid_size];
        tdest <= fsm_flit[tdest_addr+:tdest_size];
        // Determine the index of the last valid byte
        casez (fsm_flit[padd_addr_header+:padd_size_header])
          4'b???1: padd_byte_index <= 0; // Empty header
          4'b??10: padd_byte_index <= 1;
          4'b?100: padd_byte_index <= 2;
          4'b1000: padd_byte_index <= 3;                   
          default: padd_byte_index <= 4; // No padding
        endcase
      end else if (fsm_flit_type == TAIL) begin
        // Determine the index of the last valid byte
        casez (fsm_flit[padd_addr_tail+:padd_size_tail])
          7'b??????1: padd_byte_index <= 0; // Empty tail
          7'b?????10: padd_byte_index <= 1;
          7'b????100: padd_byte_index <= 2;
          7'b???1000: padd_byte_index <= 3;
          7'b??10000: padd_byte_index <= 4;
          7'b?100000: padd_byte_index <= 5;
          7'b1000000: padd_byte_index <= 6;
          default:    padd_byte_index <= 7; // No padding
        endcase
      end
    end else if(last_byte & m_axis_tready) begin
      empty_buffer <= 1'b1;
    end 
  end
 

  //----------------------------------------------------------------------------------------------
  // Output signals

  always @(posedge m_axis_aclk) begin
    if (!m_axis_arstn) begin
      byte_counter <= 3'b000;
      payload <= {AxisDataWidth{1'b0}};
      last_byte <= 1'b0;
      tkeep <= 1'b0;
      

    end else if (fsm_valid & fsm_ready & !empty_tail_tlast) begin      
      payload <= fsm_flit[0+:8];
      
      if (((fsm_flit_type == HEADER_TAIL) & fsm_flit[padd_addr_header]) |
         ((fsm_flit_type == TAIL) & fsm_flit[padd_addr_tail])) begin
        byte_counter <= 3'b000;
        last_byte <= 1'b1;
        tkeep <= 1'b0;
      end else begin
        byte_counter <= byte_counter + 1; 
        last_byte <= 1'b0;
        tkeep <= 1'b1;
      end

    end else if (!empty_buffer & m_axis_tready & !wait_tlast) begin
      payload <= flit[8*byte_counter +: 8];
      
      if (((flit_type == TAIL) | (flit_type == HEADER_TAIL)) & 
          ((padd_byte_index == byte_counter) | (padd_byte_index == (byte_counter+1)))) begin 
        byte_counter <= 3'b000;
        last_byte <= 1'b1;

        if (padd_byte_index == byte_counter) tkeep <= 1'b0;
        else if (padd_byte_index == byte_counter+1) tkeep <= 1'b1;
                
      end else if (((flit_type == BODY) & (byte_counter == 7)) | 
                   ((flit_type == HEADER) & (byte_counter == 3))) begin                   
        byte_counter <= 3'b000;
        last_byte <= 1'b1;

      end else begin
        if(last_byte == 1'b0) byte_counter <= byte_counter + 1;
        last_byte <= 1'b0;
      end
    end
  end

endmodule
