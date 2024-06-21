// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file axis_traffic_gen.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date April 12th, 2024
//
// @title AXI 4 stream target TYPE 1
//
// Very SIMPLE data sink for AXI 4 Stream transfers.
// 
// This module just consumes data coming from the previous module. This module drains as much data as configured in input parameters.
// Paramenters of this module must be configured with the same values as the axi4_stream_target_type_1, so this module will drain the same amount of bytes from the system.
//  
//  This module drains AXI 4 stream compatible traffic streams. This module implements the following AXI4 mandatory fields:
//   - tdata
//   - tlast
//   - tid
//   - tdest
//
//  Each stream consists of several frames. Each frame consists of several packets.
//  Each packet consists of several transfers.
//  Number of frames, packets,transfers and size of the transfers are configurable via parameters.
//  
//  This moudle can be configured to drain data each clock cycle, or to drain the data in intervals,
//  this is draining valid data for a specified number of cycles(TA) and then pausing the reception for a set number of cycles (TB) to then resume data read 
// 
//  This module is intended for testbenching purposes only.
//
//  From the document: AMBA AXI Stream Protocol Specification 
//  ARM IHI 0051B (ID040921)
//  The following stream terms are used:
//  - Transfer
//    A single transfer of data across an AXI-Stream interface. A single transfer is defined by a single
//    TVALID and TREADY signal handshake
//  - Packet
//    A group of bytes that are transported together across an AXI-Stream interface. A packet can consist
//    of a single transfer or multiple transfers. Interconnect components can use packets to deal more
//    efficiently with a stream in packet-sized groups. A packet is similar to an AXI burst.
//  - Frame
//     A frame contains an integer number of packets. A frame can have a very large number of bytes, for
//    example an entire video frame buffer. A frame is the highest level of byte grouping in an
//    AXI-Stream interface.
//  - Data stream
//    The transport of data from one source to one destination.
//    A data stream can be:
//      - A series of individual byte transfers.
//      - A series of byte transfers grouped together in packets.
//
//  tlast port value is check depending on  Trigger condition passed as parameter. tlast flag will be check as follows:
//    - NONE:     tlast port will never be set to one
//    - TRANSFER: tlast port will be set to one every transfer
//    - PACKET:   tlast port will be set to one the last transfer of each packet
//    - FRAME:    tlast port will be set to one the last transfer of each frame
//    - STREAM:   tlast port will be set to one the last transfer of the stream
//    
//  The total amount of bits in a data stream drained by the module will be the result of:
//    <number_of_frames_per_stream> * <number_of_packets_per_frame> * <number_of_transfers_per_packet> * <number_of_bits_per_transfer>
//
// Currently TDest field is fixed and passed as parameter.
// TO-DO: add new modes for Tid and Dest: RANDOM, FIXED, ...
//
// Current target modes are
//  - SINGLE:  the target module drains a single DATA stream as configured in parameters (frames*packets*transfers*bytes) and stops
//  - LOOP:    the target module loops draining the same stream in an infinite loop. Stream properties are configured in parameters.
//

`timescale 1ns/1ns

`define TDATA_INITIAL_VALUE 8'hA0
`define TDATA_INCR 8'h01

//`define  DEBUG_DISPLAY_STREAM_TARGET_TYPE_1_ENABLE 1
module axi4_stream_target_type_1 #(
  parameter integer AxiStreamTargetIfTDataWidth    = 0,  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the data signal (bits per single transfer).
  parameter integer AxiStreamTargetIfTIdWidth      = 0,  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the stream identifier signal.
  parameter integer AxiStreamTargetIfTDestWidth    = 0,  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the stream destination signal.
  parameter integer AxiStreamTargetIfTId           = 0,  // NoC AXI Stream Initiator interface configuration. Stream identifier signal. Initial value of Stream Id. Will automatically increase when needed
  parameter integer AxiStreamTargetIfTDest         = 0,  // NoC AXI Stream Initiator interface configuration. Initial value of the Stream destination. Target will only process transfers matching this TDest.
  parameter [47:0]  AxiStreamTargetIfTargetMode = "LOOP", // NoC AXI Stream Initiator interface configuration. Stream generation mode
  parameter [31:0]  AxiStreamTargetIfCyclesActive  = 0,  // NoC AXI Stream Initiator interface configuration. Number of consecutive cycles the target injects data before pausing data generation.
  parameter [31:0]  AxiStreamTargetIfCyclesPause   = 0,  // NoC AXI Stream Initiator interface configuration. Number of cycles the target pauses data injection before resuming data generation.
  parameter integer AxiStreamTargetIfTransfersPerPacket = 0, // NoC AXI Stream Initiator interface configuration. Number of transfers per packet of the data stream.
  parameter integer AxiStreamTargetIfPacketsPerFrame    = 0, // NoC AXI Stream Initiator interface configuration. Number of packets per frame of the data stream.
  parameter integer AxiStreamTargetIfFramesPerStream    = 0, // NoC AXI Stream Initiator interface configuration. Number of frames per data stream.
  parameter [63:0]  AxiStreamTargetIfTlastFlagTrigger   = "NONE"   // NoC AXI Stream Initiator interface configuration. Enable "tlast" flag when trigger condition is matched. 
) (
  // clocks and resets
  input clk_s_axis_i,   // Input: clock signal

  input rst_s_axis_ni,  // Input: low level active reset

  // AXI-Stream (Initiator) interface for NoC connection
  input                                     s_axis_tvalid_i,
  output                                    s_axis_tready_o,
  input [AxiStreamTargetIfTDataWidth-1:0]   s_axis_tdata_i,
  input                                     s_axis_tlast_i,
  input [AxiStreamTargetIfTIdWidth-1:0]     s_axis_tid_i,
  input [AxiStreamTargetIfTDestWidth-1:0]   s_axis_tdest_i,
  
  //simulation error detection
  output                                    s_axis_terror_o
  );
  
  //
  localparam [AxiStreamTargetIfTDataWidth-1:0] TDataInitialValue   = (AxiStreamTargetIfTDataWidth <= 8)  ? 'ha0 :
                                                                     (AxiStreamTargetIfTDataWidth <= 16) ? 'h0a00 :
                                                                     'habc00b00;  // (AxiStreamTargetIfTDataWidth >= 32)
  localparam [AxiStreamTargetIfTDataWidth-1:0] TDataIncrementValue = (AxiStreamTargetIfTDataWidth <= 8)  ? 'h01 :
                                                                     (AxiStreamTargetIfTDataWidth <= 16) ? 'h0101 :
                                                                     'h00010001;
  
  // registers associated with data validation
  reg [AxiStreamTargetIfTDataWidth-1:0]  tdata;
  wire                                   tlast;
  reg [AxiStreamTargetIfTIdWidth-1:0]    tid;
  reg [AxiStreamTargetIfTDestWidth-1:0]  tdest;
  
  // wires and regs associated with in/out ports
  reg                                    tready;
  reg                                    terror;

  // registers associated to stream counters
  reg [31:0] current_packet_remaining_transfers;
  reg [31:0] current_frame_remaining_packets;
  reg [31:0] current_stream_remaining_frames;

  // auxiliary registers
  reg end_of_stream_drain;
  
  reg [31:0] target_cycles_pause_counter;
  reg [31:0] target_cycles_active_counter;

  // ports assignments
  // input
  assign s_axis_tready_o = tready & !end_of_stream_drain;
  assign s_axis_terror_o = terror; // & !end_of_stream_drain ? nothing valid should reach that portion of the code
  
  //
  wire  last_transfer_of_current_packet;
  wire  last_packet_of_current_frame;
  wire  last_frame_of_current_stream;
  
  assign last_transfer_of_current_packet = (current_packet_remaining_transfers == 'b0);
  assign last_packet_of_current_frame    = (current_frame_remaining_packets    == 'b0);
  assign last_frame_of_current_stream    = (current_stream_remaining_frames    == 'b0);
  
  assign tlast = rst_s_axis_ni & (AxiStreamTargetIfTlastFlagTrigger != "NONE") &
                 ((AxiStreamTargetIfTlastFlagTrigger == "TRANSFER")) |
                 ((AxiStreamTargetIfTlastFlagTrigger == "PACKET")    & (last_transfer_of_current_packet)) |
                 ((AxiStreamTargetIfTlastFlagTrigger == "FRAME")     & (last_transfer_of_current_packet & last_packet_of_current_frame)) |
                 ((AxiStreamTargetIfTlastFlagTrigger == "STREAM")    & (last_transfer_of_current_packet & last_packet_of_current_frame & last_frame_of_current_stream ) );
                  
  wire [31:0] transfers_per_packet_initial_value;
  wire [31:0] packets_per_frame_initial_value;
  wire [31:0] frames_per_stream_initial_value;
  
  assign transfers_per_packet_initial_value = (AxiStreamTargetIfTransfersPerPacket == 'b0) ? 'b0 : AxiStreamTargetIfTransfersPerPacket - 'b1;
  assign packets_per_frame_initial_value    = (AxiStreamTargetIfPacketsPerFrame == 'b0)    ? 'b0 : AxiStreamTargetIfPacketsPerFrame    - 'b1;
  assign frames_per_stream_initial_value    = (AxiStreamTargetIfFramesPerStream == 'b0)    ? 'b0 : AxiStreamTargetIfFramesPerStream    - 'b1;
  
  always @(posedge clk_s_axis_i) begin
    if(!rst_s_axis_ni) begin
      end_of_stream_drain <= 1'b0;
    end else begin
      if ( last_transfer_of_current_packet && last_packet_of_current_frame && last_frame_of_current_stream) begin
        if (AxiStreamTargetIfTargetMode == "SINGLE") begin
          $display("@A4ST_T1 SINGLE Stream mode detected");
          $display("          END of stream reached");
          $display("          STOPPING frame reception");
          end_of_stream_drain <= 1'b1;
        end else begin
          end_of_stream_drain <= 1'b0;
        end
      end else begin
        //end_of_stream_drain <= 1'b0;
      end
    end
  end


  always @(posedge clk_s_axis_i or posedge end_of_stream_drain) begin
    if(!rst_s_axis_ni || end_of_stream_drain) begin
      current_packet_remaining_transfers <= transfers_per_packet_initial_value;
      current_frame_remaining_packets    <= packets_per_frame_initial_value;
      current_stream_remaining_frames    <= frames_per_stream_initial_value;
    end else begin
      if (s_axis_tvalid_i) begin 
        if (tready) begin
          // update stream counters and check whether to rise tlast
          // tlast will be update in wire and combinational logic operations
          //tlast <= update_stream_counters_and_set_tlast();
          if(current_packet_remaining_transfers > 'b0) begin
            current_packet_remaining_transfers <= current_packet_remaining_transfers - 'b1;
          end else begin
            current_packet_remaining_transfers <= transfers_per_packet_initial_value;
            if(current_frame_remaining_packets > 'b0) begin
              current_frame_remaining_packets <= current_frame_remaining_packets -'b1; 
            end else begin
              current_frame_remaining_packets <= packets_per_frame_initial_value;
              if (current_stream_remaining_frames > 0) begin
                current_stream_remaining_frames <= current_stream_remaining_frames -'b1;
              end else begin
                current_stream_remaining_frames <= frames_per_stream_initial_value;
                // increase TID
                tid <= tid + 'b1;
              end
            end
          end
        end
      end
    end
  end

  wire error_tdata_current;
  wire error_tid_current;
  wire error_tdest_current;
  wire error_tlast_current;
  assign error_tdata_current = (s_axis_tdata_i != tdata);
  assign error_tid_current   = (s_axis_tdest_i != tdest);
  assign error_tdest_current = (s_axis_tid_i   != tid);
  assign error_tlast_current = (s_axis_tlast_i != tlast);
  
  always @(posedge clk_s_axis_i or posedge end_of_stream_drain) begin
    if(!rst_s_axis_ni || end_of_stream_drain) begin
      tdata  <= TDataInitialValue;
      tid    <= AxiStreamTargetIfTId;
      tdest  <= AxiStreamTargetIfTDest;
      terror <= 1'b0;
    end else begin
      if (s_axis_tvalid_i) begin 
        if (tready) begin 
          `ifdef DEBUG_DISPLAY_STREAM_TARGET_TYPE_1_ENABLE 
              $display("READ and drained value from system: 0x%08h   tdest: 0x%02h   tid: 0x%02h   tlast: %d", 
              s_axis_tdata_i, s_axis_tdest_i, s_axis_tid_i, s_axis_tlast_i
              );
          $display("                          Expected: 0x%08h   tdest: 0x%02h   tid: 0x%02h   tlast: %d",
              tdata, tdest, tid, tlast
              );
          `endif
          // prepare next value 
          tdata <= tdata + TDataIncrementValue;
          if ( error_tdata_current | error_tid_current | error_tdest_current | error_tlast_current) begin
            terror <= 1'b1;
          end
        end
      end
    end
  end

  // end_of_stream_drain signal can be safely removed from sensivity list for implementation
  //  it is added to sensivity list for a cleaner simulation waveform, to inmediately update displayed "reset" values on end_of_stream_signal signal rise  
  always @(posedge clk_s_axis_i or posedge end_of_stream_drain) begin
    if(!rst_s_axis_ni || end_of_stream_drain) begin
      tready <= 1'b0;
      target_cycles_pause_counter  <= AxiStreamTargetIfCyclesPause;
      target_cycles_active_counter <= AxiStreamTargetIfCyclesActive;     
    end else begin
      //$display("@A4SG_T1 ");
      if (target_cycles_pause_counter > 0) begin
        target_cycles_pause_counter <= target_cycles_pause_counter - 'b1;
        tready <= 1'b0;
      end else begin
        if ((AxiStreamTargetIfCyclesPause == 'b0) || (target_cycles_active_counter > 'b0))begin
          tready <= 1'b1;
          // update counters 
          // PAUSE counter
          // set variable to pause reception for next cycles the last cycle the target module is active
          if ((AxiStreamTargetIfCyclesPause > 'b0) && (target_cycles_active_counter == 'b1)) begin
            target_cycles_pause_counter  <= AxiStreamTargetIfCyclesPause;
          end
          // ACTIVE counter
          if ((AxiStreamTargetIfCyclesPause > 'b0)) begin
            if (target_cycles_active_counter > 'b0) begin
              target_cycles_active_counter <= target_cycles_active_counter - 'b1;
            end
          end
        end else begin
          // currently: do noooooo thing
          if ((AxiStreamTargetIfCyclesPause > 'b0) && (target_cycles_active_counter <= 'b1) )begin
            target_cycles_active_counter <= AxiStreamTargetIfCyclesPause;
          end
        end

      end
    
    end
  end
endmodule
