// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_packet_creator.v  
// @author Jose Manuel Rocher Gonzalez (jorocgon@disca.upv.es)
// @date January 19th, 2024
// @title NoC Packet creator using AXI Stream inputs. 
//
// @description
//  This module creates NoC packets using AXI Stream signal inputs with 1-byte TDATA width.
//  NoC packet width (packet == flit), hereafter referred to as NocDataWidth, is set to 8 bytes.
//  The message size depends on the size of the AXI stream transmission.
//  The MaxPacketsEnable parameter limits this size to a maximum number of packets;
//  if this parameter is not enabled, it only depends on the TLAST AXI stream signal.
//  KeepEnable parameter enables TKEEP signal transmission. This module assumes continuous 
//  transmission (TKEEP always 1) but needs a padding field in HEADER_AND_TAIL and TAIL flits when
//  KeepEnable is set to 0.

`timescale 1 ns / 1 ps

module noc_packet_creator #
(
  parameter integer AxisDataWidth = 8,
  parameter integer NocDataWidth = 64,
  parameter integer NumVn = 3,
  parameter integer NumVc = 1,
  parameter integer flitTypeSize = 2,
  parameter integer KeepEnable = 0,
  parameter integer TIdWidth  = 8,
  parameter integer TDestWidth = 11,
  parameter integer MaxPacketsEnable = 0,
  parameter integer MaxPackets = 20,
  parameter integer NocBroadcastWidth = 1,
  parameter integer source_id = 11'b00000000001,
  parameter integer NocVirtualChannelIdWidth = 3,

  //localparam integer NumVnXVcWw = num_bits(NumVn*NumVc),
  localparam integer SrcDstWidth = TDestWidth * 2,
  localparam integer PaddWidthTail = 7,
  localparam integer PaddWidthHeader = 4,
  localparam integer PayloadSizeHeader = PaddWidthHeader,
  localparam integer PayloadSizeTail = PaddWidthTail,
  localparam integer PayloadSizeBody = 8
)
(
  input                                 s_axis_aclk,
  input                                 s_axis_arstn,
  input                                 clk_noc,
  input                                 rst_noc,
  
  // AXIS input
  input [AxisDataWidth-1:0]             s_axis_tdata,
  input                                 s_axis_tvalid,
  output                                s_axis_tready,
  input                                 s_axis_tlast,
  input [TIdWidth-1:0]                  s_axis_tid,
  input [TDestWidth-1:0]                s_axis_tdest,
  
  // Other AXIS inputs not used yet
  input                                 s_axis_tkeep, 
  input                                 s_axis_tstrb,
  input                                 s_axis_user,
  input                                 s_axis_twakeup,
  
  // NoC output
  output [NocDataWidth-1:0]             network_flit_o,
  output [NocBroadcastWidth-1:0]        network_broadcast_o,
  output [NocVirtualChannelIdWidth-1:0] network_vc_o,
  output                                network_valid_o,
  input                                 network_ready_i,
  output [flitTypeSize-1:0]             network_flit_type_o
);

  //----------------------------------------------------------------------------------------------
  // Local parameters definition

  // State encoding
  localparam HEADER           = 3'b001;
  localparam BODY             = 3'b010;
  localparam TAIL             = 3'b011;
  localparam HEADER_AND_TAIL  = 3'b101;
  localparam BODY_AND_TAIL    = 3'b110;
  localparam EMPTY_TAIL       = 3'b111;

  // Flit type encoding
  localparam HEADER_TYPE      = 3'b000;
  localparam BODY_TYPE        = 3'b001;
  localparam TAIL_TYPE        = 3'b010;
  localparam HEADTAIL_TYPE    = 3'b011;
  localparam EMPTY_TAIL_TYPE  = 3'b111;
  

  // fifo_type_1_async_axis_wrapper parameters
  localparam AddressWidth         = 3;
  localparam FirstWordFallThrough = "true";
  localparam SynchStages          = 2;
  localparam FifoDepth            = 2**AddressWidth;
  localparam MTDataWidth = NocDataWidth + flitTypeSize + NocVirtualChannelIdWidth 
                           + NocBroadcastWidth;

  //----------------------------------------------------------------------------------------------
  // Functions Definition
  function integer num_bits(input integer value);
    begin
      num_bits = 0;
      for (num_bits = 0; value > 0; num_bits = num_bits + 1) begin
        value = value >> 1;
      end
    end
  endfunction
  
  //----------------------------------------------------------------------------------------------
  // Wires and Regs definition
  
  reg [2:0]                            next_state;
  reg [2:0]                            state;
  reg [TIdWidth-1:0]                   tid;
  reg                                  last;
  reg [PaddWidthTail-1:0]              padd;
  reg [NocDataWidth-1:0]               byte_buffer;
  reg [NocDataWidth-1:0]               flit_out;
  reg [SrcDstWidth-1:0]                header;
  reg [2:0]                            byte_counter;
  reg                                  sending_flit_buffer_input;
  reg                                  stored_flit_to_send;
  reg [flitTypeSize:0]                 flit_type;
  reg [flitTypeSize-1:0]               flit_type_out;

  wire                                 write_to_buffer_reg;
  wire [NocDataWidth-1:0]              fsm_flit;
  wire                                 fsm_broadcast;
  wire                                 fsm_valid;
  wire [flitTypeSize-1:0]              fsm_flit_type;
  wire [MTDataWidth-1:0]               fsm_data;
  wire [NocVirtualChannelIdWidth-1:0]  fsm_vc;
  wire                                 wrapper_ready;
  wire [MTDataWidth-1:0]               m_wrapper_data;
  
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
    .s_axis_aclk     (s_axis_aclk),
    .s_axis_arstn    (s_axis_arstn),
    .s_axis_tid      (),
    .s_axis_tdest    (),
    .s_axis_tdata    (fsm_data),
    .s_axis_tvalid   (fsm_valid),
    .s_axis_tlast    (),
    .s_axis_tready   (wrapper_ready),
    .m_axis_aclk     (clk_noc),
    .m_axis_arstn    (!rst_noc),
    .m_axis_tid      (),
    .m_axis_tdest    (),
    .m_axis_tdata    (m_wrapper_data),
    .m_axis_tvalid   (network_valid_o),
    .m_axis_tlast    (),
    .m_axis_tready   (network_ready_i)
    );
    
  //----------------------------------------------------------------------------------------------
  // Assigns
  
  assign s_axis_tready = !stored_flit_to_send | wrapper_ready;
  assign fsm_valid = sending_flit_buffer_input | stored_flit_to_send;
  assign fsm_flit_type = stored_flit_to_send ? flit_type_out : flit_type[1:0];
  assign fsm_flit = stored_flit_to_send ? flit_out : 
                    ((flit_type == HEADER_TYPE)|(flit_type == HEADTAIL_TYPE)) ? 
                    {header, tid, last, padd[3:0], byte_buffer[31:0]} :
                    (((flit_type == BODY_TYPE) & KeepEnable) | (flit_type == TAIL_TYPE)) ? 
                    {last, padd, byte_buffer[55:0]} :
                    ((flit_type == BODY_TYPE) & !KeepEnable) ? byte_buffer :
                    {last, {PaddWidthTail{1'b1}}, {NocDataWidth-8{1'b0}}};
  assign fsm_broadcast = 1'b0;
  assign fsm_vc = tid % NumVn;
  assign fsm_data = {fsm_broadcast, fsm_vc, fsm_flit_type, fsm_flit};
  assign write_to_buffer_reg = sending_flit_buffer_input & 
                               ((!stored_flit_to_send & !wrapper_ready) | 
                               (stored_flit_to_send & wrapper_ready));
  assign network_flit_o = m_wrapper_data[NocDataWidth-1:0];
  assign network_flit_type_o = m_wrapper_data[NocDataWidth +: flitTypeSize];
  assign network_vc_o = m_wrapper_data[NocDataWidth + flitTypeSize +: NocVirtualChannelIdWidth];
  assign network_broadcast_o = m_wrapper_data[MTDataWidth-1];

  //----------------------------------------------------------------------------------------------
  // Store input data

  always @(posedge s_axis_aclk) begin
    if (!s_axis_arstn) begin
      byte_counter <= 3'b000;
      padd <= {PaddWidthTail{1'b1}};
      tid <= {TIdWidth{1'b0}};
      last <= 1'b0;
      byte_buffer <= {NocDataWidth{1'b0}};
      header <= {SrcDstWidth{1'b0}};
    end else if (s_axis_tvalid & (state != EMPTY_TAIL)) begin
      tid <= s_axis_tid;
      header <= {s_axis_tdest, source_id};
      last <= s_axis_tlast;
      
      //Cleaning registers 
      if(byte_counter == 3'b000) begin
        byte_buffer[NocDataWidth-1:0] <= {{NocDataWidth-8{1'b0}}, s_axis_tdata};
        if(KeepEnable)
          padd[PaddWidthTail-1:0] <= {{PaddWidthTail-1{1'b0}}, s_axis_tkeep};
        else 
          padd[6:0] <= {{PaddWidthTail-1{1'b1}}, 1'b0};
      end else begin
        byte_buffer[8 * byte_counter +: 8] <= s_axis_tdata;
        if(KeepEnable) 
          padd[byte_counter] <= s_axis_tkeep;
        else 
          padd[byte_counter] <= 1'b0;
      end
    
      if ((s_axis_tlast) || 
          (state == HEADER && byte_counter == PayloadSizeHeader-1) ||
          (KeepEnable && state == BODY && byte_counter == PayloadSizeTail-1) ||
          (!KeepEnable && state == BODY && byte_counter == PayloadSizeBody-1)) begin 
        byte_counter <= 3'b000;
      end else begin
        byte_counter <= byte_counter + 1;
      end
    end
  end

  //----------------------------------------------------------------------------------------------
  // Store output buffer

  always @(posedge s_axis_aclk) begin
    if (!s_axis_arstn) begin
      stored_flit_to_send <= 0;
      flit_out <= 0;
      flit_type_out <= 0;
    end else if (write_to_buffer_reg) begin
      stored_flit_to_send <= 1'b1;
      flit_type_out <= flit_type[1:0];
      if ((flit_type == HEADER_TYPE) | (flit_type == HEADTAIL_TYPE)) begin
        flit_out <= {header, tid, last, padd[PaddWidthHeader-1:0], byte_buffer[31:0]};
        flit_type_out <= flit_type[1:0];
      end else if (flit_type == BODY_TYPE) begin
        if (KeepEnable) 
          flit_out <= {1'b0, padd, byte_buffer[55:0]};
        else 
          flit_out <= byte_buffer;
      end else if (flit_type == TAIL_TYPE) begin
        flit_out <= {last, padd, byte_buffer[55:0]};
      end else if (flit_type == EMPTY_TAIL_TYPE) begin
        flit_out <= {last, {PaddWidthTail{1'b1}}, {NocDataWidth-8{1'b0}}};
      end  
    end else if (stored_flit_to_send & wrapper_ready) begin
      stored_flit_to_send <= 1'b0;
    end
  end
  
  //----------------------------------------------------------------------------------------------
  // FSM state updates

  always @(posedge s_axis_aclk) begin
    if (!s_axis_arstn)
      state <= HEADER;
    else
      state <= next_state;
  end

  //----------------------------------------------------------------------------------------------
  // FSM state transitions

  always @(*) begin 
    next_state = state;
    case (state)
      HEADER,
      HEADER_AND_TAIL: begin
        if (s_axis_tvalid & 
           ((byte_counter == PayloadSizeHeader-1) & !s_axis_tlast)) 
          next_state = BODY;
      end
      BODY,
      BODY_AND_TAIL: begin
        if (s_axis_tvalid & 
           (byte_counter <= PayloadSizeTail-1) & s_axis_tlast) 
          next_state = HEADER;
        else if (s_axis_tvalid & 
                (byte_counter == PayloadSizeBody-1) & s_axis_tlast) 
          next_state = EMPTY_TAIL;
      end
      TAIL,
      EMPTY_TAIL: begin
        if (!stored_flit_to_send | (wrapper_ready & stored_flit_to_send)) 
          next_state = HEADER;
      end      
      default: next_state = HEADER;
    endcase
  end

  //----------------------------------------------------------------------------------------------
  // FSM Control logic


  always @(posedge s_axis_aclk) begin
    if (!s_axis_arstn) begin
      sending_flit_buffer_input <= 0;
      flit_type <= HEADER_TYPE;
    end else begin
      case (state)
        HEADER,
        HEADER_AND_TAIL: begin
          if (s_axis_tvalid & 
             ((byte_counter == PayloadSizeHeader-1) | s_axis_tlast)) begin
            if(s_axis_tlast) 
              flit_type <= HEADTAIL_TYPE; 
            else 
              flit_type <= HEADER_TYPE;              
            sending_flit_buffer_input <= 1'b1;                
          end else 
            sending_flit_buffer_input <= 1'b0; 
        end
        BODY,
        BODY_AND_TAIL: begin
          if (s_axis_tvalid & 
             ((KeepEnable & (byte_counter == PayloadSizeTail-1)) | 
             (!KeepEnable & (byte_counter == PayloadSizeBody-1)))) begin             
            flit_type <= BODY_TYPE;              
            sending_flit_buffer_input <= 1'b1;              
          end else if (s_axis_tvalid & s_axis_tlast) begin
            flit_type <= TAIL_TYPE;              
            sending_flit_buffer_input <= 1'b1;
          end else 
            sending_flit_buffer_input <= 1'b0;               
        end 
        TAIL,
        EMPTY_TAIL: begin
          if (!stored_flit_to_send | (wrapper_ready & stored_flit_to_send)) begin  
            flit_type <= EMPTY_TAIL_TYPE;
            sending_flit_buffer_input <= 1'b1;
          end 
        end
      endcase
    end
  end
endmodule
