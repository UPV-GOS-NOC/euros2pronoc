// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file tb_axis_data_upsizer.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date April 9th, 2024
//
// @title Testbench for AXI 4 stream data generator
//
//  This module defines several tests to validate control signals behaviour
//

`timescale 1 ns / 1 ps

//`define  DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE 1

`include "svut_h.sv"
`timescale 1 ns / 1 ps

module tb_axi4_stream_data_initiator_type_1;

  `SVUT_SETUP

  // Testbench Configuration Parameters
  localparam integer ClockMasterHalfPeriod  = 25; // write domain clock half period in ticks set by timescale parameter value in this source file

  localparam integer TDataWidth    = 32;  // Width of (output) data port in bits
  localparam integer TIdWidth      =  8; // max recommended value is 8
  localparam integer TDestWidth    =  8; // max recommended value is 4, but we are using 8
  localparam [47:0]  InitiatorMode = "SINGLE"; // NoC AXI Stream Initiator interface configuration. Stream generation mode
  localparam integer InitiatorCyclesActive = 2;
  localparam integer InitiatorCyclesPause  = 4;
  localparam integer InitiatorTransfersPerPacket = 2;
  localparam integer InitiatorPacketsPerFrame    = 2;
  localparam integer InitiatorFramesPerStream    = 2;
  localparam [63:0]  InitiatorTlastFlagTrigger   = "STREAM";


  localparam [TIdWidth-1:0]   TId   = 'h11; // Initial value of TId for stream generator
  localparam [TDestWidth-1:0] TDest = 'hDE; // Initial value of TDest for stream generator


  //
  reg                    initiator_m_axis_clk;     // clock signal
  reg                    initiator_m_axis_rst_n;   // low level reset signal for module
  wire [TIdWidth-1:0]    initiator_m_axis_tid;     // Data Stream Idenfitifier 
  wire [TDestWidth-1:0]  initiator_m_axis_tdest;   // Data Stream destination
  wire [TDataWidth-1:0]  initiator_m_axis_tdata;   // Data
  wire                   initiator_m_axis_tvalid;  // Data in input port / register is valid
  wire                   initiator_m_axis_tlast;   // last Data chunk of tid, also for sync purposes
  reg                    initiator_m_axis_tready;  // data upsizer module can accept more data


     // Modules instantitation
  axi4_stream_initiator_type_1 #(
    .AxiStreamInitiatorIfTDataWidth    (TDataWidth), 
    .AxiStreamInitiatorIfTIdWidth      (TIdWidth), 
    .AxiStreamInitiatorIfTDestWidth    (TDestWidth), 
    .AxiStreamInitiatorIfTId           (TId), 
    .AxiStreamInitiatorIfTDest         (TDest), 
    .AxiStreamInitiatorIfInitiatorMode (InitiatorMode), // NoC AXI Stream Initiator interface configuration. Stream generation mode
    .AxiStreamInitiatorIfCyclesActive  (InitiatorCyclesActive),
    .AxiStreamInitiatorIfCyclesPause   (InitiatorCyclesPause),
    .AxiStreamInitiatorIfTransfersPerPacket (InitiatorTransfersPerPacket),
    .AxiStreamInitiatorIfPacketsPerFrame    (InitiatorPacketsPerFrame),
    .AxiStreamInitiatorIfFramesPerStream    (InitiatorFramesPerStream),
    .AxiStreamInitiatorIfTlastFlagTrigger   (InitiatorTlastFlagTrigger)
  ) axi4_stream_initiator_type_1_inst(
    .clk_m_axis_i     (initiator_m_axis_clk),     // Input: clock signal of slave domain
    .rst_m_axis_ni    (initiator_m_axis_rst_n),   // Input: reset signal of slave main
    .m_axis_tvalid_o  (initiator_m_axis_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_axis_tready_i  (initiator_m_axis_tready),   // Input: indicates that the next module can accept data
    .m_axis_tdata_o   (initiator_m_axis_tdata),   // Output: primary payload. Data to cross the interface
    .m_axis_tlast_o   (initiator_m_axis_tlast),   // Output: indicates the boundary of a packet  
    .m_axis_tid_o     (initiator_m_axis_tid),     // Output: Data Stream Idenfitifier 
    .m_axis_tdest_o   (initiator_m_axis_tdest)   // Output: routing information for the data stream. Destination.
  );


  // variables for loops
  integer i = 0;
  integer j = 0; 
  integer loop_aux = 0;
  integer values_wr;
  integer values_rd;
  
  
  
  initial begin
  initiator_m_axis_tready <= 1'b0;
  end
  
  //create clock
  initial initiator_m_axis_clk = 1'b0;
  always #(ClockMasterHalfPeriod) initiator_m_axis_clk <= ~initiator_m_axis_clk;

  integer initiator_timestamp = 0;
  always @(posedge initiator_m_axis_clk) begin
    initiator_timestamp <= initiator_timestamp + 64'd1;
  end

  // record generated data
  localparam ArrayDepth = InitiatorTransfersPerPacket * InitiatorPacketsPerFrame * InitiatorFramesPerStream * 2; // double capacity to check wether generator overflows in testbench
  integer record_initiator_tdata_index;
  reg  [TDataWidth-1:0] record_initiator_tdata_arr[ArrayDepth-1:0];

  always @(posedge initiator_m_axis_clk) begin
    if (initiator_m_axis_rst_n) begin
      if (initiator_m_axis_tvalid) begin
        if (initiator_m_axis_tready) begin
          `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
           $display("@tb_axi4_stream_generator  record data = 0x%08h ", initiator_m_axis_tdata);
          `endif
          record_initiator_tdata_arr[record_initiator_tdata_index] <= initiator_m_axis_tdata;
          record_initiator_tdata_index <= record_initiator_tdata_index + 1;
        end
      end
    end
  end

  task setup(string msg="Setup testcase");
  begin 
    //`ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    $display("%s. Initializing variables", msg);
    //`endif
    initiator_m_axis_rst_n       <= 1'b0;
    //initiator_low_avail_cycles   <= 0;
    //sink_low_avail_cycles  <= 0;
    record_initiator_tdata_index <= 0;
    initiator_m_axis_tready      <= 1'b0;
    
    #(4 * ClockMasterHalfPeriod);
    initiator_m_axis_rst_n <= 1'b1;
    
    #(2 * ClockMasterHalfPeriod);
    @(posedge initiator_m_axis_clk);
    
  end
  endtask

  task teardown(msg="Tearing down");
  begin
    #50;
  end
  endtask



  `TEST_SUITE("AXI_STREAM_GENERATOR")
 // 
 // `UNIT_TEST("Greetings")
 // @(posedge initiator_m_axis_clk) begin
 //   $display("Hello work");
 // end
 // `UNIT_TEST_END


//  `UNIT_TEST("Empty")
//  @(posedge initiator_m_axis_clk) begin
//    initiator_m_axis_tready <= 1'b1;
//  end
//  @(posedge initiator_m_axis_clk);
//  @(posedge initiator_m_axis_clk);
//  @(posedge initiator_m_axis_clk);
//  @(posedge initiator_m_axis_clk);
//  @(posedge initiator_m_axis_clk);
//  @(posedge initiator_m_axis_clk) begin
//    initiator_m_axis_tready <= 1'b0;
//  end
//  @(posedge initiator_m_axis_clk);
//  @(posedge initiator_m_axis_clk);
//  @(posedge initiator_m_axis_clk);
//  `UNIT_TEST_END


  `UNIT_TEST("FLAG TLAST")

  @(posedge initiator_m_axis_clk);
  initiator_m_axis_tready <= 1'b1;
  
  for(i=0; i< 64; i++) begin
     @(posedge initiator_m_axis_clk);
  end
  
  initiator_m_axis_tready <= 1'b0;
  `UNIT_TEST_END
  
  
  `TEST_SUITE_END
endmodule
