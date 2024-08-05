// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file axis_data_upsizer.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date March 22nd, 2024
//
// @title AXI Stream data upsizer
//
//  This module implements a data upsizer for axi stream data transfers.
//  Incoming transfer data width is upsized from STDataWidth bits to MTDataWidth bits.
//    By default, incoming data port width is 8 bits (1 byte) and outgoing data 
//    port width is 32 bits (4 bytes), so 4 incoming data transfers are joined into 1 output data transfer.
//    Axi-stream signals at the output are modified to ensure the correct 
//    relationship between data and signals is mantained (tlast).
//    Only one ongoing transfer is supported currently, Tid and Tdest fields must be the same 
//      for all the bytes of the incoming transfer.
//      NO verification of these parameters is done, unexpected transfers may be generated if this warning is ignored.
//
//  This module also serves to  move data across asynchronous clock domains, thus
//  it implements synchronization registers to prevent data corruption, and 
//  a fifo to prevent traffic bubbles.
//
//  WARNING: for correct woking of the module MINIMUM UPSIZER RATIO must be 2.
//           Parameters representing an upsize ratio of 1 would cause module malfunction.
//
//   This module is tightly coupled to the axis_data_downsizer.
//   This module reads data from the inport, composes the transfer and then stores all the data in the FIFO
//

`timescale 1 ns / 1 ps

`define DEBUG_DISPLAY_DATA_UPSIZER_ENABLE 1


module axis_data_upsizer #(
  parameter STDataWidth =  8,  // Width of  (input)  slave data port in bits
  parameter MTDataWidth = 32,  // Width of (output) master data port in bits
  parameter TidWidth    =  8,
  parameter TdestWidth  =  8,
  parameter SynchStages =  2,
  parameter FifoDepth   = 16, // @JM10 cambiar esto!!! so burro, esto se debe hacer a nivel interno, y no el usuario  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  WARNING NOTICE TO-DO TODO TO DO LO QUE SEA, PERO HAZLO
  parameter FirstWordFallThrough = "true" // First Word Fall Through, When set to one, data in ouptut port is available at the same time that empty signal is set to zero. When set to zero, fifo output is registered, thus updated upon rd_req signal is set to one, one cycle delay
) (
  // slave interface (data input from traffic generator)
  input                           s_axis_aclk,    // Input: clock signal of slave domain
  input                           s_axis_arstn,   // Input: reset signal of slave main
  input  [TidWidth-1:0]           s_axis_tid,     // Input: Data Stream Idenfitifier 
  input  [TdestWidth-1:0]         s_axis_tdest,   // Input: routing information for the data stream. Destination.
  input  [STDataWidth-1:0]        s_axis_tdata,   // Input: primary payload. Data to cross the interface
  input                           s_axis_tvalid,  // Input: indicates that the transmitter is driving a valid transfer
  input                           s_axis_tlast,   // Input: indicates the boundary of a packet
  output                          s_axis_tready,  // Output: indicates that the module can accept data

  // master interface (data output to NoC)
  input                           m_axis_aclk,    // Input: clock signal of slave domain
  input                           m_axis_arstn,   // Input: reset signal of slave main
  output  [TidWidth-1:0]          m_axis_tid,     // Output: Data Stream Idenfitifier 
  output  [TdestWidth-1:0]        m_axis_tdest,   // Output: routing information for the data stream. Destination.
  output  [MTDataWidth-1:0]       m_axis_tdata,   // Output: primary payload. Data to cross the interface
  output                          m_axis_tvalid,  // Output: indicates that the transmitter is driving a valid transfer
  output                          m_axis_tlast,   // Output: indicates the boundary of a packet
  input                           m_axis_tready   // Output: indicates that the module can accept data
);

  // Bunch of registers to capture the info in the s_axis input port
  // before storing it in th fifo.
  // This is because of 32-bit words must be generated from the input byte s_axis stream
  reg [MTDataWidth-1:0] word_tdata;
  reg [TdestWidth-1:0]  word_tdest;
  reg [TidWidth-1:0]    word_tid;
  reg                   word_tlast;
  reg                   word_tvalid;
  reg                   word_ready_for_byte;
  
  // Flag when the handshake completes between the
  // FIFO and the word register
  wire                  fifo_handshake_complete;  
  wire                  fifo_ready;


  // Flag when handshake completes between the 
  // input s_axis port and the word register where
  // the input byte is stored
  wire                  s_axis_handshake_complete;

  // Counter of the current byte being stored
  // in 32-bit fifo_tdata reg
  reg [1:0] byte_counter;

  assign s_axis_handshake_complete = ((s_axis_tvalid == 1) && (word_ready_for_byte));
  assign fifo_handshake_complete = ((word_tvalid == 1) && (fifo_ready == 1));

  assign s_axis_tready = word_ready_for_byte;

  // modules instantiation 
  fifo_type_1_async_axis_wrapper #(
    .TDataWidth(MTDataWidth),
    .TidWidth  (TidWidth),
    .TdestWidth(TdestWidth),
    
    .SynchStages         (SynchStages),
    .FifoDepth           (FifoDepth),
    .FirstWordFallThrough(FirstWordFallThrough)
    ) fifo_type_1_async_axis_wrapper_i(
    // slave axi interface
    .s_axis_aclk  (s_axis_aclk),
    .s_axis_arstn (s_axis_arstn),
    .s_axis_tid   (word_tid), 
    .s_axis_tdest (word_tdest),
    .s_axis_tdata (word_tdata),
    .s_axis_tvalid(word_tvalid),
    .s_axis_tlast (word_tlast),
    .s_axis_tready(fifo_ready),
    //
    //master interface
    .m_axis_aclk  (m_axis_aclk),
    .m_axis_arstn (m_axis_arstn),
    .m_axis_tid   (m_axis_tid), 
    .m_axis_tdest (m_axis_tdest),
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast (m_axis_tlast),
    .m_axis_tready(m_axis_tready)
  );

  // Counter logic
  always @(posedge s_axis_aclk) begin
    if (~s_axis_arstn) begin
      byte_counter <= 0;
    end else if (s_axis_handshake_complete == 1) begin
      byte_counter <= byte_counter + 1;
    end
  end
  
  // tdata, tdest, tid, tlast
  always @(posedge s_axis_aclk) begin
    if ((s_axis_handshake_complete == 1) || ((word_tvalid == 0) && (byte_counter == 0))) begin 
      //word_tdata[byte_counter*8 +: 8] <= s_axis_tdata;
      word_tdata = {word_tdata[MTDataWidth-STDataWidth-1:0], s_axis_tdata}; 
      word_tdest <= s_axis_tdest;
      word_tid   <= s_axis_tid;
      word_tlast <= s_axis_tlast;
    end
  end
  
  always @(posedge s_axis_aclk) begin
    if (~s_axis_arstn) begin
      word_tvalid <= 0;
    end else begin
      if ((byte_counter == 3) && (s_axis_handshake_complete == 1)) begin
        word_tvalid <= 1;
      end else if (fifo_handshake_complete == 1) begin
        word_tvalid <= 0;
      end
    end
  end
  
  always @(posedge s_axis_aclk) begin
    if (~s_axis_arstn) begin
      word_ready_for_byte <= 1;
    end else begin
      if ((byte_counter == 3) && (s_axis_handshake_complete == 1) && (fifo_ready == 0)) begin
        word_ready_for_byte <= 0;
      end else if (word_tvalid == 0) begin
        word_ready_for_byte <= 1;
      end
    end
  end  

endmodule



//module axis_data_upsizer #(
//  parameter STDataWidth =  8,  // Width of  (input)  slave data port in bits
//  parameter MTDataWidth = 32,  // Width of (output) master data port in bits
//  parameter TidWidth    =  8,
//  parameter TdestWidth  =  8,
//  parameter SynchStages =  2,
//  parameter FifoDepth   = 16, // @JM10 cambiar esto!!! so burro, esto se debe hacer a nivel interno, y no el usuario  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  WARNING NOTICE TO-DO TODO TO DO LO QUE SEA, PERO HAZLO
//  parameter FirstWordFallThrough = "true" // First Word Fall Through, When set to one, data in ouptut port is available at the same time that empty signal is set to zero. When set to zero, fifo output is registered, thus updated upon rd_req signal is set to one, one cycle delay
//) (
//  // slave interface (data input from traffic generator)
//  input                           s_axis_aclk,    // Input: clock signal of slave domain
//  input                           s_axis_arstn,   // Input: reset signal of slave main
//  input  [TidWidth-1:0]           s_axis_tid,     // Input: Data Stream Idenfitifier 
//  input  [TdestWidth-1:0]         s_axis_tdest,   // Input: routing information for the data stream. Destination.
//  input  [STDataWidth-1:0]        s_axis_tdata,   // Input: primary payload. Data to cross the interface
//  input                           s_axis_tvalid,  // Input: indicates that the transmitter is driving a valid transfer
//  input                           s_axis_tlast,   // Input: indicates the boundary of a packet
//  output                          s_axis_tready,  // Output: indicates that the module can accept data

//  // master interface (data output to NoC)
//  input                           m_axis_aclk,    // Input: clock signal of slave domain
//  input                           m_axis_arstn,   // Input: reset signal of slave main
//  output  [TidWidth-1:0]          m_axis_tid,     // Output: Data Stream Idenfitifier 
//  output  [TdestWidth-1:0]        m_axis_tdest,   // Output: routing information for the data stream. Destination.
//  output  [MTDataWidth-1:0]       m_axis_tdata,   // Output: primary payload. Data to cross the interface
//  output                          m_axis_tvalid,  // Output: indicates that the transmitter is driving a valid transfer
//  output                          m_axis_tlast,   // Output: indicates the boundary of a packet
//  input                           m_axis_tready   // Output: indicates that the module can accept data
//);

//  // --------------------------------------------------------------------------
//  // Local parameters definition
//  localparam UpSizeRatio = MTDataWidth / STDataWidth;

//  // tuned for default UpSizeRatio value, but let the tool optimize depending on "UpSizeRatio" (i.e. 2)
//  localparam FSM_DU_ST_IDLE = 2'b01;
//  localparam FSM_DU_ST_GET_DATA = 2'b11;
//  localparam FSM_DU_ST_GET_LAST_BYTE =2'b10;
//  localparam FSM_DU_ST_WAITING_READY =2'b00 ;

//  // --------------------------------------------------------------------------
//  // Functions Definition
//  function integer num_bits;
//    input integer value;
//    begin
//      num_bits = 0;
//      for (num_bits = 0; value > 0; num_bits = num_bits+1) begin
//        value = value >> 1;
//      end
//    end
//  endfunction

//  function [8*8:0] state_to_str;
//    input integer value;
//    begin
//      case (value)
//        FSM_DU_ST_IDLE:
//          state_to_str={"IDLE"};
//        FSM_DU_ST_GET_DATA:
//          state_to_str={"GET_DATA"};
//        FSM_DU_ST_GET_LAST_BYTE:
//          state_to_str={"LAST_BYTE"};
//        FSM_DU_ST_WAITING_READY:
//          state_to_str={"WAITING_READY"};
//        default:
//          state_to_str={"unknown"};
//      endcase
//    end
//  endfunction


//  // --------------------------------------------------------------------------
//  // Wires and Regs definition
//  wire  [TidWidth-1:0]           fsm_generated_tid;     // Input: Data Stream Idenfitifier 
//  wire  [TdestWidth-1:0]         fsm_generated_tdest;   // Input: routing information for the data stream. Destination.
//  wire  [MTDataWidth-1:0]        fsm_generated_tdata;   // Input: primary payload. Data to cross the interface
//  wire                           fsm_generated_tvalid;  // Input: indicates that the transmitter is driving a valid transfer
//  wire                           fsm_generated_tlast;   // Input: indicates the boundary of a packet
//  wire                           fifo_wrapper_ready;  // Output: indicates that the module can accept data


//  // wires and registers for simulation
//  //synthesis_translate off
//  integer processed_bytes_counter = 0; 
//  integer processed_words_counter = 0;
//  //synthesis_translate on

  
//  // wires assignments
//  // connections between dada downsizer input ports and axis_2_native module
//  // directly connected to data downsizer input ports 
  

  
//  // connections between fifo and native to axi module
//  //assign n2a_tvalid = !rd_empty;


//  //reg [((UpSizeRatio-1)*STDataWidth)-1:0] composed_transfer_current; // contains first bytes of current transfer being recomposed
//  reg [MTDataWidth-1:0] composed_transfer_current; // contains first bytes of current transfer being recomposed


//  reg [1:0]fsm_du_current_state;
//  reg [1:0]fsm_du_next_state;
//  reg [1:0]fsm_du_prev_state;
//  reg [num_bits(UpSizeRatio)-1:0]fsm_du_current_byte_index;
  
 
//  reg [TidWidth-1:0]      s_transfer_tid;
//  reg [TdestWidth-1:0]    s_transfer_tdest;
//  reg [MTDataWidth-1:0]   s_transfer_tdata;
//  reg                     s_transfer_tlast;
//  wire                    s_transfer_tvalid;   // transfer ready for axis_to_native module
//  wire                    s_transfer_tready;
  
//  assign s_axis_tready = s_transfer_tready;
  
//  assign s_transfer_tready = s_axis_arstn &
//                             ((fsm_du_current_state == FSM_DU_ST_IDLE) |
//                              (fsm_du_current_state == FSM_DU_ST_GET_DATA) | 
//                              (((fsm_du_current_state == FSM_DU_ST_GET_LAST_BYTE) | 
//                                (fsm_du_prev_state == FSM_DU_ST_GET_LAST_BYTE)) /*& fifo_wrapper_ready */ ) 
//                              );



//  assign fsm_generated_tid    = s_transfer_tid;
//  assign fsm_generated_tdest  = s_transfer_tdest;
//  assign fsm_generated_tdata  = s_transfer_tdata;
//  assign fsm_generated_tlast  = s_transfer_tlast;
//  assign fsm_generated_tvalid = s_transfer_tvalid;
  

//  // modules instantiation 
//  fifo_type_1_async_axis_wrapper #(
//    .TDataWidth (MTDataWidth),
//    .TidWidth (TidWidth),
//    .TdestWidth (TdestWidth),
//    .SynchStages (SynchStages),
//    .FifoDepth (FifoDepth),
//    .FirstWordFallThrough (FirstWordFallThrough)
//    ) fifo_type_1_async_axis_wrapper_i(
//    // slave axi interface
//    .s_axis_aclk     (s_axis_aclk),    // Input: clock signal
//    .s_axis_arstn    (s_axis_arstn),   // Input: reset signal, active low
//    .s_axis_tid      (fsm_generated_tid),     // Input: Data Stream Idenfitifier 
//    .s_axis_tdest    (fsm_generated_tdest),   // Input: routing information for the data stream. Destination.
//    .s_axis_tdata    (fsm_generated_tdata),   // Input: primary payload. Data to cross the interface
//    .s_axis_tvalid   (fsm_generated_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
//    .s_axis_tlast    (fsm_generated_tlast),   // Input: indicates the boundary of a packet
//    .s_axis_tready   (fifo_wrapper_ready),  // Output: indicates that this module can accept data
//    //master interface
//    .m_axis_aclk     (m_axis_aclk),   // Input: clock signal
//    .m_axis_arstn    (m_axis_arstn), // Input: reset signal, active low
//    .m_axis_tid      (m_axis_tid),     // Output: Data Stream Idenfitifier 
//    .m_axis_tdest    (m_axis_tdest),   // Output: routing information for the data stream. Destination.
//    .m_axis_tdata    (m_axis_tdata),   // Output: primary payload. Data to cross the interface
//    .m_axis_tvalid   (m_axis_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
//    .m_axis_tlast    (m_axis_tlast),   // Output indicates the boundary of a packet
//    .m_axis_tready   (m_axis_tready)   // Input: indicates that the module can accept data
//    );


//  always @(posedge s_axis_aclk) begin
//    if (!s_axis_arstn) begin
//     s_transfer_tid <= 'bX;
//     s_transfer_tdest <= 'bX;
//     s_transfer_tlast <= 1'b0;
//    end else begin
//      if (s_axis_tvalid) begin
//        //if (fsm_du_current_state == FSM_DU_ST_GET_DATA) begin
//        if(fsm_du_current_byte_index == 'b0) begin
//          s_transfer_tid <= s_axis_tid;
//          s_transfer_tdest <= s_axis_tdest;
//          s_transfer_tlast <= s_axis_tlast;
//        end
//      end
//    end
//  end
///*
//  always @(posedge s_axis_aclk) begin
//    if (!s_axis_arstn) begin
//      fsm_du_current_byte_index <= UpSizeRatio -1;
//    end else begin
//      if (s_transfer_tready) begin
//        if (fsm_du_current_byte_index == 'b0) begin
//          if (fifo_wrapper_ready) begin // only reset value when it is read by the next module
//            fsm_du_current_byte_index <= UpSizeRatio -1;
//          end
//        end else begin
//          if (s_axis_tvalid) begin
//            fsm_du_current_byte_index <= fsm_du_current_byte_index - 1'b1;
//          end
//        end 
//      end
//    end
//  end
//*/
//  always @(posedge s_axis_aclk) begin
//    if (!s_axis_arstn) begin
//      fsm_du_current_byte_index <= UpSizeRatio -1;
//    end else begin
//      if (s_transfer_tready) begin
//        if (s_axis_tvalid) begin
//          if (fsm_du_current_byte_index == 'b0) begin
//            fsm_du_current_byte_index <= UpSizeRatio -1;
//          end else begin
//            fsm_du_current_byte_index <= fsm_du_current_byte_index - 1'b1;
//          end
//        end
//      end
//    end
//  end

//  always @(posedge s_axis_aclk) begin
//    if (!s_axis_arstn) begin
//      fsm_du_current_state <= FSM_DU_ST_IDLE;
//    end else begin
//      fsm_du_current_state <= fsm_du_next_state;
//    end
//  end
//  always @(posedge s_axis_aclk) begin
//    fsm_du_prev_state <= fsm_du_current_state;
//  end

//  always @(*) begin
//    fsm_du_next_state = fsm_du_current_state;

//    case (fsm_du_current_state)
//      FSM_DU_ST_IDLE: begin
//        if (s_transfer_tready  && s_axis_tvalid) begin
//          fsm_du_next_state = FSM_DU_ST_GET_DATA;
//        end
//      end
      
//      FSM_DU_ST_GET_DATA: begin
//        if (fsm_du_current_byte_index == 'd1) begin
//          if(s_axis_tvalid) begin
//            fsm_du_next_state = FSM_DU_ST_GET_LAST_BYTE;
//          end else begin
//            fsm_du_next_state = FSM_DU_ST_GET_DATA;
//          end
//        end else begin
//          fsm_du_next_state = FSM_DU_ST_GET_DATA;
//        end
//      end
//      FSM_DU_ST_GET_LAST_BYTE: begin
//      // trampa temporal siempre voy al estado de waiting, se podria llamar enable data valid o algo así, se debe activar dos ciclos y tener el dato valido en el segundo ciclo
////        if (fifo_wrapper_ready) begin
////          // next module availabe, forwarding data and getting more
////          if(m_axsi_tvalid) begin
////             fsm_du_next_state = FSM_DU_ST_GET_DATA:
////          end else begin
////            // no valid data at the input port, let's wait next transfer
////            fsm_du_next_state = FS_DU_ST_IDDLE;
////          end
////        end else begin
////          // next module does not accept data, waiting
//          fsm_du_next_state = FSM_DU_ST_WAITING_READY;
////        end
//      end
//      FSM_DU_ST_WAITING_READY: begin
//        if (fifo_wrapper_ready) begin
//          //if (tg_axis_tvalid) begin
//          //  fsm_du_next_state = FSM_DU_ST_GET_DATA;
//          //end else begin
//            fsm_du_next_state = FSM_DU_ST_IDLE;
//          //end
//        end else begin
//          fsm_du_next_state = FSM_DU_ST_WAITING_READY;
//        end
//      end
    
//    endcase
//  end

//  //  always @(posedge s_axis_aclk)
//  //assign s_transfer_tvalid = (fsm_du_current_state == FSM_DU_ST_WAITING_READY);

//  always @(posedge s_axis_aclk) begin
//    if (s_axis_tvalid && s_transfer_tready) begin
//      composed_transfer_current[STDataWidth*fsm_du_current_byte_index+:STDataWidth] = s_axis_tdata;

//      // update value only when current transfer is completed
//      if (fsm_du_current_byte_index == 0) begin
//         s_transfer_tdata <= {composed_transfer_current[MTDataWidth-1: STDataWidth], s_axis_tdata};
//      end
//    end
//  end
  
  
//  reg s_axis_tvalid_prev;
//  always @(posedge s_axis_aclk) begin
//    s_axis_tvalid_prev <= s_axis_tvalid;
//  end
  
////  always @(posedge s_axis_aclk) begin
////    //if (fsm_du_current_state == FSM_DU_ST_GET_LAST_BYTE) begin
////    //  if(fifo_wrapper_ready) begin
////    //    s_transfer_tdata <= {composed_transfer_current[MTDataWidth-1: STDataWidth], s_axis_tdata};
////    //  end
////    //else if (fsm_du_prev_state != FSM_DU_ST_GET_LAST_BYTE) begin
////    //  s_transfer_tdata <= {composed_transfer_current[MTDataWidth-1: STDataWidth], s_axis_tdata};
////    //end
////    
////    // data was captured last cycle, so tvalid signal may go low for the last transfer, so check with registered value
////    //if ((fsm_du_current_state == FSM_DU_ST_GET_LAST_BYTE) && (fsm_du_prev_state != FSM_DU_ST_GET_LAST_BYTE) && (s_axis_tvalid_prev)) begin
////    if ((fsm_du_current_state == FSM_DU_ST_GET_LAST_BYTE) && (fsm_du_prev_state != FSM_DU_ST_GET_LAST_BYTE) && (s_axis_tvalid)) begin
////        s_transfer_tdata <= {composed_transfer_current[MTDataWidth-1: STDataWidth], s_axis_tdata};
////    end
////
////  end


//  reg fsm_transfer_valid_current_state;
//  reg fsm_transfer_valid_next_state;
//  reg fsm_transfer_valid_previous_state;
  
//    // tuned for default UpSizeRatio value, but let the tool optimize depending on "UpSizeRatio" (i.e. 2)
//  localparam FSM_TRANSFER_ST_NOT_VALID = 1'b0;
//  localparam FSM_TRANSFER_ST_VALID = 1'b1;

//  assign s_transfer_tvalid = (fsm_transfer_valid_current_state == FSM_TRANSFER_ST_VALID);
  
//  always @(posedge s_axis_aclk) begin
//    fsm_transfer_valid_previous_state <= fsm_transfer_valid_current_state;
//  end
  
//  always @(posedge s_axis_aclk) begin
//    if (!s_axis_arstn) begin
//      fsm_transfer_valid_current_state <= FSM_TRANSFER_ST_NOT_VALID;
//    end else begin
//      fsm_transfer_valid_current_state <= fsm_transfer_valid_next_state;
//    end
//  end
  
//  // Currently, axi_to_native module requires the valid signal and the value
//  // to be active / stable for two cycles to correctly process the data
//  // so let's keep the valid flag active one extra cycle

  
////  always @(posedge s_axis_aclk) begin
////    if(fsm_transfer_valid_current_state == FSM_TRANSFER_ST_NOT_VALID) begin
////      fsm_transfer_valid_signal_keep_extra_cycle <= 1'b1;
////    end else begin
////      fsm_transfer_valid_signal_keep_extra_cycle <= 1'b0;
////    end
////  end 
//  localparam integer FSM_TRANSFER_VALID_SIGNAL_EXTRA_CYCLES_VALUE = 0;
//  reg [7:0] fsm_transfer_valid_signal_extra_cycles_remaining;
//  always @(posedge s_axis_aclk) begin
//    if(fsm_transfer_valid_current_state == FSM_TRANSFER_ST_NOT_VALID) begin
//      fsm_transfer_valid_signal_extra_cycles_remaining <= FSM_TRANSFER_VALID_SIGNAL_EXTRA_CYCLES_VALUE;
//    end else begin
//      if (fifo_wrapper_ready) begin
//        if (fsm_transfer_valid_signal_extra_cycles_remaining > 0) begin
//          fsm_transfer_valid_signal_extra_cycles_remaining <= fsm_transfer_valid_signal_extra_cycles_remaining - 'b1;
//        end else begin
//          fsm_transfer_valid_signal_extra_cycles_remaining <= 'b0;
//        end
//      end
//    end
//  end 
  

  
//  always @(*) begin
//    fsm_transfer_valid_next_state = fsm_transfer_valid_current_state;
    
//    case (fsm_transfer_valid_current_state)
//      FSM_TRANSFER_ST_NOT_VALID: begin
//        //// data was captured last cycle, so tvalid signal may go low for the last transfer, so check with registered value
//        ////if ((fsm_du_current_state == FSM_DU_ST_GET_LAST_BYTE) && (fsm_du_prev_state != FSM_DU_ST_GET_LAST_BYTE) && (s_axis_tvalid_prev)) begin
//        //if ((fsm_du_current_state == FSM_DU_ST_GET_LAST_BYTE) && (fsm_du_prev_state != FSM_DU_ST_GET_LAST_BYTE) && (s_axis_tvalid)) begin
//        //  fsm_transfer_valid_next_state = FSM_TRANSFER_ST_VALID;
//        // end
//        if (s_axis_tvalid && s_transfer_tready && (fsm_du_current_byte_index == 0))  begin
//          fsm_transfer_valid_next_state = FSM_TRANSFER_ST_VALID;
//        end else begin
//          fsm_transfer_valid_next_state = FSM_TRANSFER_ST_NOT_VALID;
//        end

//      end
//      FSM_TRANSFER_ST_VALID: begin
//        if(fifo_wrapper_ready) begin
//          if (fsm_transfer_valid_signal_extra_cycles_remaining > 'b0) begin
//            `ifdef DEBUG_DISPLAY_DATA_UPSIZER_ENABLE
//            $display("@axis_data_downsizer s_axis_tready signal registered, but keeping valid flag active extra cycle (remaining %2d more)for transfer: 0x%08h",
//                       fsm_transfer_valid_signal_extra_cycles_remaining - 'b1, s_transfer_tdata
//                     );
//            `endif
//            fsm_transfer_valid_next_state = FSM_TRANSFER_ST_VALID;
//          end else begin
//            fsm_transfer_valid_next_state = FSM_TRANSFER_ST_NOT_VALID;
//          end
//        end
//      end
//    endcase
//  end


//endmodule

