// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file routing_algorithm_xy.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date April 1st, 2024
//
// @title Register Bank
//
//  This module implements the register bank of the 5-stage pipelined router.
//
//  The module accepts Switch configuration data from external agents 
//
//  The Regbank provides the switch with:
//    LBDR routing bits of the different VNs. All VCs of the same VN share the same LBDR bits. LBDR bit are different for each VN.
//        LBDR XY routing bits are loaded after reset. User can later update LBDR bits registers via configuration port.
//        In such case, all routers share the same Routing bit values, the only difference is in the connectivity bits 
//        which depend on the physical position of the node in the NoC
//          Rne = 1'b0;
//          Rnw = 1'b0;
//          Ren = 1'b1;
//          Res = 1'b1;
//          Rwn = 1'b1;
//          Rws = 1'b1;
//          Rse = 1'b0;
//          Rsw = 1'b0;
//
//
// operation input interface. AXI handshake compliant
// tdata port data format
//
// +------------------------------------------------------------------+
// |   COMMAND_ID   |   REGISTER_ID   |            PAYLOAD            |
// |------------------------------------------------------------------+
// Configuration values for COMMAND_ID, REGISTER_FILE depth set on filereg.h
//
// Bitfield for REGISTER write command  
// +------------------------------------------------------------------+
// |   COMMAND_WR   |   REGISTER_ID   |            DATA               |
// |------------------------------------------------------------------+
// Bitfield for REGISTER read command  
// +------------------------------------------------------------------+
// |   COMMAND_RD   |   REGISTER_ID   |           SOURCE_ID           |
// |------------------------------------------------------------------+ 
//
// This module shows AXI compliant interface ports with valid/ready handshake.
// This module accepts write and read operations to all the registers.
// In case a read operation can not be served, then the next read operation will block the module until the pending read operation can be attended by the subordinate module
//    In such scenario, the module can attend any write operation received between the first read operation (to be served yet) and the blocking read operation request.
//    In such scenario, the content of the register entry requested in the first (to be serverd yet) read operation will be stored in an output register, so the returned value
//                      will match the entry value when the read operation was requested 
//
// NOTE: Upon reset, LBDR XY configuration is loaded in table for all VNs
//
// TO:DO
//   provide configuration data to differnt modules of the router and also collects statistis information


`timescale 1ns / 1ps

`include "net_common.h"
`include "routing_algorithm_lbdr_2d.h"
`include "filereg.h"


module filereg #(
  parameter integer NodeId            = 0, //! Node Identifier
  parameter integer NodeIdWidth       = 0, //! Node Identifier
  parameter integer NodesInXDimension = 0, //! Number of nodes per row (number of columns)
  parameter integer NodesInYDimension = 0, //! Number of nodes per column (number of rows)
  parameter integer DimensionXWidth   = 0, //! Number of bits required to represent the coordinates of a node in X-axis
  parameter integer DimensionYWidth   = 0, //! Number of bits required to represent the coordinates of a node in Y-axis
  parameter [`AXIS_DIRECTION_WIDTH-1:0]  NodeIdIncreaseXAxis = `DIRECTION_EAST,   //! Node ID increment direction in X axis  Supported values: EASTWARDS WESTWARDS
  parameter [`AXIS_DIRECTION_WIDTH-1:0]  NodeIdIncreaseYAxis = `DIRECTION_NORTH,  //! Node ID increment direction in Y axis. Supported values: NORTHWARDS SOUTHWARDS 
  parameter integer LBDRNumberOfBits = 0,
  //
  parameter FileRegCommandIdWidth = num_bits(`FILEREG_NUMBER_OF_COMMANDS - 1), // Number of bits required to encode the command code. The module currently supports 2 commands: Read and Write
  parameter FileRegDepth          = `FILEREG_NUMBER_OF_ENTRIES,
  parameter FileRegEntryIdWidth   = num_bits(FileRegDepth-1),
  parameter FileRegEntryWidth     = `FILEREG_ENTRY_WIDTH,  // Size in bits for each entry of the Register File (paylad in tdata input port)


  parameter integer NumberOfPorts = 0,  //! number of ports in the router N-E-W-S-L
  parameter integer NumberOfVNs   = 1,
  //
  //parameter LBDRNumberOfRoutingBits      = 12,
  //parameter LBDRNumberOfConnectivityBits = 4,
  //localparam LBDRNumberOfBits             = LBDRNumberOfRoutingBits + LBDRNumberOfConnectivityBits,
  localparam LBDRBitsPortWidth            = LBDRNumberOfBits * NumberOfVNs, // {(NUM_VNs){ROUTING_BITS, CONNECTIVITY_BITS}}
  localparam NumberOfColumns              = NodesInXDimension,
  localparam NumberOfRows                 = NodesInYDimension,
  //
  //localparam FileRegCommandIdWidth = num_bits(`FILEREG_NUMBER_OF_COMMANDS - 1), // Number of bits required to encode the command code. The module currently supports 2 commands: Read and Write
  //localparam FileRegDepth          = `FILEREG_NUMBER_OF_ENTRIES,
  //localparam FileRegEntryIdWidth   = num_bits(FileRegDepth-1),
  //localparam FileRegEntryWidth     = `FILEREG_ENTRY_WIDTH,  // Size in bits for each entry of the Register File (paylad in tdata input port)
  
  localparam current_data_lsb      = 0,
  localparam current_data_msb      = current_data_lsb + FileRegEntryWidth - 1,
  localparam current_entry_id_lsb  = current_data_msb + 1,
  localparam current_entry_id_msb  = current_entry_id_lsb + FileRegEntryIdWidth - 1,
  localparam current_operation_lsb = current_entry_id_msb + 1,
  localparam current_operation_msb = current_operation_lsb + FileRegCommandIdWidth - 1,

  localparam OperationTDataWidth    = FileRegCommandIdWidth + FileRegEntryIdWidth + FileRegEntryWidth,
  localparam SourceIdWidth          = NodeIdWidth,
  localparam RegisterReadWidth      = SourceIdWidth + FileRegEntryWidth
  ) (
  input clk_i,
  input rst_i,
  //
  input                             filereg_m_tvalid_i,
  input   [OperationTDataWidth-1:0] filereg_m_tdata_i,
  input                             filereg_m_tlast_i,    //! port available but signal is not processed (safely ignored)
  output                            filereg_m_tready_o,   //! module can accpet requests
  //
  input                             filereg_s_tready_i,
  output                            filereg_s_tvalid_o,
  output [RegisterReadWidth-1:0]    filereg_s_tdata_o,     //! register data and destination id to return the register data
  output                            filereg_s_tlast_o,     //! always active, this module expects single frame streams
  // 
  output  [LBDRBitsPortWidth-1:0]   lbdr_bits_bus_o    //! lbdr configuration bits. All bits of all VNs
  // stats input: flits crossing the ports flag
  // stats output: flits crossing the ports, input bypass
  );

  // tlast ports currently not processed
  // input is ignored
  // output is always set to one
  assign filereg_s_tlast_o = 1'b1;
  assign filereg_s_tdata_o = tdata_r;
  
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

  // Let's set the LBDR XY default values for "after reset" state.
  wire Rne, Rnw, Ren, Res, Rwn, Rws, Rse, Rsw;
  wire Cn, Ce, Cw, Cs;
  wire [LBDRNumberOfBits-1:0] lbdr_entry_default;

  /////////////////////////////////////////////////////////////////////////////
  // Set current node position in NoC to determine its connectivity 
  // to calculate the "after reset" default values
  // MESSAGE 
  //
  // @ratorga @jorocgon :
  //   move this part of code to top level module
  // this part is calculated in each routing_vc module
  // and now in this module too.
  localparam DIMX = NodesInXDimension;                            //! Number of tiles in X-dimension of the NoC
  localparam DIMY = NodesInYDimension;                            //! Number of tiles in Y-dimension of the NoC
  localparam DIMX_w = DimensionXWidth > 0 ? DimensionXWidth : 1;  //! DIMX width
  localparam DIMY_w = DimensionYWidth > 0 ? DimensionYWidth : 1;  //! DIMY width
  localparam ID_SIZE = NodeIdWidth;                       //! ID width

  //current node coordinates computation
  localparam [DIMX_w-1 : 0] x_cur = (DimensionXWidth > 0) ? NodeId[DIMX_w-1:0] : 1'b0;
  localparam [DIMY_w-1 : 0] y_cur = (DimensionYWidth > 0) ? NodeId[DIMY_w+DIMX_w-1:DIMX_w] : 1'b0;
  
  /////////////////////////////////////////////////////////////////////////////

  // LBDR XY routing bits. They are the same for all nodes 
  assign Rne = 1'b0;
  assign Rnw = 1'b0;
  assign Ren = 1'b1;
  assign Res = 1'b1;
  assign Rwn = 1'b1;
  assign Rws = 1'b1;
  assign Rse = 1'b0;
  assign Rsw = 1'b0;
 
  // LBDR connectivity bits. They depend on phsyical position of the node in the mesh
  if ( ((NodeIdIncreaseXAxis == `DIRECTION_EAST) && (x_cur <= 0)) || ((NodeIdIncreaseXAxis == `DIRECTION_WEST) && (x_cur >= (NumberOfColumns - 1))) )
    assign Cw = 1'b0;
  else
    assign Cw = 1'b1;
  // rightmost column
  if ( ((NodeIdIncreaseXAxis == `DIRECTION_EAST) && (x_cur >= (NumberOfColumns - 1))) || ((NodeIdIncreaseXAxis == `DIRECTION_WEST) && (x_cur <= 0)) )
    assign Ce = 1'b0;
  else
    assign Ce = 1'b1;
  
  // y dim -> Cn, Cs
  // lowermost
  if ( ((NodeIdIncreaseYAxis == `DIRECTION_NORTH) && (y_cur <= 0)) || ((NodeIdIncreaseYAxis == `DIRECTION_SOUTH) && (y_cur >= (NumberOfRows - 1))) )
    assign Cs = 1'b0;
  else
    assign Cs = 1'b1;
  
  // uppermost
  if ( ((NodeIdIncreaseYAxis == `DIRECTION_NORTH) && (y_cur >= (NumberOfRows - 1))) || ((NodeIdIncreaseYAxis == `DIRECTION_SOUTH) && (y_cur <= 0)) )
    assign Cn = 1'b0;
  else
    assign Cn = 1'b1;
      
  //assign lbdr_entry_default = {Rne, Rnw, Ren, Res, Rwn, Rws, Rse, Rsw, Cn, Ce, Cw, Cs};
  assign lbdr_entry_default[`LBDR_2D_BIT_RNE] = Rne;
  assign lbdr_entry_default[`LBDR_2D_BIT_RNW] = Rnw;
  assign lbdr_entry_default[`LBDR_2D_BIT_REN] = Ren;
  assign lbdr_entry_default[`LBDR_2D_BIT_RES] = Res;
  assign lbdr_entry_default[`LBDR_2D_BIT_RWN] = Rwn;
  assign lbdr_entry_default[`LBDR_2D_BIT_RWS] = Rws;
  assign lbdr_entry_default[`LBDR_2D_BIT_RSE] = Rse;
  assign lbdr_entry_default[`LBDR_2D_BIT_RSW] = Rsw;
  assign lbdr_entry_default[`LBDR_2D_BIT_CN]  = Cn;
  assign lbdr_entry_default[`LBDR_2D_BIT_CE]  = Ce;
  assign lbdr_entry_default[`LBDR_2D_BIT_CW]  = Cw;
  assign lbdr_entry_default[`LBDR_2D_BIT_CS]  = Cs;
  // end of LBDR XY default bits configuration 

  // LBDR register initialization is preferrably done in reset
  // Initial block is allowed in simulation and is synthesizable on some architectures as 
  // Xilinx FPGA and CPLD.
  // But not used here to avoid incompatibilities
  //
  //reg [LBDRBitsPortWidth-1:0] lbdr_bits = {(NumberOfVNs){lbdr_entry_default}};
  //
  // or
  //
  //initial begin
  //  lbdr_bits = {(NumberOfVNs){lbdr_entry_default}};;
  //end
  //
  // or
  //
  //integer i
  //initial begin
  //  for (i = 0; i < NumberOfVNs; i++) begin
  //    lbdr_bits[NumberOfLBDRBits*i+:NumberOfLBDRBits] = lbdr_entry_default;
  //  end
  //end
  
  reg [FileRegEntryWidth-1:0]  FileRegisterArray[FileRegDepth-1:0];     // File register bank

  //assign lbdr_bits_bus_o;
  genvar gen_it_i;
  generate begin: lbdr_outports_linkage
    for (gen_it_i = 0; gen_it_i < NumberOfVNs; gen_it_i = gen_it_i + 1) begin
      assign lbdr_bits_bus_o[LBDRNumberOfBits * gen_it_i +: LBDRNumberOfBits] = FileRegisterArray[gen_it_i];
    end
  end
  endgenerate

  // 
  reg  [FileRegCommandIdWidth-1:0] current_operation_command;
  reg  [FileRegEntryIdWidth-1:0]   current_operation_entry_id;
  reg  [FileRegEntryWidth-1:0]     current_operation_data;
  
  wire [FileRegCommandIdWidth-1:0] current_operation_command_w;
  wire [FileRegEntryIdWidth-1:0]   current_operation_entry_id_w;
  wire [FileRegEntryWidth-1:0]     current_operation_data_w;

  assign current_operation_command_w   =  filereg_m_tdata_i[current_operation_msb:current_operation_lsb];
  assign current_operation_entry_id_w  =  filereg_m_tdata_i[current_entry_id_msb:current_entry_id_lsb];
  assign current_operation_data_w      =  filereg_m_tdata_i[current_data_msb:current_data_lsb];

  localparam FSM_STATE_IDLE    = 2'b00;
  localparam FSM_STATE_BUSY    = 2'b01; // processing operation 
  localparam FSM_STATE_STALLED = 2'b11; // data ready for return after read operation but next module cannot accept data

  // logic to handle operation requests (read/write)
  reg [1:0] fsm_operation_current_state;
  reg [1:0] fsm_operation_next_state;
  
  integer i;

  always @(posedge clk_i) begin
    if (rst_i) begin
      fsm_operation_current_state = FSM_STATE_IDLE;
    end else begin
      fsm_operation_current_state = fsm_operation_next_state;
    end
  end
  
  // update received command and data when system is not stalled or always ??
  // when system is stalled AXI specifies that sender must keep data values 
  always @(posedge clk_i) begin
    //if (filereg_m_tready_o) begin
      current_operation_command   =  current_operation_command_w;
      current_operation_entry_id  =  current_operation_entry_id_w; 
      current_operation_data      =  current_operation_data_w;
    //end
  end
  

  reg [8*10-1:0] fsm_operation_state_string;
  reg [8*10-1:0] fsm_register_state_string;
  
  function [8*10:0] operation_state_to_str;
    input integer value;
    begin
      case (value)
        FSM_STATE_IDLE:
          operation_state_to_str={"OP_IDLE"};
        FSM_STATE_BUSY:
          operation_state_to_str={"OP_BUSY"};
        FSM_STATE_STALLED:
          operation_state_to_str={"OP_STALLED"};
        default:
          operation_state_to_str={"OP_unknown"};
      endcase
    end
  endfunction
  
  always @(fsm_operation_current_state) begin
    fsm_operation_state_string <= operation_state_to_str(fsm_operation_current_state);
  end
  
  
  always @(*) begin
    fsm_operation_next_state = fsm_operation_current_state;

    case (fsm_operation_current_state)
      FSM_STATE_IDLE: begin
        if(filereg_m_tvalid_i) begin
          fsm_operation_next_state = FSM_STATE_BUSY;
        end else begin
          fsm_operation_next_state = FSM_STATE_IDLE;
        end
      end

      FSM_STATE_BUSY: begin
        if (filereg_s_tready_i) begin
          if (filereg_m_tvalid_i) begin
            fsm_operation_next_state = FSM_STATE_BUSY;
          end else begin
             fsm_operation_next_state = FSM_STATE_IDLE;
          end
        end else begin // filereg_s_tready_i = 0  --> next module cannot accept data
          if(filereg_m_tvalid_i && (current_operation_command_w == `FILEREG_COMMAND_WRITE)) begin
            fsm_operation_next_state = FSM_STATE_BUSY;
          end else if (filereg_m_tvalid_i && (current_operation_command_w == `FILEREG_COMMAND_READ)) begin
            fsm_operation_next_state = FSM_STATE_STALLED;
          end else begin
            // operation_valid_i = 0  or unknown command (not processing it)
            fsm_operation_next_state = FSM_STATE_IDLE;
          end
        end
      end

      FSM_STATE_STALLED: begin
        // read operation pending to return data to next module, but it cannot accpet data
        if (filereg_s_tready_i) begin
            fsm_operation_next_state = FSM_STATE_BUSY;
        end else begin
             fsm_operation_next_state = FSM_STATE_STALLED;
        end
      end

      default: begin
        fsm_operation_next_state = FSM_STATE_IDLE;
      end
    endcase
  end

  assign filereg_m_tready_o =     (fsm_operation_current_state == FSM_STATE_IDLE)
                              || ((fsm_operation_current_state == FSM_STATE_BUSY) && (current_operation_command_w == `FILEREG_COMMAND_WRITE))
                              || ((fsm_operation_current_state == FSM_STATE_BUSY) && (current_operation_command_w == `FILEREG_COMMAND_READ) && filereg_s_tready_i);

  //
  // Reset logic and write registers logic
  // enable write logic always, even if a read operation is pending
  always @(posedge clk_i) begin
    if (rst_i) begin
      // SET LBDR bit to default values: XY 
      //lbdr_bits <= {(NumberOfVNs){lbdr_entry_default}};
      for (i = 0; i < FileRegDepth; i = i +1) begin
        if ( i < NumberOfVNs) begin
          FileRegisterArray[i] = {{(FileRegEntryWidth - LBDRNumberOfBits){1'b0}}, lbdr_entry_default};
        end else begin
          FileRegisterArray[i] = {(FileRegEntryWidth){1'b0}};
        end
      end
    end else begin
      if (filereg_m_tvalid_i && filereg_m_tready_o) begin
        if (current_operation_command == `FILEREG_COMMAND_WRITE) begin
          FileRegisterArray[current_operation_entry_id] <= current_operation_data;
        end
      end
    end
  end

  // 
  // READ registers logic
  localparam FSM_REGISTER_STATE_IDLE         = 2'b00;
  localparam FSM_REGISTER_STATE_DATA_UPDATE  = 2'b01; // update data output register value and set tvalid to one 
  localparam FSM_REGISTER_STATE_STALLED      = 2'b11; // data ready for output, but next module cannot accept data

  // logic to handle operation requests (read/write)
  reg [1:0] fsm_register_current_state;
  reg [1:0] fsm_register_next_state;

  
  reg [RegisterReadWidth-1:0]      tdata_r; // registered copy of data out
 
  // JM10 debugging
  wire cmd_is_read  = filereg_m_tvalid_i && (current_operation_command_w == `FILEREG_COMMAND_READ);
  wire cmd_is_write = filereg_m_tvalid_i && (current_operation_command_w == `FILEREG_COMMAND_WRITE);
  // JM10 debugging - end of block
  
  always @(posedge clk_i) begin
    if (rst_i) begin
      fsm_register_current_state = FSM_REGISTER_STATE_IDLE;
    end else begin
      fsm_register_current_state = fsm_register_next_state;
    end
  end

  always @(*) begin
    fsm_register_next_state = fsm_register_current_state;
    case (fsm_register_current_state)
      FSM_REGISTER_STATE_IDLE: begin
        if(filereg_m_tvalid_i && (current_operation_command_w == `FILEREG_COMMAND_READ) ) begin
          fsm_register_next_state = FSM_REGISTER_STATE_DATA_UPDATE;
        end else begin
          fsm_register_next_state = FSM_REGISTER_STATE_IDLE;
        end
      end

      FSM_REGISTER_STATE_DATA_UPDATE: begin
        if (filereg_s_tready_i) begin
          if (filereg_m_tvalid_i  && (current_operation_command_w == `FILEREG_COMMAND_READ)) begin
            fsm_register_next_state = FSM_REGISTER_STATE_DATA_UPDATE;
          end else begin
            fsm_register_next_state = FSM_REGISTER_STATE_IDLE;
          end
        end else begin // filereg_s_tready_i = 0  --> next module cannot accept data
          fsm_register_next_state = FSM_REGISTER_STATE_STALLED;
        end
      end

      FSM_REGISTER_STATE_STALLED: begin
        // read operation pending to return data to next module, but it cannot accpet data
        if (filereg_s_tready_i) begin
          if (filereg_m_tvalid_i  && (current_operation_command_w == `FILEREG_COMMAND_READ)) begin
            fsm_register_next_state = FSM_REGISTER_STATE_DATA_UPDATE;
          end else begin
            fsm_register_next_state = FSM_REGISTER_STATE_IDLE;
          end
        end else begin
          fsm_register_next_state = FSM_REGISTER_STATE_STALLED;
        end
      end

      default: begin
        fsm_register_next_state = FSM_REGISTER_STATE_IDLE;
      end
    endcase
  end
  
  assign filereg_s_tvalid_o  =  (fsm_register_current_state == FSM_REGISTER_STATE_DATA_UPDATE)
                            || (fsm_register_current_state == FSM_REGISTER_STATE_STALLED);


  always @(posedge clk_i) begin
    if (rst_i) begin
      // currently do nothing on reset
    end else begin
      if (fsm_register_next_state == FSM_REGISTER_STATE_DATA_UPDATE) begin
        tdata_r <= FileRegisterArray[current_operation_entry_id_w];
      end
    end
  end



endmodule

