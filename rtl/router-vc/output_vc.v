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
//
//////////////////////////////////////////////////////////////////////////////////

`include "macro_functions.h"
`include "net_common.h"

//! This module provides support for the switch architecture at the output. It implements the forwarding of flits through a switch's output port.
//! This module is used in networks with virtual channels (VCs) and/or virtual networks (VNs) support. For networks with no VC nor VN support, the module
//! to use should be OUTPUT.
//!
//! Each VN has a fixed number of VCs. Thus, in total there are VN x VC virtual channels. A VC channel identifier ranges from 0 to VC x VN - 1. Therefore, from the
//! VC channel identifier we can know the VN of the VC. The module receives the virtual channel selected (vc_selected) that will be used for the granted flit at the
//! downstream switch or endnode. Notice that flits can jump between VCs at different switches but always within a VN range (flits can not use VCs from different VNs).
//!
//! This module defines six interfaces: NORTH, EAST, WEST, SOUTH, LOCAL, OUT. The first five interfaces are used to receive flits from the switch input ports, whereas
//! the OUT interface is used to forward flits through the link. There is an additional smaller interface for the VA module (that manages the downstream VC associations to input flits).
//! This interface indicates the VA module when a particular VC can be released (unassigned) as the tail flit of the message was just injected.
//!
//! On every NORTH, EAST, WEST, SOUTH, and LOCAL interface a set of data items are received in parallel. In particular, VN x VC data items are received simultaneously. This
//! implies VN x VC flits through the Pre_Flit_* port, VN x VC flit type identifiers through the Pre_FlitType_* port, and VN x VC broadcast bits through the Pre_BroadcastFlit_* port.
//!
//! The module receives a grant vector including a grant signal for each VN x VC virtual channel at each input port of the switch. The grant signals are used to select
//! the flit and associated data to be transmitted over the link.
//!
//! The module supports phit level transmission when the link width is lower than the flit size. For this, a GoPhit output signal is used to instruct the switch allocator
//! to stop granting flits to that output port while transmitting all the phits for the current granted flit.

// TODO: El esquemático en TEROS no sale bien por culpa de los localparams

module OUTPUT_VC #(
    parameter FLIT_SIZE          = 64,                                                            //! flit size in bits
    parameter FLIT_TYPE_SIZE     = 2,                                                             //! Flit type field size in bits
    parameter BROADCAST_SIZE     = 5,                                                             //! broadcast field size size in bits
    parameter PHIT_SIZE          = 64,                                                            //! phit size in bits
    parameter NUM_VC             = 1,                                                             //! number of virtual channels (VC) per virtual network (VN) supported
    parameter NUM_VN             = 3,                                                             //! number of virtual networks (VN) supported
    parameter VN_WEIGHT_VECTOR_w = 20,                                                            //! width of weight vector in bits
    localparam FLIT_PORT_w                = FLIT_SIZE * NUM_VC * NUM_VN,                          //! width of flits comming through a port (equals to flit size times number of VNs times number of VCs per VN)
    localparam FLIT_TYPE_PORT_w           = FLIT_TYPE_SIZE * NUM_VC * NUM_VN,                     //! width of flit types coming through a port
    localparam BROADCAST_PORT_w           = BROADCAST_SIZE * NUM_VC * NUM_VN,                     //! width of broadcast bits coming through a port
    localparam VN_X_VC_w                  = Log2_w(NUM_VC * NUM_VN),                              //! number of bits to encode a VN/VC identifier
    localparam VN_X_VC                    = NUM_VN * NUM_VC,                                      //! number of VNxVCs
    localparam [6 : 0] NUM_PHITS          = (PHIT_SIZE > 7'd0 ? FLIT_SIZE / PHIT_SIZE : 7'b1),    //! number of phits in a flit
    localparam [6 : 0] LAST_PHIT          = NUM_PHITS - 7'd1,                                     //! last phit identifier (num phits - 1)
    localparam [6 : 0] BEFORE_LAST_PHIT   = (NUM_PHITS == 7'd1) ? LAST_PHIT : (NUM_PHITS - 7'd2)  //! num_phits - 2
    )(
    input  [FLIT_PORT_w-1 : 0]        Pre_Flit_N,                    //! NORTH interface: flits (one per VN/VC)
    input  [FLIT_TYPE_PORT_w-1 : 0]   Pre_FlitType_N,                //! NORTH interface: flit type (one per VN/VC)
    input  [BROADCAST_PORT_w-1 : 0]   Pre_BroadcastFlit_N,           //! NORTH interface: broadcast bit (one per VN/VC)
    input  [FLIT_PORT_w-1 : 0]        Pre_Flit_E,                    //! EAST interface: flits (one per VN/VC)
    input  [FLIT_TYPE_PORT_w-1 : 0]   Pre_FlitType_E,                //! EAST interface: flit type (one per VN/VC)
    input  [BROADCAST_PORT_w-1 : 0]   Pre_BroadcastFlit_E,           //! EAST interface: broadcast bit (one per VN/VC)
    input  [FLIT_PORT_w-1 : 0]        Pre_Flit_L,                    //! LOCAL interface: flits (one per VN/VC)
    input  [FLIT_TYPE_PORT_w-1 : 0]   Pre_FlitType_L,                //! LOCAL interface: flit type (one per VN/VC)
    input  [BROADCAST_PORT_w-1 : 0]   Pre_BroadcastFlit_L,           //! LOCAL interface: broadcast bit (one per VN/VC)
    input  [FLIT_PORT_w-1 : 0]        Pre_Flit_S,                    //! SOUTH interface: flits (one per VN/VC)
    input  [FLIT_TYPE_PORT_w-1 : 0]   Pre_FlitType_S,                //! SOUTH interface: flit type (one per VN/VC)
    input  [BROADCAST_PORT_w-1 : 0]   Pre_BroadcastFlit_S,           //! SOUTH interface: broadcast bit (one per VN/VC)
    input  [FLIT_PORT_w-1 : 0]        Pre_Flit_W,                    //! WEST interface: flits (one per VN/VC)
    input  [FLIT_TYPE_PORT_w-1 : 0]   Pre_FlitType_W,                //! WEST interface: flit type (one per VN/VC)
    input  [BROADCAST_PORT_w-1 : 0]   Pre_BroadcastFlit_W,           //! WEST interface: broadcast bit (one per VN/VC)
    input  [(5 * NUM_VC * NUM_VN)-1 : 0] GRANTS,                     //! Grant bits, VC x VN bits per input port (NEWSL)
    input  [VN_X_VC_w-1 : 0]          vc_selected,                   //! virtual channel selected for the granted flit
    output free_VC,                                                  //! VA interface: free vc signal, when a tail flit is forwarded this signal is set
    output [VN_X_VC_w-1 : 0]          vc_to_release,                 //! VA interface: VC to release (when free_VC is set)
    output GoPhit,                                                   //! flow control to SA
    output reg                        Valid,                         //! OUT interface: valid signal
    output [PHIT_SIZE-1 : 0]          FlitOut,                       //! OUT interface: flit
    output reg                        BroadcastFlitOut,              //! OUT interface: broadcast bit
    output reg [FLIT_TYPE_SIZE-1 : 0] FlitTypeOut,                   //! OUT interface: flit type
    output reg [VN_X_VC_w-1 : 0]      VC_out,                        //! OUT interface: vc asigned to output flit
    input                             clk,                           //! clock signal
    input                             rst_p                          //! reset signal
  );

`include "common_functions.vh"

  wire [VN_X_VC-1 : 0] GRANTS_E = GRANTS[(VN_X_VC * 4 + VN_X_VC - 1) -: VN_X_VC];  //! grant signals for the east input port
  wire [VN_X_VC-1 : 0] GRANTS_S = GRANTS[(VN_X_VC * 3 + VN_X_VC - 1) -: VN_X_VC];  //! grant signals for the south input port
  wire [VN_X_VC-1 : 0] GRANTS_W = GRANTS[(VN_X_VC * 2 + VN_X_VC - 1) -: VN_X_VC];  //! grant signals for the west input port
  wire [VN_X_VC-1 : 0] GRANTS_N = GRANTS[(VN_X_VC * 1 + VN_X_VC - 1) -: VN_X_VC];  //! grant signals for the north input port
  wire [VN_X_VC-1 : 0] GRANTS_L = GRANTS[(VN_X_VC * 0 + VN_X_VC - 1) -: VN_X_VC];  //! grant signals for the local input port
  
  wire [VN_X_VC_w-1:0] GRANTS_E_IDX;
  wire [VN_X_VC_w-1:0] GRANTS_S_IDX;
  wire [VN_X_VC_w-1:0] GRANTS_W_IDX;
  wire [VN_X_VC_w-1:0] GRANTS_N_IDX;
  wire [VN_X_VC_w-1:0] GRANTS_L_IDX;        

  wire Grant_to_E = (|GRANTS_E);         //! global grant signal to east input port
  wire Grant_to_S = (|GRANTS_S);         //! global grant signal to south input port
  wire Grant_to_W = (|GRANTS_W);         //! global grant signal to west input port
  wire Grant_to_N = (|GRANTS_N);         //! global grant signal to north input port
  wire Grant_to_L = (|GRANTS_L);         //! global grant signal to local input port

  wire [FLIT_SIZE-1:0] Flit_E;           //! flit from east input port
  wire [FLIT_SIZE-1:0] Flit_S;           //! flit from south input port
  wire [FLIT_SIZE-1:0] Flit_W;           //! flit from west input port
  wire [FLIT_SIZE-1:0] Flit_N;           //! flit from north input port
  wire [FLIT_SIZE-1:0] Flit_L;           //! flit from local input port
  wire [FLIT_TYPE_SIZE-1:0] FlitType_E;  //! flit type from east input port
  wire [FLIT_TYPE_SIZE-1:0] FlitType_S;  //! flit type from south input port
  wire [FLIT_TYPE_SIZE-1:0] FlitType_W;  //! flit type from west input port
  wire [FLIT_TYPE_SIZE-1:0] FlitType_N;  //! flit type from north input port
  wire [FLIT_TYPE_SIZE-1:0] FlitType_L;  //! flit type from local input port
  wire BroadcastFlit_E;                  //! broadcast bit from east input port
  wire BroadcastFlit_S;                  //! broadcast bit from south input port
  wire BroadcastFlit_W;                  //! broadcast bit from west input port
  wire BroadcastFlit_N;                  //! broadcast bit from north input port
  wire BroadcastFlit_L;                  //! broadcast bit from local input port

  // We extract the data from incoming vectors
  
  encoder #(
    .lenght_in(VN_X_VC),
    .lenght_out(VN_X_VC_w)
  ) grant_e_encoder_inst (
    .vector_in(GRANTS_E),
    .vector_id(GRANTS_E_IDX)
  );
  
  encoder #(
    .lenght_in(VN_X_VC),
    .lenght_out(VN_X_VC_w)
  ) grant_s_encoder_inst (
    .vector_in(GRANTS_S),
    .vector_id(GRANTS_S_IDX)
  );
  
    encoder #(
    .lenght_in(VN_X_VC),
    .lenght_out(VN_X_VC_w)
  ) grant_w_encoder_inst (
    .vector_in(GRANTS_W),
    .vector_id(GRANTS_W_IDX)
  );
  
    encoder #(
    .lenght_in(VN_X_VC),
    .lenght_out(VN_X_VC_w)
  ) grant_n_encoder_inst (
    .vector_in(GRANTS_N),
    .vector_id(GRANTS_N_IDX)
  );  

    encoder #(
    .lenght_in(VN_X_VC),
    .lenght_out(VN_X_VC_w)
  ) grant_l_encoder_inst (
    .vector_in(GRANTS_L),
    .vector_id(GRANTS_L_IDX)
  );  
  
  //generate
    //genvar i;
    //for (i = 0; i < VN_X_VC; i = i + 1)
    //begin
      assign Flit_E = (|GRANTS_E) ? Pre_Flit_E[(GRANTS_E_IDX*FLIT_SIZE+(FLIT_SIZE-1))-:FLIT_SIZE] : `V_ZERO(FLIT_SIZE);
      assign Flit_S = (|GRANTS_S) ? Pre_Flit_S[(GRANTS_S_IDX*FLIT_SIZE+(FLIT_SIZE-1))-:FLIT_SIZE] : `V_ZERO(FLIT_SIZE);
      assign Flit_W = (|GRANTS_W) ? Pre_Flit_W[(GRANTS_W_IDX*FLIT_SIZE+(FLIT_SIZE-1))-:FLIT_SIZE] : `V_ZERO(FLIT_SIZE);
      assign Flit_N = (|GRANTS_N) ? Pre_Flit_N[(GRANTS_N_IDX*FLIT_SIZE+(FLIT_SIZE-1))-:FLIT_SIZE] : `V_ZERO(FLIT_SIZE);
      assign Flit_L = (|GRANTS_L) ? Pre_Flit_L[(GRANTS_L_IDX*FLIT_SIZE+(FLIT_SIZE-1))-:FLIT_SIZE] : `V_ZERO(FLIT_SIZE);
      assign FlitType_E = (|GRANTS_E) ? Pre_FlitType_E[(GRANTS_E_IDX*FLIT_TYPE_SIZE+(FLIT_TYPE_SIZE-1))-:FLIT_TYPE_SIZE] : `V_ZERO(FLIT_TYPE_SIZE);
      assign FlitType_S = (|GRANTS_S) ? Pre_FlitType_S[(GRANTS_S_IDX*FLIT_TYPE_SIZE+(FLIT_TYPE_SIZE-1))-:FLIT_TYPE_SIZE] : `V_ZERO(FLIT_TYPE_SIZE);
      assign FlitType_W = (|GRANTS_W) ? Pre_FlitType_W[(GRANTS_W_IDX*FLIT_TYPE_SIZE+(FLIT_TYPE_SIZE-1))-:FLIT_TYPE_SIZE] : `V_ZERO(FLIT_TYPE_SIZE);
      assign FlitType_N = (|GRANTS_N) ? Pre_FlitType_N[(GRANTS_N_IDX*FLIT_TYPE_SIZE+(FLIT_TYPE_SIZE-1))-:FLIT_TYPE_SIZE] : `V_ZERO(FLIT_TYPE_SIZE);
      assign FlitType_L = (|GRANTS_L) ? Pre_FlitType_L[(GRANTS_L_IDX*FLIT_TYPE_SIZE+(FLIT_TYPE_SIZE-1))-:FLIT_TYPE_SIZE] : `V_ZERO(FLIT_TYPE_SIZE);
      assign BroadcastFlit_E = (|GRANTS_E) ? Pre_BroadcastFlit_E[GRANTS_E_IDX] : 1'b0;
      assign BroadcastFlit_S = (|GRANTS_S) ? Pre_BroadcastFlit_S[GRANTS_S_IDX] : 1'b0;
      assign BroadcastFlit_W = (|GRANTS_W) ? Pre_BroadcastFlit_W[GRANTS_W_IDX] : 1'b0;
      assign BroadcastFlit_N = (|GRANTS_N) ? Pre_BroadcastFlit_N[GRANTS_N_IDX] : 1'b0;
      assign BroadcastFlit_L = (|GRANTS_L) ? Pre_BroadcastFlit_L[GRANTS_L_IDX] : 1'b0;
    //end
  //endgenerate

  // free_VC output signal, a VC is released when the tail of the tail flit will be injected
  assign free_VC = Grant_to_N ? (FlitType_N == `tail | FlitType_N == `header_tail) :
                   Grant_to_E ? (FlitType_E == `tail | FlitType_E == `header_tail) :
                   Grant_to_W ? (FlitType_W == `tail | FlitType_W == `header_tail) :
                   Grant_to_S ? (FlitType_S == `tail | FlitType_S == `header_tail) :
                   Grant_to_L ? (FlitType_L == `tail | FlitType_L == `header_tail) :
                                1'b0;
  // VC to release will be (in case of) the current selected VC at the downstream switch or endnode
  assign vc_to_release =  vc_selected;

  reg   [FLIT_SIZE-1 : 0] flit;        //! buffer to keep the flit (we need to stored in case the phit size < flit size)
  reg   [6 : 0]           phit_number; //! counter for the current phit to transmit

  // Flit output, is the current phit (in case of phit size == flit size the complete flit is assigned)
  assign FlitOut = flit[phit_number * PHIT_SIZE +: PHIT_SIZE];

  if (NUM_PHITS > 1)
  begin
    assign GoPhit  = (phit_number >= LAST_PHIT) & ~(Grant_to_N | Grant_to_E | Grant_to_W | Grant_to_S | Grant_to_L);
  end
  else
  begin
    assign GoPhit = 1'b1;
  end

  always @ (posedge clk)
    if (rst_p)
    begin
      flit             <= `V_ZERO(FLIT_SIZE);
      phit_number      <= LAST_PHIT;
      BroadcastFlitOut <= 1'b0;
      FlitTypeOut      <= 2'b0;
      Valid            <= 1'b0;
      VC_out           <= `V_ZERO(VN_X_VC_w);
    end
    else
    begin
      if (Grant_to_N)
      begin
        flit             <= Flit_N;
        BroadcastFlitOut <= BroadcastFlit_N;
        FlitTypeOut      <= FlitType_N;
        Valid            <= 1'b1;
        phit_number      <= 7'b0;
        VC_out           <= vc_selected;
      end
      else if (Grant_to_E)
      begin
        flit             <= Flit_E;
        BroadcastFlitOut <= BroadcastFlit_E;
        FlitTypeOut      <= FlitType_E;
        Valid            <= 1'b1;
        phit_number      <= 7'b0;
        VC_out           <= vc_selected;
      end
      else if (Grant_to_W)
      begin
        flit             <= Flit_W;
        BroadcastFlitOut <= BroadcastFlit_W;
        FlitTypeOut      <= FlitType_W;
        Valid            <= 1'b1;
        phit_number      <= 7'b0;
        VC_out           <= vc_selected;
      end
      else if (Grant_to_S)
      begin
        flit             <= Flit_S;
        BroadcastFlitOut <= BroadcastFlit_S;
        FlitTypeOut      <= FlitType_S;
        Valid            <= 1'b1;
        phit_number      <= 7'b0;
        VC_out           <= vc_selected;
      end
      else if (Grant_to_L)
      begin
        flit             <= Flit_L;
        BroadcastFlitOut <= BroadcastFlit_L;
        FlitTypeOut      <= FlitType_L;
        Valid            <= 1'b1;
        phit_number      <= 7'b0;
        VC_out           <= vc_selected;
      end
      else
      begin
        if (phit_number < LAST_PHIT)
        begin
          Valid          <= 1'b1;
          phit_number    <= phit_number + 7'b1;
          VC_out         <= vc_selected;
        end
        else
        begin
          VC_out         <= vc_selected;
          Valid          <= 1'b0;
        end
      end
    end
endmodule
