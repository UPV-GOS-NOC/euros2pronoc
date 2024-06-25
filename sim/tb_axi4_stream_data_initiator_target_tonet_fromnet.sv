// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file tb_axis_data_upsizer.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date April 9th, 2024
//
//
// @title Testbench for AXI 4 stream conversion to Flits, ready for NoC injection and way back 
//  from NoC's Flit format to AXI4 stream
//
//  This module connects
// 
//  +-----------+       +--------+       +------+       +----------+       +--------+                                                                   
//  |   AXI4    |       |        |       |      |       |          |       |  AXI4  |
//  |  Stream   |------>| to_net |------>| FIFO |------>| from_net |------>| Stream |
//  | Initiator |       |        |       |      |       |          |       | Target |
//  +-----------+       +--------+       +------+       +----------+       +--------+                                                                  
//
//
//                        axis              axis            NoC
//    inititator        converter          stream          packet                                  
//                       signals          downsizer        creator                                      
//
//  |                  combinational     |                 |
//  - clk_initiator                      - clk_initiator   - clk_downsizer
//                                       - clk_downsizer   - clk_network
//
//
//
//  the fifo in the middle of the data path is used to simulate traffic congestion 
//  to buffer .....
//

`timescale 1 ns / 1 ps

//`define  DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE 1

`include "svut_h.sv"
`timescale 1 ns / 1 ps

module tb_axi4_stream_data_initiator_target_tonet_fromnet;

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
  
  `SVUT_SETUP

  // Testbench Configuration Parameters
  // clock configuration for testing that modules only introduce delay but no bubbles,
  localparam integer ClockInitiatorHalfPeriod  = 40; // write domain clock half period in ticks set by timescale parameter value in this source file
  localparam integer ClockDownsizerHalfPeriod  = 10;
  localparam integer ClockNetworkHalfPeriod    = 5;
  localparam integer ClockUpsizerHalfPeriod    = 10;
  localparam integer ClockTargetHalfPeriod     = 40;

  localparam integer TDataWidth    = 32;  // Width of (output) data port in bits
  localparam integer TIdWidth      =  8; // max recommended value is 8
  localparam integer TDestWidth    =  8; // max recommended value is 4, but we are using 8
  localparam [47:0]  InitiatorMode = "SINGLE"; // NoC AXI Stream Initiator interface configuration. Stream generation mode
  localparam integer InitiatorCyclesActive = 2;
  localparam integer InitiatorCyclesPause  = 4;
  localparam integer InitiatorTransfersPerPacket = 2;
  localparam integer InitiatorPacketsPerFrame    = 2;
  localparam integer InitiatorFramesPerStream    = 2;
  localparam [63:0]  InitiatorTlastFlagTrigger   = "STREAM";

  localparam [TIdWidth-1:0]   TId   = 'h11; // Initial value of TId for stream generator
  localparam [TDestWidth-1:0] TDest = 'hDE; // Initial value of TDest for stream generator

  localparam integer NetworkIfFlitWidth              = 64;  // Network interface configuration. Size (in bits) of the data flit signal
  localparam integer NetworkIfFlitTypeWidth          = 2;  // Network interface configuration. Size (in bits) of the Flit Type signal
  localparam integer NetworkIfBroadcastWidth         = 1;  // Network interface configuration. Size (in bits) of the broadcast signal
  localparam integer NumberOfVirtualNetworks         = 3;
  localparam integer NumberOfVirtualChannelsPerVirtualNetwork = 1;
  localparam integer NetworkIfVirtualNetworkIdWidth  = num_bits( NumberOfVirtualNetworks *  NumberOfVirtualChannelsPerVirtualNetwork);  // Network interface configuration. Size (in bits) of the Virtual Network identifier
  localparam integer NetworkIfVirtualChannelIdWidth  = 2;
  
  // regs for clks and resets
  reg    clk_initiator;
  reg    clk_downsizer;
  reg    clk_network;
  reg    clk_upsizer;
  reg    clk_target;
  //
  reg    rst_initiator_n;
  reg    rst_downsizer;
  reg    rst_network;
  reg    rst_upsizer;
  reg    rst_target_n;
  //
  wire   downsizer_clk;
  wire   upsizer_clk;
  wire   downsizer_rst;
  wire   upsizer_rst;

  // Wires connecting stream_data_initiator (output) and axistream_tonet (input)
  wire                   initiator_m_axis_clk;     // clock signal
  wire                   initiator_m_axis_rst_n;   // low level reset signal for module
  wire [TIdWidth-1:0]    initiator_m_axis_tid;     // Data Stream Idenfitifier 
  wire [TDestWidth-1:0]  initiator_m_axis_tdest;   // Data Stream destination
  wire [TDataWidth-1:0]  initiator_m_axis_tdata;   // Data
  wire                   initiator_m_axis_tvalid;  // Data in input port / register is valid
  wire                   initiator_m_axis_tlast;   // last Data chunk of tid, also for sync purposes
  wire                   initiator_m_axis_tready;  // data upsizer module can accept more data
  
  // wires connecting ports of tonet_module and fromnet module
  wire                                      network_clk;
  wire                                      network_rst;
  wire                                      network_valid;
  wire                                      network_ready;
  wire [NetworkIfFlitWidth-1:0]             network_flit;
  wire [NetworkIfFlitTypeWidth-1:0]         network_flit_type;
  wire [NetworkIfBroadcastWidth-1:0]        network_broadcast;
  wire [NetworkIfVirtualChannelIdWidth-1:0] network_virtual_channel_id;

 
  // wires connecting the oputput of fromnet module and the input of the target module
  wire                    fromnet_m_axis_clk;     // clock signal
  wire                    fromnet_m_axis_rst_n;   // low level reset signal for module
  wire  [TIdWidth-1:0]    fromnet_m_axis_tid;     // Data Stream Idenfitifier 
  //wire  [TDestWidth-1:0]  fromnet_m_axis_tdest;   // Data Stream destination
  wire  [TDataWidth-1:0]  fromnet_m_axis_tdata;   // Data
  wire                    fromnet_m_axis_tvalid;  // Data in input port / register is valid
  wire                    fromnet_m_axis_tlast;   // last Data chunk of tid, also for sync purposes
  wire                    fromnet_m_axis_tready;  // data upsizer module can accept more data

  //target module error detection flag output port
  wire                   target_s_axis_terror;

  assign initiator_m_axis_clk   = clk_initiator;
  assign initiator_m_axis_rst_n = rst_initiator_n;

  assign downsizer_clk = clk_downsizer;
  assign downsizer_rst = rst_downsizer;

  assign network_clk = clk_network;
  assign network_rst = rst_network;

  assign upsizer_clk = clk_upsizer;
  assign upsizer_rst = rst_upsizer;

  assign fromnet_m_axis_clk   = clk_target;
  assign fromnet_m_axis_rst_n = rst_target_n;
  


  // Modules instantitation
  axi4_stream_initiator_type_1 #(
    .AxiStreamInitiatorIfTDataWidth    (TDataWidth), 
    .AxiStreamInitiatorIfTIdWidth      (TIdWidth), 
    .AxiStreamInitiatorIfTDestWidth    (TDestWidth), 
    .AxiStreamInitiatorIfTId           (TId), 
    .AxiStreamInitiatorIfTDest         (TDest), 
    .AxiStreamInitiatorIfInitiatorMode (InitiatorMode), // NoC AXI Stream Initiator interface configuration. Stream generation mode
    .AxiStreamInitiatorIfCyclesActive  (InitiatorCyclesActive),
    .AxiStreamInitiatorIfCyclesPause   (InitiatorCyclesPause),
    .AxiStreamInitiatorIfTransfersPerPacket (InitiatorTransfersPerPacket),
    .AxiStreamInitiatorIfPacketsPerFrame    (InitiatorPacketsPerFrame),
    .AxiStreamInitiatorIfFramesPerStream    (InitiatorFramesPerStream),
    .AxiStreamInitiatorIfTlastFlagTrigger   (InitiatorTlastFlagTrigger)
  ) axi4_stream_initiator_type_1_inst(
    .clk_m_axis_i     (initiator_m_axis_clk),     // Input: clock signal of slave domain
    .rst_m_axis_ni    (initiator_m_axis_rst_n),   // Input: reset signal of slave main
    .m_axis_tvalid_o  (initiator_m_axis_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_axis_tready_i  (initiator_m_axis_tready),   // Input: indicates that the next module can accept data
    .m_axis_tdata_o   (initiator_m_axis_tdata),   // Output: primary payload. Data to cross the interface
    .m_axis_tlast_o   (initiator_m_axis_tlast),   // Output: indicates the boundary of a packet  
    .m_axis_tid_o     (initiator_m_axis_tid),     // Output: Data Stream Idenfitifier 
    .m_axis_tdest_o   (initiator_m_axis_tdest)   // Output: routing information for the data stream. Destination.
  );


  axistream_tonet #( 
  .AxiStreamIfDataWidth           (TDataWidth),  // AXI Stream interface configuration. Size (in bits) of the data signal
  .AxiStreamIfTidWidth            (TIdWidth),  // AXI Stream interface configuration. Size (in bits) of the stream identifier signal
  .AxiStreamIfDestIdWidth         (TDestWidth),  // AXI Stream interface configuration. Size (in bits) of the stream destination signal
  //.AxiStreamIfStrobeWidth         (),  // AXI Stream interface configuration. Size (in bits) of Strobe signal
  .NetworkIfFlitWidth             (NetworkIfFlitWidth),  // Network interface configuration. Size (in bits) of the data flit signal
  .NetworkIfFlitTypeWidth         (NetworkIfFlitTypeWidth),  // Network interface configuration. Size (in bits) of the Flit Type signal
  .NetworkIfBroadcastWidth        (NetworkIfBroadcastWidth),  // Network interface configuration. Size (in bits) of the broadcast signal
  .NetworkIfVirtualChannelIdWidth (NetworkIfVirtualNetworkIdWidth)   // Network interface configuration. Size (in bits) of the Virtual Channel identifier
  ) axi_stream_tonet_inst(
    // Clocks and resets  
    .clk_axis_i        (initiator_m_axis_clk),
    .clk_network_i     (network_clk),
    .clk_downsizer_i   (downsizer_clk),
    .rst_axis_ni       (initiator_m_axis_rst_n),
    .rst_network_i     (network_rst),
    .rst_downsizer_i   (downsizer_rst),
    // AXI Stream Target interface , connecting stream generator and tonet
    .s_axis_tvalid_i   (initiator_m_axis_tvalid),
    .s_axis_tready_o   (initiator_m_axis_tready),
    .s_axis_tdata_i    (initiator_m_axis_tdata),
    .s_axis_tlast_i    (initiator_m_axis_tlast),
    .s_axis_tid_i      (initiator_m_axis_tid),
    .s_axis_tdest_i    (initiator_m_axis_tdest),
  // Network interface
    .network_valid_o         (network_valid),
    .network_ready_i         (network_ready),
    .network_flit_o          (network_flit),
    .network_flit_type_o     (network_flit_type),
    .network_broadcast_o     (network_broadcast),
    .network_virtual_channel_id_o     (network_virtual_channel_id)
    );


    // AND some magic happens here to connect the wires
    // why are the interfaces different on both sides, and the first module of the fromnet just unpacks the bus......
    // makes no sense to me why not do it externally and keep the fromnet module interface similar to the tonet module
  // Network packed signals  

  // Let's use Constant convention here since both Constant and Parameters are mixed here
  localparam integer NETWORK_FLIT_LSB = 0;
  localparam integer NETWORK_FLIT_MSB = NETWORK_FLIT_LSB + NetworkIfFlitWidth - 1;
  localparam integer NETWORK_FLIT_TYPE_LSB = NETWORK_FLIT_MSB + 1;
  localparam integer NETWORK_FLIT_TYPE_MSB = NETWORK_FLIT_TYPE_LSB + NetworkIfFlitTypeWidth - 1;
  localparam integer NETWORK_BROADCAST_LSB = NETWORK_FLIT_TYPE_MSB + 1;
  localparam integer NETWORK_BROADCAST_MSB = NETWORK_BROADCAST_LSB + NetworkIfBroadcastWidth - 1;
  localparam integer NETWORK_VIRTUAL_NETWORK_ID_LSB = NETWORK_BROADCAST_MSB + 1;
  localparam integer NETWORK_VIRTUAL_NETWORK_ID_MSB = NETWORK_VIRTUAL_NETWORK_ID_LSB + NetworkIfVirtualNetworkIdWidth - 1;
  localparam integer NetworkIfDataWidth = NetworkIfFlitWidth +
                                          NetworkIfFlitTypeWidth +
                                          NetworkIfBroadcastWidth +
                                          NetworkIfVirtualNetworkIdWidth;  // Network configuration. Size (in bits) to pack the network signals
  //
  // WARNING  el módulo to_net proporciona VIRTUAL CHANNNEL en cambio el fromnet recibe  VIRTUAL NETWORK
  //   en este caso no hay problema porque vc sólo hay uno, pero vn nay 3.... no debería haber problema porque usamos más bits para almacenar el valor
  //   y este es un testbench que no es definitivo, faltaría modulos entre medias que se encargan de asignar vn en función del trafico 
  // 

  wire [NetworkIfDataWidth-1:0] network_packed_data;
  assign network_packed_data [NETWORK_FLIT_MSB:NETWORK_FLIT_LSB]                = network_flit;
  assign network_packed_data [NETWORK_FLIT_TYPE_MSB:NETWORK_FLIT_TYPE_LSB]      = network_flit_type;
  assign network_packed_data [NETWORK_BROADCAST_MSB:NETWORK_BROADCAST_LSB]      = network_broadcast;
  assign network_packed_data [NETWORK_VIRTUAL_NETWORK_ID_MSB:NETWORK_VIRTUAL_NETWORK_ID_LSB] = network_virtual_channel_id ;

  axistream_fromnet #(
    .AxiStreamIfDataWidth     (TDataWidth),  // AXI Stream interface configuration. Size (in bits) of the data signal
    .AxiStreamIfTidWidth      (TIdWidth),  // AXI Stream interface configuration. Size (in bits) of the stream identifier signal
    .AxiStreamIfDestIdWidth   (TDestWidth),  // AXI Stream interface configuration. Size (in bits) of the stream destination signal
    .NetworkIfFlitWidth              (NetworkIfFlitWidth),  // Network interface configuration. Size (in bits) of the data flit signal
    .NetworkIfFlitTypeWidth          (NetworkIfFlitTypeWidth),  // Network interface configuration. Size (in bits) of the Flit Type signal
    .NetworkIfBroadcastWidth         (NetworkIfBroadcastWidth),  // Network interface configuration. Size (in bits) of the broadcast signal
    .NetworkIfVirtualNetworkIdWidth  (NetworkIfVirtualNetworkIdWidth)  // Network interface configuration. Size (in bits) of the Virtual Network identifier
  ) axi_stream_fromnet_inst(
  // Clocks and resets
   .clk_axis_i       (fromnet_m_axis_clk),
   .clk_network_i    (network_clk),
   .clk_upsizer_i    (upsizer_clk),

   .rst_axis_ni      (fromnet_m_axis_rst_n),
   .rst_network_i    (network_rst),
   .rst_upsizer_i    (upsizer_rst),

  // AXI Stream Initiator interface 
   .m_axis_tvalid_o    (fromnet_m_axis_tvalid),
   .m_axis_tready_i    (fromnet_m_axis_tready),
   .m_axis_tdata_o     (fromnet_m_axis_tdata),
   .m_axis_tlast_o     (fromnet_m_axis_tlast),
   .m_axis_tid_o       (fromnet_m_axis_tid),
   .m_axis_tdest_o     (froment_m_axis_tdest),

  // Network interface with packed data signals
  .network_valid_i    (network_valid),
  .network_ready_o    (network_ready),
  .network_data_i     (network_packed_data)
  );
  

  localparam integer TargetMode = "SINGLE";
  localparam integer TargetCyclesActive = 3;
  localparam integer TargetCyclesPause  = 0; 

  axi4_stream_target_type_1 #(
    .AxiStreamTargetIfTDataWidth    (TDataWidth),  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the data signal (bits per single transfer).
    .AxiStreamTargetIfTIdWidth      (TIdWidth),  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the stream identifier signal.
    .AxiStreamTargetIfTDestWidth    (TDestWidth),  // NoC AXI Stream Initiator interface configuration. Size (in bits) of the stream destination signal.
    .AxiStreamTargetIfTId           (TId),  // NoC AXI Stream Initiator interface configuration. Stream identifier signal. Initial value of Stream Id. Will automatically increase when needed
    .AxiStreamTargetIfTDest         (TDest),  // NoC AXI Stream Initiator interface configuration. Initial value of the Stream destination. Target will only process transfers matching this TDest.
    .AxiStreamTargetIfTargetMode    (TargetMode), // NoC AXI Stream Initiator interface configuration. Stream generation mode
    .AxiStreamTargetIfCyclesActive  (TargetCyclesActive),  // NoC AXI Stream Initiator interface configuration. Number of consecutive cycles the target injects data before pausing data generation.
    .AxiStreamTargetIfCyclesPause   (TargetCyclesPause),  // NoC AXI Stream Initiator interface configuration. Number of cycles the target pauses data injection before resuming data generation.
    .AxiStreamTargetIfTransfersPerPacket (InitiatorTransfersPerPacket), // NoC AXI Stream Initiator interface configuration. Number of transfers per packet of the data stream.
    .AxiStreamTargetIfPacketsPerFrame    (InitiatorPacketsPerFrame), // NoC AXI Stream Initiator interface configuration. Number of packets per frame of the data stream.
    .AxiStreamTargetIfFramesPerStream    (InitiatorFramesPerStream), // NoC AXI Stream Initiator interface configuration. Number of frames per data stream.
    .AxiStreamTargetIfTlastFlagTrigger   (InitiatorTlastFlagTrigger)   // NoC AXI Stream Initiator interface configuration. Enable "tlast" flag when trigger condition is matched. 
) axi4_stream_target_type_1_inst (
  // clocks and resets
  .clk_s_axis_i     (fromnet_m_axis_clk),   // Input: clock signal
  .rst_s_axis_ni    (fromnet_m_axis_rst_n),  // Input: low level active reset
  // AXI-Stream (Initiator) interface for NoC connection
  .s_axis_tvalid_i  (fromnet_m_axis_tvalid),
  .s_axis_tready_o  (fromnet_m_axis_tready),
  .s_axis_tdata_i   (fromnet_m_axis_tdata),
  .s_axis_tlast_i   (fromnet_m_axis_tlast),
  .s_axis_tid_i     (fromnet_m_axis_tid),
  .s_axis_tdest_i   (froment_m_axis_tdest),
  .s_axis_terror_o  (target_s_axis_terror)
  );

  // variables for loops
  integer i = 0;
  integer j = 0; 
  integer loop_aux = 0;
  integer values_wr;
  integer values_rd;
    
  //create clocks

  initial clk_initiator = 1'b0;
  always #(ClockInitiatorHalfPeriod) clk_initiator <= ~clk_initiator;
  
  initial clk_downsizer = 1'b0;
  always #(ClockDownsizerHalfPeriod) clk_downsizer <= ~clk_downsizer;
  
  initial clk_network = 1'b0;
  always #(ClockNetworkHalfPeriod) clk_network <= ~clk_network;

  initial clk_upsizer = 1'b0;
  always #(ClockUpsizerHalfPeriod) clk_upsizer <= ~clk_upsizer;
  
  initial clk_target = 1'b0;
  always #(ClockTargetHalfPeriod) clk_target <= ~clk_target;


  integer initiator_timestamp = 0;
  always @(posedge clk_initiator) begin
    initiator_timestamp <= initiator_timestamp + 64'd1;
  end
  integer target_timestamp = 0;
  always @(posedge clk_target) begin
    target_timestamp <= target_timestamp + 64'd1;
  end

  // record generated data
  localparam ArrayDepth = InitiatorTransfersPerPacket * InitiatorPacketsPerFrame * InitiatorFramesPerStream * 2; // double capacity to check wether generator overflows in testbench
  integer record_initiator_tdata_index;
  reg  [TDataWidth-1:0] record_initiator_tdata_arr[ArrayDepth-1:0];

  always @(posedge initiator_m_axis_clk) begin
    if (initiator_m_axis_rst_n) begin
      if (initiator_m_axis_tvalid) begin
        if (initiator_m_axis_tready) begin
          `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
           $display("@tb_axi4_stream_generator  record data = 0x%08h ", initiator_m_axis_tdata);
          `endif
          record_initiator_tdata_arr[record_initiator_tdata_index] <= initiator_m_axis_tdata;
          record_initiator_tdata_index <= record_initiator_tdata_index + 1;
        end
      end
    end
  end

  // for more complex systems we can also add a received data recorder
  // record received data
  //localparam ArrayDepth = InitiatorTransfersPerPacket * InitiatorPacketsPerFrame * InitiatorFramesPerStream * 2; // double capacity to check wether generator overflows in testbench
  integer record_target_tdata_index;
  reg  [TDataWidth-1:0] record_target_tdata_arr[ArrayDepth-1:0];

  always @(posedge fromnet_m_axis_clk) begin
    if (fromnet_m_axis_rst_n) begin
      if (fromnet_m_axis_tvalid) begin
        if (fromnet_m_axis_tready) begin
          `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
           $display("@tb_axi4_stream_receiver  record data = 0x%08h ", fromnet_m_axis_tdata);
          `endif
          record_target_tdata_arr[record_target_tdata_index] <= fromnet_m_axis_tdata;
          record_target_tdata_index <= record_target_tdata_index + 1;
        end
      end
    end
  end
    

  task setup(string msg="Setup testcase");
  begin 
    //`ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    $display("%s. Initializing variables", msg);
    //`endif
    rst_network           <= 1'b1;
    rst_downsizer         <= 1'b1;
    rst_upsizer           <= 1'b1;
    rst_initiator_n       <= 1'b0;
    rst_target_n          <= 1'b0;

    record_initiator_tdata_index <= 0;
    record_target_tdata_index    <= 0;
    
    for (i = 0; i < ArrayDepth; i++) begin
    record_target_tdata_arr[i] = {(TDataWidth){1'bX}};
    record_target_tdata_arr[i] = {(TDataWidth){1'bX}};
    end
    
    // exit reset status, from target -> noc -> inititator
    #(4 * ClockInitiatorHalfPeriod);
    @(posedge clk_target) begin
      rst_target_n <= 1'b1;
    end
    @(posedge clk_upsizer) begin
      rst_upsizer <= 1'b0;
    end
    @(posedge clk_network) begin
      rst_network <= 1'b0;
    end
    @(posedge clk_downsizer) begin
      rst_downsizer <= 1'b0;
    end
    
    @(posedge clk_initiator) begin
      rst_initiator_n <= 1'b1;
    end

    // end of initialization task
    #(2 * ClockInitiatorHalfPeriod);
    @(posedge initiator_m_axis_clk);
    
  end
  endtask

  task teardown(msg="Tearing down");
  begin
    #50;
  end
  endtask

  `TEST_SUITE("AXI_STREAM_GENERATOR")

  `UNIT_TEST("STREAM GENERATION AND RECEPTION")
  for(i=0; i< 256; i++) begin
     @(posedge initiator_m_axis_clk);
     // change in function of terror flag behaviour, currently a latch 
     //`FAIL_IF(target_s_axis_terror, "TARGET data mismatch or data reached wrong target");
  end
  `FAIL_IF(target_s_axis_terror, "TARGET data mismatch or data reached wrong target");
  
  values_wr = InitiatorTransfersPerPacket * InitiatorPacketsPerFrame * InitiatorFramesPerStream;
  if (record_initiator_tdata_index != values_wr) begin
    $display("ERROR @TB_A4SITT1: generated %d transfers, expected%d", record_initiator_tdata_index, values_wr);
  end
  `FAIL_IF_NOT_EQUAL(record_initiator_tdata_index, values_wr);
  
  if (record_initiator_tdata_index != record_target_tdata_index) begin
    $display("ERROR @TB_A4SITT1: send %d transfers, received %d", record_initiator_tdata_index, record_target_tdata_index);
  end
  `FAIL_IF_NOT_EQUAL(record_initiator_tdata_index , record_target_tdata_index);
  `UNIT_TEST_END
    
  `TEST_SUITE_END
endmodule

