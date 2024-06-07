// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file axis_data_downsizer.v
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date: March 20th, 2024
//
// @title AXI4 Stream data downsizer
//
//  This module implements a dada downsizer for axi stream data transfers.
//  Incoming transfer data width is downsized from STDataWidth bits to MTDataWidth bits.
//    By default, incoming data port width is 32 bits (4 bytes) and outgoing data 
//    port width is 8 bits (1 byte), so 1 incoming data transfer is split into 4 output data transfers.
//    Axi-stream signals at the output are modified to ensure the correct 
//    relationship between data and signals is mantained.
//    Currently, Tid and Tdest fields are copied and replicated from each incoming transfer
//    to the downsized transfers, but Tlast field is set to zero to all the outgoing transfers resulting from 
//    an incoming transfer but to the last one, For the last outgoing (downsized) transfer
//    associated to an incoming transfer, the value of the Tlast field is forwarded
//    from the incoming transfer the outgoing transfer.
//
//  This module also serves to  move data across asynchronous clock domains, thus
//  it implements synchronization registers to prevent data corruption, and 
//  a fifo to prevent traffic bubbles.
//
//  WARNING: for correct woking of the module MINIMUM DOWNSIZER RATIO must be 2.
//           Parameters representing a downsize ratio of 1 would cause module malfunction.
//
// Dependencies: 
// 

`timescale 1 ns / 1 ps

//`define DEBUG_DISPLAY_DATA_DOWNSIZER_ENABLE 1

module axis_data_downsizer #(
  parameter STDataWidth = 32,  // Width of  (input)  slave data port in bits
  parameter MTDataWidth =  8,  // Width of (output) master data port in bits
  parameter TidWidth    =  8,
  parameter TdestWidth  =  8,
  parameter FifoDepth   = 16
  //parameter FirstWordFallThrough = "true" // First Word Fall Through, When set to one, data in ouptut port is available at the same time that empty signal is set to zero. When set to zero, fifo output is registered, thus updated upon rd_req signal is set to one, one cycle delay
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

  // --------------------------------------------------------------------------
  // Local parameters definition
  localparam FifoSynchStages = 2;
  localparam FirstWordFallThrough = "yes";
  localparam DownSizeRatio = STDataWidth / MTDataWidth;

  //`define  FifoDepth  64
  localparam FifoFirstWordFallThrough = "true";             // 
  //localparam FifoDepth = 16;  // Depth (size) of dual clock FIFO for incoming data through the AXI Slave port 
  localparam FifoAddressWidth = num_bits(FifoDepth-1); // number of necessary bits to represent the addresses of the fifo
  localparam FifoSyncStages = 2; // number of synchronization stages for clock domain crossing logic
  localparam FifoDataWidth = TdestWidth + TidWidth + 1 + STDataWidth; // each fifo entry must store all data and control information of the incoming axi transfer

  // wr_data = {tid, tdest, tlast, tdata}
  localparam WrDataTDataLSB = 0;
  localparam WrDataTDataMSB = WrDataTDataLSB + STDataWidth - 1;
  localparam WrDataTlastB   = WrDataTDataMSB + 1;
  localparam WrDataTdestLSB = WrDataTlastB + 1;
  localparam WrDataTdestMSB = WrDataTdestLSB + TdestWidth-1;
  localparam WrDataTidLSB   = WrDataTdestMSB +1;
  localparam WrDataTidMSB   = WrDataTidLSB + TidWidth-1;

  // tuned for default DownSizeRatio value, but let the tool optimize depending on "DownSizeRatio" (i.e. 2)
  localparam FSM_DD_ST_IDLE = 2'b01;
  localparam FSM_DD_ST_SEND_FIRST = 2'b11;
  localparam FSM_DD_ST_SEND_BODY =2'b10;
  localparam FSM_DD_ST_SEND_LAST =2'b00 ;

  // --------------------------------------------------------------------------
  // Functions Definition

//  function automatic log2 (int i);
//    if (i <= 1)
//      return 0;
//    else
//      return $log2(i/2) + 1;
//  endfunction
//
//  function int array_width (int i);
//    return $log2 (i + 1);
//  endfunction
  // returns the required number of bits to represent the "value" passed as
  // input parameter
  function integer num_bits;
    input integer value;
    begin
      num_bits = 0;
      for (num_bits = 0; value > 0; num_bits = num_bits+1) begin
        value = value >> 1;
      end
    end
  endfunction

  function [8*8:0] state_to_str;
    input integer value;
    begin
      case (value)
        FSM_DD_ST_IDLE:
          state_to_str={"IDLE"};
        FSM_DD_ST_SEND_FIRST:
          state_to_str={"FIRST"};
        FSM_DD_ST_SEND_BODY:
          state_to_str={"BODY"};
        FSM_DD_ST_SEND_LAST:
          state_to_str={"LAST"};
        default:
          state_to_str={"unknown"};
      endcase
    end
  endfunction

  // --------------------------------------------------------------------------
  // Wires and Regs definition

  // wires and registers for simulation
  //synthesis_translate off
  integer processed_words_counter = 0; 
  //synthesis_translate on

  wire rst_glbl;
  wire wr_req;  // request to write saxis data into fifo when there is space avail
  // data to write in FIFO. It comprises dest, tid , tlast and tdata ports.
  wire [(TdestWidth+TidWidth+1+STDataWidth)-1:0] wr_data ;
  wire wr_full;

  //>>> assign rst_glbl = ????; // @JM10 To-Do: complete
  assign rst_glbl =  s_axis_arstn;
  wire wr_rst;
  wire rd_rst;
  
  assign wr_rst = !s_axis_arstn;
  assign rd_rst = !m_axis_arstn;

  reg                                            rd_req;
  wire [(TdestWidth+TidWidth+1+STDataWidth)-1:0] rd_data;
  wire                                           rd_empty;
  reg [(TdestWidth+TidWidth+1+STDataWidth)-1:0]  rd_data_reg; // register copy of fifo output for downsizing operations

  
  //changes
  // wires connecting AXI streams source with AXI to NATIVE adapter
  wire [TidWidth-1:0]    a2n_tid;
  wire [TdestWidth-1:0]  a2n_tdest;
  wire [STDataWidth-1:0] a2n_tdata;
  wire                   a2n_tvalid;
  wire                   a2n_tlast;
  wire                   a2n_tready;
  // wires connecting Native flow control FIFO to AXI adapter
  wire [TidWidth-1:0]    n2a_tid;     // Input: Data Stream Idenfitifier 
  wire [TdestWidth-1:0]  n2a_tdest;   // Input: routing information for the data stream. Destination.
  //wire [DataWidth-1:0]  n2a_tdata;   // Input: primary payload. Data to cross the interface
  wire [(TdestWidth+TidWidth+1+STDataWidth)-1:0] n2a_tdata; // WARNING: Slave data width since it contains the full incoming data  "word"
  wire                   n2a_tvalid;  // Input: indicates that the transmitter is driving a valid transfer
  wire                   n2a_tlast;   // Input: indicates the boundary of a packet
  wire                   n2a_tready;  // Output:  indicates that the module can accept data

  // wires connecting Native2Axi module with FSM and output
  wire                   n2a_o_tvalid;

  // wires assignments
  // connections between dada downsizer input ports and axis_2_native module
  // directly connected to data downsizer input ports 
  
  //connections between axis_2_native and fifo modules
  assign wr_req = a2n_tvalid;

  // specify position range to avoid misalignment of data if any data field
  // is reduced(less number of bits) or removed
  assign wr_data [WrDataTidMSB:WrDataTidLSB]     = a2n_tid [TidWidth-1:0];
  assign wr_data [WrDataTdestMSB:WrDataTdestLSB] = a2n_tdest[TdestWidth-1:0];
  assign wr_data [WrDataTlastB]                  = a2n_tlast;
  assign wr_data [WrDataTDataMSB:WrDataTDataLSB] = a2n_tdata[STDataWidth-1:0];

  assign  a2n_tready = !wr_full;
  
  // connections between fifo and native to axi module
  assign n2a_tvalid = !rd_empty;

  // --------------------------------------------------------------------------
  // Moodules instantiation
  axis_2_native_fifo #(
    .STDataWidth (STDataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth)
  )
  a2nf_i(
    // slave axi interface
    .aclk            (s_axis_aclk),            // Input: clock signal
    .arstn           (s_axis_arstn),   // Input: reset signal, active low
     //
    .s_axis_tid      (s_axis_tid),     // Input: Data Stream Idenfitifier 
    .s_axis_tdest    (s_axis_tdest),   // Input: routing information for the data stream. Destination.
    .s_axis_tdata    (s_axis_tdata),   // Input: primary payload. Data to cross the interface
    .s_axis_tvalid   (s_axis_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
    .s_axis_tlast    (s_axis_tlast),   // Input: indicates the boundary of a packet
    .s_axis_tready   (s_axis_tready),  // Output: indicates that this module can accept data
    // native interface
    .m_native_tid    (a2n_tid),      
    .m_native_tdest  (a2n_tdest),   // Output: routing information for the data stream. Destination.
    .m_native_tdata  (a2n_tdata),   // Output: primary payload. Data to cross the interface
    .m_native_tvalid (a2n_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_native_tlast  (a2n_tlast),   // Output: indicates the boundary of a packet
    .m_native_tready (a2n_tready)   // Input: indicates that next module can accept data
  );



  // store incoming data (axi slave interface) into Fifo
  fifo_type_1_async #(
    .DataWidth    (FifoDataWidth),
    .AddressWidth (FifoAddressWidth),
    .SynchStages  (FifoSynchStages),
    .FirstWordFallThrough (FirstWordFallThrough)
  ) cross_clock_domain_fifo (
    .wr_clk   (s_axis_aclk),
    .wr_rst   (wr_rst),
    .wr_req   (wr_req),
    .wr_data  (wr_data),
    .wr_full  (wr_full),
    //.wr_almost_full ( ),       //-    .wr_almost_full  (awfull)
    .rd_clk   (m_axis_aclk), 
    .rd_rst   (rd_rst),
    .rd_req   (n2a_tready),     //-    .rd_req   (rd_req),
    .rd_data  (n2a_tdata),      //-    .rd_data  (rd_data),
    .rd_empty (rd_empty)
    //.rd_almost_empty ( )       //-    .rd_almost_empty (arempty)
  );

  //.fifo entry contains all the fields of (very lite) axi stream: data,tid, tlast,tdest 
  native_fifo_2_axi #(
    .STDataWidth (FifoDataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth)
  ) nf2a_i(
    // slave axi interface
    .aclk            (m_axis_aclk),    // Input: clock signal
    .arstn           (m_axis_arstn),   // Input: reset signal, active low
     // Data input from native flow control FIFO
    .s_native_tid    (n2a_tid),     // Input: Data Stream Idenfitifier 
    .s_native_tdest  (n2a_tdest),   // Input: routing information for the data stream. Destination.
    .s_native_tdata  (n2a_tdata),   // Input: primary payload. Data to cross the interface
    .s_native_tvalid (n2a_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
    .s_native_tlast  (n2a_tlast),   // Input: indicates the boundary of a packet
    .s_native_tready (n2a_tready),  // Output:  indicates that the module can accept data
    // next module with (reduced subset) AXI interface  
    .m_axis_tid      ( ),           //-    .m_axis_tid      (n2a_o_tid),     // Output: Data Stream Idenfitifier 
    .m_axis_tdest    ( ),           //-    .m_axis_tdest    (n2a_o_tdest),   // Output: routing information for the data stream. Destination.
    .m_axis_tdata    (rd_data),      //-    .m_axis_tdata    (n2a_o_tdata) //(adapter_o_tdata),   // Output: primary payload. Data to cross the interface
    .m_axis_tvalid   (n2a_o_tvalid),          //-    .m_axis_tvalid   (n2a_o_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_axis_tlast    ( ),           //-    .m_axis_tlast    (n2a_o_tlast),   // Output indicates the boundary of a packet
    .m_axis_tready   (rd_req)       //-    .m_axis_tready   (n2a_read)//(adapter_o_tready)   // Input: indicates that the module can accept data
  );
  // read data from fifo and perform the downsizing operation
  // fsm idle -> update reg with output from fifo
  //     downsize -> create new axi-s frames with  data bytes from rd_data,
  //                 and generating appropiate contol signals
  //                 tdest, tid will remain the same always (from the
  //                 rd_data_registered
  //
  //

  reg [1:0]fsm_dd_current_state;
  reg [1:0]fsm_dd_next_state;
  reg [1:0]fsm_dd_prev_state;

  reg [num_bits(DownSizeRatio)-1:0]fsm_dd_current_byte_index;
  
  // Update FSM current state each clock cycle
  always @(posedge m_axis_aclk) begin
   if( !m_axis_arstn) 
     fsm_dd_current_state <= FSM_DD_ST_IDLE;// when reset=0, reset the state of the FSM to "IDLE" State
   else
     fsm_dd_current_state <= fsm_dd_next_state; // otherwise, next state
  end 

  // resgister lass state to detect changes (update read value from fifo when not empty)
  always @(posedge m_axis_aclk) begin
    fsm_dd_prev_state <= fsm_dd_current_state;
  end

  // FSM states
  always @(*) begin
    fsm_dd_next_state = fsm_dd_current_state;
    //$display("FSM state   curr_st %s   m_axis_t_ready %d    rd_empty %d", state_to_str(fsm_dd_current_state), m_axis_tready, rd_empty);
    case (fsm_dd_current_state)
      FSM_DD_ST_IDLE: begin
        //if (m_axis_tready & !rd_empty) begin  The AXI specification says that the ready signall must not be coupled to the data valid signal
        if (n2a_o_tvalid) begin
          fsm_dd_next_state = FSM_DD_ST_SEND_FIRST;
        end
      end
      FSM_DD_ST_SEND_FIRST,
      FSM_DD_ST_SEND_BODY: begin
        if (m_axis_tready) begin
          if (fsm_dd_current_byte_index  <= 1) begin
              fsm_dd_next_state = FSM_DD_ST_SEND_LAST;
          end else begin
            fsm_dd_next_state = FSM_DD_ST_SEND_BODY;
          end
        end
      end
      FSM_DD_ST_SEND_LAST: begin
        if (m_axis_tready) begin
          if (n2a_o_tvalid) begin
            fsm_dd_next_state = FSM_DD_ST_SEND_FIRST;
          end else begin
            fsm_dd_next_state = FSM_DD_ST_IDLE;
          end
        end
      end
      default: begin
        fsm_dd_next_state = FSM_DD_ST_IDLE;
      end
    endcase
  end

  // update index for output byte multiplexing 
  always @(posedge m_axis_aclk) begin
    if (fsm_dd_current_state == FSM_DD_ST_IDLE) begin
      fsm_dd_current_byte_index <= DownSizeRatio -1;
    end else if ((fsm_dd_current_state == FSM_DD_ST_SEND_FIRST) | (fsm_dd_current_state == FSM_DD_ST_SEND_BODY)) begin
      if (m_axis_tready) begin
        fsm_dd_current_byte_index <= fsm_dd_current_byte_index - 'b1;
      end
    end else if (fsm_dd_current_state == FSM_DD_ST_SEND_LAST) begin
      if (m_axis_tready) begin
        fsm_dd_current_byte_index <= DownSizeRatio -1;
      end
    end
  end

  // update local copy of last data received from fifo when matching condition:
  wire update_registered_val_from_fifo =    (fsm_dd_current_state == FSM_DD_ST_IDLE) 
                                         || ((fsm_dd_current_state == FSM_DD_ST_SEND_LAST) & (m_axis_tready));

  always @(posedge m_axis_aclk) begin
    if (update_registered_val_from_fifo) begin
      `ifdef  DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE
      //synthesis_translate off
      //$display("UPDATE registered data from fifo to: 0x%08h", rd_data);
      if(rd_data_reg != rd_data) begin
        `ifdef DEBUG_DISPLAY_DATA_DOWNSIZER_ENABLE
        $display("@axis_data_downsizer: change value of registered data from fifo to: 0x%08h", rd_data);
        `endif
      end
      //synthesis_translate on
      `endif
      rd_data_reg <= rd_data;
    end
  end

//  localparam FSM_DD_ST_IDLE = 2'b01;
//  localparam FSM_DD_ST_SEND_FIRST = 2'b11;
//  localparam FSM_DD_ST_SEND_BODY =2'b10;
//  localparam FSM_DD_ST_SEND_LAST =2'b00 ;
  //synthesis_translate off
  always @(posedge m_axis_aclk) begin
    if (!m_axis_arstn) begin
      // reset everything
      processed_words_counter <= 0;
    end else begin
      if ((fsm_dd_current_state != FSM_DD_ST_IDLE) && (m_axis_tready == 1) ) begin
        //synthesis_translate off
        //$display("SEND word  %2d   FSM ST %8s   rd_data_reg [%d] = 0x%08h   m_axis_tdata = 0x%2h", 
        //  processed_words_counter, state_to_str(fsm_dd_current_state), fsm_dd_current_byte_index, rd_data_reg, m_axis_tdata);
        //synthesis_translate on
        if (m_axis_tready) begin
          if (fsm_dd_current_state == FSM_DD_ST_SEND_LAST) begin
            processed_words_counter = processed_words_counter + 1;
          end
        end
      end
    end
  end
  //synthesis translate on

  // update fifo output
  // remove already read value from fifo while processing and downsizing
  // current value
  always @(posedge m_axis_aclk) begin
    //synthesis_translate off
    //$display("rd_rst: %d   prev_state: %s   curr_state: %s",  rd_rst, state_to_str(fsm_dd_prev_state), state_to_str(fsm_dd_current_state));
    //synthesis_translate on
    if (rd_rst) begin
      rd_req <= 1'b0;
    end else begin
      if ((fsm_dd_current_state == FSM_DD_ST_SEND_FIRST) & (fsm_dd_prev_state != FSM_DD_ST_SEND_FIRST)) begin
        rd_req <= 1'b1;
      end else begin
        rd_req <= 1'b0;
      end
    end
  end

  wire [STDataWidth-1:0] rd_fifo_out_data; // same size as input, so output is dynamically muxed this array
  wire [TidWidth-1:0]    rd_fifo_out_tid;
  wire [TdestWidth-1:0]  rd_fifo_out_tdest;
  wire                   rd_fifo_out_tvalid;
  wire                   rd_fifo_out_tlast;

  assign rd_fifo_out_tid    = rd_data_reg [WrDataTidMSB:WrDataTidLSB];
  assign rd_fifo_out_tdest  = rd_data_reg [WrDataTdestMSB:WrDataTdestLSB] ;
  assign rd_fifo_out_tlast  = rd_data_reg [WrDataTlastB];
  assign rd_fifo_out_data   = rd_data_reg [WrDataTDataMSB:WrDataTDataLSB];
  
  assign rd_fifo_out_tvalid = (fsm_dd_current_state == FSM_DD_ST_SEND_FIRST)
                            | (fsm_dd_current_state == FSM_DD_ST_SEND_BODY)
                            | (fsm_dd_current_state == FSM_DD_ST_SEND_LAST);

  assign m_axis_tid    = rd_fifo_out_tid;
  assign m_axis_tdest  = rd_fifo_out_tdest;
  assign m_axis_tdata  = rd_fifo_out_data[fsm_dd_current_byte_index*MTDataWidth+:MTDataWidth];
  assign m_axis_tvalid = rd_fifo_out_tvalid;
  // enable tlast signal only for last byte of frame with tlast field enabled.
  assign m_axis_tlast  = rd_fifo_out_tlast & (fsm_dd_current_state == FSM_DD_ST_SEND_LAST); 
    
endmodule
