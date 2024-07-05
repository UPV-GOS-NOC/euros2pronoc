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

//! This module implements the switch allocation stage when virtual channels and virtual networks are used. This module is used by the SWITCH_VC module. 
//!
//! The module receives a vector of requests from every incoming port (NORTH, EAST, WEST, SOUTH, and LOCAL). Each request vector is made of one bit per 
//! virtual channel supported at the input port. There are VC virtual channels per virtual network and VN virtual networks. Therefore, each input port
//! supports VN x VC virtual channels. The module performs the allocation stage in order to grant access to one request to the output port.
//!
//! Stop & Go signals for every potential virtual channel at the downstream or switch are received as input. In case one request has a virtual channel stopped, then
//! the request is filtered out and not granted. Notice that this module can be implemented on a LOCAL output port. In that case, only one VC per VN is supported. In this
//! case the number of Stop&Go signals is VC (instead of VN x VC in the other type of ports).
//!
//! Additionaly, the module receives a GoPhit signal from the associated output module. This signal, when set to zero means the output port needs more cycles to transmit
//! the current assigned data to transmit (since one flit needs an amount of phit cycles to be transmited). In that case, the module does not grant any request.
//!
//! The module supports two modes. Round-robin arbitration or weighted arbitration. With weighted arbitration the module receives a vector of weights (one element per VN) and 
//! applies those weights, thus granting more bandwidth to specific VNs). In round-robin mode the module performs a fair round-robin arbitration between VNs. The Weighted arbitration
//! is enabled with the ENABLE_VN_WEIGHTS_SUPPORT parameter.
//!
//! Virtual channels currently assigned to input requests are received as an input (from the VA_VC module). Therefore, the module retrieves the specific VC requested by each input port request vector.
//! 
//! A grant vector with one bit per VN x VC x Port is outputed. Only one bit will be set taking into account the arbitration policy (round robin or weighted arbitration). The
//! assigned virtual channel to be used at the downstream switch or endnode is outputed also to the OUTPUT module (TODO: check this goes to OUTPUT really).

module SA_VC #( 
  parameter Port                      = 0,                                     //! Port type (Local, North, East, West, or South)
  parameter FLIT_SIZE                 = 64,                                    //! Flit size in bits
  parameter FLIT_TYPE_SIZE            = 2,                                     //! Flit type size in bits
  parameter BROADCAST_SIZE            = 5,                                     //! Broadcast size in bits
  parameter NUM_VC                    = 1,                                     //! Number of Virtual Channels supported for each Virtual Network
  parameter NUM_VN                    = 3,                                     //! Number of Virtual Networks supported 
  parameter VN_WEIGHT_VECTOR_w        = 20,                                    //! Weight vector width in bits
  parameter ENABLE_VN_WEIGHTS_SUPPORT = "no",                                  //! Enable for weight vector support
  parameter NUM_PORTS                 = 5,                                     //! Number of ports in the switch
  localparam VN_X_VC_w                  = Log2_w(NUM_VC * NUM_VN),                                 //! width for a VNxVC identifier
  localparam NUM_VN_X_VC                = NUM_VN * NUM_VC,                                         //! number of VNxVCs
  localparam VN_w                       = Log2_w(NUM_VN),                                          //! width for a VN identifier
  localparam NUM_VN_X_VC_AND_PORTS = NUM_VN_X_VC * NUM_PORTS,                   //! Number of signals per port and each signal have one bit per VC  
  localparam long_vector_grants_id = 3 * NUM_VN_X_VC,                           //! Number of bits needed to save the port id which is granted in each VC
  localparam bits_VN = Log2_w(NUM_VN),
  localparam NUM_PORTS_w = Log2_w(NUM_PORTS),							        //! Number of bits needed to code NUM_PORTS number
  localparam bits_VC = Log2_w(NUM_VC),                                          //! Number of bits needed to code NUM_VC number  
  localparam bits_VN_X_VC_AND_PORTS = Log2_w(NUM_VN_X_VC_AND_PORTS),            //! Number of bits needed to code NUM_VC number      
  localparam long_VC_assigns = ((bits_VN_X_VC_AND_PORTS+1) * NUM_VN_X_VC),      //! Bits neded to store bidimensional array like //{E*NUM_VC, S*NUM_VC, W*NUM_VC, N*NUM_VC, L*NUM_VC}, in Verilog is not supported a I/O bidimensional array port           
  localparam bits_VN_X_VC = Log2_w(NUM_VN_X_VC)
)(
  input [NUM_VN_X_VC-1 : 0]                                 REQ_E,             //! request vector from EAST port
  input [NUM_VN_X_VC-1 : 0]                                 REQ_S,             //! request vector from SOUTH port 
  input [NUM_VN_X_VC-1 : 0]                                 REQ_W,             //! request vector from WEST port
  input [NUM_VN_X_VC-1 : 0]                                 REQ_N,             //! request vector from NORTH port
  input [NUM_VN_X_VC-1 : 0]                                 REQ_L,             //! request vector from LOCAL port
  input [((Port==`PORT_L) ? NUM_VN : NUM_VN_X_VC)-1 : 0]    SG,                //! Stop & Go signals from downstream switch/endnode
  input [VN_WEIGHT_VECTOR_w-1:0]                            WeightsVector_in,  //! Weight vector for the arbiter (one weight per VN)
  input                                                     GoPhit,            //! GoPhit signal from output module (blocks grants)
  input [long_VC_assigns-1:0]                               VC_assigns_in,     //! Current assigns to virtual channels. Each port is using one VC. [bits_VC_AND_PORTS-1:0] VC_assigns [NUM_VC-1:0]-->{E*NUM_VC, S*NUM_VC, W*NUM_VC, N*NUM_VC, L*NUM_VC}
  output reg [NUM_VN_X_VC_AND_PORTS-1 : 0]                  GRANTS,            //! Grant access vector to output port. This signal goes to the RT module and the OUTPUT module 
  output reg [bits_VN_X_VC-1:0] vc_selected_out,                               //! VC channel assigned to each grant
  input                                                     clk,               //! clock signal
  input                                                     rst_p              //! reset signal
);

`include "common_functions.vh"

wire [NUM_VN_X_VC_AND_PORTS-1 : 0] REQ = {REQ_E, REQ_S, REQ_W, REQ_N, REQ_L};
wire [NUM_VN_X_VC_AND_PORTS-1 : 0] REQ_filtered;
wire [(bits_VN_X_VC*NUM_VN_X_VC_AND_PORTS)-1:0] vector_this_vc_selected;
genvar i,j;
generate
  for(i=0; i<NUM_VN_X_VC_AND_PORTS;i = i+1)begin  : ME
    wire [bits_VN_X_VC_AND_PORTS:0] this_REQ_id;
    wire [NUM_VN_X_VC-1:0] this_channel;
    wire [bits_VN_X_VC-1:0] this_vc_selected;
  end//for
endgenerate

generate
  for(i=0; i<NUM_VN_X_VC_AND_PORTS;i = i+1) begin
    // Get REQ_id
    assign ME[i].this_REQ_id = (REQ[i])?i:{(bits_VN_X_VC_AND_PORTS+1){1'b1}};
    // Get matching REQ_id into vector VC_assigns
    for(j=0; j<NUM_VN_X_VC;j = j+1) begin
      assign ME[i].this_channel[j] = ((VC_assigns_in[(j*(bits_VN_X_VC_AND_PORTS+1)+(bits_VN_X_VC_AND_PORTS))-:(bits_VN_X_VC_AND_PORTS+1)]==ME[i].this_REQ_id) & (REQ[i]));//|
    end

    encoder #( //Get this_vc_selected
      .lenght_in(NUM_VN_X_VC),
      .lenght_out(bits_VN_X_VC)       
    ) encoder_64_channel (
      .vector_in(ME[i].this_channel),
      .vector_id(ME[i].this_vc_selected)
    );
    assign vector_this_vc_selected[(i * bits_VN_X_VC) + (bits_VN_X_VC - 1)-:bits_VN_X_VC] = ME[i].this_vc_selected;
    assign REQ_filtered[i] = (REQ[i] & (SG[((Port==`PORT_L) ? (ME[i].this_vc_selected / NUM_VC) : ME[i].this_vc_selected)]) & GoPhit);
  end
endgenerate

wire [NUM_VN_X_VC-1 : 0]  REQ_N_filtered = REQ_filtered[(1 * NUM_VN_X_VC) + (NUM_VN_X_VC - 1)-:NUM_VN_X_VC];
wire [NUM_VN_X_VC-1 : 0]  REQ_E_filtered = REQ_filtered[(4 * NUM_VN_X_VC) + (NUM_VN_X_VC - 1)-:NUM_VN_X_VC];
wire [NUM_VN_X_VC-1 : 0]  REQ_W_filtered = REQ_filtered[(2 * NUM_VN_X_VC) + (NUM_VN_X_VC - 1)-:NUM_VN_X_VC];
wire [NUM_VN_X_VC-1 : 0]  REQ_S_filtered = REQ_filtered[(3 * NUM_VN_X_VC) + (NUM_VN_X_VC - 1)-:NUM_VN_X_VC];
wire [NUM_VN_X_VC-1 : 0]  REQ_L_filtered = REQ_filtered[(0 * NUM_VN_X_VC) + (NUM_VN_X_VC - 1)-:NUM_VN_X_VC];
//----------------------------------------------------------------------------------------------------------------------------------------------------------------

wire [VN_WEIGHT_VECTOR_w-1:0] WEIGTHS;
reg [3:0] pointer_weigths;
wire [bits_VN-1:0] WEIGTH;
wire [(NUM_VN_X_VC*NUM_PORTS)-1:0] vector_grant_to_end;
wire [NUM_VN_X_VC-1:0] vector_grants_in_to_RR_prio_not_zeros;
wire [long_vector_grants_id-1:0] vector_grants_id_to_end;
wire [NUM_VN_X_VC-1:0] vector_in_RR_prio;
wire [NUM_VN_X_VC-1:0] grants_in_RR_prio;
wire [bits_VN_X_VC-1:0] grants_in_id_RR_prio;
wire GRANTS_DONE;
wire [NUM_VN_X_VC-1:0] GRANTS_IN_RR_prio;
wire [NUM_VN_X_VC-1:0] grants_in_RR_P_per_VN;
wire [(bits_VN_X_VC*NUM_VN)-1:0] grants_in_id_RR_P_per_VN;
wire [NUM_VN-1:0] grants_for_VN;
wire grants_for_VN_WEIGHTED;
wire no_grants_for_VN_WEIGHTED;
wire [NUM_VN-1:0] grants_in_RR_VN;
wire [bits_VN-1:0] grants_in_id_RR_VN;
wire [NUM_VN-1:0] GRANTS_IN_RR_VN;
wire [2:0] grants_in_id_after_prio;
wire [NUM_PORTS-1:0] grants_in_after_prio;
wire [NUM_VN_X_VC_AND_PORTS-1:0] grants_in;
wire [bits_VN_X_VC_AND_PORTS-1:0] grants_in_id;


generate

  // --------------------------------------------------------------------------------------
  // Weighted arbitration support begins here
  //
  if (ENABLE_VN_WEIGHTS_SUPPORT == "yes") begin
    //Once the request signals are filtered, we select for each virtual channel in each virtual network WICH PORT will have the chance to be granted.

    //This vector (WEIGTHS), will give priotities for some virtual channels in the round robin arbiter. Its token will be updated with one of the weigths each time gives any grant
    assign WEIGTHS = WeightsVector_in;
    assign WEIGTH = WEIGTHS[(pointer_weigths * bits_VN) + (bits_VN - 1)-:bits_VN];

    for (j=0; j<NUM_VN_X_VC; j=j+1) begin : VN_X_VC
      wire [NUM_PORTS-1:0] vector_in;
      wire [NUM_PORTS-1:0] GRANTS_IN_RR;
      wire [NUM_PORTS-1:0] grants_in;                 // Grants incomming from Arbiter
      wire [NUM_PORTS_w-1:0] grants_in_id;            // Position of incomming grant
      wire grants_in_not_zeros;                       // There is one grant for this channel
      wire [bits_VN-1:0] this_vn;
    end 

    for (i=0; i<NUM_VN_X_VC; i=i+1) begin
      assign VN_X_VC[i].this_vn = (i / NUM_VC);
      assign VN_X_VC[i].grants_in_not_zeros = (|{REQ_E_filtered[i], REQ_S_filtered[i], REQ_W_filtered[i], REQ_N_filtered[i], REQ_L_filtered[i]}) /*& (SG[((Port==`PORT_L) ? VN_X_VC[i].this_vn : i)])*/;
      assign VN_X_VC[i].vector_in = (/*(SG[((Port==`PORT_L) ? VN_X_VC[i].this_vn : i)]) & GoPhit &*/ VN_X_VC[i].grants_in_not_zeros ) ? {REQ_E_filtered[i], REQ_S_filtered[i], REQ_W_filtered[i], REQ_N_filtered[i], REQ_L_filtered[i]} : `V_ZERO(NUM_PORTS);
      assign VN_X_VC[i].GRANTS_IN_RR = ( GRANTS_DONE & grants_in_id_RR_prio == i) ? grants_in_after_prio : `V_ZERO(NUM_PORTS);

      RR_X_IN #(
        .IO_SIZE      ( NUM_PORTS               ),
        .IO_w         ( NUM_PORTS_w             ),
        .OUTPUT_ID    ( "yes"                   ),
        .SHUFFLE      ( "no"                    ),
        .SUFFLE_DIM_1 ( 1                       ),
        .SUFFLE_DIM_2 ( 1                       )
      ) round_robin_PORTS_IN (
        .vector_in    ( VN_X_VC[i].vector_in    ),
        .clk          ( clk                     ),
        .rst_p        ( rst_p                   ),
        .GRANTS_IN    ( VN_X_VC[i].GRANTS_IN_RR ),
        .vector_out   ( VN_X_VC[i].grants_in    ),
        .grant_id     ( VN_X_VC[i].grants_in_id )
      );

      assign vector_grants_in_to_RR_prio_not_zeros[i] = VN_X_VC[i].grants_in_not_zeros;
      assign vector_grant_to_end[((i*NUM_PORTS)+(NUM_PORTS-1))-:NUM_PORTS] = VN_X_VC[i].grants_in;
      assign vector_grants_id_to_end[((i*3)+(3-1))-:3] = VN_X_VC[i].grants_in_id;
    end

    assign vector_in_RR_prio = vector_grants_in_to_RR_prio_not_zeros;
    assign GRANTS_DONE = (|vector_in_RR_prio) ? 1'b1 : 1'b0;
    assign GRANTS_IN_RR_prio = (|grants_in_RR_prio) ? grants_in_RR_prio : `V_ZERO(NUM_VN_X_VC);

    //------------------------------------------------------------------------------------------------------------------------------------
    //The second step is to select WICH VIRTUAL CHANNEL of this port will have the chance to be granted
    for (j=0; j<NUM_VN; j=j+1) begin : P_per_VN
      wire [bits_VC-1:0] id_P_per_VN;
    end 

    for (j=0; j<NUM_VN; j=j+1) begin

      RR_X_IN #(
        .IO_SIZE      ( NUM_VC   ),
        .IO_w         ( bits_VC  ),
        .OUTPUT_ID    ( "yes"    ),
        .SHUFFLE      ( "no"     ),
        .SUFFLE_DIM_1 ( 1        ),
        .SUFFLE_DIM_2 ( 1        )
      ) round_robin_NUM_VC (
        .vector_in    ( vector_in_RR_prio[((j*NUM_VC)+(NUM_VC-1))-:NUM_VC]     ),
        .clk          ( clk                                                    ),
        .rst_p        ( rst_p                                                  ),
        .GRANTS_IN    ( GRANTS_IN_RR_prio[((j*NUM_VC)+(NUM_VC-1))-:NUM_VC]     ),
        .vector_out   ( grants_in_RR_P_per_VN[((j*NUM_VC)+(NUM_VC-1))-:NUM_VC] ),
        .grant_id     ( P_per_VN[j].id_P_per_VN                                )
      );
  
      assign grants_in_id_RR_P_per_VN[((j*bits_VN_X_VC)+(bits_VN_X_VC-1))-:bits_VN_X_VC] = (P_per_VN[j].id_P_per_VN + (j*NUM_VC)); //Corresponding id in REQ vector
    end 
    //------------------------------------------------------------------------------------------------------------------------------------
    //The third step is to select WICH VIRTUAL NETWORK considering the VN weighted (WEIGTHS vector).
    //In this part we must check wether VN weighted contains any grant or not.
    //Only in case there is no grants for VN weighted a Round-Robin arbiter will select wich VN will be the next one to check out for grants.
  
    //This RR will select the corresponding VN in case there is no grants for VN weighted
    for (j=0; j<NUM_VN; j=j+1) begin
      assign grants_for_VN[j] = (|grants_in_RR_P_per_VN[((j*NUM_VC)+(NUM_VC-1))-:NUM_VC]);  
    end 
    assign grants_for_VN_WEIGHTED = (|grants_in_RR_P_per_VN[((WEIGTH*NUM_VC)+(NUM_VC-1))-:NUM_VC]);                                                                                                                                                                 
    assign no_grants_for_VN_WEIGHTED = ~grants_for_VN_WEIGHTED;
    assign GRANTS_IN_RR_VN = /*{NUM_VN{GoPhit}} &*/ {NUM_VN{no_grants_for_VN_WEIGHTED}} & grants_in_RR_VN;  //These token is updated only when GoPhit and there is no grants from VN weighted
    RR_X_IN #(
      .IO_SIZE(NUM_VN),
      .IO_w(bits_VN),
      .OUTPUT_ID("yes"),
      .SHUFFLE("no"),
      .SUFFLE_DIM_1(1),
      .SUFFLE_DIM_2(1)
    ) round_robin_NUM_VN (
      .vector_in(grants_for_VN),
      .clk(clk),
      .rst_p(rst_p),
      .GRANTS_IN(GRANTS_IN_RR_VN),
      .vector_out(grants_in_RR_VN),     // Vector of grants corresponding VN granted in case there is no grant for VN weighted
      .grant_id(grants_in_id_RR_VN)     // VN granted in case there is no grant for VN weighted
    );
    //Once we have studied both cases is time to select the corresponding result
    assign grants_in_RR_prio = (|grants_in_RR_P_per_VN[((WEIGTH*NUM_VC)+(NUM_VC-1))-:NUM_VC]) ? {grants_in_RR_P_per_VN[((WEIGTH*NUM_VC)+(NUM_VC-1))-:NUM_VC] << (WEIGTH*NUM_VC)} : //Weigthed VN is granted
                               (|grants_in_RR_VN) ? { grants_in_RR_P_per_VN[((grants_in_id_RR_VN*NUM_VC)+(NUM_VC-1))-:NUM_VC] << (grants_in_id_RR_VN*NUM_VC)} :     //Different VN that weight is granted
                                                                                                                                          `V_ZERO(NUM_VN_X_VC);     //no one is granted
    
    assign grants_in_id_RR_prio = (|grants_in_RR_P_per_VN[((WEIGTH*NUM_VC)+(NUM_VC-1))-:NUM_VC]) ? grants_in_id_RR_P_per_VN[((WEIGTH*bits_VN_X_VC)+(bits_VN_X_VC-1))-:bits_VN_X_VC] : //Weigthed VN is granted
                                  (|grants_in_RR_VN) ? grants_in_id_RR_P_per_VN[((grants_in_id_RR_VN*bits_VN_X_VC)+(bits_VN_X_VC-1))-:bits_VN_X_VC] :                   //Different VN that weight is granted
                                                                                                                               `V_ZERO(bits_VN_X_VC);                   //no one is granted
    
    assign grants_in_id_after_prio = (GRANTS_DONE) ? vector_grants_id_to_end[((grants_in_id_RR_prio*3)+(3-1))-:3] : `V_ZERO(3);
    assign grants_in_after_prio = (GRANTS_DONE) ? vector_grant_to_end[((grants_in_id_RR_prio*NUM_PORTS)+(NUM_PORTS-1))-:NUM_PORTS] : `V_ZERO(NUM_PORTS);
    //------------------------------------------------------------------------------------------------------------------------------------
    //Already filtered by WEIGHT
    assign grants_in = (|vector_grants_in_to_RR_prio_not_zeros) ? ((1'b1 << ((grants_in_id_after_prio * NUM_VN_X_VC) + grants_in_id_RR_prio) ) | `V_ZERO(NUM_VN_X_VC_AND_PORTS)) : `V_ZERO(NUM_VN_X_VC_AND_PORTS);
    assign grants_in_id = (|vector_grants_in_to_RR_prio_not_zeros) ? (((grants_in_id_after_prio * NUM_VN_X_VC) + grants_in_id_RR_prio) | `V_ZERO(bits_VN_X_VC_AND_PORTS)) : `V_ZERO(bits_VN_X_VC_AND_PORTS);
    //------------------------------------------------------------------------------------------------------------------------------------

  //
  // Weighted arbitration support ends here
  // --------------------------------------------------------------------------------------
  end else begin
    wire [NUM_VN_X_VC_AND_PORTS-1:0] vector_in;// = (REQ & go);
    for(i=0; i<NUM_VN_X_VC_AND_PORTS;i = i+1) begin                                
      assign vector_in[i] = (REQ_filtered[i]); // /*& (SG[((Port==`PORT_L) ? ((i%NUM_VN_X_VC)/NUM_VC) : (i%NUM_VN_X_VC))])*/ & GoPhit);//SG[]
    end                                        

    //wire [NUM_VN_X_VC_AND_PORTS-1:0] grants_in;           //Grants incomming from Arbiter
    wire [bits_VN_X_VC_AND_PORTS-1:0] grants_in_id;         //Position of incomming grant    
    wire [NUM_VN_X_VC_AND_PORTS-1:0] GRANTS_IN_RR = ( (|vector_in) /*& (|Channels_preselected)*//*grants_in_not_zeros*/) ? grants_in : `V_ZERO(NUM_VN_X_VC_AND_PORTS);

    RR_X_IN #(
      .IO_SIZE      ( NUM_VN_X_VC_AND_PORTS  ),
      .IO_w         ( bits_VN_X_VC_AND_PORTS ),
      .OUTPUT_ID    ( "yes"                  ),
      .SHUFFLE      ( "yes"                  ),
      .SUFFLE_DIM_1 ( NUM_PORTS              ),
      .SUFFLE_DIM_2 ( NUM_VN_X_VC            )
    ) ROUND_ROBIN_ARB_NUM_VN_X_VC_AND_PORTS (
      .vector_in    ( vector_in              ),
      .clk          ( clk                    ),
      .rst_p        ( rst_p                  ),
      .GRANTS_IN    ( GRANTS_IN_RR           ),
      .vector_out   ( grants_in              ),
      .grant_id     ( grants_in_id           )
    );
  end
endgenerate

wire [bits_VN_X_VC-1:0] vc_selected = vector_this_vc_selected[(grants_in_id * bits_VN_X_VC) + (bits_VN_X_VC - 1)-:bits_VN_X_VC];

always @(posedge clk) begin
  if (rst_p) begin
    GRANTS <= `V_ZERO(NUM_VN_X_VC_AND_PORTS);
    if (ENABLE_VN_WEIGHTS_SUPPORT == "yes") begin pointer_weigths <= `V_ZERO(4); end
  end
  else begin
    if (|grants_in) begin
      GRANTS <= grants_in;
      vc_selected_out <= vc_selected;
      if (ENABLE_VN_WEIGHTS_SUPPORT == "yes") begin
        pointer_weigths <= (pointer_weigths == 4'd9) ? 4'd0 : pointer_weigths + 4'd1;
      end
    end else begin
      GRANTS <= `V_ZERO(NUM_VN_X_VC_AND_PORTS);
    end
  end
end

endmodule
