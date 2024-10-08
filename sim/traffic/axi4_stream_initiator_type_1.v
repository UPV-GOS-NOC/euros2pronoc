// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file axis_traffic_gen.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date April 8th, 2024
//
// @title AXI 4 stream initiator TYPE 1
//
//  Very SIMPLE data initiator for AXI 4 Stream transfers.
//  This module generates AXI 4 stream compatible traffic streams. This module implements the following AXI4 mandatory fields:
//   - tdata
//   - tlast
//   - tid
//   - tdest
//
//  Each stream consists of several frames. Each frame consists of several packets.
//  Each packet consists of several transfers.
//  Number of frames, packets,transfers and size of the transfers are configurable via parameters.
//  
//  This initiator can be configured to send valid data each clock cycle, or to generate the data in chunks,
//  this is generating valid data for a specified number of cycles(TA) and then pausing the transmission for a set number of cycles (TB) to then resume data injection. 
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
//  tlast port value is automatically set depending on  Trigger condition passed as parameter. tlast flag will be set to one as follows:
//    - NONE:     tlast port will never be set to one
//    - TRANSFER: tlast port will be set to one every transfer
//    - PACKET:   tlast port will be set to one the last transfer of each packet
//    - FRAME:    tlast port will be set to one the last transfer of each frame
//    - STREAM:   tlast port will be set to one the last transfer of the stream
//    
//  The total amount of bits in a data stream generated by the module will be the result of:
//    <number_of_frames_per_stream> * <number_of_packets_per_frame> * <number_of_transfers_per_packet> * <number_of_bits_per_transfer>
//
// Currently TDest field is fixed and passed as parameter.
// TO-DO: add new modes for Tid and Dest: RANDOM, FIXED, ...
//
// Current initiator modes are
//  - SINGLE:  the initiator sends a single DATA stream as configured in parameters (frames*packets*transfers*bytes) and stops
//  - LOOP:    the initiator loops sending the same stream in an infinite loop. Stream properties are configured in parameters.

`timescale 1ns/1ns

`define TDATA_INITIAL_VALUE 8'hA0
`define TDATA_INCR 8'h01

//`define  DEBUG_DISPLAY_STREAM_INITIATOR_TYPE_1_ENABLE 1
module axi4_stream_initiator_type_1 #(
  parameter integer AxiStreamInitiatorIfTDataWidth    = 0,  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the data signal (bits per single transfer).
  parameter integer AxiStreamInitiatorIfTIdWidth      = 0,  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the stream identifier signal.
  parameter integer AxiStreamInitiatorIfTDestWidth    = 0,  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the stream destination signal.
  parameter integer AxiStreamInitiatorIfTId           = 0,  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the stream identifier signal.
  parameter integer AxiStreamInitiatorIfTDest         = 0,  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the stream destination signal.
  parameter [47:0]  AxiStreamInitiatorIfInitiatorMode = "LOOP", // NoC AXI Stream Initiator interface configuration. Stream generation mode
  parameter [31:0]  AxiStreamInitiatorIfCyclesActive  = 0,  // NoC AXI Stream Initiator interface configuration. Number of consecutive cycles the initiator injects data before pausing data generation.
  parameter [31:0]  AxiStreamInitiatorIfCyclesPause   = 0,  // NoC AXI Stream Initiator interface configuration. Number of cycles the initiator pauses data injection before resuming data generation.
  parameter integer AxiStreamInitiatorIfTransfersPerPacket = 0, // NoC AXI Stream Initiator interface configuration. Number of transfers per packet of the data stream.
  parameter integer AxiStreamInitiatorIfPacketsPerFrame    = 0, // NoC AXI Stream Initiator interface configuration. Number of packets per frame of the data stream.
  parameter integer AxiStreamInitiatorIfFramesPerStream    = 0, // NoC AXI Stream Initiator interface configuration. Number of frames per data stream.
  parameter [63:0]  AxiStreamInitiatorIfTlastFlagTrigger   = "NONE"   // NoC AXI Stream Initiator interface configuration. Enable "tlast" flag when trigger condition is matched. 
) (
  // clocks and resets
  input clk_m_axis_i,   // Input: clock signal

  input rst_m_axis_ni,  // Input: low level active reset

  // AXI-Stream (Initiator) interface for NoC connection
  output                                        m_axis_tvalid_o,
  input                                         m_axis_tready_i,
  output [AxiStreamInitiatorIfTDataWidth-1:0]   m_axis_tdata_o,
  output                                        m_axis_tlast_o,
  output [AxiStreamInitiatorIfTIdWidth-1:0]     m_axis_tid_o,
  output [AxiStreamInitiatorIfTDestWidth-1:0]   m_axis_tdest_o
  );
  
  //
  localparam [AxiStreamInitiatorIfTDataWidth-1:0] TDataInitialValue   = (AxiStreamInitiatorIfTDataWidth <= 8)  ? 'ha0 :
                                                                        (AxiStreamInitiatorIfTDataWidth <= 16) ? 'h0a00 :
                                                                        'habc00b00;  // (AxiStreamInitiatorIfTDataWidth >= 32)
  localparam [AxiStreamInitiatorIfTDataWidth-1:0] TDataIncrementValue = (AxiStreamInitiatorIfTDataWidth <= 8)  ? 'h01 :
                                                                        (AxiStreamInitiatorIfTDataWidth <= 16) ? 'h0101 :
                                                                        'h00010001;
  
  // registers associated with in/out ports
  reg                                        tvalid;
  reg [AxiStreamInitiatorIfTDataWidth-1:0]   tdata;
  wire                                       tlast;
  reg [AxiStreamInitiatorIfTIdWidth-1:0]     tid;
  reg [AxiStreamInitiatorIfTDestWidth-1:0]   tdest;
  wire                                       tready;

  // registers associated to stream counters
  reg [31:0] current_packet_remaining_transfers;
  reg [31:0] current_frame_remaining_packets;
  reg [31:0] current_stream_remaining_frames;

  // auxiliary registers
  reg end_of_stream_generation;
  
  reg [31:0] initiator_cycles_pause_counter;
  reg [31:0] initiator_cycles_active_counter;

  // ports assignments
  // input
  assign tready          = m_axis_tready_i;
  // output
  assign m_axis_tvalid_o = tvalid & !end_of_stream_generation;
  assign m_axis_tdata_o  = tdata;
  assign m_axis_tlast_o  = tlast;
  assign m_axis_tid_o    = tid;
  assign m_axis_tdest_o  = tdest;

  //
  wire  last_transfer_of_current_packet;
  wire  last_packet_of_current_frame;
  wire  last_frame_of_current_stream;
  
  assign last_transfer_of_current_packet = (current_packet_remaining_transfers == 'b0);
  assign last_packet_of_current_frame    = (current_frame_remaining_packets    == 'b0);
  assign last_frame_of_current_stream    = (current_stream_remaining_frames    == 'b0);
  
  assign tlast = rst_m_axis_ni & (AxiStreamInitiatorIfTlastFlagTrigger != "NONE") &
                 ((AxiStreamInitiatorIfTlastFlagTrigger == "TRANSFER")) |
                 ((AxiStreamInitiatorIfTlastFlagTrigger == "PACKET")    & (last_transfer_of_current_packet)) |
                 ((AxiStreamInitiatorIfTlastFlagTrigger == "FRAME")     & (last_transfer_of_current_packet & last_packet_of_current_frame)) |
                 ((AxiStreamInitiatorIfTlastFlagTrigger == "STREAM")    & (last_transfer_of_current_packet & last_packet_of_current_frame & last_frame_of_current_stream ) );
                  
  wire [31:0] transfers_per_packet_initial_value;
  wire [31:0] packets_per_frame_initial_value;
  wire [31:0] frames_per_stream_initial_value;
  
  assign transfers_per_packet_initial_value = (AxiStreamInitiatorIfTransfersPerPacket == 'b0) ? 'b0 : AxiStreamInitiatorIfTransfersPerPacket - 'b1;
  assign packets_per_frame_initial_value    = (AxiStreamInitiatorIfPacketsPerFrame == 'b0)    ? 'b0 : AxiStreamInitiatorIfPacketsPerFrame    - 'b1;
  assign frames_per_stream_initial_value    = (AxiStreamInitiatorIfFramesPerStream == 'b0)    ? 'b0 : AxiStreamInitiatorIfFramesPerStream    - 'b1;
  
  always @(posedge clk_m_axis_i) begin
    if(!rst_m_axis_ni) begin
      end_of_stream_generation <= 1'b0;
    end else begin
      if ( last_transfer_of_current_packet && last_packet_of_current_frame && last_frame_of_current_stream && tvalid && tready) begin
        if (AxiStreamInitiatorIfInitiatorMode == "SINGLE") begin
          $display("@A4SG_T1 SINGLE Stream mode detected");
          $display("          END of stream reached");
          $display("          STOPPING frame generation");
          end_of_stream_generation <= 1'b1;
        end else begin
          //end_of_stream_generation <= 1'b0;
        end
      end else begin
        //end_of_stream_generation <= 1'b0;
      end
    end
  end
  

  always @(posedge clk_m_axis_i or posedge end_of_stream_generation) begin
    if(!rst_m_axis_ni || end_of_stream_generation) begin
      current_packet_remaining_transfers <= transfers_per_packet_initial_value;
      current_frame_remaining_packets    <= packets_per_frame_initial_value;
      current_stream_remaining_frames    <= frames_per_stream_initial_value;
    end else begin
      if (tvalid) begin 
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


  // end_of_stream_generation signal can be safely removed from sensivity list for implementation
  //  it is added to sensivity list for a cleaner simulation waveform, to inmediately update displayed "reset" values on end_of_stream_generation signal rise
  //  if removed, TId and tdata fields are updated for one cycle and then set to reset, but the tvalid is inmediately set to zero so the new values are not valid.  
  always @(posedge clk_m_axis_i or posedge end_of_stream_generation) begin
    if(!rst_m_axis_ni || end_of_stream_generation) begin
      tvalid <= 1'b0;
      tdata  <= TDataInitialValue;
      //tlast  <= 1'b0;
      tid    <= AxiStreamInitiatorIfTId;
      tdest  <= AxiStreamInitiatorIfTDest;
      initiator_cycles_pause_counter  <= AxiStreamInitiatorIfCyclesPause;
      initiator_cycles_active_counter <= AxiStreamInitiatorIfCyclesActive;      
    end else begin
      //$display("@A4SG_T1 ");
      
      if (initiator_cycles_pause_counter > 0) begin
        initiator_cycles_pause_counter <= initiator_cycles_pause_counter - 'b1;
        // The AXI specification says that:
        //   TVALID is asserted it must remain asserted until the handshake occurs.
        // but we are testing "limit cases" to test system robustness, so we are allowing this, since 
        // this may happen in the signals comming from the NoC modules
 
        // update output tdata value only if tdata and tvalid were both "active" im the same cycle
        // the first time the code enters this section (each time the initiator changes from active to pause)
        // the receiver may acknowledge the reception of the data in previous cycle, so update output for next time the ouput is active and valid
        //tvalid <= 1'b0;
        //if (tready && tvalid) begin
        //  // previous data was read
        //  tdata <= tdata + TDataIncrementValue;
        //end
        
        // The implementation for the AXI handshake specification 
        // The axi spec determines that after marking a transfer as valid it must keep the valid flag ative until
        // the receiver sets the ready port to one. So:
        if (tvalid) begin 
          if (tready) begin
            tdata <= tdata + TDataIncrementValue;
            tvalid <= 1'b0; // deactivate valid signal until next active cycle          
          end else begin
            tvalid <= 1'b1; 
            //tdata  <= tdata; // keep valid flag until the receiver reads the data
          end
        end else begin
          tvalid <= 1'b0;
          //tdata  <= tdata;
        end
                     
        // update cycles active counter, it could also be done in the active counter logic since the code will enter this loop first before checking active counter value
        if(initiator_cycles_pause_counter == 'b1) begin
          initiator_cycles_active_counter <= AxiStreamInitiatorIfCyclesActive;
        end

      end else begin
        //$display("@A4SG_T1 ");
        if ((AxiStreamInitiatorIfCyclesPause == 'b0) || (initiator_cycles_active_counter > 'b0))begin
          // update tvalid flag 
          tvalid <= 1'b1;
          // update output tdata value only if tdata and tvalid were both "active" im the same cycle
          if (tready && tvalid) begin
            // previous data was read
            tdata <= tdata + TDataIncrementValue;
          end

          // update counters 
          // PAUSE counter
          // set variable to pause transmission for next cycles the last cycle the initiator is active
          if ((AxiStreamInitiatorIfCyclesPause > 'b0) && (initiator_cycles_active_counter == 'b1)) begin
            initiator_cycles_pause_counter  <= AxiStreamInitiatorIfCyclesPause;
          end
          // ACTIVE counter
          if ((AxiStreamInitiatorIfCyclesPause > 'b0)) begin
            if (initiator_cycles_active_counter > 'b0) begin
              initiator_cycles_active_counter <= initiator_cycles_active_counter - 'b1;
            end
          end
        end else begin
          if ((AxiStreamInitiatorIfCyclesPause > 'b0)) begin
            if (initiator_cycles_active_counter > 'b0) begin
              initiator_cycles_active_counter <= initiator_cycles_active_counter - 'b1;
            end
          end
        end
      end
    end
  end
 
endmodule
