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

  // fifo_type_1_async_axis_wrapper parameters
  localparam         FIFO_FIRST_WORD_FALL_THROUGH  = "true";
  localparam integer FIFO_SYNC_STAGES               = 2;
  localparam integer FIFO_DEPTH                     = 8;
  localparam integer FIFODataWidth                  = NocDataWidth + flitTypeSize;
  
  localparam [1:0] FLIT_TYPE_HEADER      = 2'b00;
  localparam [1:0] FLIT_TYPE_BODY        = 2'b01;
  localparam [1:0] FLIT_TYPE_TAIL        = 2'b10;
  localparam [1:0] FLIT_TYPE_HEADER_TAIL = 2'b11;
  
  // Fields within the flit
  localparam integer TID_LSB         = 37;
  localparam integer TID_MSB         = 41;
  localparam integer TDEST_LSB       = 53;
  localparam integer TDEST_MSB       = 63;  
  
  wire [FIFODataWidth-1:0] fifo_data_in;
  wire [FIFODataWidth-1:0] fifo_data_out;
  wire                     fifo_flit_full_padding_tail;
  wire                     fifo_flit_not_padding_tail;
  
  // A bunch of registers to store the first flit in the
  // fifo and be able to lookahead the next one
  // (if it is one) to get rid of null bytes in the stream
  // when tlast come in a tail made of padding bytes
  reg [NocDataWidth-1:0] flit_q;
  reg [flitTypeSize-1:0] flit_type_q;
  reg                    flit_ready_d;
  reg                    flit_downsize_complete;
  reg                    flit_buffered;
  
  // Counter to downsize flit payload into bytes
  // It is a 64-bit word byte counter (8 bytes) 
  reg [2:0] byte_counter;
  
  // A bunch of registers for the output port stream of bytes
  reg [7:0]            byte_tdata_q;
  reg [TIdWidth-1:0]   byte_tid_q;
  reg [TDestWidth-1:0] byte_tdest_q;
  reg                  byte_valid_q;
  reg                  byte_tlast_q;  
  wire                 byte_handshake_complete; // Flags when the handshake for output bytes completes
  
  
  assign m_axis_tdata  = byte_tdata_q;
  assign m_axis_tvalid = byte_valid_q;
  assign m_axis_tlast  = byte_tlast_q;
  assign m_axis_tdest  = byte_tdest_q;
  assign m_axis_tid    = byte_tid_q;
  assign m_axis_tkeep  = 1;
  
  assign fifo_data_in = {network_flit_type_i, network_flit_i};
  assign fifo_flit_full_padding_tail = (
    (fifo_data_valid == 1'b1) &&
    (fifo_data_out[NocDataWidth +: flitTypeSize] == FLIT_TYPE_TAIL) && 
    (fifo_data_out[63:56] == 8'hFF)
  );
  assign fifo_flit_not_padding_tail = (
    (fifo_data_valid == 1'b1) &&
     (
      ((fifo_data_out[NocDataWidth +: flitTypeSize] == FLIT_TYPE_TAIL) && (fifo_data_out[63:56] != 8'hFF)) ||
      (fifo_data_out[NocDataWidth +: flitTypeSize] != FLIT_TYPE_TAIL)
     )
    );

  assign byte_handshake_complete = (byte_valid_q == 1'b1) && (m_axis_tready == 1'b1);

  fifo_type_1_async_axis_wrapper #(
    .TDataWidth(FIFODataWidth),
    .TidWidth(TIdWidth),
    .TdestWidth(TDestWidth),
    .SynchStages(FIFO_SYNC_STAGES),
    .FifoDepth(FIFO_DEPTH),
    .FirstWordFallThrough(FIFO_FIRST_WORD_FALL_THROUGH)
    ) fifo_type_1_async_axis_wrapper_i(
    //subordinate axi interface
    .s_axis_aclk  (clk_noc),
    .s_axis_arstn (!rst_noc),
    .s_axis_tid   (), 
    .s_axis_tdest (),
    .s_axis_tdata (fifo_data_in),
    .s_axis_tvalid(network_valid_i),
    .s_axis_tlast (),
    .s_axis_tready(network_ready_o),
    
    //manager axi interface
    .m_axis_aclk     (m_axis_aclk),
    .m_axis_arstn    (m_axis_arstn),
    .m_axis_tid      (), 
    .m_axis_tdest    (),
    .m_axis_tdata    (fifo_data_out),
    .m_axis_tvalid   (fifo_data_valid),
    .m_axis_tlast    (),
    .m_axis_tready   (flit_ready_d)
    );



  // Capture flit into intermediate register
  // Using this register we can take advantage of the FWFT FIFO
  // to inspect the next flit to know whether it is 
  // a full padding tail and anticipate tlast to the last
  // byte of this flit, since next module (upsizer) does
  // not support tkeep to assert tlast with null bytes
  always @(posedge m_axis_aclk) begin
    if (!m_axis_arstn) begin
      flit_q <= 0;
      flit_type_q <= 0;
    end else if ((fifo_data_valid == 1) && (fifo_flit_full_padding_tail != 1) && (flit_ready_d == 1)) begin
      flit_q      <= fifo_data_out[NocDataWidth-1:0];
      flit_type_q <= fifo_data_out[NocDataWidth +: flitTypeSize];
    end
  end


  // Mux to set the input for the flit ready signal in next sequential block
  always @(*) begin
    flit_ready_d = 1;

    if (flit_buffered == 1) begin
      flit_ready_d = 0;
    end
    
    if (flit_downsize_complete == 1) begin
      flit_ready_d = 1;
    end    
  end  

  // logic to handle flit_buffered signal  
  always @(posedge m_axis_aclk) begin
    if (!m_axis_arstn) begin
      flit_buffered <= 0;
    end else begin
      if ((fifo_data_valid == 1) && (fifo_flit_full_padding_tail != 1) && (flit_ready_d == 1)) begin
        flit_buffered <= 1;
      end else if ((fifo_data_valid == 1) && (fifo_flit_full_padding_tail == 1) && (flit_ready_d == 1)) begin
        flit_buffered <= 0;
      end else if ((fifo_data_valid == 0) && (flit_downsize_complete == 1)) begin
        flit_buffered <= 0;
      end
    end
  end  
  
  // Logic to flag when flit has been downsized to bytes
  always @(*) begin
    flit_downsize_complete = 0;
    
    // byte_counter can reach 3 and 7 when there is flit buffered, so
    // this code is implicitly assuming there is a flit buffered
    if ((byte_counter == 3) && (m_axis_tready == 1'b1) &&
        ((flit_type_q == FLIT_TYPE_HEADER_TAIL) || (flit_type_q == FLIT_TYPE_TAIL))) begin
      flit_downsize_complete = 1;
    end    
    
    if ((byte_counter == 3) && (m_axis_tready == 1'b1) &&
        (flit_type_q == FLIT_TYPE_HEADER) && (fifo_data_valid == 1)) begin
      flit_downsize_complete = 1;
    end
    
    if ((byte_counter == 7) && (m_axis_tready == 1'b1) &&
        (flit_type_q == FLIT_TYPE_BODY) && (fifo_data_valid == 1)) begin
      flit_downsize_complete = 1;
    end   

  end

  // Counter logic to keep track of the current byte of the flit
  // to be downsized
  always @(posedge m_axis_aclk) begin
    if (!m_axis_arstn) begin
      byte_counter <= 0;
    end else begin
      if (flit_buffered == 1'b0) begin
        byte_counter <= 0;
      end else begin
        // flit is already in the downsize flit buffer
               
        if (m_axis_tready == 1) begin
          if (flit_type_q == FLIT_TYPE_HEADER_TAIL) begin
            if (byte_counter == 3) begin
              byte_counter <= 0;
            end else begin
              byte_counter <= byte_counter + 1;
            end
          end else if (flit_type_q == FLIT_TYPE_HEADER) begin
            if ((byte_counter != 3) ||  // not last byte in flit
                (fifo_data_valid == 1)  // or next flit at front of the FIFO
               ) begin
              if (byte_counter == 3) begin
                byte_counter <= 0;
              end else begin
                byte_counter <= byte_counter + 1;
              end
            end 
          end else if (flit_type_q == FLIT_TYPE_BODY) begin
           if ((byte_counter != 7) || // not last byte of body 
               (fifo_data_valid == 1) // next flit at front of the FIFO
              ) begin
              // there is enough info to determine whether tlast must be asserted
              // then no need to gate the counter
              //
              // the counter must wrap itself
             byte_counter <= byte_counter + 1;
           end
          end else begin
            // tail case: is like header, since the payload can be only a word,
            // flit_q must not have full_padding flits, so no need to check for this case
            if (byte_counter == 3) begin
              byte_counter <= 0;
            end else begin
              byte_counter <= byte_counter + 1;
            end
          end
        end else begin
          // there is not handshake completed 
          // increment when first byte is loaded in byte_q register
          if ((byte_counter == 0) && (byte_valid_q == 0)) begin
            byte_counter <= byte_counter + 1;
          end
        end
      end
    end 
  end
        
  // Output port logic for the m_axis interface
  // It delivers bytes and assert tlast for every
  // network received packet upon reception of a tail flit
  
  // Valid logic
  always @(posedge m_axis_aclk) begin
    if (!m_axis_arstn) begin
      byte_valid_q <= 0;
    end else begin
      if (flit_buffered == 1'b1) begin
        // Take care to enable tvalid for the byte
        // since it could be the last byte of a body
        // so in that case it is required to inspect the next flit from the fifo
        // to know whether it is an full padding tail (64'hff000..000) with tlast
        // and assert tlast for this byte, since next module
        // does not support tkeep

        if ((byte_counter == 3) && (flit_type_q == FLIT_TYPE_HEADER)) begin
          if ((byte_handshake_complete == 1) && (fifo_data_valid == 0)) begin
            // it safe to deassert valid, since handshake has completed
            // and it is required to wail next flit in fifo
            //to know whether it is a full padding flit to assert tlast for current byte
            // This case could not be exercised in NIMBLEAI, but testbenches support it...
            byte_valid_q <= 0;
          end else if (fifo_data_valid == 1) begin
            // flit at fifo front, then the info required to resume
            // byte transfers is available
            byte_valid_q <= 1;
          end
        end else if (byte_counter == 7) begin 
          // body flit, the counter only reach that value for body flits
          if ((byte_handshake_complete == 1) && (fifo_data_valid == 0)) begin
            // it safe to deassert valid, since handshake has completed
            // and it is required to wail next flit in fifo
            //to know whether it is a full padding flit to assert tlast for current byte
            byte_valid_q <= 0;
          end else if (fifo_data_valid == 1) begin
            // flit at fifo front, then the info required to resume
            // byte transfers is available
            byte_valid_q <= 1;
          end          
        end else begin
          byte_valid_q <= 1;
        end

      end else begin
        // valid cannot be deasserted until handshake completes
        if (byte_handshake_complete == 1) begin
          byte_valid_q <= 0;
        end
      end
    end
  end  
  
  // tlast logic
  always @(posedge m_axis_aclk) begin
    if (!m_axis_arstn) begin
      byte_tlast_q <= 0;
    end else begin
      if (flit_buffered == 1'b1) begin
        if ((byte_counter == 3) && 
            ((flit_type_q == FLIT_TYPE_HEADER_TAIL) || 
             (flit_type_q == FLIT_TYPE_TAIL))) begin
           byte_tlast_q <= 1;
        end else if ((byte_counter == 3) &&
                     (flit_type_q == FLIT_TYPE_HEADER) &&
                     (fifo_flit_full_padding_tail == 1'b1)) begin
           byte_tlast_q <= 1;
        end else if ((byte_counter == 7) &&
                     (flit_type_q == FLIT_TYPE_BODY) &&
                     (fifo_flit_full_padding_tail == 1'b1)) begin
          byte_tlast_q <= 1;           
        end else begin
          byte_tlast_q <= 0;
        end      
      end else if (byte_handshake_complete == 1) begin
        byte_tlast_q <= 0;
      end
    end
  end
  
  // tdata, tdest, tid logic
   always @(posedge m_axis_aclk) begin
    if (!m_axis_arstn) begin
      byte_tdest_q <= 0;
      byte_tid_q   <= 0;
      byte_tdata_q       <= 0;
    end else begin
      if (flit_buffered == 1'b1) begin
        //
        if (byte_valid_q == 0) begin
          byte_tdata_q <= flit_q[byte_counter*8 +: 8];
            
          if ((flit_type_q == FLIT_TYPE_HEADER) || (flit_type_q == FLIT_TYPE_HEADER_TAIL)) begin
            byte_tdest_q <= flit_q[TDEST_MSB:TDEST_LSB];
            byte_tid_q   <= flit_q[TID_MSB:TID_LSB];
          end
        end else if (byte_handshake_complete) begin
          byte_tdata_q <= flit_q[byte_counter*8 +: 8];
          
          if ((flit_type_q == FLIT_TYPE_HEADER) || (flit_type_q == FLIT_TYPE_HEADER_TAIL)) begin
            byte_tdest_q <= flit_q[TDEST_MSB:TDEST_LSB];
            byte_tid_q   <= flit_q[TID_MSB:TID_LSB];
          end          
        end  
      end
    end
  end
      
endmodule

//module network_data_axis_downsizer #
//(
//  // Width of AXI stream TDATA signal in bits
//  parameter integer AxisDataWidth = 8,

//  // Width of NoC DATA signal in bits
//  parameter integer NocDataWidth = 64,
 
//  parameter integer flitTypeSize = 2,

//  // Propagate tkeep signal
//  parameter KeepEnable = 0,
  
//  // Tid width
//  parameter integer TIdWidth  = 8,
  
//  // Tdest width
//  parameter integer TDestWidth = 11 
//)
//(
//  input                      m_axis_aclk,
//  input                      m_axis_arstn,

//  input                      clk_noc,
//  input                      rst_noc,

//  // Input interface
//  input      [flitTypeSize-1:0]    network_flit_type_i,
//  input      [NocDataWidth-1:0]    network_flit_i,
//  input                            network_valid_i,
//  output                           network_ready_o,

//  // Output interface
//  output     [AxisDataWidth-1:0]   m_axis_tdata,
//  output                           m_axis_tvalid,
//  input                            m_axis_tready,
//  output                           m_axis_tlast,
//  output                           m_axis_tkeep,
//  output     [TIdWidth-1:0]        m_axis_tid,
//  output     [TDestWidth-1:0]      m_axis_tdest
//);

//  //----------------------------------------------------------------------------------------------
//  // Local parameters definition

//  // Flit Types
//  localparam HEADER          = 2'b00;
//  localparam HEADER_TAIL     = 2'b11;
//  localparam BODY            = 2'b01;
//  localparam TAIL            = 2'b10;
  
//  // Addresses of fields within the flit
//  localparam padd_addr_header = 32;
//  localparam padd_size_header = 4;
//  localparam padd_addr_tail   = 56;
//  localparam padd_size_tail   = 7;
//  localparam last_addr_header = 36;
//  localparam last_addr_tail   = 63;
//  localparam tid_addr         = 37;
//  localparam tid_size         = 5;
//  localparam tdest_addr       = 53;
//  localparam tdest_size       = 11;

//  // fifo_type_1_async_axis_wrapper parameters
//  localparam AddressWidth         = 3;
//  localparam FirstWordFallThrough = "true";
//  localparam SynchStages          = 2;
//  localparam FifoDepth            = 2**AddressWidth;
//  localparam MTDataWidth          = NocDataWidth + flitTypeSize;

//  //----------------------------------------------------------------------------------------------
//  // Wires and Regs definition  

//  // Registers to save inputs
//  reg [NocDataWidth-1:0]      flit;
//  reg [flitTypeSize-1:0]      flit_type;
//  reg [TIdWidth-1:0]          tid;
//  reg [TDestWidth-1:0]        tdest;
//  reg                         tkeep;
//  reg [AxisDataWidth-1:0]     payload;

//  // Control registers
//  reg                         last_byte;
//  reg                         empty_buffer; 
//  reg [2:0]                   byte_counter;
//  reg [2:0]                   padd_byte_index;
  
//  // Wires
//  wire                        last_no_tkeep;
//  wire                        tlast_output;
//  wire [MTDataWidth -1:0]     network_data;
//  wire [MTDataWidth -1:0]     fsm_data;
//  wire                        fsm_ready;
//  wire                        fsm_valid;
//  wire                        wrapper_ready;
//  wire [NocDataWidth-1:0]     fsm_flit;
//  wire [flitTypeSize-1:0]     fsm_flit_type;

//  wire			                  wait_tlast;
//  wire                        empty_tail_tlast;

//  //----------------------------------------------------------------------------------------------
//  // Assigns
  
//  // m_axis signals
//  assign m_axis_tkeep = tkeep;
//  assign m_axis_tid = tid;
//  assign m_axis_tdest = tdest;
//  assign m_axis_tdata = payload;
//  assign m_axis_tlast = tlast_output;
//  assign m_axis_tvalid = !empty_buffer; //& wait_tlast;


//  // Control signals
//  assign last_no_tkeep = ((flit_type == HEADER_TAIL) | (flit_type == TAIL) | (empty_tail_tlast)) 
//                          & (last_byte); 
//  assign tlast_output = last_no_tkeep;
//  assign network_ready_o = wrapper_ready;
//  assign fsm_ready = empty_buffer | (last_byte & m_axis_tready);

//  // Wrapper input
//  assign network_data = {network_flit_type_i, network_flit_i};

//  // Wrapper output to fsm
//  assign fsm_flit = fsm_data[NocDataWidth-1:0];
//  assign fsm_flit_type = fsm_data[NocDataWidth+:flitTypeSize];

//  // Tlast output forced when !KeepEnable and empty tail ( tail & flit == hff00_0000_0000_0000)
//  assign wait_tlast = (byte_counter == 3'b111) & (flit_type == BODY) & !fsm_valid & !KeepEnable;
//  assign empty_tail_tlast = (fsm_valid & fsm_flit_type == TAIL) & (fsm_flit == 64'hff00_0000_0000_0000);

//  //----------------------------------------------------------------------------------------------
//  // modules instantiation

//  fifo_type_1_async_axis_wrapper #(
//    .TDataWidth (MTDataWidth),
//    .TidWidth (TIdWidth),
//    .TdestWidth (TDestWidth),
//    .SynchStages (SynchStages),
//    .FifoDepth (FifoDepth),
//    .FirstWordFallThrough (FirstWordFallThrough)
//    ) fifo_type_1_async_axis_wrapper_i(
//    //subordinate axi interface
//    .s_axis_aclk     (clk_noc),         // Input: clock signal
//    .s_axis_arstn    (!rst_noc),        // Input: reset signal, active low
//    .s_axis_tid      (),                // Input: Data Stream Idenfitifier 
//    .s_axis_tdest    (),                // Input: routing information for the data stream. Destination.
//    .s_axis_tdata    (network_data),    // Input: primary payload. Data to cross the interface
//    .s_axis_tvalid   (network_valid_i), // Input: indicates that the transmitter is driving a valid transfer
//    .s_axis_tlast    (),                // Input: indicates the boundary of a packet
//    .s_axis_tready   (wrapper_ready),   // Output: indicates that this module can accept data
//    //manager axi interface
//    .m_axis_aclk     (m_axis_aclk),     // Input: clock signal
//    .m_axis_arstn    (m_axis_arstn),    // Input: reset signal, active low
//    .m_axis_tid      (),                // Output: Data Stream Idenfitifier 
//    .m_axis_tdest    (),                // Output: routing information for the data stream. Destination.
//    .m_axis_tdata    (fsm_data),        // Output: primary payload. Data to cross the interface
//    .m_axis_tvalid   (fsm_valid),       // Output: indicates that the transmitter is driving a valid transfer
//    .m_axis_tlast    (),                // Output indicates the boundary of a packet
//    .m_axis_tready   (fsm_ready)        // Input: indicates that the module can accept data
//    );

//  //----------------------------------------------------------------------------------------------
//  // Store input data

//  always @(posedge m_axis_aclk) begin

//    if (!m_axis_arstn) begin
//      flit <= {NocDataWidth{1'b0}};
//      flit_type <= {flitTypeSize{1'b0}};
//      tid <= {TIdWidth{1'b0}};
//      tdest <= {TDestWidth{1'b0}};
//      padd_byte_index <= 1'b0;
//      empty_buffer <= 1'b1;
      

//    end else if (fsm_valid & fsm_ready & !empty_tail_tlast) begin
//      empty_buffer <= 1'b0;
//      flit <= fsm_flit;
//      flit_type <= fsm_flit_type;
//      if (fsm_flit_type == HEADER) begin
//        tid <= fsm_flit[tid_addr+:tid_size];
//        tdest <= fsm_flit[tdest_addr+:tdest_size];
//      end else if (fsm_flit_type == HEADER_TAIL) begin
//        tid <= fsm_flit[tid_addr+:tid_size];
//        tdest <= fsm_flit[tdest_addr+:tdest_size];
//        // Determine the index of the last valid byte
//        casez (fsm_flit[padd_addr_header+:padd_size_header])
//          4'b???1: padd_byte_index <= 0; // Empty header
//          4'b??10: padd_byte_index <= 1;
//          4'b?100: padd_byte_index <= 2;
//          4'b1000: padd_byte_index <= 3;                   
//          default: padd_byte_index <= 4; // No padding
//        endcase
//      end else if (fsm_flit_type == TAIL) begin
//        // Determine the index of the last valid byte
//        casez (fsm_flit[padd_addr_tail+:padd_size_tail])
//          7'b??????1: padd_byte_index <= 0; // Empty tail
//          7'b?????10: padd_byte_index <= 1;
//          7'b????100: padd_byte_index <= 2;
//          7'b???1000: padd_byte_index <= 3;
//          7'b??10000: padd_byte_index <= 4;
//          7'b?100000: padd_byte_index <= 5;
//          7'b1000000: padd_byte_index <= 6;
//          default:    padd_byte_index <= 7; // No padding
//        endcase
//      end
//    end else if(last_byte & m_axis_tready) begin
//      empty_buffer <= 1'b1;
//    end 
//  end
 

//  //----------------------------------------------------------------------------------------------
//  // Output signals

//  always @(posedge m_axis_aclk) begin
//    if (!m_axis_arstn) begin
//      byte_counter <= 3'b000;
//      payload <= {AxisDataWidth{1'b0}};
//      last_byte <= 1'b0;
//      tkeep <= 1'b0;
      

//    end else if (fsm_valid & fsm_ready & !empty_tail_tlast) begin      
//      payload <= fsm_flit[0+:8];
      
//      if (((fsm_flit_type == HEADER_TAIL) & fsm_flit[padd_addr_header]) |
//         ((fsm_flit_type == TAIL) & fsm_flit[padd_addr_tail])) begin
//        byte_counter <= 3'b000;
//        last_byte <= 1'b1;
//        tkeep <= 1'b0;
//      end else begin
//        byte_counter <= byte_counter + 1; 
//        last_byte <= 1'b0;
//        tkeep <= 1'b1;
//      end

//    end else if (!empty_buffer & m_axis_tready & !wait_tlast) begin
//      payload <= flit[8*byte_counter +: 8];
      
//      if (((flit_type == TAIL) | (flit_type == HEADER_TAIL)) & 
//          ((padd_byte_index == byte_counter) | (padd_byte_index == (byte_counter+1)))) begin 
//        byte_counter <= 3'b000;
//        last_byte <= 1'b1;

//        if (padd_byte_index == byte_counter) tkeep <= 1'b0;
//        else if (padd_byte_index == byte_counter+1) tkeep <= 1'b1;
                
//      end else if (((flit_type == BODY) & (byte_counter == 7)) | 
//                   ((flit_type == HEADER) & (byte_counter == 3))) begin                   
//        byte_counter <= 3'b000;
//        last_byte <= 1'b1;

//      end else begin
//        if(last_byte == 1'b0) byte_counter <= byte_counter + 1;
//        last_byte <= 1'b0;
//      end
//    end
//  end

//endmodule
