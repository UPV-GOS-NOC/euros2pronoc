`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// (c) Copyright 2012 - 2017  Parallel Architectures Group (GAP)
// Department of Computing Engineering (DISCA)
// Universitat Politecnica de Valencia (UPV)
// Valencia, Spain
// All rights reserved.
//
// All code contained herein is, and remains the property of
// Parallel Architectures Group. The intellectual and technical concepts
// contained herein are proprietary to Parallel Architectures Group and
// are protected by trade secret or copyright law.
// Dissemination of this code or reproduction of this material is
// strictly forbidden unless prior written permission is obtained
// from Parallel Architectures Group.
//
// THIS SOFTWARE IS MADE AVAILABLE "AS IS" AND IT IS NOT INTENDED FOR USE
// IN WHICH THE FAILURE OF THE SOFTWARE COULD LEAD TO DEATH, PERSONAL INJURY,
// OR SEVERE PHYSICAL OR ENVIRONMENTAL DAMAGE.
//
// contact: jflich@disca.upv.es
//-----------------------------------------------------------------------------
//
// Company:  GAP (UPV)
// Engineer: J. Flich (jflich@disca.upv.es)
//
// Create Date: 09/03/2013
// Design Name:
// Module Name:
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//  this file includes common defines for switches
//
//////////////////////////////////////////////////////////////////////////////////

`include "macro_functions.h"

// This module provides the support for the buffer at an input port of the switch (<SWITCH: SWITCH>  <SWITCH_VC: SWITCH_VC>). 
//
//The module has
// two interfaces:: IN and OUT. IN interface is used to connect to other router's output port (or to
// a network interface injector) and OUT interface is used to connect to the routing module.
//
//  In the switch design the flit goes to the routing module and from there is forwarded to the output, once
// the arbiter(s) provide the appropriate grant(s). This module assumes the current flit has been
// forwarded once it sees the avail signal from the routing module.
//
// The module stores received flits in a queue. Associated information (flit type and broadcast bit) is
// stored in two separate queues. For the three queues, a read pointer and a write pointer is managed. The
// write pointer is used to store incoming flits (and associated info) and the read pointer is used to read stored flits (and associated info). The
// read pointer is incremented every time the routing module asserts the avail signal (and there are stored flits)
// and the write pointer is incremented every time a new flit arrives. Both pointers are incremented by one. The
// queues and the read/write pointers assume a circular queue structure.
//
// The module uses the Stop & Go handshake protocol. For this, a counter of stored flits is used. A single queue is supported and proper queue depth must
// be defined in order to enable efficient data transmission along the incoming network's link. The queue size
// can be indicated by parameter. The Go signal
// is typically asserted. When the Stop threshold is reached the Go signal is set to zero. This signal will remain
// to zero until the Go threshold is reached. The two thresholds are defined by parameters (SG_UPPER_THOLD and
// SG_LOWER_THOLD). These two threshold values may affect link bandwidth and, thus, must be set in accordance with the 
// queue size.
//
// An incoming flit may reach the input buffer in several cycles, when the phit size is lower than the flit size. In that
// case, incoming phits are stored at the corresponding slot for the flit and the number of phits to receive is managed by the input buffer.
// Phits with different values than the flit size are common in an input port connected to a FPGA-to-FPGA link.
//
// This module is used on every <switch: SWITCH>/<switch_vc: SWITCH_VC> input port and also on the <inject: INJECT> modules inside the <network interface: NI> modules.
//
// <br>
module IBUFFER #(
    parameter          FLIT_SIZE      = 64,       // Flit size in bits
    parameter          PHIT_SIZE      = 64,       // Phit size in bits
    parameter          FLIT_TYPE_SIZE = 2,        // Width of the flit type field in number of bits
    parameter          QUEUE_SIZE     = 8,        // FIFO's queue depth (number of slots, one flit fits one slot)
    parameter          SG_UPPER_THOLD = 6,        // Stop & Go upper threshold (Stop threshold)
    parameter          SG_LOWER_THOLD = 4         // Stop & Go lower threshold (Go threshold)
  )(
    input                       clk,              // clock signal
    input                       rst_p,            // reset signal
    input [PHIT_SIZE-1:0]       Flit,             // IN interface:: Flit
    input [FLIT_TYPE_SIZE-1:0]  FlitType,         // IN interface:: Flit type (is not coded in the flit structure)
    input                       BroadcastFlit,    // IN interface:: Broadcast bit
    input                       Valid,            // IN interface:: Valid bit
    output                      Go,               // IN interface:: S&G protocol signal (Go)
    output                      Req_RT,           // OUT interface:: Request signal (to the routing module)
    input                       Avail,            // OUT interface:: Available signal
    output [FLIT_SIZE-1:0]      FlitOut,          // OUT interface:: flit
    output [FLIT_TYPE_SIZE-1:0] FlitTypeOut,      // OUT interface:: flit type (is not coded in the flit structure)
    output                      BroadcastFlitOut  // OUT interface:: Broadcast bit
  );
  
  `include "common_functions.vh"
  
  localparam [6 : 0] NUM_PHITS      = (PHIT_SIZE > 7'b0 ? FLIT_SIZE / PHIT_SIZE : 7'b1);  // Number of phits to transmit a flit
  localparam [5 : 0] LAST_PHIT      = NUM_PHITS - 7'b1;                                   // Last phit(num_phits-1)
  localparam         QUEUE_width    = Log2(QUEUE_SIZE);                                 // Width of QUEUE_SIZE parameter  )

  reg   [5 : 0]      phit_number;                                        // Phit number, to keep track when all phits are received for a flit

  //Internal registers for the queue
  
  
  reg [QUEUE_width:0] queued_flits;                                      // Counter for the current number of queued flits
  reg [QUEUE_width-1:0] read_ptr;                                        // Read pointer in the circular queue
  reg [QUEUE_width-1:0] write_ptr;                                       // Write pointer in the circular queue
  reg [FLIT_SIZE-1:0] queue [QUEUE_SIZE-1:0];                            // Module's FIFO queue (circular queue)
  reg [FLIT_TYPE_SIZE-1:0] queued_flit_type_signals [QUEUE_SIZE-1:0];    // Associated queue to keep flit type field of every stored flit
  reg queued_bcast_signals [QUEUE_SIZE-1:0];                             // Associated queue to keep broadcast bit of every stored flit
  reg go_mode;                                                           // Registered go signal
  wire w_request;                                                        // a request to the ROUTING module is performed
  wire received_flit_s;                                                  // set when the complete flit has been received (until the last phit)

  assign FlitOut          = queue[read_ptr];                       
  assign FlitTypeOut      = queued_flit_type_signals[read_ptr];    
  assign BroadcastFlitOut = queued_bcast_signals[read_ptr];        
  assign w_request        = Avail & (queued_flits != 0);
  assign received_flit_s  = (phit_number == LAST_PHIT) & Valid;
  
  //a request to the routing engine is done when the RT is ready for accepting requests and there is at least a flit in the buffer (queued or not)
  assign Req_RT           = w_request;
  
  assign Go = go_mode;


  always @ (posedge clk)
    if (rst_p)
    begin
      queued_flits <= `V_ZERO(QUEUE_width+1);
      read_ptr     <= `V_ZERO(QUEUE_width);
      write_ptr    <= `V_ZERO(QUEUE_width);
      go_mode      <= 1'b1;
      phit_number  <= 6'b0;
    end
    else
    begin
      if (w_request)
      begin
        read_ptr  <= read_ptr + `V_ONE(QUEUE_width);

        if (~received_flit_s)
        begin
          // routing request and not new flit arrival, let's decrement queued flits
          queued_flits  <= queued_flits - `V_ONE(QUEUE_width+1);
        end
      end

      // Let's see if we receive a new flit
      if (Valid)
      begin
        queue[write_ptr][phit_number * PHIT_SIZE +: PHIT_SIZE] <= Flit;

        if (received_flit_s)
        begin
          phit_number <= 6'b0;
          if (~w_request)
          begin
            //a new flit arrival and there is not next enabled, let's increment the number of queued flits
            queued_flits <= queued_flits + `V_ONE(QUEUE_width+1);
          end

          queued_bcast_signals[write_ptr]     <= BroadcastFlit;
          queued_flit_type_signals[write_ptr] <= FlitType;
          write_ptr                           <= write_ptr  + `V_ONE(QUEUE_width);
        end
        else
        begin
          // no flit received yet
          phit_number <= phit_number + 6'b1;
        end // if received_flit_s
      end  // if valid

      if (go_mode)
      begin
        if (queued_flits >= SG_UPPER_THOLD)
        begin
          go_mode <= 1'b0;
        end
        else
        begin
          go_mode <= 1'b1;
        end
      end
      else
      begin
        if (queued_flits < SG_LOWER_THOLD)
        begin
          go_mode <= 1'b1;
        end
        else
        begin
          go_mode <= 1'b0;
        end
      end
    end
endmodule
