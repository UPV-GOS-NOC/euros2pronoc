// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file tb_axis_data_downsizer.v
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date: March 18th 2024
//
// @title Testbench for AXI Stream Data Downsizer module 
//
//  This module defines several tests to validate control signals behaviour
//  when fifo is full/empty and to check data correctness after downsizing packet operation.
//

`timescale 1 ns / 1 ps

//`define  DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE 1

`include "svut_h.sv"
`timescale 1 ns / 1 ps


module tb_axis_data_downsizer;

  `SVUT_SETUP
  // variables for loops
  integer i = 0;
  integer j = 0; 
  integer loop_aux = 0;
  integer values_wr;
  integer values_rd;
  integer loop_var_wr;
  integer loop_var_rd;
  integer gen_low_avail_cycles;
  integer sink_low_avail_cycles;
 
  // tested clk freq pairs rd/wr
  // {2,3} {2,5} {19,5}
  parameter ClockMasterHalfPeriod = 25; // read domain clock half period in ticks set by timescale parameter value in this source file
  parameter ClockSlaveHalfPeriod = 8; // write domain clock half period in ticks set by timescale parameter value in this source file
  
  parameter STDataWidth = 32;  // Width of  (input)  slave data port in bits
  parameter MTDataWidth =  8;  // Width of (output) master data port in bits
  parameter TidWidth    =  8;
  parameter TdestWidth  =  8;
  parameter FifoDepth   =  16;


  // testbench axi gen wires/regs
  reg tb_ena_gen;
  reg tb_tlast_req;
  // testbench axi sink wires/regs
  reg                   tb_ena_sink;
  reg [MTDataWidth-1:0] tb_tdata_out;
  wire                  tb_tdata_valid;

  reg                    tgen_m_axis_aclk;
  reg                    tgen_m_axis_arst;
  wire                   tgen_m_axis_arstn;   // low level reset signal for dd module
  reg  [TidWidth-1:0]    tgen_m_axis_tid;     // Data Stream Idenfitifier 
  reg  [TdestWidth-1:0]  tgen_m_axis_tdest;   // Data Stream destination
  reg  [STDataWidth-1:0] tgen_m_axis_tdata;   // Data
  reg                    tgen_m_axis_tvalid;  // Data in input port / register is valid
  reg                    tgen_m_axis_tlast;   // last Data chunk of tid, also for sync purposes
  wire                   tgen_m_axis_tready;  // data downsizer module can accept more data

  reg                    sink_s_axis_aclk;
  reg                    sink_s_axis_arst;
  wire                   sink_s_axis_arstn;
  wire [TidWidth-1:0]    sink_s_axis_tid; 
  wire [TdestWidth-1:0]  sink_s_axis_tdest;
  wire [MTDataWidth-1:0] sink_s_axis_tdata;
  wire                   sink_s_axis_tvalid;
  wire                   sink_s_axis_tlast;
  reg                    sink_s_axis_tready;
  
//  function integer num_bits;
//    input integer value;
//    begin
//      num_bits = 0;
//      for (num_bits = 0; value > 0; num_bits = num_bits+1) begin
//        value = value >> 1;
//      end
//    end
//  endfunction
  
  localparam DownSizeRatio = STDataWidth / MTDataWidth;

  integer record_tgen_tdata_index;
  reg  [STDataWidth-1:0] record_tgen_tdata_arr[2*FifoDepth-1:0];
  
  integer record_sink_tdata_index;
  integer record_sink_tdata_byte_index;
  reg  [STDataWidth-1:0] record_sink_tdata_curr;
  reg  [STDataWidth-1:0] record_sink_tdata_arr[2*FifoDepth-1:0];


  assign tgen_m_axis_arstn = !tgen_m_axis_arst;
  assign sink_s_axis_arstn = !sink_s_axis_arst;
  
  
   // Modules instantitation
  axis_traffic_gen #(
    .TDataWidth (STDataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth)
  ) atg_i(
    .tb_ena          (tb_ena_gen),
    .tb_tlast_req    (tb_tlast_req),
    
    .m_axis_aclk     (tgen_m_axis_aclk),  // Input: clock signal of slave domain
    .m_axis_arstn    (tgen_m_axis_arstn),   // Input: reset signal of slave main
    .m_axis_tid      (tgen_m_axis_tid),     // Output: Data Stream Idenfitifier 
    .m_axis_tdest    (tgen_m_axis_tdest),     // Output: routing information for the data stream. Destination.
    .m_axis_tdata    (tgen_m_axis_tdata),   // Output: primary payload. Data to cross the interface
    .m_axis_tvalid   (tgen_m_axis_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_axis_tlast    (tgen_m_axis_tlast),     // Output: indicates the boundary of a packet
    .m_axis_tready   (tgen_m_axis_tready)   // Input: indicates that the next module can accept data
  ); 
  

  axis_data_downsizer #(
    .STDataWidth (STDataWidth),  // Width of  (input)  slave data port in bits
    .MTDataWidth (MTDataWidth),  // Width of (output) master data port in bits
    .TidWidth    (TidWidth),
    .TdestWidth  (TdestWidth),
    .FifoDepth   (FifoDepth)
  //parameter FirstWordFallThrough = "true" // First Word Fall Through, When set to one, data in ouptut port is available at the same time that empty signal is set to zero. When set to zero, fifo output is registered, thus updated upon rd_req signal is set to one, one cycle delay
) dut_dd (
  // slave interface (data input from traffic generator)
    .s_axis_aclk     (tgen_m_axis_aclk),    // Input: clock signal of slave domain
    .s_axis_arstn    (tgen_m_axis_arstn),   // Input: reset signal of slave main
    .s_axis_tid      (tgen_m_axis_tid),     // Input: Data Stream Idenfitifier 
    .s_axis_tdest    (tgen_m_axis_tdest),   // Input: routing information for the data stream. Destination.
    .s_axis_tdata    (tgen_m_axis_tdata),   // Input: primary payload. Data to cross the interface
    .s_axis_tvalid   (tgen_m_axis_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
    .s_axis_tlast    (tgen_m_axis_tlast),   // Input: indicates the boundary of a packet
    .s_axis_tready   (tgen_m_axis_tready),  // Output: indicates that the module can accept data
  
    .m_axis_aclk     (sink_s_axis_aclk),    // Input: clock signal of slave domain
    .m_axis_arstn    (sink_s_axis_arstn),   // Input: reset signal of slave main
    .m_axis_tid      (sink_s_axis_tid),     // Output: Data Stream Idenfitifier 
    .m_axis_tdest    (sink_s_axis_tdest),   // Output: routing information for the data stream. Destination.
    .m_axis_tdata    (sink_s_axis_tdata),   // Output: primary payload. Data to cross the interface
    .m_axis_tvalid   (sink_s_axis_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_axis_tlast    (sink_s_axis_tlast),   // Output: indicates the boundary of a packet
    .m_axis_tready   (sink_s_axis_tready)   // Output: indicates that the module can accept data
);

  axis_traffic_sink #(
    .TDataWidth (MTDataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth)
  ) ats_i (
    .tb_ena          (tb_ena_sink), // module enable signal from testbench
    .tb_tdata        (tb_tdata_out),
    .tb_tvalid       (tb_tdata_valid),
    
    .s_axis_aclk     (sink_s_axis_aclk),    // Input: clock signal of slave domain
    .s_axis_arstn    (sink_s_axis_arstn),   // Input: reset signal of slave main
    .s_axis_tid      (sink_s_axis_tid),     // Input: Data Stream Idenfitifier 
    .s_axis_tdest    (sink_s_axis_tdest),   // Input: routing information for the data stream. Destination.
    .s_axis_tdata    (sink_s_axis_tdata),   // Input: primary payload. Data to cross the interface
    .s_axis_tvalid   (sink_s_axis_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
    .s_axis_tlast    (sink_s_axis_tlast),   // Input: indicates the boundary of a packet
    .s_axis_tready   (sink_s_axis_tready)   // Output: indicates that this module can accept data
  );

  //create clocks 
  initial tgen_m_axis_aclk = 1'b0;
  always #(ClockMasterHalfPeriod) tgen_m_axis_aclk <= ~tgen_m_axis_aclk;
  initial sink_s_axis_aclk = 1'b0;
  always #(ClockSlaveHalfPeriod) sink_s_axis_aclk <= ~sink_s_axis_aclk;
   
  initial begin
    $dumpvars(0, tb_axis_data_downsizer);
  end
  
  integer wr_timestamp = 0;
  always @(posedge tgen_m_axis_aclk) begin
    wr_timestamp <= wr_timestamp + 1;
  end
  integer rd_timestamp = 0;
  always @(posedge sink_s_axis_aclk) begin
    rd_timestamp <= rd_timestamp + 1;
  end
  
  // record generated data
  always @(posedge tgen_m_axis_aclk) begin
    if(tgen_m_axis_arstn) begin
      if (tgen_m_axis_tvalid) begin
        if (tgen_m_axis_tready) begin
          `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
           $display("@tb_axis_data_downsizer  record data in = 0x%08h ", tgen_m_axis_tdata);
          `endif
          record_tgen_tdata_arr[record_tgen_tdata_index] <= tgen_m_axis_tdata;
          record_tgen_tdata_index = record_tgen_tdata_index + 1;
        end
      end
    end
  end
  
  // record out data
  always @(posedge sink_s_axis_aclk) begin
    if(sink_s_axis_arstn) begin
      if (sink_s_axis_tvalid) begin
        if (sink_s_axis_tready) begin
          `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
          $display("@tb_axis_data_downsizer  record byte out [%2d] = 0x%02h ", record_sink_tdata_byte_index, tb_tdata_out);
          `endif
          //record_sink_tdata_curr[record_sink_tdata_byte_index*MTDataWidth +: MTDataWidth] = tb_tdata_out;
          record_sink_tdata_curr[record_sink_tdata_byte_index*MTDataWidth +: MTDataWidth] = sink_s_axis_tdata;
          if (record_sink_tdata_byte_index == 0) begin          
            record_sink_tdata_arr[record_sink_tdata_index] = record_sink_tdata_curr;
            `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
            $display("@tb_axis_data_downsizer  record data out = 0x%08h ", record_sink_tdata_curr);
            `endif
            record_sink_tdata_byte_index = DownSizeRatio - 1;
            record_sink_tdata_index = record_sink_tdata_index + 1;
          end else begin
            record_sink_tdata_byte_index = record_sink_tdata_byte_index - 1;
          end
        end
      end
    end
  end  
  
  task setup(string msg="Setup testcase");
  begin 
    //`ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    $display("%s. Initializing variables", msg);
    //`endif
    tgen_m_axis_arst = 1'b1;
    sink_s_axis_arst = 1'b1;
    tb_ena_gen = 1'b0;
    tb_ena_sink = 1'b0;
    gen_low_avail_cycles = 0;
    sink_low_avail_cycles = 0;
    record_tgen_tdata_index = 0;
    record_sink_tdata_index = 0;
    record_sink_tdata_byte_index = DownSizeRatio - 1;
    tb_tlast_req = 1'b0;
    
    #100;
    tgen_m_axis_arst = 0;
    sink_s_axis_arst = 0;
    
    #50;
    @(posedge tgen_m_axis_aclk);
    
  end
  endtask

  task teardown(msg="Tearing down");
  begin
    #50;
  end
  endtask

  `TEST_SUITE("AXI_STREAM_DATA_DOWNSIZER_32_TO_8_BITS")

  `UNIT_TEST("IDLE")
    `FAIL_IF(tgen_m_axis_tvalid, "Detected traffic generator data valid, generator and sink are offline");
    `FAIL_IF(tb_tdata_valid, "Detected valid data at sink, generator and sink are offline");
  `UNIT_TEST_END

  `UNIT_TEST("T_WRITE_READ")
    // BASIC Single WRITE READ 
    // without any other signal handling/monitoring
    
    // write single value to fifo
    @(posedge tgen_m_axis_aclk);
    tb_ena_gen = 1;    
    @(posedge tgen_m_axis_aclk);
    @(posedge tgen_m_axis_aclk);
    tb_ena_gen = 0;
    
    // enable traffic sink 
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    
    // wait for fifo to lower the empty flag if not already low
    @(posedge sink_s_axis_aclk);
    wait (tb_tdata_valid == 1'b1);
    
    // read the value
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
            
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 0;
    
    `FAIL_IF_NOT_EQUAL(record_tgen_tdata_arr[0], record_sink_tdata_arr[0], "GENERATED/RECEIVED data mismatch");
    
`UNIT_TEST_END


`UNIT_TEST("T_MULTIPLE_WRITE_READ")
    
    // write 2 values to fifo
    // axis_2_native module adds a delay of one cycle to the pipeline
    //  so, it is required to add this extra cycle to the loop counter
    // to wire the required number of words
    values_wr = 2;
    loop_var_wr = values_wr + 1;
    sink_low_avail_cycles = 0;
    gen_low_avail_cycles = 0;
    
    for (i = 0; i < loop_var_wr; i++) begin
      @(posedge tgen_m_axis_aclk);
      tb_ena_gen = 1;    
    end
    
    //stop traffic generation
    @(posedge tgen_m_axis_aclk);
    tb_ena_gen = 0;
    
    // Drain data, 
    //  enable traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    
    // wait for fifo to lower the empty flag, then the sink will trigger the valid data available
    @(posedge sink_s_axis_aclk);
    wait (tb_tdata_valid == 1'b1);
 
    //Enable sink dat read
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
   
    // read value in single bytes, then pause for XX cycles
    loop_var_rd = loop_var_wr  * DownSizeRatio;
    for (i = 0; i < loop_var_rd; i++) begin
      @(posedge sink_s_axis_aclk);
      tb_ena_sink = 1;    
      // could wait here inside for tb_tdata_valid == 1 as well, but not right now (Under Devel)
      for (j = 0; j < sink_low_avail_cycles; j++) begin
        @(posedge sink_s_axis_aclk);
        tb_ena_sink = 0;
      end
    end
    
    // extra cycles to ensure all data is out of memory->native_to_fifo->downsizer  
    // but should not be necessary, evenmore the tb_ena_sink is already set to 0
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);   
            
    // stop the traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 0;
    
    for (i = 0; i < values_wr; i++) begin
      if (record_tgen_tdata_arr[i] != record_sink_tdata_arr[i]) begin
        $display ("DATA mismatch 0x%08h != 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
      end
    `FAIL_IF_NOT_EQUAL(record_tgen_tdata_arr[i], record_sink_tdata_arr[i], "GENERATED/RECEIVED data mismatch");
    end
    
`UNIT_TEST_END

`UNIT_TEST("T_SINGLE_WRITE__READ_PAUSED")
    
    // write 1 value to fifo
    values_wr = 1;
    loop_var_wr = values_wr + 1;
    sink_low_avail_cycles = 1;
    
    for (i = 0; i < loop_var_wr; i++) begin
      @(posedge tgen_m_axis_aclk);
      tb_ena_gen = 1;    
    end
    
    //stop traffic generation
    @(posedge tgen_m_axis_aclk);
    tb_ena_gen = 0;
    
    // Drain data, 
    //  enable traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    
    // wait for fifo to lower the empty flag 
    @(posedge sink_s_axis_aclk);
    wait (tb_tdata_valid == 1'b1);
        
    // read value in single bytes, then pause for XX cycles
    loop_var_rd = loop_var_wr  * DownSizeRatio;
    for(i = 0; i < loop_var_rd; i++) begin
      @(posedge sink_s_axis_aclk);
      tb_ena_sink = 1;    
      for (j = 0; j < sink_low_avail_cycles; j++) begin
        @(posedge sink_s_axis_aclk);
        tb_ena_sink = 0;
      end
    end
        
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);   
    
    // stop the traffic sink    
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 0;
    
    for (i = 0; i < values_wr; i++) begin
      `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
      $display ("Compare data 0x%08h ?= 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
      `endif
      if (record_tgen_tdata_arr[i] != record_sink_tdata_arr[i]) begin
        $display ("DATA mismatch 0x%08h != 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
      end
      `FAIL_IF_NOT_EQUAL(record_tgen_tdata_arr[i], record_sink_tdata_arr[i], "GENERATED/RECEIVED data mismatch");
    end
    
`UNIT_TEST_END

`UNIT_TEST("T_MULTIPLE_WRITE_READ_PAUSED")
    
    // write 5 values to fifo
    values_wr = 5;
    loop_var_wr = values_wr + 1;
    sink_low_avail_cycles = 1;
    
    for (i = 0; i < loop_var_wr; i++) begin
      @(posedge tgen_m_axis_aclk);
      tb_ena_gen = 1;    
    end
    
    //stop traffic generation
    @(posedge tgen_m_axis_aclk);
    tb_ena_gen = 0;
    
    // Drain data, 
    //  enable traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    
    // wait for fifo to lower the empty flag 
    @(posedge sink_s_axis_aclk);
    wait (tb_tdata_valid == 1'b1);
        
    // read value in single bytes, then pause for XX cycles
    loop_var_rd = loop_var_wr  * DownSizeRatio;
    for(i = 0; i < loop_var_rd; i++) begin
      @(posedge sink_s_axis_aclk);
      tb_ena_sink = 1;    
      for (j = 0; j < sink_low_avail_cycles; j++) begin
        @(posedge sink_s_axis_aclk);
        tb_ena_sink = 0;
      end
    end
        
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);   
    
    // stop the traffic sink        
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 0;
    
    for (i = 0; i < values_wr; i++) begin
      `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
       $display ("Compare data 0x%08h ?= 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
       `endif
      if (record_tgen_tdata_arr[i] != record_sink_tdata_arr[i]) begin
        $display ("DATA mismatch 0x%08h != 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
      end
      `FAIL_IF_NOT_EQUAL(record_tgen_tdata_arr[i], record_sink_tdata_arr[i], "GENERATED/RECEIVED data mismatch");
    end

`UNIT_TEST_END


`UNIT_TEST("T_MULTIPLE_WRITE_READ")
    
    // write 2 values to fifo
    // axis_2_native module adds a delay of one cycle to the pipeline
    //  so, it is required to add this extra cycle to the loop counter
    // to wire the required number of words
    values_wr = 2;
    loop_var_wr = values_wr + 1;
    sink_low_avail_cycles = 0;
    gen_low_avail_cycles = 0;
    
    for (i = 0; i < loop_var_wr; i++) begin
      @(posedge tgen_m_axis_aclk);
      tb_ena_gen = 1;    
    end
    
    //stop traffic generation
    @(posedge tgen_m_axis_aclk);
    tb_ena_gen = 0;
    
    // Drain data, 
    //  enable traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    
    // wait for fifo to lower the empty flag, then the sink will trigger the valid data available
    @(posedge sink_s_axis_aclk);
    wait (tb_tdata_valid == 1'b1);
 
    //Enable sink dat read
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
   
    // read value in single bytes, then pause for XX cycles
    loop_var_rd = loop_var_wr  * DownSizeRatio;
    for (i = 0; i < loop_var_rd; i++) begin
      @(posedge sink_s_axis_aclk);
      tb_ena_sink = 1;    
      // could wait here inside for tb_tdata_valid == 1 as well, but not right now (Under Devel)
      for (j = 0; j < sink_low_avail_cycles; j++) begin
        @(posedge sink_s_axis_aclk);
        tb_ena_sink = 0;
      end
    end
    
    // extra cycles to ensure all data is out of memory->native_to_fifo->downsizer  
    // but should not be necessary, evenmore the tb_ena_sink is already set to 0
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);   
    
    // stop the traffic sink    
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 0;
    
    for (i = 0; i < values_wr; i++) begin
      if (record_tgen_tdata_arr[i] != record_sink_tdata_arr[i]) begin
        $display ("DATA mismatch 0x%08h != 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
      end
    `FAIL_IF_NOT_EQUAL(record_tgen_tdata_arr[i], record_sink_tdata_arr[i], "GENERATED/RECEIVED data mismatch");
    end
    
  `UNIT_TEST_END

  `UNIT_TEST("T_MULTIPLE_WRITE_READ_MULTI_PAUSED")
    
    // write 5 values to fifo
    values_wr = 5;
    loop_var_wr = values_wr + 1;
    sink_low_avail_cycles = 1;
    gen_low_avail_cycles = 1;
        
    // NOTICE, due to the behaviour of the axis_2_native module, 
    // IT requires the source keeping the valid signal at least 2 consecutive cycles
    // for it to process the data  
    for (i = 0; i < loop_var_wr; i++) begin
      @(posedge tgen_m_axis_aclk);
      tb_ena_gen = 1;  
      @(posedge tgen_m_axis_aclk)
      for (j = 0; j < gen_low_avail_cycles; j++) begin
        @(posedge tgen_m_axis_aclk);
        tb_ena_gen = 0;
      end
    end
    
    //stop traffic generation
    @(posedge tgen_m_axis_aclk);
    tb_ena_gen = 0;
    
    // Drain data, 
    //  enable traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    
    // wait for fifo to lower the empty flag 
    @(posedge sink_s_axis_aclk);
    wait (tb_tdata_valid == 1'b1);
        
    // read value in single bytes, then pause for XX cycles
    loop_var_rd = loop_var_wr  * DownSizeRatio;
    for(i = 0; i < loop_var_rd; i++) begin
      @(posedge sink_s_axis_aclk);
      tb_ena_sink = 1;    
      for (j = 0; j < sink_low_avail_cycles; j++) begin
        @(posedge sink_s_axis_aclk);
        tb_ena_sink = 0;
      end
    end
        
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);   
    
    // stop the traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 0;
    
    for (i = 0; i < values_wr; i++) begin
       `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
       $display ("Compare data 0x%08h ?= 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
       `endif
      if (record_tgen_tdata_arr[i] != record_sink_tdata_arr[i]) begin
        $display ("DATA mismatch 0x%08h != 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
      end
      `FAIL_IF_NOT_EQUAL(record_tgen_tdata_arr[i], record_sink_tdata_arr[i], "GENERATED/RECEIVED data mismatch");
    end
    
`UNIT_TEST_END

`UNIT_TEST("FILL_FLUSH_FIFO")
    
    // will attempt to generate twice values the capacity of the fifo,
    // but it will only write FifoDepth + 1 (axis_to_native internal value)
    values_wr = FifoDepth;
    loop_var_wr = (2 * values_wr) + 1; 
    sink_low_avail_cycles = 0;
    gen_low_avail_cycles = 0;
    
        // NOTICE, due to the behaviour of the axis_2_native module, 
    // IT requires the source keeping the valid signal at least 2 consecutive cycles
    // for it to process the data  
    for (i = 0; i < loop_var_wr; i++) begin
      @(posedge tgen_m_axis_aclk);
      tb_ena_gen = 1;  
      @(posedge tgen_m_axis_aclk)
      for (j = 0; j < gen_low_avail_cycles; j++) begin
        @(posedge tgen_m_axis_aclk);
        tb_ena_gen = 0;
      end
    end
    
    //stop traffic generation
    @(posedge tgen_m_axis_aclk);
    tb_ena_gen = 0;
    
    // Drain data, 
    //  enable traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    
    // wait for fifo to lower the empty flag 
    @(posedge sink_s_axis_aclk);
    wait (tb_tdata_valid == 1'b1);
        
    // read value in single bytes, then pause for XX cycles
    loop_var_rd = loop_var_wr  * DownSizeRatio;
    for(i = 0; i < loop_var_rd; i++) begin
      @(posedge sink_s_axis_aclk);
      tb_ena_sink = 1;    
      for (j = 0; j < sink_low_avail_cycles; j++) begin
        @(posedge sink_s_axis_aclk);
        tb_ena_sink = 0;
      end
    end
        
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);   
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk); 
        
    // stop the traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 0;
    
    `FAIL_IF_NOT_EQUAL(record_tgen_tdata_index, record_sink_tdata_index, "UNEXPECTED number of words read by the sink");
    `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    if (record_tgen_tdata_index != record_sink_tdata_index) begin
      $display("@tb_top: wrote %2d values read %2d values", record_tgen_tdata_index, record_sink_tdata_index);
    end
    `endif
    
    j = (record_tgen_tdata_index < record_sink_tdata_index) ? record_tgen_tdata_index : record_sink_tdata_index;
    
    for (i = 0; i < j; i++) begin
       `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
       $display ("@tb_top: Compare data 0x%08h ?= 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
       `endif
      if (record_tgen_tdata_arr[i] != record_sink_tdata_arr[i]) begin
        $display ("@tb_top: DATA mismatch 0x%08h != 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
      end
      `FAIL_IF_NOT_EQUAL(record_tgen_tdata_arr[i], record_sink_tdata_arr[i], "GENERATED/RECEIVED data mismatch");
    end
    
`UNIT_TEST_END

`UNIT_TEST("FILL_FLUSH_FIFO_INTERLEAVED")
    
    // will attempt to generate twice values the capacity of the fifo,
    // but it will only write FifoDepth + 1 (axis_to_native internal value)
    values_wr = FifoDepth - 2;
    loop_var_wr = (2 * values_wr) + 1; 
    sink_low_avail_cycles = 0;
    gen_low_avail_cycles = 1;
        
    // NOTICE, due to the behaviour of the axis_2_native module, 
    // IT requires the source keeping the valid signal at least 2 consecutive cycles
    // for it to process the data  
    for (i = 0; i < values_wr; i++) begin
      @(posedge tgen_m_axis_aclk);
      tb_ena_gen = 1;  
      @(posedge tgen_m_axis_aclk)
      for (j = 0; j < gen_low_avail_cycles; j++) begin
        @(posedge tgen_m_axis_aclk);
        tb_ena_gen = 0;
      end
    end
    @(posedge tgen_m_axis_aclk)
        
    // Start draining data, 
    //  enable traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    
    // wait for some valid data at the outpot of the module 
    @(posedge sink_s_axis_aclk);
    wait (tb_tdata_valid == 1'b1);
    
    // attempt to write some more values on the fifo,, will not write when full
    for (i = 0; i < values_wr; i++) begin
      @(posedge tgen_m_axis_aclk);
      tb_ena_gen = 1;  
      @(posedge tgen_m_axis_aclk)
      for (j = 0; j < gen_low_avail_cycles; j++) begin
        @(posedge tgen_m_axis_aclk);
        tb_ena_gen = 0;
      end
    end
    @(posedge tgen_m_axis_aclk)
    
    //Finally, stop traffic generation
    @(posedge tgen_m_axis_aclk);
    tb_ena_gen = 0;
        
    // read value in single bytes, then pause for XX cycles
    loop_var_rd = loop_var_wr  * DownSizeRatio;
    for(i = 0; i < loop_var_rd; i++) begin
      @(posedge sink_s_axis_aclk);
      tb_ena_sink = 1;    
      for (j = 0; j < sink_low_avail_cycles; j++) begin
        @(posedge sink_s_axis_aclk);
        tb_ena_sink = 0;
      end
    end
        
    // for this use case, the module will provide valid data until the fifo is empty 
    //  so let's take advantage of it
    @(posedge sink_s_axis_aclk);
    wait(tb_tdata_valid == 1'b0);
    
    $display("@tb_top: FILL_FLUSH_FIFO_INTERLEAVED wrote %2d values read %2d values", record_tgen_tdata_index, record_sink_tdata_index);
    
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 0;
    
    `FAIL_IF_NOT_EQUAL(record_tgen_tdata_index, record_sink_tdata_index, "UNEXPECTED number of words read by the sink");
    `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    if (record_tgen_tdata_index != record_sink_tdata_index) begin
      $display("@tb_top: wrote %2d values read %2d values", record_tgen_tdata_index, record_sink_tdata_index);
    end
    `endif
    
    j = (record_tgen_tdata_index < record_sink_tdata_index) ? record_tgen_tdata_index : record_sink_tdata_index;
    
    for (i = 0; i < j; i++) begin
       `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
       $display ("@tb_top: Compare data 0x%08h ?= 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
       `endif
      if (record_tgen_tdata_arr[i] != record_sink_tdata_arr[i]) begin
        $display ("@tb_top: DATA mismatch 0x%08h != 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
      end
      `FAIL_IF_NOT_EQUAL(record_tgen_tdata_arr[i], record_sink_tdata_arr[i], "GENERATED/RECEIVED data mismatch");
    end
    
`UNIT_TEST_END

`UNIT_TEST("T_TLAST")
    
    // write 2 values to fifo
    // axis_2_native module adds a delay of one cycle to the pipeline
    //  so, it is required to add this extra cycle to the loop counter
    // to wire the required number of words
    values_wr = 5;
    loop_var_wr = values_wr + 1;
    sink_low_avail_cycles = 0;
    gen_low_avail_cycles = 0;
    
    for (i = 0; i < loop_var_wr; i++) begin
      @(posedge tgen_m_axis_aclk);
      tb_ena_gen = 1;
      if (i == 2) begin
        tb_tlast_req = 1'b1;
      end else begin
        tb_tlast_req = 1'b0;
      end
    end
    
    //stop traffic generation
    @(posedge tgen_m_axis_aclk);
    tb_ena_gen = 0;
    
    // Drain data, 
    //  enable traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
    
    // wait for fifo to lower the empty flag, then the sink will trigger the valid data available
    @(posedge sink_s_axis_aclk);
    wait (tb_tdata_valid == 1'b1);
 
    //Enable sink dat read
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 1;
   
    // read value in single bytes, then pause for XX cycles
    loop_var_rd = loop_var_wr  * DownSizeRatio;
    for (i = 0; i < loop_var_rd; i++) begin
      @(posedge sink_s_axis_aclk);
      tb_ena_sink = 1;    
      // could wait here inside for tb_tdata_valid == 1 as well, but not right now (Under Devel)
      for (j = 0; j < sink_low_avail_cycles; j++) begin
        @(posedge sink_s_axis_aclk);
        tb_ena_sink = 0;
      end
    end
    
    // extra cycles to ensure all data is out of memory->native_to_fifo->downsizer  
    // but should not be necessary, evenmore the tb_ena_sink is already set to 0
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);
    @(posedge sink_s_axis_aclk);   
            
    // stop the traffic sink
    @(posedge sink_s_axis_aclk);
    tb_ena_sink = 0;
    
    for (i = 0; i < values_wr; i++) begin
      if (record_tgen_tdata_arr[i] != record_sink_tdata_arr[i]) begin
        $display ("DATA mismatch 0x%08h != 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
      end
    `FAIL_IF_NOT_EQUAL(record_tgen_tdata_arr[i], record_sink_tdata_arr[i], "GENERATED/RECEIVED data mismatch");
    end
    
`UNIT_TEST_END

`TEST_SUITE_END

endmodule
