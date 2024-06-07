// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file fifo_type_1_async_axis_wrapper.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date March 13th, 2024
//
// @title AXI4-Stream Wrapper for fifo_type_1_async module
// 
//  This module implements a wrapper to generate a VERY BASIC axi stream compliant fifo from the fifo_type_1_async fifo in this project.
//

`timescale 1 ns / 1 ps

//`define DEBUG_DISPLAY_FIFO_TYPE_1_ASYNC_AXIS_WRAPPER_ENABLE 1


module fifo_type_1_async_axis_wrapper #(
  parameter TDataWidth  = 32,     // Width of  (input)  slave data port in bits
  parameter TidWidth    =  8,
  parameter TdestWidth  =  8,
  parameter SynchStages = 2, // Number of stages for the cross clock domain data syncrhonizer
  parameter FifoDepth   = 16,    // Number of slots in the fifo
  parameter FirstWordFallThrough = "yes" // FWFT capability of the FIFO
  ) (
  // slave interface (data input from transfer source)
  input                   s_axis_aclk,    // Input: clock signal of slave domain
  input                   s_axis_arstn,   // Input: reset signal of slave main
  input [TidWidth-1:0]    s_axis_tid,     // Input: Data Stream Idenfitifier 
  input [TdestWidth-1:0]  s_axis_tdest,   // Input: routing information for the data stream. Destination.
  input [TDataWidth-1:0]  s_axis_tdata,   // Input: primary payload. Data to cross the interface
  input                   s_axis_tvalid,  // Input: indicates that the transmitter is driving a valid transfer
  input                   s_axis_tlast,   // Input: indicates the boundary of a packet
  output                  s_axis_tready,  // Output: indicates that the module can accept data

  // master interface (data output to transfer destination)
  input                   m_axis_aclk,    // Input: clock signal of slave domain
  input                   m_axis_arstn,   // Input: reset signal of slave main
  output [TidWidth-1:0]   m_axis_tid,     // Output: Data Stream Idenfitifier 
  output [TdestWidth-1:0] m_axis_tdest,   // Output: routing information for the data stream. Destination.
  output [TDataWidth-1:0] m_axis_tdata,   // Output: primary payload. Data to cross the interface
  output                  m_axis_tvalid,  // Output: indicates that the transmitter is driving a valid transfer
  output                  m_axis_tlast,   // Output: indicates the boundary of a packet
  input                   m_axis_tready   // Output: indicates that the module can accept data
);

  // --------------------------------------------------------------------------
  // Functions Definition
  function integer num_bits;
    input integer value;
    begin
      num_bits = 0;
      for (num_bits = 0; value > 0; num_bits = num_bits+1) begin
        value = value >> 1;
      end
    end
  endfunction

  // --------------------------------------------------------------------------
  // Parameters definition
  localparam AddressWidth = num_bits(FifoDepth-1);
  
  // wr_data = {tid, tdest, tlast, tdata}
  localparam FifoDataWidth = TdestWidth + TidWidth + 1 + TDataWidth; // each fifo entry must store all data and control information of the incoming axi transfer
  localparam WrDataTDataLSB = 0;
  localparam WrDataTDataMSB = WrDataTDataLSB + TDataWidth - 1;
  localparam WrDataTlastB   = WrDataTDataMSB + 1;
  localparam WrDataTdestLSB = WrDataTlastB + 1;
  localparam WrDataTdestMSB = WrDataTdestLSB + TdestWidth-1;
  localparam WrDataTidLSB   = WrDataTdestMSB +1;
  localparam WrDataTidMSB   = WrDataTidLSB + TidWidth-1;

  // fifo wires
  wire   wfull;  // flag: fifo write side is full. 
  wire   rempty; // flag: fifo read side is empty

  // wires connecting AXI streams source with AXI to NATIVE adapter
  wire [TidWidth-1:0]   a2n_tid;
  wire [TdestWidth-1:0] a2n_tdest;
  wire [TDataWidth-1:0] a2n_tdata;
  wire                  a2n_tvalid;
  wire                  a2n_tlast;
  wire                  a2n_tready;

  assign a2n_tready = !wfull;
  
  // wires connecting Native flow control FIFO to AXI adapter
  wire [TidWidth-1:0]   n2a_tid;     // Input: Data Stream Idenfitifier 
  wire [TdestWidth-1:0] n2a_tdest;   // Input: routing information for the data stream. Destination.
  wire [TDataWidth-1:0] n2a_tdata;   // Input: primary payload. Data to cross the interface
  wire                  n2a_tvalid;  // Input: indicates that the transmitter is driving a valid transfer
  wire                  n2a_tlast;   // Input: indicates the boundary of a packet
  wire                  n2a_tready;  // Output:  indicates that the module can accept data

  assign n2a_tvalid = !rempty;

  // --------------------------------------------------------------------------
  // modules instantiation  

axis_2_native_fifo #(
    .STDataWidth (TDataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth)
  )
  a2nf_i(
    // slave axi interface
    .aclk            (s_axis_aclk),    // Input: clock signal
    .arstn           (s_axis_arstn),   // Input: reset signal, active low
     //
    .s_axis_tid      (s_axis_tid),     // Input: Data Stream Idenfitifier 
    .s_axis_tdest    (s_axis_tdest),   // Input: routing information for the data stream. Destination.
    .s_axis_tdata    (s_axis_tdata),   // Input: primary payload. Data to cross the interface
    .s_axis_tvalid   (s_axis_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
    .s_axis_tlast    (s_axis_tlast),   // Input: indicates the boundary of a packet
    .s_axis_tready   (s_axis_tready),  // Output: indicates that this module can accept data
    // native interface
    .m_native_tid    (a2n_tid),      
    .m_native_tdest  (a2n_tdest),   // Output: routing information for the data stream. Destination.
    .m_native_tdata  (a2n_tdata),   // Output: primary payload. Data to cross the interface
    .m_native_tvalid (a2n_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_native_tlast  (a2n_tlast),   // Output: indicates the boundary of a packet
    .m_native_tready (a2n_tready)
  );
  
  wire a2n_rst = ~s_axis_arstn;
  wire n2a_rst = ~m_axis_arstn;
  
  wire [(TdestWidth+TidWidth+1+TDataWidth)-1:0] wr_data ;
  wire [(TdestWidth+TidWidth+1+TDataWidth)-1:0] rd_data;

  assign wr_data [WrDataTidMSB:WrDataTidLSB]     = a2n_tid [TidWidth-1:0];
  assign wr_data [WrDataTdestMSB:WrDataTdestLSB] = a2n_tdest[TdestWidth-1:0];
  assign wr_data [WrDataTlastB]                  = a2n_tlast;
  assign wr_data [WrDataTDataMSB:WrDataTDataLSB] = a2n_tdata[TDataWidth-1:0];
  
  assign n2a_tid   = rd_data[WrDataTidMSB:WrDataTidLSB];
  assign n2a_tdest = rd_data[WrDataTdestMSB:WrDataTdestLSB] ;
  assign n2a_tlast = rd_data[WrDataTlastB];
  assign n2a_tdata = rd_data[WrDataTDataMSB:WrDataTDataLSB];

  fifo_type_1_async #(
    .DataWidth (FifoDataWidth),
    .AddressWidth (AddressWidth),
    .SynchStages (SynchStages),
    .FirstWordFallThrough (FirstWordFallThrough)
  ) fifo_type_1_async_i (
    .wr_clk   (s_axis_aclk),
    .wr_rst   (a2n_rst),
    .wr_req   (a2n_tvalid),
    .wr_data  (wr_data),
    .wr_full  (wfull),
    //.wr_almost_full (awfull),
    .rd_clk   (m_axis_aclk),
    .rd_rst   (n2a_rst),
    .rd_req   (n2a_tready),
    .rd_data  (rd_data),
    .rd_empty (rempty)
    //.rd_almost_empty (arempty)
  );
    
  native_fifo_2_axi #(
    .STDataWidth (TDataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth)
  ) nf2a_i(
    // slave axi interface
    .aclk            (m_axis_aclk),            // Input: clock signal
    .arstn           (m_axis_arstn),   // Input: reset signal, active low
     // Data input from native flow control FIFO
    .s_native_tid    (n2a_tid),     // Input: Data Stream Idenfitifier 
    .s_native_tdest  (n2a_tdest),   // Input: routing information for the data stream. Destination.
    .s_native_tdata  (n2a_tdata),   // Input: primary payload. Data to cross the interface
    .s_native_tvalid (n2a_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
    .s_native_tlast  (n2a_tlast),   // Input: indicates the boundary of a packet
    .s_native_tready (n2a_tready),  // Output:  indicates that the module can accept data
    // next module with (reduced subset) AXI interface  
    .m_axis_tid      (m_axis_tid),     // Output: Data Stream Idenfitifier 
    .m_axis_tdest    (m_axis_tdest),   // Output: routing information for the data stream. Destination.
    .m_axis_tdata    (m_axis_tdata),   // Output: primary payload. Data to cross the interface
    .m_axis_tvalid   (m_axis_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_axis_tlast    (m_axis_tlast),   // Output indicates the boundary of a packet
    .m_axis_tready   (m_axis_tready)   // Input: indicates that the module can accept data
  );
  
  endmodule;
